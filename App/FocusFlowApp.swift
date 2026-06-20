import SwiftUI

@main
struct FocusFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            RootPopoverView(
                timerVM: appDelegate.timerVM,
                statsVM: appDelegate.statsVM,
                onOpenPreferences: { appDelegate.showPreferences() })
        } label: {
            MenuBarLabel(vm: appDelegate.timerVM)
        }
        .menuBarExtraStyle(.window)
    }
}
