import Foundation
import Testing
@testable import EONKit

private func bytes(_ hex: String) -> Data {
    Data(hex.split(separator: " ").map { UInt8($0, radix: 16)! })
}

@Suite("Packets match frames captured from a real EON615")
struct PacketTests {
    @Test func bassGainFrame() {
        var encoder = PacketEncoder(sequence: 0x6B)
        let payload = Fixed.encode(-83_494_016.0 / 67_108_864.0, fractionBits: Fixed.gainBits)
        #expect(encoder.packet(.bassGain, payload) == bytes("96 6c 01 01 05 05 0e 00 80 fb 05 fb 00"))
    }

    @Test func volumeFrame() {
        var encoder = PacketEncoder(sequence: 1)
        #expect(encoder.packet(.volume, [90, 0]) == bytes("96 02 01 01 02 02 0a 00 5a 00"))
    }

    @Test func readRequestFrame() {
        var encoder = PacketEncoder()
        #expect(encoder.readRequest(.volume) == bytes("96 01 01 01 04 04 1b 00 00 00 0a 00"))
    }

    @Test func sequenceWraps() {
        var encoder = PacketEncoder(sequence: 0xFF)
        #expect(encoder.packet(.ping, [0, 0])[1] == 0x00)
    }
}

@Suite("Responses read from JBLEON615.2")
struct ResponseTests {
    private func applied(_ pairs: [(Command, String)]) -> SpeakerState {
        var state = SpeakerState(volume: 0, locate: true, sound: .withSubwoofer(crossover: 150))
        for (command, hex) in pairs { state.apply(response: bytes(hex), for: command) }
        return state
    }

    @Test func decodesFactoryState() {
        let state = applied([
            (.locate, "00 00"), (.volume, "64 00"), (.delay, "00 00 00 00"), (.mode, "00 00"), (.polarity, "00 00"),
            (.bassGain, "00 00 00 00 00"), (.trebleGain, "00 00 00 00 00"),
            (.ueq1Gain, "00 00 00 00 00"), (.ueq1Frequency, "00 00 19 00 00"), (.ueq1Q, "00 00 00 04 00"),
            (.ueq2Gain, "00 00 00 00 00"), (.ueq2Frequency, "00 c0 2b 00 00"), (.ueq2Q, "00 00 00 04 00"),
            (.ueq3Gain, "00 00 00 00 00"), (.ueq3Frequency, "00 00 3b 00 00"), (.ueq3Q, "00 00 00 04 00"),
            (.switches, "01 01 01 00 00"),
        ])
        #expect(state == SpeakerState(volume: 100, locate: false, sound: .factory))
    }

    @Test func decodesNegativeGain() {
        let state = applied([(.bassGain, "c0 1a 31 fc 00")])
        #expect(abs(state.sound[.bass].gain - -0.952) < 0.001)
    }

    @Test func decodedValuesReencodeIdentically() {
        let state = applied([(.ueq1Frequency, "00 00 19 00 00"), (.ueq1Q, "00 00 00 04 00")])
        let payloads = Dictionary(uniqueKeysWithValues: state.payloads().map { ($0.0, $0.1) })
        #expect(payloads[.ueq1Frequency] == [0x00, 0x00, 0x19, 0x00, 0x00])
        #expect(payloads[.ueq1Q] == [0x00, 0x00, 0x00, 0x04, 0x00])
    }
}

@Suite("Change detection")
struct ChangeTests {
    private let base = SpeakerState(volume: 100, locate: false, sound: .factory)

    @Test func volumeOnlySendsVolume() {
        var next = base
        next.volume = 90
        let changes = next.changes(from: base)
        #expect(changes.map(\.0) == [.volume])
        #expect(changes.first?.1 == [90, 0])
    }

    @Test func bassFrequencyIsNeverSent() {
        var next = base
        next.sound[.bass].frequency = 80
        #expect(next.changes(from: base).isEmpty)
    }

    @Test func delayEncodesSamples() {
        var next = base
        next.sound.delayMs = 2.5
        #expect(next.changes(from: base).map(\.1) == [[120, 0, 0, 0]])
    }

    @Test func subwooferEQLeavesModeAlone() {
        var next = base
        next.sound.mode = .monitor
        let monitor = next
        next.sound.setSubwoofer(crossover: 150)
        #expect(Set(next.changes(from: monitor).map(\.0)) == [.bassGain, .ueq1Gain, .ueq1Frequency, .ueq1Q])
        #expect(next.sound.mode == .monitor)
        #expect(next.sound.subwooferCrossover == 150)
        next.sound.setSubwoofer(crossover: nil)
        #expect(next.sound.subwooferCrossover == 0)
        #expect(next == monitor)
    }

    @Test func noUnsafeCommandIsRepresentable() {
        #expect(Command(rawValue: 0x20) == nil)
        #expect(Command(rawValue: 0x06) == nil)
        #expect(Command(rawValue: 0x01) == nil)
    }
}

@Suite("EQ response and notifications")
struct MiscTests {
    @Test func flatIsZero() {
        #expect(abs(EQResponse.gain(of: .factory, at: 1_000)) < 1e-9)
    }

    @Test func bellReachesGainAtCenter() {
        var s = SoundSettings.factory
        s[.ueq2] = EQBand(gain: -6, frequency: 700, q: 2)
        #expect(abs(EQResponse.gain(of: s, at: 700) - -6) < 0.01)
    }

    @Test func parsesModeNotification() {
        let n = StateNotification(bytes("00 00 07 00 09 02 00 00 00 00"))
        #expect(n == StateNotification(command: .mode, value: bytes("02 00 00 00 00")))
    }

    @Test func ignoresAck() {
        #expect(StateNotification(bytes("6c 01 00")) == nil)
    }
}

extension StateNotification {
    init(command: Command, value: Data) {
        var raw: [UInt8] = [0, 0, 7, 0, command.rawValue]
        raw += [UInt8](value)
        self.init(Data(raw))!
    }
}
