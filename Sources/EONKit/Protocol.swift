import Foundation

/// GATT layout of the JBL EON600-series control service (ST BlueNRG chip).
public enum GATT {
    public static let service = "F3D77ED5-AB73-27AA-A042-EA87938521DD"
    /// Commands and read requests are written here.
    public static let write = "D426E5EC-562B-D9AF-1D40-F12B121E0731"
    /// Notifies a 3-byte ack `[sequence, packetIndex, status]` per packet, plus longer unsolicited state frames.
    public static let notify = "C48FC8AC-A981-5F82-C146-225A145C34AC"
    /// Holds the answer to the last read request.
    public static let response = "C95AC8DD-9269-06A1-124D-70A92AB53BA9"
}

/// Commands this app is allowed to send. Firmware-update (0x20), MAC (0x06), rename (0x01) and
/// undocumented command bytes are deliberately not representable.
public enum Command: UInt8, Sendable, CaseIterable, Hashable {
    case mode = 0x09
    case volume = 0x0A
    case delay = 0x0C
    case switches = 0x0D
    case bassGain = 0x0E
    case trebleGain = 0x0F
    case ueq1Gain = 0x10, ueq1Frequency, ueq1Q
    case ueq2Gain = 0x13, ueq2Frequency, ueq2Q
    case ueq3Gain = 0x16, ueq3Frequency, ueq3Q
    case locate = 0x19
    case readRequest = 0x1B
    case ping = 0x1E
    case polarity = 0x1F

    /// Values read from the speaker on connect, in the order the official app uses.
    public static let syncReadOrder: [Command] = [
        .locate, .volume, .delay, .mode, .polarity,
        .bassGain, .trebleGain,
        .ueq1Gain, .ueq1Frequency, .ueq1Q,
        .ueq2Gain, .ueq2Frequency, .ueq2Q,
        .ueq3Gain, .ueq3Frequency, .ueq3Q,
        .switches,
    ]
}

/// Builds single-packet frames: `[0x96, seq, index, count, chunkLength, totalLength, command, 0x00] + payload`.
/// The official app's multi-packet split is broken, so payloads are limited to one packet.
public struct PacketEncoder: Sendable {
    public static let magic: UInt8 = 0x96
    public static let maxPayload = 12

    public private(set) var sequence: UInt8

    public init(sequence: UInt8 = 0) {
        self.sequence = sequence
    }

    public mutating func packet(_ command: Command, _ payload: [UInt8]) -> Data {
        precondition(payload.count <= Self.maxPayload, "Payload exceeds one packet")
        sequence &+= 1
        let length = UInt8(payload.count)
        return Data([Self.magic, sequence, 1, 1, length, length, command.rawValue, 0x00] + payload)
    }

    public mutating func readRequest(_ command: Command) -> Data {
        packet(.readRequest, [0x00, 0x00, command.rawValue, 0x00])
    }
}

/// Fixed-point encodings used by the EQ commands (int32 little endian, then a 0x00 byte).
enum Fixed {
    static let gainBits = 26
    static let frequencyBits = 12
    static let qBits = 26

    static func encode(_ value: Double, fractionBits: Int) -> [UInt8] {
        let raw = Int32((value * Double(1 << fractionBits)).rounded(.towardZero))
        return le32(raw) + [0x00]
    }

    static func decode(_ data: Data, fractionBits: Int) -> Double? {
        guard let raw = int32LE(data) else { return nil }
        return Double(raw) / Double(1 << fractionBits)
    }

    static func le32(_ v: Int32) -> [UInt8] {
        let u = UInt32(bitPattern: v)
        return [UInt8(u & 0xFF), UInt8(u >> 8 & 0xFF), UInt8(u >> 16 & 0xFF), UInt8(u >> 24)]
    }

    static func int32LE(_ data: Data) -> Int32? {
        let b = [UInt8](data.prefix(4))
        guard b.count == 4 else { return nil }
        return Int32(bitPattern: UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24)
    }
}

/// An unsolicited state frame on the notify characteristic: `00 00 xx <id BE16> <5 bytes>`.
public struct StateNotification: Equatable, Sendable {
    public let command: Command
    public let value: Data

    public init?(_ data: Data) {
        let b = [UInt8](data)
        guard b.count >= 10, b[0] == 0, b[1] == 0 else { return nil }
        let id = UInt16(b[3]) << 8 | UInt16(b[4])
        guard id <= UInt8.max, let command = Command(rawValue: UInt8(id)),
              [.mode, .polarity, .switches].contains(command) else { return nil }
        self.command = command
        self.value = Data(b[5..<10])
    }
}
