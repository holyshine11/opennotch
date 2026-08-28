import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 440)
        .padding()
    }
}

struct GeneralSettingsView: View {
    @AppStorage(PrefKey.hoverToOpen) private var hoverToOpen = false
    @AppStorage(PrefKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(PrefKey.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(PrefKey.hotkeyEnabled) private var hotkeyEnabled = true
    @AppStorage(PrefKey.showVirtualNotch) private var showVirtualNotch = true
    @AppStorage(PrefKey.clipboardEnabled) private var clipboardEnabled = true
    @AppStorage(PrefKey.clipboardLimit) private var clipboardLimit = Constants.clipboardDefaultLimit
    @State private var confirmHideIcon = false
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("Notch") {
                Toggle("Open on hover (0.4 s)", isOn: $hoverToOpen)
                Toggle("Show virtual notch on screens without a notch", isOn: $showVirtualNotch)
                Toggle("Global shortcut ⌃⌥N", isOn: $hotkeyEnabled)
            }
            Section("App") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do { try LaunchAtLogin.set(newValue) } catch { launchError = error.localizedDescription; launchAtLogin = !newValue }
                    }
                if LaunchAtLogin.requiresApproval {
                    Button("Allow in System Settings…") { LaunchAtLogin.openSystemSettings() }
                }
                Toggle("Show menu bar icon", isOn: Binding(
                    get: { showMenuBarIcon },
                    set: { newValue in newValue ? (showMenuBarIcon = true) : (confirmHideIcon = true) }))
            }
            Section("Clipboard") {
                Toggle("Keep clipboard history", isOn: $clipboardEnabled)
                Stepper("Maximum items: \(clipboardLimit)", value: $clipboardLimit, in: 20...500, step: 10)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Hide the menu bar icon?", isPresented: $confirmHideIcon) {
            Button("Hide") { showMenuBarIcon = false }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can still open Settings from the ⚙︎ button in the panel, with ⌃⌥N, or by launching OpenNotch again.")
        }
        .alert("Could not change login item", isPresented: Binding(get: { launchError != nil }, set: { if !$0 { launchError = nil } })) {
            Button("OK") {}
        } message: { Text(launchError ?? "") }
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
    }
}

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "") (\(info?["CFBundleVersion"] as? String ?? ""))"
    }
    private var githubURL: URL? { (Bundle.main.infoDictionary?["ONGitHubURL"] as? String).flatMap(URL.init) }
    private var privacyURL: URL? { (Bundle.main.infoDictionary?["ONPrivacyURL"] as? String).flatMap(URL.init) }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.topthird.inset.filled").font(.system(size: 48))
            Text("OpenNotch").font(.title2.bold())
            Text("Version \(version)").foregroundStyle(.secondary)
            Text("Free and open source. MIT License.").font(.caption)
            HStack {
                if let githubURL { Link("GitHub", destination: githubURL) }
                if let privacyURL { Link("Privacy Policy", destination: privacyURL) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}
