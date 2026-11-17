import EONKit
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @State private var addingSpeaker = false
    @State private var savingPreset = false
    @State private var presetName = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 250)
                .background(Theme.window)
            Divider().overlay(Theme.hairline)
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundStyle(Theme.ink)
        .font(.system(size: 13))
        .frame(minWidth: 980, minHeight: 760)
        .sheet(isPresented: $addingSpeaker) { AddSpeakerView() }
        .alert("Save preset", isPresented: $savingPreset) {
            TextField("Name", text: $presetName)
            Button("Save") {
                let name = presetName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { model.savePreset(named: name) }
                presetName = ""
            }
            Button("Cancel", role: .cancel) { presetName = "" }
        }
    }

    @ViewBuilder private var detail: some View {
        if let speaker = model.selected, let index = model.speakers.firstIndex(where: { $0.id == speaker.id }) {
            SpeakerDetailView(speaker: speaker, index: index).id(speaker.id)
        } else {
            VStack(spacing: 12) {
                Text("No speakers yet").font(.system(size: 17, weight: .semibold))
                Button("Add speaker…") { addingSpeaker = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
        }
    }

    private var sidebar: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                CapsLabel("Speakers").padding(.horizontal, 8).padding(.bottom, 6)
                ForEach(Array(model.speakers.enumerated()), id: \.element.id) { i, s in
                    speakerRow(s, i)
                }
                Toggle(isOn: $model.linked) {
                    Label("Move all together", systemImage: "link")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.horizontal, 8)
                .padding(.top, 4)
                Button { addingSpeaker = true } label: {
                    Label("Add speaker", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkMuted)
                .padding(.horizontal, 8)
            }

            VStack(alignment: .leading, spacing: 4) {
                CapsLabel("Presets").padding(.horizontal, 8).padding(.bottom, 6)
                let active = model.activePreset(for: model.selected)
                ForEach(model.presets) { preset in
                    presetRow(preset, active: preset.id == active?.id)
                }
                Button { savingPreset = true } label: {
                    Label("Save as preset", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.inkMuted)
                .padding(.horizontal, 8)
                .disabled(model.selected?.isReady != true)
            }

            Spacer()
            HStack(spacing: 6) {
                Image(systemName: model.isInSync ? "checkmark" : "arrow.triangle.2.circlepath")
                    .foregroundStyle(model.isInSync ? Theme.play : Theme.inkMuted)
                Text(model.isInSync ? "Confirmed by the speakers" : "Syncing…")
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.inkMuted)
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 20)
    }

    private func speakerRow(_ s: Speaker, _ i: Int) -> some View {
        let on = s.id == model.selected?.id
        return Button { model.selectedID = s.id } label: {
            HStack(spacing: 10) {
                Text(Theme.badge(i))
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 22, height: 22)
                    .background(Theme.deck(i), in: RoundedRectangle(cornerRadius: Theme.radiusSm))
                    .foregroundStyle(Theme.window)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name).font(.system(size: 13, weight: .semibold))
                    Text(s.phase.label).font(.system(size: 12)).foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                if let v = s.state?.volume {
                    Text("\(v)").font(.system(size: 12)).monospacedDigit().foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 52)
            .background(on ? Theme.control : .clear, in: RoundedRectangle(cornerRadius: Theme.radiusMd))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove \(s.name)", role: .destructive) { model.central.remove(s) }
        }
    }

    private func presetRow(_ preset: Preset, active: Bool) -> some View {
        Button { model.apply(preset) } label: {
            Text(preset.name)
                .foregroundStyle(active ? Theme.accent : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                .padding(.horizontal, 8)
                .background(active ? Theme.control : .clear, in: RoundedRectangle(cornerRadius: Theme.radiusMd))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.selected?.isReady != true)
        .contextMenu {
            if !Preset.builtIn.contains(where: { $0.id == preset.id }) {
                Button("Delete preset", role: .destructive) { model.deletePreset(preset) }
            }
        }
    }
}

extension ConnectionPhase {
    var label: String {
        switch self {
        case .waiting: "Not connected"
        case .connecting: "Connecting…"
        case .syncing: "Reading settings…"
        case .ready: "Connected"
        }
    }
}
