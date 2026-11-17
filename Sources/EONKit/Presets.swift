import Foundation

public struct Preset: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var sound: SoundSettings

    public init(id: UUID = UUID(), name: String, sound: SoundSettings) {
        self.id = id
        self.name = name
        self.sound = sound
    }
}

public extension SoundSettings {
    /// Factory voicing as hard-coded in the official app (EON Connect `populateFactoryPreset`).
    static let factory = SoundSettings(
        bands: [
            .bass: EQBand(gain: 0, frequency: 120, q: 0.7),
            .ueq1: EQBand(gain: 0, frequency: 400, q: 1),
            .ueq2: EQBand(gain: 0, frequency: 700, q: 1),
            .ueq3: EQBand(gain: 0, frequency: 944, q: 1),
            .treble: EQBand(gain: 0, frequency: 4500, q: 0.7),
        ],
        eqPlus: true, tone: true, userEQ: true, dynamics: false,
        polarity: false, delayMs: 0, mode: .main
    )

    /// Factory sound with the crossover EQ for a subwoofer at `crossover` Hz. The speaker mode is left alone.
    static func withSubwoofer(crossover: Double) -> SoundSettings {
        var s = factory
        s.setSubwoofer(crossover: crossover)
        return s
    }

    /// Bass and EQ 1 shaped to keep the tops from piling up on a sub whose low-pass sits at `crossover` Hz;
    /// `nil` restores both bands to factory. Other bands and the speaker mode are untouched.
    mutating func setSubwoofer(crossover: Double?) {
        let bands = Self.subwooferBands(crossover: crossover)
        self[.bass] = bands.bass
        self[.ueq1] = bands.ueq1
    }

    /// The crossover whose EQ the bass and EQ 1 bands currently match: `0` for factory bands, `nil` for custom.
    var subwooferCrossover: Double? {
        ([0] + Preset.subwooferCrossovers).first { cut in
            let bands = Self.subwooferBands(crossover: cut == 0 ? nil : cut)
            return self[.bass] == bands.bass && self[.ueq1] == bands.ueq1
        }
    }

    private static func subwooferBands(crossover: Double?) -> (bass: EQBand, ueq1: EQBand) {
        guard let crossover else { return (factory[.bass], factory[.ueq1]) }
        var bass = factory[.bass]
        if crossover >= 150 { bass.gain = -6 }
        let ueq1 = EQBand(gain: crossover >= 150 ? -3 : -2, frequency: crossover, q: crossover >= 150 ? 0.9 : 1)
        return (bass, ueq1)
    }
}

public extension Preset {
    static let subwooferCrossovers: [Double] = [100, 150]

    static let builtIn: [Preset] = [
        Preset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Factory", sound: .factory),
        Preset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000100")!, name: "With sub · 100 Hz",
               sound: .withSubwoofer(crossover: 100)),
        Preset(id: UUID(uuidString: "00000000-0000-0000-0000-000000000150")!, name: "With sub · 150 Hz",
               sound: .withSubwoofer(crossover: 150)),
    ]
}
