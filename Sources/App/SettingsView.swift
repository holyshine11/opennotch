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
    @AppStorage(PrefKey.hoverToOpen) private var hoverToOpen = true
    @AppStorage(PrefKey.launchAtLogin) private var launchAtLogin = false
    @AppStorage(PrefKey.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(PrefKey.hotkeyEnabled) private var hotkeyEnabled = true
    @AppStorage(PrefKey.showVirtualNotch) private var showVirtualNotch = true
    @AppStorage(PrefKey.clipboardEnabled) private var clipboardEnabled = true
    @AppStorage(PrefKey.clipboardLimit) private var clipboardLimit = Constants.clipboardDefaultLimit
    @AppStorage(PrefKey.mediaEnabled) private var mediaEnabled = true
    @AppStorage(PrefKey.disabledBrowsers) private var disabledBrowsers = ""
    @State private var confirmHideIcon = false
    @State private var launchError: String?
    @State private var isRevertingLaunchToggle = false

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
                        guard !isRevertingLaunchToggle else { isRevertingLaunchToggle = false; return }
                        do { try LaunchAtLogin.set(newValue) } catch {
                            launchError = error.localizedDescription
                            isRevertingLaunchToggle = true
                            launchAtLogin = !newValue
                        }
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
                Stepper("Maximum items: \(clipboardLimit)", value: $clipboardLimit,
                        in: Constants.clipboardLimitRange, step: Constants.clipboardLimitStep)
                Button("Clear history") { NotificationCenter.default.post(name: .openNotchClearClipboard, object: nil) }
            }
            #if MEDIA_ENABLED
            Section("YouTube") {
                Toggle("Control YouTube in your browser", isOn: $mediaEnabled)
                ForEach(BrowserKind.allCases.filter(\.isInstalled), id: \.rawValue) { browser in
                    Toggle(browser.displayName, isOn: browserBinding(browser)).disabled(!mediaEnabled)
                }
                Button("Setup guide…") { NotificationCenter.default.post(name: .openNotchShowMediaSetup, object: nil) }
                Text("Needs a one-time browser setting. The guide shows where.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            #endif
        }
        .formStyle(.grouped)
        .confirmationDialog("Hide the menu bar icon?", isPresented: $confirmHideIcon) {
            Button("Hide") { showMenuBarIcon = false }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can still open Settings from the ⚙︎ button in the panel (open it with ⌃⌥N or by launching OpenNotch again).")
        }
        .alert("Could not change login item", isPresented: Binding(get: { launchError != nil }, set: { if !$0 { launchError = nil } })) {
            Button("OK") {}
        } message: { Text(launchError ?? "") }
        .onAppear {
            let systemValue = LaunchAtLogin.isEnabled
            if launchAtLogin != systemValue {
                isRevertingLaunchToggle = true
                launchAtLogin = systemValue
            }
        }
    }
}

extension GeneralSettingsView {
    /// 브라우저 토글: 켜짐 = `disabledBrowsers`(쉼표 구분 번들 ID)에 없음.
    fileprivate func browserBinding(_ browser: BrowserKind) -> Binding<Bool> {
        Binding(
            get: { !disabledBrowsers.split(separator: ",").contains(Substring(browser.rawValue)) },
            set: { on in
                var ids = Set(disabledBrowsers.split(separator: ",").map(String.init))
                if on { ids.remove(browser.rawValue) } else { ids.insert(browser.rawValue) }
                disabledBrowsers = ids.sorted().joined(separator: ",")
            })
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
