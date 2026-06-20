import AppKit
import SwiftUI
import FocusFlowKit

/// Drives the full-screen break experience off the timer's phase transitions.
/// Reuses the borderless-window pattern from AppDelegate's aux windows.
@MainActor
final class BreakFlowCoordinator {
    private let timerVM: TimerViewModel
    private var window: NSWindow?

    init(timerVM: TimerViewModel) {
        self.timerVM = timerVM
        timerVM.onPhaseTransition = { [weak self] finished, next in
            self?.handle(BreakPrompt.onTransition(finished: finished, next: next))
        }
    }

    private func handle(_ kind: BreakPromptKind) {
        switch kind {
        case .start(let phase):
            present(AnyView(BreakStartView(
                minutes: Int(timerVM.engine.settings.duration(for: phase) / 60),
                onStartBreath: { [weak self] in self?.presentBreathing() },
                onStartBreak: { [weak self] in self?.timerVM.start(); self?.dismiss() },
                onSkip: { [weak self] in self?.timerVM.skip(); self?.dismiss() }
            )))
        case .complete:
            present(AnyView(BreakCompleteView(
                onResume: { [weak self] in self?.timerVM.start(); self?.dismiss() },
                onExtend: { [weak self] in self?.dismiss() }
            )))
        case .none:
            break
        }
    }

    private func presentBreathing() {
        let pattern = BreathingPattern.all.first { $0.id == "box" }!
        let vm = BreathingViewModel(pattern: pattern, targetCycles: 6, ticker: DispatchSourceTimerTicker())
        present(AnyView(BreathingSessionView(vm: vm, onEnd: { [weak self] in self?.dismiss() })))
    }

    private func present(_ view: AnyView) {
        let window = self.window ?? makeFullScreenWindow()
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func dismiss() { window?.orderOut(nil) }

    private func makeFullScreenWindow() -> NSWindow {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        return window
    }
}
