import Foundation

/// `@AppStorage`/UserDefaults 키. 기본값은 `registerDefaults()`로 한 번 등록한다.
enum PrefKey {
    static let hoverToOpen = "hoverToOpen"
    static let launchAtLogin = "launchAtLogin"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let hotkeyEnabled = "hotkeyEnabled"
    static let showVirtualNotch = "showVirtualNotch"
    static let clipboardEnabled = "clipboardEnabled"
    static let clipboardLimit = "clipboardLimit"
    static let firstLaunchDone = "firstLaunchDone"

    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            hoverToOpen: false,
            launchAtLogin: false,
            showMenuBarIcon: true,
            hotkeyEnabled: true,
            showVirtualNotch: true,
            clipboardEnabled: true,
            clipboardLimit: Constants.clipboardDefaultLimit,
            firstLaunchDone: false,
        ])
    }
}
