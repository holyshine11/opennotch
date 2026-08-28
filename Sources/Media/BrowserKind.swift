import AppKit

/// 지원 브라우저. rawValue = 번들 ID. `OpenNotch.entitlements`의 temporary-exception 목록과 정확히 같아야 한다(EntitlementsTests).
/// 순수 데이터라 `#if MEDIA_ENABLED` 밖에 둔다(테스트 타깃에서도 컴파일).
enum BrowserKind: String, CaseIterable, Sendable {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    case edge = "com.microsoft.edgemac"
    case arc = "company.thebrowser.Browser"
    case brave = "com.brave.Browser"
    case whale = "com.naver.Whale"

    var displayName: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Chrome"
        case .edge: "Edge"
        case .arc: "Arc"
        case .brave: "Brave"
        case .whale: "Whale"
        }
    }

    var isSafari: Bool { self == .safari }
    var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: rawValue).isEmpty }
    var isInstalled: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) != nil }

    /// "Apple Events의 JavaScript 허용" 토글 위치 안내. 크로미움 계열은 보기 › 개발자 아래에 있고, Whale만 하위 메뉴 이름이 다르다.
    var jsToggleHint: String {
        switch self {
        case .safari:
            String(localized: "Safari › Settings › Advanced › Show features for web developers, then Develop › Allow JavaScript from Apple Events")
        case .whale:
            String(localized: "Whale menu bar › View › Developer info › Allow JavaScript from Apple Events (only once)")
        default:
            String(localized: "\(displayName) menu bar › View › Developer › Allow JavaScript from Apple Events (only once)")
        }
    }
}
