import SwiftUI

struct AddSpeakerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add speaker").font(.system(size: 17, weight: .semibold))
                Text("Your Mac remembers it and reconnects on its own next time.").foregroundStyle(Theme.inkMuted)
            }
            VStack(alignment: .leading, spacing: 10) {
                step(1, "Turn the speaker on.")
                step(2, "Press the Bluetooth button on the back until the blue LED blinks.")
                step(3, "Close EON Connect on your phone. While it's connected, the speaker stays hidden.")
            }
            VStack(spacing: 0) {
                HStack {
                    CapsLabel("Nearby")
                    Spacer()
                    if bluetoothOff {
                        Text("Bluetooth is off").font(.system(size: 12)).foregroundStyle(Theme.inkMuted)
                    } else {
                        ProgressView().controlSize(.small)
                        Text("Searching…").font(.system(size: 12)).foregroundStyle(Theme.inkMuted)
                    }
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 40)
                Divider().overlay(Theme.hairline)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.central.discovered) { found in row(found) }
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.radiusLg))
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(32)
        .frame(width: 560, height: 560)
        .background(Theme.panel)
        .foregroundStyle(Theme.ink)
        .onAppear { model.central.startScan() }
        .onDisappear { model.central.stopScan() }
    }

    private var bluetoothOff: Bool { model.central.bluetoothState == .poweredOff }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(n)").font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(Theme.control, in: Circle())
            Text(text)
        }
    }

    private func row(_ found: DiscoveredSpeaker) -> some View {
        let index = model.speakers.firstIndex { $0.id == found.id }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(found.name).font(.system(size: 13, weight: .semibold))
                Text("Signal \(found.rssi) dBm").font(.system(size: 12)).foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            if index != nil {
                Label("Added", systemImage: "checkmark").font(.system(size: 12)).foregroundStyle(Theme.inkMuted)
            } else {
                Button("Add") { model.central.add(found) }.buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 60)
    }
}
