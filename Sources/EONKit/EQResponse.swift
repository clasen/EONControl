import Foundation

/// Magnitude response of the EON's biquads (RBJ cookbook), used to draw the EQ curve.
public enum EQResponse {
    static let sampleRate = 48_000.0

    public static func gain(of settings: SoundSettings, at frequency: Double) -> Double {
        Band.allCases.reduce(0) { $0 + gain(of: $1, settings[$1], at: frequency) }
    }

    public static func gain(of band: Band, _ eq: EQBand, at frequency: Double) -> Double {
        let k = coefficients(band.kind, eq)
        let w = 2 * Double.pi * frequency / sampleRate
        let c1 = cos(w), c2 = cos(2 * w)
        let num = k.b0 * k.b0 + k.b1 * k.b1 + k.b2 * k.b2 + 2 * (k.b0 * k.b1 + k.b1 * k.b2) * c1 + 2 * k.b0 * k.b2 * c2
        let den = k.a0 * k.a0 + k.a1 * k.a1 + k.a2 * k.a2 + 2 * (k.a0 * k.a1 + k.a1 * k.a2) * c1 + 2 * k.a0 * k.a2 * c2
        return 10 * log10(num / den)
    }

    private static func coefficients(_ kind: FilterKind, _ eq: EQBand)
        -> (b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
        let a = pow(10, eq.gain / 40)
        let w0 = 2 * Double.pi * eq.frequency / sampleRate
        let c = cos(w0)
        let alpha = sin(w0) / (2 * eq.q)
        let sq = 2 * a.squareRoot() * alpha
        switch kind {
        case .bell:
            return (1 + alpha * a, -2 * c, 1 - alpha * a, 1 + alpha / a, -2 * c, 1 - alpha / a)
        case .lowShelf:
            return (a * ((a + 1) - (a - 1) * c + sq), 2 * a * ((a - 1) - (a + 1) * c), a * ((a + 1) - (a - 1) * c - sq),
                    (a + 1) + (a - 1) * c + sq, -2 * ((a - 1) + (a + 1) * c), (a + 1) + (a - 1) * c - sq)
        case .highShelf:
            return (a * ((a + 1) + (a - 1) * c + sq), -2 * a * ((a - 1) + (a + 1) * c), a * ((a + 1) + (a - 1) * c - sq),
                    (a + 1) - (a - 1) * c + sq, 2 * ((a - 1) - (a + 1) * c), (a + 1) - (a - 1) * c - sq)
        }
    }
}
