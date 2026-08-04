import SwiftUI

@main
struct FocusFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Supplies ⌘, and the "Settings…" app-menu item; replaces the
        // hand-rolled preferences window. The main window is not a scene —
        // AppDelegate owns it, so it can be raised from anywhere.
        Settings {
            PreferencesView(settings: appDelegate.settings)
        }

        MenuBarExtra {
            MenuBarCommands(
                timerVM: appDelegate.timerVM,
                onShowWindow: { appDelegate.showMainWindow() })
        } label: {
            MenuBarLabel(vm: appDelegate.timerVM)
        }
    }
}
