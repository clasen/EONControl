import EONKit
import SwiftUI

struct SpeakerDetailView: View {
    @Environment(AppModel.self) private var model
    let speaker: Speaker
    let index: Int
    @State private var band: Band = .ueq1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let state = speaker.state, speaker.isReady {
                    volume(state)
                    equalizer(state)
                    output(state)
                } else {
                    waiting
                }
            }
            .padding(24)
        }
        .background(Theme.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(Theme.badge(index))
                .font(.system(size: 15, weight: .bold))
                .frame(width: 36, height: 36)
                .background(Theme.deck(index), in: RoundedRectangle(cornerRadius: Theme.radiusMd))
                .foregroundStyle(Theme.window)
            VStack(alignment: .leading, spacing: 2) {
                Text(speaker.name).font(.system(size: 17, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            if let state = speaker.state, speaker.isReady {
                Button { speaker.update { $0.locate.toggle() } } label: {
                    Label(state.locate ? "Blinking" : "Locate", systemImage: "dot.radiowaves.left.and.right")
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(state.locate ? Theme.selection.opacity(0.14) : Theme.control,
                                    in: RoundedRectangle(cornerRadius: Theme.radiusMd))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd)
                            .stroke(state.locate ? Theme.selection : Theme.hairline))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var subtitle: String {
        if let error = speaker.lastError { return error }
        switch speaker.phase {
        case .waiting: return "Waiting for the speaker"
        case .connecting: return "Connecting…"
        case .syncing: return "Reading settings…"
        case .ready: return model.linked ? "EON615 · Changes apply to all speakers" : "EON615 · This speaker only"
        }
    }

    private var waiting: some View {
        PanelBox {
            HStack(spacing: 12) {
                ProgressView().controlSize(.small)
                VStack(alignment: .leading, spacing: 4) {
                    Text(speaker.phase == .syncing ? "Reading settings…" : "Looking for \(speaker.name)")
                        .font(.system(size: 13, weight: .semibold))
                    Text("If it doesn't connect, press the Bluetooth button on the back until the blue LED blinks, and close EON Connect on your phone.")
                        .font(.system(size: 12)).foregroundStyle(Theme.inkMuted)
                }
            }
        }
    }

    private func volume(_ state: SpeakerState) -> some View {
        PanelBox {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    CapsLabel("Volume")
                    Text("\(state.volume)").font(.system(size: 28, weight: .semibold)).monospacedDigit()
                }
                .frame(minWidth: 88, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(state.volume) },
                    set: { model.setVolume(Int($0.rounded()), on: speaker) }
                ), in: 0...100)
                .tint(Theme.ink)
                .accessibilityLabel("Volume")
                StepButton(symbol: "minus", label: "Volume down", size: 36) {
                    model.setVolume(max(0, state.volume - 1), on: speaker)
                }
                StepButton(symbol: "plus", label: "Volume up", size: 36) {
                    model.setVolume(min(100, state.volume + 1), on: speaker)
                }
            }
        }
    }

    private func equalizer(_ state: SpeakerState) -> some View {
        let sound = state.sound
        return PanelBox {
            HStack(spacing: 8) {
                CapsLabel("Equalizer")
                Spacer()
                PillToggle(title: "EQ+", isOn: sound.eqPlus) { model.update { $0.sound.eqPlus.toggle() } }
                PillToggle(title: "Tone", isOn: sound.tone) { model.update { $0.sound.tone.toggle() } }
                PillToggle(title: "User EQ", isOn: sound.userEQ) { model.update { $0.sound.userEQ.toggle() } }
                Button("Flat") {
                    model.update { s in for b in Band.allCases { s.sound[b].gain = 0 } }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkMuted)
                .padding(.horizontal, 10)
            }
            EQGraph(sound: sound, selected: $band, subwooferCrossover: subwooferCrossover(sound)) { b, eq in
                model.update { $0.sound[b] = eq }
            }
            .frame(height: 280)
            HStack(spacing: 8) {
                ForEach(Band.allCases) { b in bandCard(b, sound[b]) }
            }
        }
    }

    private func bandCard(_ b: Band, _ eq: EQBand) -> some View {
        let on = b == band
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(b.title.uppercased()).font(.system(size: 10, weight: .bold)).kerning(0.6)
                Spacer()
                Text(b.isParametric ? "Bell" : "Shelf").font(.system(size: 12)).foregroundStyle(Theme.inkTertiary)
            }
            HStack {
                StepButton(symbol: "minus", label: "\(b.title) gain down") { setGain(b, eq.gain - 0.5) }
                Spacer()
                Text(eq.gain.dbText).font(.system(size: 17, weight: .semibold)).monospacedDigit()
                Spacer()
                StepButton(symbol: "plus", label: "\(b.title) gain up") { setGain(b, eq.gain + 0.5) }
            }
            HStack {
                Text(eq.frequency.hzText).foregroundStyle(Theme.inkMuted)
                Spacer()
                if b.isParametric {
                    Button { setQ(b, eq.q - 0.25) } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.plain).accessibilityLabel("\(b.title) narrower")
                    Text(String(format: "Q %.2f", eq.q)).foregroundStyle(Theme.inkTertiary)
                    Button { setQ(b, eq.q + 0.25) } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.plain).accessibilityLabel("\(b.title) wider Q")
                }
            }
            .font(.system(size: 12))
            .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.radiusMd))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd)
            .stroke(on ? Theme.selection : Color.white.opacity(0.04), lineWidth: on ? 1.5 : 1))
        .contentShape(Rectangle())
        .onTapGesture { band = b }
    }

    private func setGain(_ b: Band, _ gain: Double) {
        band = b
        model.update { $0.sound[b].gain = min(max(gain, EQBand.gainRange.lowerBound), EQBand.gainRange.upperBound) }
    }

    private func setQ(_ b: Band, _ q: Double) {
        band = b
        model.update { $0.sound[b].q = min(max(q, EQBand.qRange.lowerBound), EQBand.qRange.upperBound) }
    }

    private func subwooferCrossover(_ sound: SoundSettings) -> Double? {
        sound.subwooferCrossover.flatMap { $0 == 0 ? nil : $0 }
    }

    private func subwooferCaption(_ sound: SoundSettings) -> String {
        switch sound.subwooferCrossover {
        case 0: "Where does your sub cut off?"
        case nil: "Bass and EQ 1 are set by hand."
        default: "Crossover dip on Bass and EQ 1. Tune delay and polarity to align."
        }
    }

    private func output(_ state: SpeakerState) -> some View {
        let sound = state.sound
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16, alignment: .top)], spacing: 16) {
            PanelBox {
                CapsLabel("Delay")
                HStack {
                    StepButton(symbol: "minus", label: "Less delay", size: 36) { setDelay(sound.delayMs - 0.5) }
                    Text(String(format: "%.1f ms", sound.delayMs))
                        .font(.system(size: 17, weight: .semibold)).monospacedDigit()
                        .frame(maxWidth: .infinity)
                    StepButton(symbol: "plus", label: "More delay", size: 36) { setDelay(sound.delayMs + 0.5) }
                }
                Text(String(format: "≈ %.2f m of distance", sound.delayMs * 0.343))
                    .font(.system(size: 12)).foregroundStyle(Theme.inkTertiary)
            }
            PanelBox {
                CapsLabel("Subwoofer")
                Segmented(options: [(0.0, "None")] + Preset.subwooferCrossovers.map { ($0, "\(Int($0)) Hz") },
                          selection: sound.subwooferCrossover) { cut in
                    model.update { $0.sound.setSubwoofer(crossover: cut == 0 ? nil : cut) }
                }
                Text(subwooferCaption(sound))
                    .font(.system(size: 12)).foregroundStyle(Theme.inkTertiary)
                Toggle("Invert polarity", isOn: Binding(
                    get: { sound.polarity },
                    set: { v in model.update { $0.sound.polarity = v } }
                ))
                .toggleStyle(.switch)
            }
            PanelBox {
                CapsLabel("Speaker mode")
                Segmented(options: SpeakerMode.allCases.map { ($0, $0.title) }, selection: sound.mode) { mode in
                    model.update { $0.sound.mode = mode }
                }
            }
            PanelBox {
                CapsLabel("Processing")
                Toggle("Dynamics", isOn: Binding(
                    get: { sound.dynamics },
                    set: { v in model.update { $0.sound.dynamics = v } }
                ))
                .toggleStyle(.switch)
            }
        }
    }

    private func setDelay(_ ms: Double) {
        model.update { $0.sound.delayMs = min(max(ms, SoundSettings.delayRange.lowerBound), SoundSettings.delayRange.upperBound) }
    }
}

extension SpeakerMode {
    var title: String {
        switch self {
        case .main: "Main"
        case .monitor: "Monitor"
        case .sub: "Sub"
        case .speech: "Speech"
        }
    }
}
