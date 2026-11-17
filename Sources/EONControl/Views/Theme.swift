import EONKit
import SwiftUI

/// Blendline design tokens (dark only).
enum Theme {
    static let window = Color(hex: 0x0E0F12)
    static let background = Color(hex: 0x131519)
    static let panel = Color(hex: 0x17191D)
    static let field = Color(hex: 0x1F2227)
    static let control = Color(hex: 0x26292F)
    static let controlHover = Color(hex: 0x30333B)
    static let hairline = Color.white.opacity(0.08)
    static let ink = Color(hex: 0xEBEBEB)
    static let inkMuted = Color(hex: 0x949494)
    static let inkTertiary = Color(hex: 0x6E7178)
    static let selection = Color(hex: 0x599EFF)
    static let accent = Color(hex: 0xFF991F)
    static let play = Color(hex: 0x4CD966)
    static let waveLow = Color(hex: 0x6652F5)
    static let waveMid = Color(hex: 0xF24F99)
    static let waveHigh = Color(hex: 0xFFD6E8)
    static let decks = [Color(hex: 0x338FFF), Color(hex: 0xFF5473)]

    static func deck(_ index: Int) -> Color { decks[index % decks.count] }
    static func badge(_ index: Int) -> String { String(UnicodeScalar(UInt8(65 + index % 26))) }

    static let radiusSm: CGFloat = 4
    static let radiusMd: CGFloat = 6
    static let radiusLg: CGFloat = 10
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

struct CapsLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .kerning(0.6)
            .foregroundStyle(Theme.inkMuted)
    }
}

struct PanelBox<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: Theme.radiusLg))
    }
}

struct StepButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = 28
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: size, height: size)
                .background(Theme.control, in: RoundedRectangle(cornerRadius: Theme.radiusMd))
                .foregroundStyle(Theme.inkMuted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct Segmented<Value: Hashable>: View {
    let options: [(Value, String)]
    let selection: Value?
    let pick: (Value) -> Void
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { value, title in
                let on = value == selection
                Button { pick(value) } label: {
                    Text(title)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(on ? Theme.controlHover : .clear, in: RoundedRectangle(cornerRadius: Theme.radiusSm))
                        .foregroundStyle(on ? Theme.ink : Theme.inkMuted)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.radiusMd))
    }
}

struct PillToggle: View {
    let title: String
    let isOn: Bool
    let toggle: () -> Void
    var body: some View {
        Button(action: toggle) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 28)
                .foregroundStyle(isOn ? Theme.waveHigh : Theme.inkTertiary)
                .background(isOn ? Theme.waveMid.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: Theme.radiusMd))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusMd)
                    .stroke(isOn ? Theme.waveMid.opacity(0.5) : Theme.hairline))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

extension Double {
    var dbText: String {
        let sign = self > 0.005 ? "+" : self < -0.005 ? "−" : ""
        return sign + String(format: "%.1f", abs(self))
    }

    var hzText: String {
        self >= 1000 ? String(format: "%.1f kHz", self / 1000) : String(format: "%.0f Hz", self)
    }
}

extension Band {
    var title: String {
        switch self {
        case .bass: "Bass"
        case .ueq1: "EQ 1"
        case .ueq2: "EQ 2"
        case .ueq3: "EQ 3"
        case .treble: "Treble"
        }
    }
}
