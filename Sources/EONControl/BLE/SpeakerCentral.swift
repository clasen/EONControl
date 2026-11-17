import CoreBluetooth
import EONKit
import Foundation
import Observation
import os

struct DiscoveredSpeaker: Identifiable, Equatable {
    let id: UUID
    var name: String
    var rssi: Int
}

/// Owns Bluetooth: remembers added speakers, keeps a pending connection to each, and scans when adding.
@MainActor
@Observable
final class SpeakerCentral: NSObject {
    private static let log = Logger(subsystem: "app.eoncontrol", category: "central")

    private(set) var speakers: [Speaker] = []
    private(set) var discovered: [DiscoveredSpeaker] = []
    private(set) var bluetoothState: CBManagerState = .unknown

    @ObservationIgnored private var manager: CBCentralManager!
    @ObservationIgnored private var peripherals: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var links: [UUID: SpeakerLink] = [:]
    @ObservationIgnored private var wantsScan = false

    override init() {
        super.init()
        let known = UserDefaults.standard.dictionary(forKey: AppConfig.Storage.knownSpeakersKey) as? [String: String] ?? [:]
        speakers = known.compactMap { key, name in UUID(uuidString: key).map { Speaker(id: $0, name: name) } }
            .sorted { $0.name < $1.name }
        manager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        wantsScan = true
        discovered = []
        if bluetoothState == .poweredOn { manager.scanForPeripherals(withServices: nil) }
    }

    func stopScan() {
        wantsScan = false
        manager.stopScan()
    }

    func add(_ found: DiscoveredSpeaker) {
        guard !speakers.contains(where: { $0.id == found.id }) else { return }
        speakers.append(Speaker(id: found.id, name: found.name))
        speakers.sort { $0.name < $1.name }
        persist()
        connect(found.id)
    }

    func remove(_ speaker: Speaker) {
        speakers.removeAll { $0.id == speaker.id }
        persist()
        if let p = peripherals.removeValue(forKey: speaker.id) { manager.cancelPeripheralConnection(p) }
        links[speaker.id] = nil
    }

    private func persist() {
        let map = Dictionary(uniqueKeysWithValues: speakers.map { ($0.id.uuidString, $0.name) })
        UserDefaults.standard.set(map, forKey: AppConfig.Storage.knownSpeakersKey)
    }

    private func connect(_ id: UUID) {
        guard bluetoothState == .poweredOn else { return }
        let peripheral = peripherals[id] ?? manager.retrievePeripherals(withIdentifiers: [id]).first
        guard let peripheral else {
            Self.log.error("No peripheral for \(id, privacy: .public)")
            return
        }
        peripherals[id] = peripheral
        speaker(id)?.phase = .connecting
        manager.connect(peripheral)
    }

    private func reconnectLater(_ id: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConfig.BLE.reconnectDelaySeconds) { [weak self] in
            guard let self, self.speaker(id) != nil else { return }
            self.connect(id)
        }
    }

    private func speaker(_ id: UUID) -> Speaker? {
        speakers.first { $0.id == id }
    }
}

extension SpeakerCentral: @MainActor CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        guard central.state == .poweredOn else {
            for s in speakers { s.detach() }
            links.removeAll()
            return
        }
        for s in speakers { connect(s.id) }
        if wantsScan { central.scanForPeripherals(withServices: nil) }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? peripheral.name ?? ""
        guard name.uppercased().hasPrefix(AppConfig.BLE.namePrefix) else { return }
        peripherals[peripheral.identifier] = peripheral
        let entry = DiscoveredSpeaker(id: peripheral.identifier, name: name, rssi: RSSI.intValue)
        if let i = discovered.firstIndex(where: { $0.id == entry.id }) {
            discovered[i] = entry
        } else {
            discovered.append(entry)
            discovered.sort { $0.name < $1.name }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let speaker = speaker(peripheral.identifier) else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        Self.log.info("Connected \(speaker.name, privacy: .public)")
        speaker.lastError = nil
        links[peripheral.identifier] = SpeakerLink(peripheral: peripheral, speaker: speaker)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Self.log.error("Connect failed: \(error?.localizedDescription ?? "-", privacy: .public)")
        speaker(peripheral.identifier)?.detach()
        reconnectLater(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        links[peripheral.identifier] = nil
        speaker(peripheral.identifier)?.detach()
        reconnectLater(peripheral.identifier)
    }
}
