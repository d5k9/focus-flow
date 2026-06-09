import SwiftUI

@main
struct FocusFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            TimerPopoverView(
                vm: appDelegate.timerVM,
                onOpenPreferences: { appDelegate.showPreferences() }
            )
        } label: {
            MenuBarLabel(vm: appDelegate.timerVM)
        }
        .menuBarExtraStyle(.window)
    }
}
