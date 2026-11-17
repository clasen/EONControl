import AppKit
import SwiftUI

extension View {
    /// Calls `action` with +1 (scroll up) or −1 (scroll down) for each scroll step while the pointer is over this view.
    /// The scroll is consumed, so the surrounding page does not move.
    func onScrollStep(_ action: @escaping (Int) -> Void) -> some View {
        modifier(ScrollStepModifier(action: action))
    }
}

private struct ScrollStepModifier: ViewModifier {
    let action: (Int) -> Void
    @State private var handler = Handler()

    func body(content: Content) -> some View {
        handler.action = action
        return content
            .contentShape(Rectangle())
            .onHover { inside in inside ? start() : stop() }
            .onDisappear(perform: stop)
    }

    private func start() {
        guard handler.monitor == nil else { return }
        let handler = handler
        handler.pending = 0
        handler.monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            var dy = event.scrollingDeltaY
            if event.isDirectionInvertedFromDevice { dy = -dy }
            if event.hasPreciseScrollingDeltas {
                handler.pending += dy
                let steps = Int(handler.pending / AppConfig.Input.trackpadPointsPerStep)
                handler.pending -= Double(steps) * AppConfig.Input.trackpadPointsPerStep
                if steps != 0 { handler.action(steps) }
            } else if dy != 0 {
                handler.action(dy > 0 ? 1 : -1)
            }
            return nil
        }
    }

    private func stop() {
        if let monitor = handler.monitor { NSEvent.removeMonitor(monitor) }
        handler.monitor = nil
    }
}

/// Holds the event monitor and the latest action, so the monitor never calls a stale closure.
private final class Handler {
    var action: (Int) -> Void = { _ in }
    var monitor: Any?
    var pending = 0.0
}
