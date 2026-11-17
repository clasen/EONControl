import CoreBluetooth
import EONKit
import Foundation
import Observation
import os

enum ConnectionPhase: Equatable {
    case waiting, connecting, syncing, ready
}

/// One EON speaker: its last known state and the queue of commands that keeps the device in step with it.
@MainActor
@Observable
final class Speaker: Identifiable {
    let id: UUID
    var name: String
    var phase: ConnectionPhase = .waiting
    var state: SpeakerState?
    var lastError: String?
    private(set) var pendingCommands = 0

    @ObservationIgnored private var link: SpeakerLink?

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    var isReady: Bool { phase == .ready && state != nil }

    /// Applies an edit locally and sends only the commands whose payload changed.
    func update(_ edit: (inout SpeakerState) -> Void) {
        guard isReady, let old = state else { return }
        var next = old
        edit(&next)
        guard next != old else { return }
        state = next
        for (command, payload) in next.changes(from: old) {
            link?.enqueue(.write(command, payload))
        }
    }

    func attach(_ link: SpeakerLink) {
        self.link = link
        phase = .syncing
        state = nil
    }

    func detach() {
        link = nil
        phase = .waiting
        pendingCommands = 0
    }

    func linkDidFinishSync(_ synced: SpeakerState) {
        state = synced
        phase = .ready
    }

    func linkDidChangeQueue(count: Int) {
        pendingCommands = count
    }

    func linkDidReceive(_ notification: StateNotification) {
        state?.apply(response: notification.value, for: notification.command)
    }
}

/// Drives one connected peripheral: discovers the control service, reads the full state, then sends
/// queued commands one at a time, each waiting for the write response.
@MainActor
final class SpeakerLink: NSObject {
    enum Operation: Equatable {
        case write(Command, [UInt8])
        case read(Command)
    }

    private static let log = Logger(subsystem: "app.eoncontrol", category: "link")

    let peripheral: CBPeripheral
    private weak var speaker: Speaker?
    private var encoder = PacketEncoder()
    private var writeChar: CBCharacteristic?
    private var responseChar: CBCharacteristic?
    private var queue: [Operation] = []
    private var inFlight: Operation?
    private var syncState: SpeakerState?

    init(peripheral: CBPeripheral, speaker: Speaker) {
        self.peripheral = peripheral
        self.speaker = speaker
        super.init()
        peripheral.delegate = self
        speaker.attach(self)
        peripheral.discoverServices([CBUUID(string: GATT.service)])
    }

    func enqueue(_ op: Operation) {
        if case .write(let command, _) = op,
           let index = queue.firstIndex(where: { if case .write(command, _) = $0 { true } else { false } }) {
            queue[index] = op
        } else {
            queue.append(op)
        }
        reportQueue()
        pump()
    }

    private func pump() {
        guard inFlight == nil, !queue.isEmpty, let writeChar else { return }
        let op = queue.removeFirst()
        inFlight = op
        let packet = switch op {
        case .write(let command, let payload): encoder.packet(command, payload)
        case .read(let command): encoder.readRequest(command)
        }
        peripheral.writeValue(packet, for: writeChar, type: .withResponse)
    }

    private func finish() {
        inFlight = nil
        reportQueue()
        if syncState != nil, queue.isEmpty, let synced = syncState {
            syncState = nil
            speaker?.linkDidFinishSync(synced)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.BLE.commandSpacingSeconds) { [weak self] in
            self?.pump()
        }
    }

    private func reportQueue() {
        speaker?.linkDidChangeQueue(count: queue.count + (inFlight == nil ? 0 : 1))
    }

    private func startSync() {
        syncState = SpeakerState(volume: 0, locate: false, sound: .factory)
        for command in Command.syncReadOrder { enqueue(.read(command)) }
    }

    private func fail(_ message: String) {
        Self.log.error("\(self.peripheral.identifier, privacy: .public): \(message, privacy: .public)")
        speaker?.lastError = message
    }
}

extension SpeakerLink: @MainActor CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == CBUUID(string: GATT.service) }) else {
            fail("Control service not found")
            return
        }
        peripheral.discoverCharacteristics(
            [GATT.write, GATT.notify, GATT.response].map { CBUUID(string: $0) }, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            switch c.uuid {
            case CBUUID(string: GATT.write): writeChar = c
            case CBUUID(string: GATT.response): responseChar = c
            case CBUUID(string: GATT.notify): peripheral.setNotifyValue(true, for: c)
            default: break
            }
        }
        guard writeChar != nil, responseChar != nil else {
            fail("Control characteristics not found")
            return
        }
        startSync()
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let op = inFlight else { return }
        if let error {
            fail("Write failed: \(error.localizedDescription)")
            finish()
            return
        }
        switch op {
        case .write:
            finish()
        case .read:
            guard let responseChar else { preconditionFailure("Read without response characteristic") }
            peripheral.readValue(for: responseChar)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let value = characteristic.value else { return }
        if characteristic.uuid == CBUUID(string: GATT.notify) {
            if let note = StateNotification(value) { speaker?.linkDidReceive(note) }
            return
        }
        guard characteristic.uuid == CBUUID(string: GATT.response), case .read(let command) = inFlight else { return }
        if let error {
            fail("Read failed: \(error.localizedDescription)")
        } else if syncState != nil {
            syncState?.apply(response: value, for: command)
        } else {
            speaker?.state?.apply(response: value, for: command)
        }
        finish()
    }
}
