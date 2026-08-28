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

    /// "Apple Events의 JavaScript 허용"을 켜는 순서. 메뉴 이름은 실제 한국어 UI에서 채집(2026-08-29: Chrome·Whale 모두 보기 › 개발자 정보).
    var setupSteps: [String] {
        switch self {
        case .safari:
            [String(localized: "Safari menu › Settings… (⌘,) › Advanced tab › turn on “Show features for web developers” at the bottom"),
             String(localized: "In the new “Developer” tab, check “Allow JavaScript from Apple Events”")]
        case .chrome, .whale:
            [String(localized: "Menu bar › View › Developer › click “Allow JavaScript from Apple Events” so it shows a check mark")]
        default:
            [String(localized: "\(displayName) menu bar › View › Developer › click “Allow JavaScript from Apple Events” so it shows a check mark")]
        }
    }

    /// 한 줄 안내(툴팁·로그용).
    var jsToggleHint: String { setupSteps.joined(separator: " → ") }

    /// 실행 중이면 앞으로 가져오고, 아니면 연다 — 안내 창에서 바로 메뉴를 찾아가게.
    func activate() {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: rawValue).first {
            app.activate()
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
