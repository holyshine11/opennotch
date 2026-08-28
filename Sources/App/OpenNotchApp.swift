import SwiftUI

@main
struct OpenNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("Settings")  // Task 7에서 SettingsView로 교체
        }
    }
}
