import SwiftUI

@main
struct EONControlApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("EON Control", id: "main") {
            ContentView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1180, height: 820)

        MenuBarExtra("EON Control", systemImage: "hifispeaker.2") {
            MenuBarView()
                .environment(model)
                .preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)
    }
}
