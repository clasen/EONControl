import EONKit
import Foundation
import Observation

/// App-level state: which speaker is shown, whether edits go to every speaker, and the preset library.
@MainActor
@Observable
final class AppModel {
    let central = SpeakerCentral()
    var selectedID: UUID?
    var linked: Bool {
        didSet { UserDefaults.standard.set(linked, forKey: AppConfig.Storage.linkedKey) }
    }
    private(set) var userPresets: [Preset] = []

    init() {
        linked = UserDefaults.standard.object(forKey: AppConfig.Storage.linkedKey) as? Bool ?? true
        userPresets = Self.loadPresets()
    }

    var speakers: [Speaker] { central.speakers }

    var selected: Speaker? {
        speakers.first { $0.id == selectedID } ?? speakers.first
    }

    var presets: [Preset] { Preset.builtIn + userPresets }

    var isInSync: Bool {
        speakers.allSatisfy { $0.isReady && $0.pendingCommands == 0 }
    }

    /// Speakers an edit applies to: every ready one when linked, else only the selected one.
    private var targets: [Speaker] {
        guard let selected else { return [] }
        return linked ? speakers.filter(\.isReady) : [selected]
    }

    func update(_ edit: (inout SpeakerState) -> Void) {
        for speaker in targets { speaker.update(edit) }
    }

    func setVolume(_ volume: Int, on speaker: Speaker) {
        let target = linked ? speakers.filter(\.isReady) : [speaker]
        for s in target { s.update { $0.volume = volume } }
    }

    func apply(_ preset: Preset) {
        update { $0.sound = preset.sound }
    }

    func activePreset(for speaker: Speaker?) -> Preset? {
        guard let sound = speaker?.state?.sound else { return nil }
        return presets.first { $0.sound == sound }
    }

    func savePreset(named name: String) {
        guard let sound = selected?.state?.sound else { return }
        userPresets.append(Preset(name: name, sound: sound))
        storePresets()
    }

    func deletePreset(_ preset: Preset) {
        userPresets.removeAll { $0.id == preset.id }
        storePresets()
    }

    private static var presetsURL: URL {
        let dir = URL.applicationSupportDirectory.appending(path: "EON Control", directoryHint: .isDirectory)
        return dir.appending(path: AppConfig.Storage.presetsFile)
    }

    private static func loadPresets() -> [Preset] {
        guard let data = try? Data(contentsOf: presetsURL) else { return [] }
        do {
            return try JSONDecoder().decode([Preset].self, from: data)
        } catch {
            preconditionFailure("Corrupt presets file at \(presetsURL.path): \(error)")
        }
    }

    private func storePresets() {
        let url = Self.presetsURL
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(userPresets).write(to: url, options: .atomic)
        } catch {
            selected?.lastError = "Could not save presets: \(error.localizedDescription)"
        }
    }
}
