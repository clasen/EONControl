import EONKit
import SwiftUI

/// Combined EQ curve on a log-frequency axis, with one draggable handle per band.
struct EQGraph: View {
    let sound: SoundSettings
    @Binding var selected: Band
    var subwooferCrossover: Double?
    let onChange: (Band, EQBand) -> Void

    private static let displayRange = 12.0
    private static let space = "eqGraph"
    private static let gridFrequencies: [(Double, String)] = [
        (50, "50"), (100, "100"), (200, "200"), (500, "500"), (1000, "1k"), (2000, "2k"), (5000, "5k"), (10000, "10k"),
    ]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in draw(ctx, size) }
                ForEach(Self.gridFrequencies, id: \.0) { f, label in
                    Text(label).font(.system(size: 10)).foregroundStyle(Theme.inkTertiary)
                        .position(x: x(f, size.width), y: size.height - 10)
                }
                ForEach([(6.0, "+6"), (0, "0 dB"), (-6, "−6")], id: \.0) { db, label in
                    Text(label).font(.system(size: 10)).foregroundStyle(Theme.inkTertiary)
                        .position(x: 22, y: y(db, size.height) - 9)
                }
                if let cut = subwooferCrossover {
                    CapsLabel("Sub to \(Int(cut)) Hz")
                        .position(x: x(cut, size.width) + 48, y: 14)
                }
                ForEach(Band.allCases) { band in handle(band, size) }
            }
            .coordinateSpace(name: Self.space)
        }
        .background(Theme.background, in: RoundedRectangle(cornerRadius: Theme.radiusMd))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("EQ curve")
    }

    private func handle(_ band: Band, _ size: CGSize) -> some View {
        let eq = sound[band]
        let on = band == selected
        return Circle()
            .fill(on ? Theme.waveHigh : Theme.background)
            .overlay(Circle().stroke(Theme.waveMid, lineWidth: on ? 0 : 2))
            .shadow(color: on ? Theme.waveMid.opacity(0.6) : .clear, radius: 4)
            .frame(width: on ? 16 : 12, height: on ? 16 : 12)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .position(x: x(eq.frequency, size.width), y: y(eq.gain, size.height))
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                .onChanged { drag in
                    selected = band
                    var next = eq
                    next.gain = clamp(gainAt(drag.location.y, size.height), EQBand.gainRange, step: 0.25)
                    if band.isParametric {
                        next.frequency = clamp(frequencyAt(drag.location.x, size.width), EQBand.frequencyRange, step: 1)
                    }
                    onChange(band, next)
                })
            .accessibilityLabel("\(band.title), \(eq.frequency.hzText), \(eq.gain.dbText) dB")
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        var grid = Path()
        for (f, _) in Self.gridFrequencies {
            grid.move(to: CGPoint(x: x(f, size.width), y: 0))
            grid.addLine(to: CGPoint(x: x(f, size.width), y: size.height))
        }
        for db in [-6.0, 6.0] {
            grid.move(to: CGPoint(x: 0, y: y(db, size.height)))
            grid.addLine(to: CGPoint(x: size.width, y: y(db, size.height)))
        }
        ctx.stroke(grid, with: .color(.white.opacity(0.06)), lineWidth: 1)
        var zero = Path()
        zero.move(to: CGPoint(x: 0, y: y(0, size.height)))
        zero.addLine(to: CGPoint(x: size.width, y: y(0, size.height)))
        ctx.stroke(zero, with: .color(.white.opacity(0.16)), lineWidth: 1)

        if let cut = subwooferCrossover {
            var line = Path()
            line.move(to: CGPoint(x: x(cut, size.width), y: 0))
            line.addLine(to: CGPoint(x: x(cut, size.width), y: size.height))
            ctx.stroke(line, with: .color(Theme.inkTertiary), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }

        let bandCurve = curve(size) { EQResponse.gain(of: selected, sound[selected], at: $0) }
        ctx.fill(closed(bandCurve, size), with: .color(Theme.waveLow.opacity(0.22)))
        let total = curve(size) { EQResponse.gain(of: sound, at: $0) }
        ctx.fill(closed(total, size), with: .color(Theme.waveMid.opacity(0.10)))
        ctx.stroke(total, with: .color(Theme.waveMid), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
    }

    private func curve(_ size: CGSize, _ gain: (Double) -> Double) -> Path {
        var p = Path()
        let steps = max(Int(size.width / 3), 2)
        for i in 0...steps {
            let px = size.width * Double(i) / Double(steps)
            let point = CGPoint(x: px, y: y(gain(frequencyAt(px, size.width)), size.height))
            i == 0 ? p.move(to: point) : p.addLine(to: point)
        }
        return p
    }

    private func closed(_ curve: Path, _ size: CGSize) -> Path {
        var p = curve
        p.addLine(to: CGPoint(x: size.width, y: y(0, size.height)))
        p.addLine(to: CGPoint(x: 0, y: y(0, size.height)))
        p.closeSubpath()
        return p
    }

    private func x(_ f: Double, _ width: Double) -> Double { log10(f / 20) / 3 * width }
    private func frequencyAt(_ x: Double, _ width: Double) -> Double { 20 * pow(1000, x / width) }
    private func y(_ db: Double, _ height: Double) -> Double {
        height / 2 - min(max(db, -Self.displayRange), Self.displayRange) / Self.displayRange * height / 2
    }
    private func gainAt(_ y: Double, _ height: Double) -> Double {
        (height / 2 - y) / (height / 2) * Self.displayRange
    }
    private func clamp(_ v: Double, _ range: ClosedRange<Double>, step: Double) -> Double {
        min(max((v / step).rounded() * step, range.lowerBound), range.upperBound)
    }
}
