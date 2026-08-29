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
    static let mediaEnabled = "mediaEnabled"
    /// 브라우저 하나라도 제어에 성공한 적이 있으면 true. 패널의 첫 실행 안내 카드를 접는 데만 쓴다.
    static let mediaSetupDone = "mediaSetupDone"
    /// 설정에서 끈 브라우저 번들 ID를 쉼표로 이은 문자열(`@AppStorage` 호환). 나머지는 실행 중이면 모두 대상.
    static let disabledBrowsers = "disabledBrowsers"

    static func registerDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            hoverToOpen: true,
            launchAtLogin: false,
            showMenuBarIcon: true,
            hotkeyEnabled: true,
            showVirtualNotch: true,
            clipboardEnabled: true,
            clipboardLimit: Constants.clipboardDefaultLimit,
            firstLaunchDone: false,
            mediaEnabled: true,
            mediaSetupDone: false,
            disabledBrowsers: "",
        ])
    }
}

extension Notification.Name {
    /// 설정 창의 "Clear history" → 스토어가 비운다.
    static let openNotchClearClipboard = Notification.Name("com.holyshine11.opennotch.clearClipboard")
}
