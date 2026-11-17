import Foundation

enum AppConfig {
    enum BLE {
        /// Advertised local-name prefix of EON600-series speakers.
        static let namePrefix = "JBLEON"
        /// Pause between consecutive commands to one speaker (the official app uses 30 ms).
        static let commandSpacingSeconds = 0.03
        /// Delay before re-requesting a connection to a speaker that dropped or failed.
        static let reconnectDelaySeconds = 2.0
    }

    enum Input {
        /// Trackpad scroll distance, in points, that counts as one step of a scrolled control.
        static let trackpadPointsPerStep = 8.0
    }

    enum Storage {
        static let knownSpeakersKey = "knownSpeakers"
        static let linkedKey = "linked"
        static let presetsFile = "presets.json"
    }
}
