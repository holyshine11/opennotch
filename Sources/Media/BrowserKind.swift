import AppKit

/// 안내 창에서 브라우저마다 "지금 할 일 하나"를 고르기 위한 상태.
enum BrowserSetupStatus: Equatable, Sendable {
    case ready, jsOff, permissionDenied, noTab, notRunning

    static func derive(jsReady: Bool?, denied: Bool, running: Bool) -> BrowserSetupStatus {
        if denied { return .permissionDenied }
        switch jsReady {
        case true?: return .ready
        case false?: return .jsOff
        default: return running ? .noTab : .notRunning
        }
    }
}

/// 손쉬운 사용 도우미가 메뉴·체크박스를 찾을 때 쓰는 이름 후보. 브라우저 UI의 실제 라벨이라(앱 언어가 아니라 브라우저 언어를 따른다)
/// 번역 카탈로그가 아니라 여기에 둔다. 못 찾으면 도우미는 아무것도 누르지 않고 수동 경로 안내로 되돌아간다.
enum MenuTitles {
    static let view: [String] = ["View", "보기"]
    static let developer: [String] = ["Developer", "개발자 정보", "개발자"]
    static let allowJS: [String] = ["Allow JavaScript from Apple Events", "Apple Events의 자바스크립트 허용", "Apple 이벤트에서 JavaScript 허용"]
    static let safariDeveloperTab: [String] = ["Developer", "개발자"]
    static let safariAdvancedTab: [String] = ["Advanced", "고급"]
    static let safariShowDevFeatures: [String] = ["Show features for web developers", "웹 개발자를 위한 기능 보기"]
    static let allowJSSafari: [String] = ["Allow JavaScript from Apple Events", "Apple 이벤트에서 JavaScript 허용"]
    /// 이름으로 못 찾았을 때의 보기 메뉴 위치(0부터: Apple, 앱, 파일, 편집, 보기).
    static let viewMenuIndex: Int = 4
}

/// 미디어 소스. rawValue = 번들 ID. 브라우저(`isBrowser`)는 `OpenNotch.entitlements`의 temporary-exception 목록과,
/// Apple Music은 `scripting-targets` 키와 정확히 같아야 한다(EntitlementsTests).
/// 순수 데이터라 `#if MEDIA_ENABLED` 밖에 둔다(테스트 타깃에서도 컴파일).
enum BrowserKind: String, CaseIterable, Sendable {
    case safari = "com.apple.Safari"
    case chrome = "com.google.Chrome"
    case edge = "com.microsoft.edgemac"
    case arc = "company.thebrowser.Browser"
    case brave = "com.brave.Browser"
    case whale = "com.naver.Whale"
    /// 브라우저가 아니지만 같은 후보·우선순위·전환 로직을 탄다. 탭·JS 없이 Music 사전으로 직접 읽는다.
    case appleMusic = "com.apple.Music"

    var displayName: String {
        switch self {
        case .safari: "Safari"
        case .chrome: "Chrome"
        case .edge: "Edge"
        case .arc: "Arc"
        case .brave: "Brave"
        case .whale: "Whale"
        case .appleMusic: "Apple Music"
        }
    }

    var isBrowser: Bool { self != .appleMusic }
    static var browsers: [BrowserKind] { allCases.filter(\.isBrowser) }

    var isSafari: Bool { self == .safari }
    var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: rawValue).isEmpty }
    var isInstalled: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) != nil }

    /// "Apple Events의 JavaScript 허용"을 켜는 순서. 메뉴 이름은 실제 한국어 UI에서 채집(2026-08-29: Chrome·Whale 모두 보기 › 개발자 정보).
    var setupSteps: [String] {
        switch self {
        case .appleMusic: []
        case .safari:
            [String(localized: "Safari menu › Settings… (⌘,) › Advanced tab › turn on “Show features for web developers” at the bottom"),
             String(localized: "In the new “Developer” tab, check “Allow JavaScript from Apple Events”")]
        case .chrome, .whale:
            [String(localized: "Menu bar › View › Developer › click “Allow JavaScript from Apple Events” so it shows a check mark")]
        default:
            [String(localized: "\(displayName) menu bar › View › Developer › click “Allow JavaScript from Apple Events” so it shows a check mark")]
        }
    }

    /// 안내 창에서 클릭 경로를 메뉴 모양으로 그리기 위한 조각. 마지막 조각이 켤 항목.
    /// Chrome·Whale 한국어 UI는 "개발자 정보", Edge 등은 "개발자"라 키를 나눈다.
    var menuPath: [String] {
        switch self {
        case .appleMusic: []
        case .safari:
            [String(localized: "Safari"), String(localized: "Settings… (⌘,)"), String(localized: "Developer (Safari tab)"),
             String(localized: "Allow JavaScript from Apple Events (Safari)")]
        case .chrome, .whale:
            [String(localized: "View"), String(localized: "Developer"), String(localized: "Allow JavaScript from Apple Events")]
        default:
            [String(localized: "View"), String(localized: "Developer (other browsers)"), String(localized: "Allow JavaScript from Apple Events")]
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

    /// 확인용 페이지(YouTube Music)를 이 브라우저에서 연다. 실행 중이 아니면 함께 실행된다 — 안내 창에서 탭을 직접 찾아 열지 않아도 되게.
    func openCheckPage() {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue),
              let url = Constants.mediaSetupCheckURL else { return }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }
}
