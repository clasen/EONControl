import Foundation

public enum FilterKind: String, Codable, Sendable {
    case lowShelf, bell, highShelf
}

/// The five EQ bands of an EON615. Bass and treble are fixed-frequency shelves; only their gain is writable.
public enum Band: String, Codable, Sendable, CaseIterable, Identifiable {
    case bass, ueq1, ueq2, ueq3, treble

    public var id: String { rawValue }

    public var kind: FilterKind {
        switch self {
        case .bass: .lowShelf
        case .treble: .highShelf
        default: .bell
        }
    }

    public var isParametric: Bool { kind == .bell }

    var gainCommand: Command {
        switch self {
        case .bass: .bassGain
        case .treble: .trebleGain
        case .ueq1: .ueq1Gain
        case .ueq2: .ueq2Gain
        case .ueq3: .ueq3Gain
        }
    }

    var frequencyCommand: Command? {
        switch self {
        case .ueq1: .ueq1Frequency
        case .ueq2: .ueq2Frequency
        case .ueq3: .ueq3Frequency
        default: nil
        }
    }

    var qCommand: Command? {
        switch self {
        case .ueq1: .ueq1Q
        case .ueq2: .ueq2Q
        case .ueq3: .ueq3Q
        default: nil
        }
    }
}

public struct EQBand: Codable, Equatable, Sendable {
    public static let gainRange = -12.0...3.0
    public static let frequencyRange = 20.0...20_000.0
    public static let qRange = 0.25...12.0

    public var gain: Double
    public var frequency: Double
    public var q: Double

    public init(gain: Double, frequency: Double, q: Double) {
        self.gain = gain
        self.frequency = frequency
        self.q = q
    }
}

/// Crossover preset of a full-range EON. It selects a voicing, not a frequency.
public enum SpeakerMode: Int, Codable, Sendable, CaseIterable, Identifiable {
    case main = 0, monitor = 1, sub = 2, speech = 3
    public var id: Int { rawValue }
}

/// Everything a preset carries. Volume is excluded so recalling a preset never jumps the level.
public struct SoundSettings: Codable, Equatable, Sendable {
    public static let delayRange = 0.0...20.0

    public var bands: [Band: EQBand]
    public var eqPlus: Bool
    public var tone: Bool
    public var userEQ: Bool
    public var dynamics: Bool
    public var polarity: Bool
    public var delayMs: Double
    public var mode: SpeakerMode

    public init(bands: [Band: EQBand], eqPlus: Bool, tone: Bool, userEQ: Bool, dynamics: Bool,
                polarity: Bool, delayMs: Double, mode: SpeakerMode) {
        self.bands = bands
        self.eqPlus = eqPlus
        self.tone = tone
        self.userEQ = userEQ
        self.dynamics = dynamics
        self.polarity = polarity
        self.delayMs = delayMs
        self.mode = mode
    }

    public subscript(band: Band) -> EQBand {
        get {
            guard let value = bands[band] else { preconditionFailure("Missing band \(band)") }
            return value
        }
        set { bands[band] = newValue }
    }
}

public struct SpeakerState: Equatable, Sendable {
    public static let volumeRange = 0...100

    public var volume: Int
    public var locate: Bool
    public var sound: SoundSettings

    public init(volume: Int, locate: Bool, sound: SoundSettings) {
        self.volume = volume
        self.locate = locate
        self.sound = sound
    }

    /// The payload each command would carry for this state, in send order.
    public func payloads() -> [(Command, [UInt8])] {
        var out: [(Command, [UInt8])] = [
            (.polarity, [sound.polarity ? 1 : 0, 0]),
            (.mode, [UInt8(sound.mode.rawValue), 0]),
            (.delay, delayPayload()),
        ]
        for band in Band.allCases {
            let b = sound[band]
            if let cmd = band.frequencyCommand { out.append((cmd, Fixed.encode(b.frequency, fractionBits: Fixed.frequencyBits))) }
            if let cmd = band.qCommand { out.append((cmd, Fixed.encode(b.q, fractionBits: Fixed.qBits))) }
            out.append((band.gainCommand, Fixed.encode(b.gain, fractionBits: Fixed.gainBits)))
        }
        out.append((.switches, [sound.eqPlus, sound.tone, sound.userEQ, sound.dynamics].map { $0 ? 1 : 0 } + [0]))
        out.append((.volume, [UInt8(volume), 0]))
        out.append((.locate, [0, locate ? 1 : 0]))
        return out
    }

    /// Commands whose payload differs from `old`, in send order.
    public func changes(from old: SpeakerState) -> [(Command, [UInt8])] {
        let previous = Dictionary(uniqueKeysWithValues: old.payloads().map { ($0.0, $0.1) })
        return payloads().filter { previous[$0.0] != $0.1 }
    }

    private func delayPayload() -> [UInt8] {
        let samples = UInt16(truncatingIfNeeded: Int((sound.delayMs * 48).rounded(.towardZero)))
        return [UInt8(samples & 0xFF), UInt8(samples >> 8), 0, 0]
    }

    /// Applies the speaker's answer to a read request.
    public mutating func apply(response data: Data, for command: Command) {
        let b = [UInt8](data)
        switch command {
        case .volume:
            if let v = b.first { volume = Int(v) }
        case .mode:
            if let v = b.first, let mode = SpeakerMode(rawValue: Int(v)) { sound.mode = mode }
        case .delay:
            let tail = [UInt8](data.suffix(4))
            if tail.count >= 2 { sound.delayMs = Double(Int16(bitPattern: UInt16(tail[0]) | UInt16(tail[1]) << 8)) / 48 }
        case .polarity:
            if let v = b.first { sound.polarity = v == 1 }
        case .locate:
            if b.count > 1 { locate = b[1] == 1 }
        case .switches:
            if b.count >= 4 {
                sound.eqPlus = b[0] != 0
                sound.tone = b[1] != 0
                sound.userEQ = b[2] != 0
                sound.dynamics = b[3] != 0
            }
        case .readRequest, .ping:
            break
        default:
            applyEQ(data, for: command)
        }
    }

    private mutating func applyEQ(_ data: Data, for command: Command) {
        for band in Band.allCases {
            if command == band.gainCommand, let v = Fixed.decode(data, fractionBits: Fixed.gainBits) {
                sound[band].gain = v
            } else if command == band.frequencyCommand, let v = Fixed.decode(data, fractionBits: Fixed.frequencyBits) {
                sound[band].frequency = v
            } else if command == band.qCommand, let v = Fixed.decode(data, fractionBits: Fixed.qBits) {
                sound[band].q = v
            }
        }
    }
}
