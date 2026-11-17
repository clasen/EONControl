import EONKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("EON Control").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(model.speakers.filter(\.isReady).count) connected")
                    .font(.system(size: 12)).foregroundStyle(Theme.inkMuted)
            }
            ForEach(Array(model.speakers.enumerated()), id: \.element.id) { i, s in
                volumeRow(s, i)
            }
            Toggle("Move all together", isOn: $model.linked).toggleStyle(.switch)
            VStack(alignment: .leading, spacing: 6) {
                CapsLabel("Preset")
                Segmented(options: Preset.builtIn.map { ($0.id, $0.name.replacingOccurrences(of: "With sub · ", with: "Sub ")) },
                          selection: model.activePreset(for: model.selected)?.id) { id in
                    if let preset = Preset.builtIn.first(where: { $0.id == id }) { model.apply(preset) }
                }
            }
            Divider().overlay(Theme.hairline)
            Button("Open EON Control…") {
                openWindow(id: "main")
                NSApp.activate()
            }
            .buttonStyle(.plain)
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkMuted)
        }
        .padding(16)
        .frame(width: 340)
        .foregroundStyle(Theme.ink)
        .font(.system(size: 13))
    }

    private func volumeRow(_ s: Speaker, _ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(Theme.badge(i))
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 20, height: 20)
                    .background(Theme.deck(i), in: RoundedRectangle(cornerRadius: Theme.radiusSm))
                    .foregroundStyle(Theme.window)
                Text(s.name).font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(s.state.map { "\($0.volume)" } ?? s.phase.label)
                    .font(.system(size: s.isReady ? 17 : 12, weight: s.isReady ? .semibold : .regular))
                    .monospacedDigit()
            }
            if let state = s.state, s.isReady {
                Slider(value: Binding(
                    get: { Double(state.volume) },
                    set: { model.setVolume(Int($0.rounded()), on: s) }
                ), in: 0...100)
                .tint(Theme.ink)
                .accessibilityLabel("\(s.name) volume")
            }
        }
        .padding(12)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.radiusMd))
    }
}
