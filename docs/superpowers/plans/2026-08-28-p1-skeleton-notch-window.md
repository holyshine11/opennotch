# OpenNotch P1 — 스켈레톤 + 노치 윈도우 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 샌드박스·MAS 규격의 xcodegen 프로젝트를 만들고, 노치 위에 접힘/펼침되는 패널(클릭·호버·바깥 클릭·드래그 진입·단축키·가상 노치), 메뉴바 메뉴, 설정 창(일반·정보 탭)을 완성한다. 기능 모듈(셸프·클립보드·미디어)은 자리만 둔다.

**Architecture:** AppKit `NSPanel`(비활성화 패널, 항상 펼친 크기, 투명) 위에 SwiftUI `NSHostingView`가 노치 모양과 내용을 그린다. 상태는 순수 상태기계 `NotchViewModel`(타이머 스케줄러 주입)이 관리하고, 입력은 `EventMonitors`(마우스/Esc)·`DropZoneView`(AppKit 드래그)·`HotKey`(Carbon)가 이벤트로 넘긴다. 화면 선택·재배치는 `NotchWindowController`.

**Tech Stack:** Swift 6.3 언어 모드 6(strict concurrency), SwiftUI + AppKit, Swift Testing, xcodegen 2.46, 외부 의존성 0.

**Spec:** `docs/superpowers/specs/2026-08-28-opennotch-design.md` (§3, §4.1–4.5, §4.9–4.10, D9·D10)

## Global Constraints

- 최소 macOS **14.0**, Swift 언어 모드 **6**, 외부 의존성 **0개**.
- 번들 ID `com.holyshine11.opennotch`, 팀 `MWC6DSJWJR`, 앱 이름 `OpenNotch`.
- 사설 API·temporary-exception(미디어 제외)·Accessibility·전역 키 모니터 **금지**. 전역 모니터는 마우스 이벤트만.
- `NSPanel.ignoresMouseEvents`에 **절대 대입 금지**. 접힌 상태에서 노치 밖 픽셀은 alpha 0(그림자·블러 금지). 예외: 드래그 진입용 `opacity(0.001)` 영역(노치 좌우 32pt, 노치 높이만).
- quality-gate 호환(D10): 수치 상수는 `Constants.swift`에 **타입 명시 + 서술적 이름**(`static let hoverOpenDelay: TimeInterval = 0.4` ✓, `let timeout = 3` ✗). 소스에 `https://` 리터럴 금지 — URL은 Info.plist 키(`ONGitHubURL`, `ONPrivacyURL`)에서 읽는다. Swift `enum`은 허용.
- 문자열은 영어 소스(`String(localized:)`/SwiftUI `Text`), 한국어 번역은 P5.
- 커밋: 각 태스크 끝. 메시지 한국어, `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` 꼬리말. git 사용자 `holyshine11 <anodpark@gmail.com>`.
- 빌드/테스트 명령(프로젝트 루트 `/Users/Dev/Notch_app`):
  - 생성: `xcodegen generate`
  - 테스트: `xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -destination 'platform=macOS' test -quiet 2>&1 | tail -20`
  - 빌드만: `xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -destination 'platform=macOS' build -quiet 2>&1 | tail -20`
- 테스트 호스트가 앱이므로 `AppDelegate`는 `XCTestConfigurationFilePath` 환경변수가 있으면 윈도우를 만들지 않는다(Task 1).

---

## 파일 구조 (P1에서 만드는 것)

| 파일 | 책임 |
|---|---|
| `project.yml` | xcodegen 정의(타깃 2개, Info 키, 빌드 설정) |
| `Config/Media.xcconfig`, `Config/NoMedia.xcconfig` | `MEDIA_ENABLED` 조건·entitlements 선택 |
| `OpenNotch.entitlements`, `OpenNotch-NoMedia.entitlements` | 샌드박스 entitlements(P1에서는 두 파일 모두 기본 3개 키; apple-events 키는 P4가 Media 쪽에 추가) |
| `Sources/App/OpenNotchApp.swift` | `@main`, `MenuBarExtra`, `Settings` 씬 |
| `Sources/App/AppDelegate.swift` | 컨트롤러 생성, reopen, 첫 실행, 단축키 |
| `Sources/App/Preferences.swift` | `@AppStorage` 키 상수 + 기본값 등록 |
| `Sources/App/Constants.swift` | 수치 상수 |
| `Sources/App/SettingsView.swift` | 설정 창(일반·정보 탭) |
| `Sources/App/LaunchAtLogin.swift` | `SMAppService` 래핑 |
| `Sources/App/HotKey.swift` | Carbon 전역 단축키 |
| `Sources/NotchWindow/ScreenMetrics.swift` | `NSScreen` → 값 타입 |
| `Sources/NotchWindow/NotchGeometry.swift` | 노치 rect·패널 frame 순수 계산 |
| `Sources/NotchWindow/NotchViewModel.swift` | 상태기계 + `NotchTimers` 프로토콜 |
| `Sources/NotchWindow/NotchPanel.swift` | `NSPanel` 서브클래스 + 호스팅 뷰 |
| `Sources/NotchWindow/NotchShape.swift` | 노치/패널 모양 |
| `Sources/NotchWindow/NotchRootView.swift` | 접힘/펼침 레이아웃, 모듈 자리, 드롭존 표시 |
| `Sources/NotchWindow/NotchWindowController.swift` | 화면 선택, 프레임, 이벤트 배선, `NotchHost` 구현 |
| `Sources/NotchWindow/EventMonitors.swift` | 전역/로컬 마우스, 로컬 Esc |
| `Sources/NotchWindow/DropZoneView.swift` | AppKit 드래그 목적지 + `NSViewRepresentable` |
| `Sources/NotchWindow/NotchHost.swift` | 모듈 계약 프로토콜 |
| `Sources/NotchWindow/Toast.swift` | 토스트 상태 + 뷰 |
| `Resources/PrivacyInfo.xcprivacy`, `Resources/Localizable.xcstrings`, `Resources/Assets.xcassets` | 리소스 |
| `Tests/*.swift` | Swift Testing |
| `LICENSE`, `README.md`, `PRIVACY.md` | 공개 저장소 문서 |

---

### Task 1: 프로젝트 스켈레톤이 빌드·테스트된다

**Files:**
- Create: `project.yml`, `Config/Media.xcconfig`, `Config/NoMedia.xcconfig`, `OpenNotch.entitlements`, `OpenNotch-NoMedia.entitlements`
- Create: `Sources/App/OpenNotchApp.swift`, `Sources/App/AppDelegate.swift`, `Sources/App/Preferences.swift`, `Sources/App/Constants.swift`
- Create: `Resources/PrivacyInfo.xcprivacy`, `Resources/Localizable.xcstrings`, `Resources/Assets.xcassets/Contents.json`
- Create: `Tests/EntitlementsTests.swift`
- Modify: `.gitignore` (이미 `*.xcodeproj` 제외됨 — 확인만)

**Interfaces:**
- Produces: `Constants` (enum, 아래 값), `PrefKey` (문자열 키), `AppDelegate`(빈 껍데기, Task 4에서 채움)

- [ ] **Step 1: project.yml 작성**

```yaml
name: OpenNotch
options:
  bundleIdPrefix: com.holyshine11
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
  generateEmptyDirectories: true
configs:
  Debug: debug
  Release: release
settings:
  base:
    SWIFT_VERSION: "6.0"
    MACOSX_DEPLOYMENT_TARGET: "14.0"
    DEVELOPMENT_TEAM: MWC6DSJWJR
    CODE_SIGN_STYLE: Automatic
    ENABLE_HARDENED_RUNTIME: YES
    ENABLE_APP_SANDBOX: YES
    SWIFT_TREAT_WARNINGS_AS_ERRORS: NO
    LOCALIZATION_PREFERS_STRING_CATALOGS: YES
    SWIFT_EMIT_LOC_STRINGS: YES
targets:
  OpenNotch:
    type: application
    platform: macOS
    sources:
      - path: Sources
      - path: Resources
    configFiles:
      Debug: Config/Media.xcconfig
      Release: Config/Media.xcconfig
    info:
      path: Resources/Info.plist
      properties:
        CFBundleDisplayName: OpenNotch
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
        LSUIElement: true
        LSMinimumSystemVersion: "14.0"
        LSApplicationCategoryType: public.app-category.utilities
        NSHumanReadableCopyright: "© 2026 holyshine11. MIT License."
        ITSAppUsesNonExemptEncryption: false
        ONGitHubURL: "https://github.com/holyshine11/OpenNotch"
        ONPrivacyURL: "https://holyshine11.github.io/OpenNotch/privacy"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.holyshine11.opennotch
        PRODUCT_NAME: OpenNotch
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        SWIFT_STRICT_CONCURRENCY: complete
  OpenNotchTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: Tests
      - path: OpenNotch.entitlements
        buildPhase: resources
      - path: OpenNotch-NoMedia.entitlements
        buildPhase: resources
    dependencies:
      - target: OpenNotch
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.holyshine11.opennotch.tests
        SWIFT_STRICT_CONCURRENCY: complete
schemes:
  OpenNotch:
    build:
      targets:
        OpenNotch: all
        OpenNotchTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - OpenNotchTests
```

(`ONGitHubURL`·`ONPrivacyURL`은 plist이므로 quality-gate의 URL 규칙 대상이 아니다. Swift 소스에는 URL 리터럴을 쓰지 않는다.)

- [ ] **Step 2: xcconfig 2개와 entitlements 2개 작성**

`Config/Media.xcconfig`:
```
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) MEDIA_ENABLED
CODE_SIGN_ENTITLEMENTS = OpenNotch.entitlements
```
`Config/NoMedia.xcconfig`:
```
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited)
CODE_SIGN_ENTITLEMENTS = OpenNotch-NoMedia.entitlements
```
`OpenNotch.entitlements` **와** `OpenNotch-NoMedia.entitlements` (P1에서는 내용 동일; P4가 Media 쪽에 apple-events 키 2개를 추가):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-only</key>
	<true/>
	<key>com.apple.security.files.bookmarks.app-scope</key>
	<true/>
</dict>
</plist>
```

- [ ] **Step 3: 리소스 최소 파일**

`Resources/PrivacyInfo.xcprivacy`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```
`Resources/Localizable.xcstrings`:
```json
{
  "sourceLanguage" : "en",
  "strings" : {
  },
  "version" : "1.0"
}
```
`Resources/Assets.xcassets/Contents.json`:
```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```
`Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` (아이콘 이미지는 P5; 빈 세트로 빌드 가능):
```json
{ "images" : [], "info" : { "author" : "xcode", "version" : 1 } }
```

- [ ] **Step 4: Constants, Preferences, App, AppDelegate 작성**

`Sources/App/Constants.swift`:
```swift
import Foundation

/// 모든 수치 상수. 타입을 명시하고 서술적 이름을 쓴다(D10).
enum Constants {
    static let hoverOpenDelay: TimeInterval = 0.4
    static let hoverCloseDelay: TimeInterval = 0.3
    static let idleCollapseDelay: TimeInterval = 6
    static let expandAnimationDuration: TimeInterval = 0.35
    static let toastDuration: TimeInterval = 3
    static let dragEnterMargin: CGFloat = 32
    static let virtualNotchWidth: CGFloat = 180
    static let panelWidth: CGFloat = 560
    static let panelBodyHeight: CGFloat = 190
    static let panelCornerRadius: CGFloat = 14
    static let panelTopOverhang: CGFloat = 1
    static let shelfCapacity: Int = 12
    static let clipboardDefaultLimit: Int = 100
}
```

`Sources/App/Preferences.swift`:
```swift
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
```

`Sources/App/AppDelegate.swift` (Task 4·7·8에서 채운다):
```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 테스트 호스트로 실행될 때는 UI를 만들지 않는다.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        PrefKey.registerDefaults()
        guard !Self.isRunningTests else { return }
    }
}
```

`Sources/App/OpenNotchApp.swift`:
```swift
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
```

- [ ] **Step 5: 실패하는 테스트 작성 — entitlements 파일이 기대한 3개 키만 갖는지**

`Tests/EntitlementsTests.swift`:
```swift
import Foundation
import Testing

/// 소스의 entitlements 파일(테스트 번들에 리소스로 복사됨)이 정확히 기대한 키만 갖는지 검증한다.
/// 샌드박스 안에서는 소스 트리를 읽을 수 없으므로 번들 리소스를 읽는다.
@Suite struct EntitlementsTests {
    static let base: Set<String> = [
        "com.apple.security.app-sandbox",
        "com.apple.security.files.user-selected.read-only",
        "com.apple.security.files.bookmarks.app-scope",
    ]

    private func keys(of resource: String) throws -> Set<String> {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: resource, withExtension: "entitlements"))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let dict = try #require(plist as? [String: Any])
        return Set(dict.keys)
    }

    @Test func mediaEntitlementsAreExactlyBasePlusMediaKeys() throws {
        // P1: 기본 3개. P4가 apple-events 키 2개를 추가하면 이 집합을 갱신한다.
        #expect(try keys(of: "OpenNotch") == Self.base)
    }

    @Test func noMediaEntitlementsAreExactlyBase() throws {
        #expect(try keys(of: "OpenNotch-NoMedia") == Self.base)
    }
}

private final class BundleToken {}
```

- [ ] **Step 6: 프로젝트 생성·빌드·테스트 실행 → 통과 확인**

```bash
cd /Users/Dev/Notch_app && xcodegen generate && \
xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -destination 'platform=macOS' test -quiet 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`. 실패 시 흔한 원인: (a) 서명 — `DEVELOPMENT_TEAM`이 맞는지 `security find-identity -v -p codesigning`으로 "Apple Development" 존재 확인; (b) 테스트 호스트가 뜨면서 `AppDelegate`가 UI를 만들면 안 됨 — `isRunningTests` 가드 확인.

- [ ] **Step 7: 커밋**

```bash
git add project.yml Config OpenNotch.entitlements OpenNotch-NoMedia.entitlements Sources Resources Tests .gitignore
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: xcodegen 프로젝트 스켈레톤(샌드박스·LSUIElement·테스트 타깃)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: ScreenMetrics + NotchGeometry (순수 계산)

**Files:**
- Create: `Sources/NotchWindow/ScreenMetrics.swift`, `Sources/NotchWindow/NotchGeometry.swift`
- Test: `Tests/NotchGeometryTests.swift`

**Interfaces:**
- Produces:
  - `struct ScreenMetrics: Equatable, Sendable { frame, visibleFrame: CGRect; safeAreaTop, auxLeftWidth, auxRightWidth, menuBarHeight: CGFloat }`, `extension NSScreen { var metrics: ScreenMetrics }`
  - `struct NotchRect: Equatable, Sendable { rect: CGRect; isVirtual: Bool }`
  - `enum NotchGeometry { static func notchRect(_:) -> NotchRect; static func panelFrame(_:notch:) -> CGRect; static func dragEnterRect(notch:) -> CGRect }` (모두 화면 좌표, 원점 좌하단)

- [ ] **Step 1: 실패하는 테스트**

`Tests/NotchGeometryTests.swift`:
```swift
import Foundation
import Testing
@testable import OpenNotch

@Suite struct NotchGeometryTests {
    /// 14" MacBook Pro 기본 해상도(1512×982), 노치 높이 32, 보조 영역 좌우 각 ~656.
    static let notched = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 950),
        safeAreaTop: 32, auxLeftWidth: 656, auxRightWidth: 656, menuBarHeight: 32)

    /// 외장 모니터(노치 없음), 메뉴바 24pt.
    static let external = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1416),
        safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0, menuBarHeight: 24)

    /// 메뉴바가 숨겨진 노치 없는 화면: visibleFrame이 frame과 같다.
    static let externalHiddenMenuBar = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
        safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0, menuBarHeight: 24)

    @Test func realNotchIsCenteredAtTop() {
        let n = NotchGeometry.notchRect(Self.notched)
        #expect(n.isVirtual == false)
        #expect(n.rect == CGRect(x: 656, y: 950, width: 200, height: 32))
    }

    @Test func virtualNotchUsesMenuBarHeightAndFixedWidth() {
        let n = NotchGeometry.notchRect(Self.external)
        #expect(n.isVirtual == true)
        #expect(n.rect.width == Constants.virtualNotchWidth)
        #expect(n.rect.height == 24)
        #expect(n.rect.midX == 1280)
        #expect(n.rect.maxY == 1440)
    }

    @Test func virtualNotchNeverCollapsesWhenMenuBarHidden() {
        let n = NotchGeometry.notchRect(Self.externalHiddenMenuBar)
        #expect(n.rect.height == 24)
    }

    @Test func panelFrameIsExpandedSizeCenteredOnNotchWithOverhang() {
        let n = NotchGeometry.notchRect(Self.notched)
        let f = NotchGeometry.panelFrame(Self.notched, notch: n)
        #expect(f.width == Constants.panelWidth)
        #expect(f.height == 32 + Constants.panelBodyHeight + Constants.panelTopOverhang)
        #expect(f.midX == 756)
        #expect(f.maxY == 982 + Constants.panelTopOverhang)
    }

    @Test func dragEnterRectExtendsSidewaysOnly() {
        let n = NotchGeometry.notchRect(Self.notched)
        let d = NotchGeometry.dragEnterRect(notch: n)
        #expect(d.minX == 656 - Constants.dragEnterMargin)
        #expect(d.maxX == 856 + Constants.dragEnterMargin)
        #expect(d.height == 32)
    }
}
```

- [ ] **Step 2: 실패 확인**

```bash
xcodegen generate && xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -destination 'platform=macOS' test -quiet 2>&1 | tail -20
```
Expected: 컴파일 실패 — `ScreenMetrics`/`NotchGeometry` 없음.

- [ ] **Step 3: 구현**

`Sources/NotchWindow/ScreenMetrics.swift`:
```swift
import AppKit

/// NSScreen에서 계산에 필요한 값만 뽑은 값 타입. 테스트에서 픽스처로 만든다.
struct ScreenMetrics: Equatable, Sendable {
    var frame: CGRect
    var visibleFrame: CGRect
    var safeAreaTop: CGFloat
    var auxLeftWidth: CGFloat
    var auxRightWidth: CGFloat
    var menuBarHeight: CGFloat

    var hasNotch: Bool {
        safeAreaTop > 0 && auxLeftWidth > 0 && auxRightWidth > 0
    }
}

extension NSScreen {
    @MainActor var metrics: ScreenMetrics {
        ScreenMetrics(
            frame: frame,
            visibleFrame: visibleFrame,
            safeAreaTop: safeAreaInsets.top,
            auxLeftWidth: auxiliaryTopLeftArea?.width ?? 0,
            auxRightWidth: auxiliaryTopRightArea?.width ?? 0,
            menuBarHeight: NSStatusBar.system.thickness)
    }
}
```

`Sources/NotchWindow/NotchGeometry.swift`:
```swift
import Foundation

struct NotchRect: Equatable, Sendable {
    var rect: CGRect
    var isVirtual: Bool
}

/// 화면 좌표(원점 좌하단) 기준 순수 계산.
enum NotchGeometry {
    static func notchRect(_ m: ScreenMetrics) -> NotchRect {
        if m.hasNotch {
            let width = m.frame.width - m.auxLeftWidth - m.auxRightWidth
            let rect = CGRect(x: m.frame.midX - width / 2,
                              y: m.frame.maxY - m.safeAreaTop,
                              width: width, height: m.safeAreaTop)
            return NotchRect(rect: rect, isVirtual: false)
        }
        let height = max(m.frame.maxY - m.visibleFrame.maxY, m.menuBarHeight)
        let width = Constants.virtualNotchWidth
        let rect = CGRect(x: m.frame.midX - width / 2,
                          y: m.frame.maxY - height,
                          width: width, height: height)
        return NotchRect(rect: rect, isVirtual: true)
    }

    /// 패널은 항상 펼친 크기. 상단이 화면 위로 overhang만큼 나간다.
    static func panelFrame(_ m: ScreenMetrics, notch: NotchRect) -> CGRect {
        let height = notch.rect.height + Constants.panelBodyHeight + Constants.panelTopOverhang
        return CGRect(x: notch.rect.midX - Constants.panelWidth / 2,
                      y: m.frame.maxY + Constants.panelTopOverhang - height,
                      width: Constants.panelWidth, height: height)
    }

    /// 드래그 진입 판정 영역: 노치를 좌우로만 margin 확장(아래로는 확장하지 않는다).
    static func dragEnterRect(notch: NotchRect) -> CGRect {
        notch.rect.insetBy(dx: -Constants.dragEnterMargin, dy: 0)
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: 위 test 명령. Expected: `** TEST SUCCEEDED **`, `NotchGeometryTests` 5개 통과.

- [ ] **Step 5: 커밋**

```bash
git add Sources/NotchWindow Tests/NotchGeometryTests.swift
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: 노치 기하 계산(ScreenMetrics, NotchGeometry) + 테스트

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: NotchViewModel 상태기계 (타이머 주입)

**Files:**
- Create: `Sources/NotchWindow/NotchViewModel.swift`
- Test: `Tests/NotchViewModelTests.swift`

**Interfaces:**
- Produces:
  - `enum NotchState { collapsed, expanded, dropTargeting }`, `enum DropZone { airdrop, shelf }`, `enum NotchTimerKind { hoverOpen, hoverClose, idle }`
  - `enum NotchEvent { clickNotch, hoverEnter, hoverExit, hoverOpenFired, hoverCloseFired, clickOutside, escape, idleFired, dragEnter, dragExit, drop(DropZone), toggleRequested, screenChanged }`
  - `protocol NotchTimers: AnyObject { func schedule(_ kind: NotchTimerKind, seconds: TimeInterval, action: @escaping @MainActor () -> Void); func cancel(_ kind: NotchTimerKind) }`
  - `@MainActor @Observable final class NotchViewModel { init(timers: NotchTimers); var state: NotchState { get }; var hoverToOpen: Bool; var wantsKey: Bool; var onDrop: ((DropZone) -> Void)?; func send(_ event: NotchEvent); func resetIdle() }`

- [ ] **Step 1: 실패하는 테스트 (상태표 전체)**

`Tests/NotchViewModelTests.swift`:
```swift
import Foundation
import Testing
@testable import OpenNotch

@MainActor
final class FakeTimers: NotchTimers {
    var scheduled: [NotchTimerKind: (seconds: TimeInterval, action: @MainActor () -> Void)] = [:]
    var cancelled: [NotchTimerKind] = []
    func schedule(_ kind: NotchTimerKind, seconds: TimeInterval, action: @escaping @MainActor () -> Void) {
        scheduled[kind] = (seconds, action)
    }
    func cancel(_ kind: NotchTimerKind) { scheduled[kind] = nil; cancelled.append(kind) }
    func fire(_ kind: NotchTimerKind) {
        guard let entry = scheduled.removeValue(forKey: kind) else { return }
        entry.action()
    }
}

@MainActor
@Suite struct NotchViewModelTests {
    func make(hover: Bool = false) -> (NotchViewModel, FakeTimers) {
        let timers = FakeTimers()
        let vm = NotchViewModel(timers: timers)
        vm.hoverToOpen = hover
        return (vm, timers)
    }

    @Test func clickTogglesAndStartsIdleTimer() {
        let (vm, timers) = make()
        vm.send(.clickNotch)
        #expect(vm.state == .expanded)
        #expect(timers.scheduled[.idle]?.seconds == Constants.idleCollapseDelay)
        vm.send(.clickNotch)
        #expect(vm.state == .collapsed)
        #expect(timers.cancelled.contains(.idle))
    }

    @Test func hoverIsIgnoredWhenDisabled() {
        let (vm, timers) = make(hover: false)
        vm.send(.hoverEnter)
        #expect(timers.scheduled[.hoverOpen] == nil)
        #expect(vm.state == .collapsed)
    }

    @Test func hoverOpensAfterDelayAndClosesAfterExitDelay() {
        let (vm, timers) = make(hover: true)
        vm.send(.hoverEnter)
        #expect(vm.state == .collapsed)
        #expect(timers.scheduled[.hoverOpen]?.seconds == Constants.hoverOpenDelay)
        timers.fire(.hoverOpen)
        #expect(vm.state == .expanded)
        vm.send(.hoverExit)
        #expect(timers.scheduled[.hoverClose]?.seconds == Constants.hoverCloseDelay)
        timers.fire(.hoverClose)
        #expect(vm.state == .collapsed)
    }

    @Test func hoverExitBeforeOpenCancelsOpen() {
        let (vm, timers) = make(hover: true)
        vm.send(.hoverEnter)
        vm.send(.hoverExit)
        #expect(timers.scheduled[.hoverOpen] == nil)
        #expect(vm.state == .collapsed)
    }

    @Test func clickOutsideAndEscapeCollapse() {
        let (vm, _) = make()
        vm.send(.clickNotch)
        vm.send(.clickOutside)
        #expect(vm.state == .collapsed)
        vm.send(.clickNotch)
        vm.wantsKey = true
        vm.send(.escape)
        #expect(vm.state == .collapsed)
    }

    @Test func escapeIgnoredWithoutKeyWindow() {
        let (vm, _) = make()
        vm.send(.clickNotch)
        vm.wantsKey = false
        vm.send(.escape)
        #expect(vm.state == .expanded)
    }

    @Test func idleCollapsesUnlessKeyOrDropTargeting() {
        let (vm, timers) = make()
        vm.send(.clickNotch)
        timers.fire(.idle)
        #expect(vm.state == .collapsed)

        vm.send(.clickNotch)
        vm.wantsKey = true
        #expect(timers.scheduled[.idle] == nil)   // 키 윈도우면 타이머 정지
        vm.wantsKey = false
        #expect(timers.scheduled[.idle] != nil)   // 해제되면 재개
    }

    @Test func dragEnterFromAnyStateTargetsAndExitCollapses() {
        let (vm, timers) = make()
        vm.send(.dragEnter)
        #expect(vm.state == .dropTargeting)
        #expect(timers.scheduled[.idle] == nil)
        vm.send(.dragExit)
        #expect(vm.state == .collapsed)

        vm.send(.clickNotch)
        vm.send(.dragEnter)
        #expect(vm.state == .dropTargeting)
    }

    @Test func dropOnShelfExpandsAndDropOnAirDropCollapses() {
        let (vm, timers) = make()
        var dropped: [DropZone] = []
        vm.onDrop = { dropped.append($0) }

        vm.send(.dragEnter)
        vm.send(.drop(.shelf))
        #expect(vm.state == .expanded)
        #expect(timers.scheduled[.idle] != nil)

        vm.send(.dragEnter)
        vm.send(.drop(.airdrop))
        #expect(vm.state == .collapsed)
        #expect(dropped == [.shelf, .airdrop])
    }

    @Test func eventsIgnoredWhileDropTargeting() {
        let (vm, timers) = make(hover: true)
        vm.send(.dragEnter)
        for event in [NotchEvent.clickNotch, .hoverEnter, .hoverExit, .clickOutside, .escape, .toggleRequested] {
            vm.send(event)
            #expect(vm.state == .dropTargeting)
        }
        timers.fire(.idle)
        #expect(vm.state == .dropTargeting)
    }

    @Test func toggleAndScreenChanged() {
        let (vm, _) = make()
        vm.send(.toggleRequested)
        #expect(vm.state == .expanded)
        vm.send(.toggleRequested)
        #expect(vm.state == .collapsed)

        vm.send(.dragEnter)
        vm.send(.screenChanged)
        #expect(vm.state == .collapsed)
        vm.send(.clickNotch)
        vm.send(.screenChanged)
        #expect(vm.state == .expanded)
    }

    @Test func resetIdleReschedules() {
        let (vm, timers) = make()
        vm.send(.clickNotch)
        timers.scheduled[.idle] = nil
        vm.resetIdle()
        #expect(timers.scheduled[.idle] != nil)
    }
}
```

- [ ] **Step 2: 실패 확인** — 컴파일 실패(타입 없음).

- [ ] **Step 3: 구현**

`Sources/NotchWindow/NotchViewModel.swift`:
```swift
import Foundation
import Observation

enum NotchState: Equatable, Sendable { case collapsed, expanded, dropTargeting }
enum DropZone: Equatable, Sendable { case airdrop, shelf }
enum NotchTimerKind: Hashable, Sendable { case hoverOpen, hoverClose, idle }

enum NotchEvent: Equatable, Sendable {
    case clickNotch
    case hoverEnter, hoverExit, hoverOpenFired, hoverCloseFired
    case clickOutside, escape, idleFired
    case dragEnter, dragExit
    case drop(DropZone)
    case toggleRequested
    case screenChanged
}

/// 타이머는 뷰모델 밖에서 소유한다(테스트에서 가짜로 대체).
@MainActor
protocol NotchTimers: AnyObject {
    func schedule(_ kind: NotchTimerKind, seconds: TimeInterval, action: @escaping @MainActor () -> Void)
    func cancel(_ kind: NotchTimerKind)
}

@MainActor
@Observable
final class NotchViewModel {
    private(set) var state: NotchState = .collapsed
    var hoverToOpen = false
    /// 클립보드 검색창 등 텍스트 입력이 포커스를 가진 동안 true. 유휴 타이머가 멈춘다.
    var wantsKey = false {
        didSet { if state == .expanded { wantsKey ? timers.cancel(.idle) : scheduleIdle() } }
    }
    var onDrop: ((DropZone) -> Void)?

    private let timers: NotchTimers

    init(timers: NotchTimers) {
        self.timers = timers
    }

    func send(_ event: NotchEvent) {
        switch (state, event) {
        // dropTargeting: 드래그 관련 이벤트만 받는다.
        case (.dropTargeting, .dragExit):
            collapse()
        case (.dropTargeting, .drop(let zone)):
            onDrop?(zone)
            zone == .shelf ? expand() : collapse()
        case (.dropTargeting, .screenChanged):
            collapse()
        case (.dropTargeting, _):
            break

        case (_, .dragEnter):
            timers.cancel(.hoverOpen); timers.cancel(.hoverClose); timers.cancel(.idle)
            state = .dropTargeting

        case (.collapsed, .clickNotch), (.collapsed, .toggleRequested), (.collapsed, .hoverOpenFired):
            expand()
        case (.collapsed, .hoverEnter) where hoverToOpen:
            timers.schedule(.hoverOpen, seconds: Constants.hoverOpenDelay) { [weak self] in self?.send(.hoverOpenFired) }
        case (.collapsed, .hoverExit):
            timers.cancel(.hoverOpen)

        case (.expanded, .clickNotch), (.expanded, .toggleRequested), (.expanded, .clickOutside), (.expanded, .hoverCloseFired):
            collapse()
        case (.expanded, .escape) where wantsKey:
            collapse()
        case (.expanded, .idleFired) where !wantsKey:
            collapse()
        case (.expanded, .hoverExit) where hoverToOpen:
            timers.schedule(.hoverClose, seconds: Constants.hoverCloseDelay) { [weak self] in self?.send(.hoverCloseFired) }
        case (.expanded, .hoverEnter):
            timers.cancel(.hoverClose)

        default:
            break
        }
    }

    /// 사용자 조작이 있을 때 호출 — 유휴 타이머를 다시 시작한다.
    func resetIdle() {
        guard state == .expanded, !wantsKey else { return }
        scheduleIdle()
    }

    private func expand() {
        timers.cancel(.hoverOpen)
        state = .expanded
        if !wantsKey { scheduleIdle() }
    }

    private func collapse() {
        timers.cancel(.hoverOpen); timers.cancel(.hoverClose); timers.cancel(.idle)
        state = .collapsed
    }

    private func scheduleIdle() {
        timers.schedule(.idle, seconds: Constants.idleCollapseDelay) { [weak self] in self?.send(.idleFired) }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인** — `NotchViewModelTests` 12개 통과.

- [ ] **Step 5: 커밋**

```bash
git add Sources/NotchWindow/NotchViewModel.swift Tests/NotchViewModelTests.swift
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: NotchViewModel 상태기계(타이머 주입) + 상태표 테스트

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: NotchPanel + NotchShape + NotchRootView + NotchWindowController — 노치가 화면에 뜨고 클릭으로 펼쳐진다

**Files:**
- Create: `Sources/NotchWindow/NotchPanel.swift`, `Sources/NotchWindow/NotchShape.swift`, `Sources/NotchWindow/NotchRootView.swift`, `Sources/NotchWindow/NotchWindowController.swift`, `Sources/NotchWindow/NotchHost.swift`, `Sources/NotchWindow/Toast.swift`
- Modify: `Sources/App/AppDelegate.swift`

**Interfaces:**
- Consumes: `NotchGeometry`, `ScreenMetrics`, `NotchViewModel`, `NotchTimers`
- Produces:
  - `protocol NotchHost: AnyObject { func resetIdle(); func setWantsKey(_:); func showToast(_ text: String, action: ToastAction?); func collapse(); var panel: NSWindow { get } }`
  - `struct ToastAction { title: String; handler: @MainActor () -> Void }`, `@MainActor @Observable final class ToastCenter { var message: String?; var action: ToastAction?; func show(_:action:) }`
  - `final class NotchPanel: NSPanel { var wantsKey: Bool }`
  - `@MainActor final class NotchWindowController: NotchHost { let viewModel: NotchViewModel; let toast: ToastCenter; var notch: NotchRect { get }; func show(); func reposition() }`
  - SwiftUI environment: `\.notchHost: NotchHost?` (EnvironmentKey)

- [ ] **Step 1: NotchHost, Toast**

`Sources/NotchWindow/NotchHost.swift`:
```swift
import AppKit
import SwiftUI

struct ToastAction {
    let title: String
    let handler: @MainActor () -> Void
}

/// 기능 모듈(셸프·클립보드·미디어)이 노치 윈도우에 요구하는 것.
@MainActor
protocol NotchHost: AnyObject {
    func resetIdle()
    func setWantsKey(_ wants: Bool)
    func showToast(_ text: String, action: ToastAction?)
    func collapse()
    var panel: NSWindow { get }
}

private struct NotchHostKey: EnvironmentKey {
    static let defaultValue: NotchHost? = nil
}

extension EnvironmentValues {
    var notchHost: NotchHost? {
        get { self[NotchHostKey.self] }
        set { self[NotchHostKey.self] = newValue }
    }
}
```

`Sources/NotchWindow/Toast.swift`:
```swift
import SwiftUI
import Observation

@MainActor
@Observable
final class ToastCenter {
    private(set) var message: String?
    private(set) var action: ToastAction?
    private var hideTask: Task<Void, Never>?

    func show(_ text: String, action: ToastAction? = nil) {
        message = text
        self.action = action
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.toastDuration))
            guard !Task.isCancelled else { return }
            self?.message = nil
            self?.action = nil
        }
    }
}

struct ToastView: View {
    let center: ToastCenter

    var body: some View {
        if let message = center.message {
            HStack(spacing: 8) {
                Text(message).font(.caption).lineLimit(1)
                if let action = center.action {
                    Button(action.title) { action.handler() }
                        .buttonStyle(.link).font(.caption)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
```

- [ ] **Step 2: NotchPanel**

`Sources/NotchWindow/NotchPanel.swift`:
```swift
import AppKit
import SwiftUI

/// 노치 위에 항상 떠 있는 비활성화 패널. 속성 순서·값은 스펙 §4.4 그대로.
final class NotchPanel: NSPanel {
    var wantsKey = false
    override var canBecomeKey: Bool { wantsKey }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isFloatingPanel = true            // level보다 먼저
        level = .mainMenu + 3
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // ignoresMouseEvents 는 절대 대입하지 않는다.
    }
}

/// 비활성화 패널에서 첫 클릭을 뷰로 전달한다.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    required init(rootView: Content) { super.init(rootView: rootView) }
    @MainActor required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
```

- [ ] **Step 3: NotchShape**

`Sources/NotchWindow/NotchShape.swift`:
```swift
import SwiftUI

/// 위쪽은 평평하고 아래 두 모서리만 둥근 노치/패널 모양.
struct NotchShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(bottomRadius, rect.width / 2, rect.height)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}
```

- [ ] **Step 4: NotchRootView (접힘/펼침 레이아웃, 모듈 자리)**

`Sources/NotchWindow/NotchRootView.swift`:
```swift
import SwiftUI

/// 패널 콘텐츠. 좌표계는 SwiftUI(원점 좌상단), 크기 = 패널 frame.
struct NotchRootView: View {
    let viewModel: NotchViewModel
    let toast: ToastCenter
    let notch: NotchRect          // 화면 좌표 — 여기서는 크기만 쓴다
    /// 모듈 뷰는 P2~P4에서 주입된다. nil이면 자리 표시.
    var mediaPane: AnyView?
    var shelfPane: AnyView?
    var clipboardPane: AnyView?

    private var isOpen: Bool { viewModel.state != .collapsed }
    private var notchHeight: CGFloat { notch.rect.height }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Constants.panelTopOverhang)
            ZStack(alignment: .top) {
                shape
                if isOpen {
                    content
                        .frame(width: Constants.panelWidth, height: notchHeight + Constants.panelBodyHeight)
                        .transition(.opacity)
                }
            }
            .frame(width: isOpen ? Constants.panelWidth : notch.rect.width,
                   height: isOpen ? notchHeight + Constants.panelBodyHeight : notchHeight)
            .contentShape(NotchShape(bottomRadius: isOpen ? Constants.panelCornerRadius : 8))
            .onTapGesture { if !isOpen { viewModel.send(.clickNotch) } }
            .onHover { inside in viewModel.send(inside ? .hoverEnter : .hoverExit) }
            Spacer(minLength: 0)
        }
        .frame(width: Constants.panelWidth,
               height: notchHeight + Constants.panelBodyHeight + Constants.panelTopOverhang,
               alignment: .top)
        .animation(.spring(duration: Constants.expandAnimationDuration), value: viewModel.state)
        .overlay(alignment: .bottom) {
            ToastView(center: toast).padding(.bottom, 8)
                .animation(.easeInOut(duration: 0.2), value: toast.message)
        }
    }

    private var shape: some View {
        NotchShape(bottomRadius: isOpen ? Constants.panelCornerRadius : 8)
            .fill(Color.black)
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)   // 노치 밴드: 펼친 상태에서 다시 클릭하면 접힌다
                .contentShape(Rectangle())
                .onTapGesture { viewModel.send(.clickNotch) }
            if viewModel.state == .dropTargeting {
                dropZones
            } else {
                panes
            }
        }
        .foregroundStyle(.white)
    }

    private var panes: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                (mediaPane ?? AnyView(placeholder("Media")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                (shelfPane ?? AnyView(placeholder("Shelf")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            (clipboardPane ?? AnyView(placeholder("Clipboard")))
                .frame(height: 44)
        }
        .padding(12)
    }

    private var dropZones: some View {
        HStack(spacing: 8) {
            dropZoneLabel("AirDrop", systemImage: "airplayaudio")
            dropZoneLabel("Keep in Shelf", systemImage: "tray.and.arrow.down")
        }
        .padding(12)
    }

    private func dropZoneLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).font(.title)
            Text(title).font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func placeholder(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}
```

(`.onHover`는 `hoverToOpen`이 꺼져 있으면 뷰모델이 무시한다. 접힌 상태의 검은 노치 영역만 `contentShape`에 포함되므로 그 밖의 투명 픽셀은 클릭·호버를 통과시킨다.)

- [ ] **Step 5: NotchWindowController (화면 선택·프레임·타이머·NotchHost)**

`Sources/NotchWindow/NotchWindowController.swift`:
```swift
import AppKit
import SwiftUI

/// 실제 타이머 구현. 뷰모델이 요구한 타이머를 종류별로 하나씩만 유지한다.
@MainActor
final class MainThreadTimers: NotchTimers {
    private var tasks: [NotchTimerKind: Task<Void, Never>] = [:]

    func schedule(_ kind: NotchTimerKind, seconds: TimeInterval, action: @escaping @MainActor () -> Void) {
        tasks[kind]?.cancel()
        tasks[kind] = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel(_ kind: NotchTimerKind) {
        tasks[kind]?.cancel()
        tasks[kind] = nil
    }
}

@MainActor
final class NotchWindowController: NotchHost {
    let viewModel: NotchViewModel
    let toast = ToastCenter()
    private let notchPanel = NotchPanel()
    private(set) var notch = NotchRect(rect: .zero, isVirtual: true)
    private var currentScreenKey: String = ""
    private var screenObserver: NSObjectProtocol?

    var panel: NSWindow { notchPanel }
    var showVirtualNotch = true { didSet { reposition(force: true) } }

    init(timers: NotchTimers = MainThreadTimers()) {
        viewModel = NotchViewModel(timers: timers)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersChanged() }
        }
    }

    // MARK: 화면 선택

    /// 노치가 있는 화면 중 첫 번째, 없으면 메뉴바가 있는 screens[0].
    static func targetScreen(_ screens: [NSScreen]) -> NSScreen? {
        screens.first { $0.metrics.hasNotch } ?? screens.first
    }

    func show() {
        reposition(force: true)
        notchPanel.orderFrontRegardless()
    }

    func reposition(force: Bool = false) {
        guard let screen = Self.targetScreen(NSScreen.screens) else { return }
        let metrics = screen.metrics
        let key = "\(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? "")|\(metrics.frame)|\(metrics.visibleFrame)"
        guard force || key != currentScreenKey else { return }
        currentScreenKey = key

        notch = NotchGeometry.notchRect(metrics)
        let hidden = notch.isVirtual && !showVirtualNotch
        notchPanel.setFrame(NotchGeometry.panelFrame(metrics, notch: notch), display: true)
        notchPanel.contentView = NotchHostingView(rootView: makeRootView())
        notchPanel.alphaValue = hidden ? 0 : 1
    }

    private func screenParametersChanged() {
        viewModel.send(.screenChanged)
        reposition()
    }

    /// P2~P4가 모듈 뷰를 끼워 넣을 수 있도록 오버라이드 지점을 둔다.
    var paneProvider: (() -> (media: AnyView?, shelf: AnyView?, clipboard: AnyView?))?

    private func makeRootView() -> some View {
        let panes = paneProvider?() ?? (nil, nil, nil)
        return NotchRootView(viewModel: viewModel, toast: toast, notch: notch,
                             mediaPane: panes.media, shelfPane: panes.shelf, clipboardPane: panes.clipboard)
            .environment(\.notchHost, self)
    }

    // MARK: NotchHost

    func resetIdle() { viewModel.resetIdle() }

    func setWantsKey(_ wants: Bool) {
        viewModel.wantsKey = wants
        notchPanel.wantsKey = wants
        if wants { notchPanel.makeKey() } else if notchPanel.isKeyWindow { notchPanel.resignKey() }
    }

    func showToast(_ text: String, action: ToastAction?) { toast.show(text, action: action) }

    func collapse() { viewModel.send(.clickOutside) }

}
```

- [ ] **Step 6: AppDelegate에서 컨트롤러 생성**

`Sources/App/AppDelegate.swift` 전체 교체:
```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private(set) var notchController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PrefKey.registerDefaults()
        guard !Self.isRunningTests else { return }

        let controller = NotchWindowController()
        controller.viewModel.hoverToOpen = UserDefaults.standard.bool(forKey: PrefKey.hoverToOpen)
        controller.showVirtualNotch = UserDefaults.standard.bool(forKey: PrefKey.showVirtualNotch)
        controller.show()
        notchController = controller
    }
}
```

- [ ] **Step 7: 빌드·테스트 후 수동 확인**

```bash
xcodegen generate && xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -destination 'platform=macOS' test -quiet 2>&1 | tail -5
open -a "$(xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -configuration Debug -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2}')/OpenNotch.app"
```
Expected: 테스트 통과. 앱 실행 후 (a) 노치 위 검은 형태가 화면과 일치(노치 있는 화면) 또는 메뉴바 중앙에 180pt 검은 형태(가상), (b) 노치 클릭 → 패널이 스프링으로 펼쳐지고 "Media/Shelf/Clipboard" 자리 표시가 보임, (c) 6초 후 자동 접힘, (d) 접힌 상태에서 노치 옆 메뉴바 항목이 정상 클릭됨. 확인 후 `pkill -x OpenNotch`.

- [ ] **Step 8: 커밋**

```bash
git add Sources
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: 노치 패널·모양·루트 뷰·윈도우 컨트롤러 — 클릭으로 펼침/유휴 접힘

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: EventMonitors — 바깥 클릭·Esc·호버 배선

**Files:**
- Create: `Sources/NotchWindow/EventMonitors.swift`
- Modify: `Sources/NotchWindow/NotchWindowController.swift` (`init`에서 모니터 시작)

**Interfaces:**
- Consumes: `NotchViewModel.send`, `NotchWindowController.panelFrame`
- Produces: `@MainActor final class EventMonitors { init(onOutsideClick:onEscape:); func start(); func stop(); var panelFrameProvider: () -> CGRect }`

- [ ] **Step 1: 구현**

`Sources/NotchWindow/EventMonitors.swift`:
```swift
import AppKit

/// 전역(다른 앱)·로컬(자기 앱) 마우스 다운과 로컬 Esc를 감시한다.
/// 마우스 전역 모니터는 권한이 필요 없다. 키 이벤트는 로컬(자기 앱이 키 윈도우일 때)만 본다.
@MainActor
final class EventMonitors {
    private var globalMouse: Any?
    private var localMouse: Any?
    private var localKey: Any?
    private let onOutsideClick: @MainActor () -> Void
    private let onEscape: @MainActor () -> Void
    var panelFrameProvider: @MainActor () -> CGRect = { .zero }

    private static let escapeKeyCode: UInt16 = 53

    init(onOutsideClick: @escaping @MainActor () -> Void, onEscape: @escaping @MainActor () -> Void) {
        self.onOutsideClick = onOutsideClick
        self.onEscape = onEscape
    }

    func start() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        globalMouse = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMouseDown(location: NSEvent.mouseLocation) }
        }
        localMouse = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouseDown(location: NSEvent.mouseLocation) }
            return event
        }
        localKey = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == Self.escapeKeyCode else { return event }
            MainActor.assumeIsolated { self?.onEscape() }
            return nil
        }
    }

    func stop() {
        for monitor in [globalMouse, localMouse, localKey].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        globalMouse = nil; localMouse = nil; localKey = nil
    }

    private func handleMouseDown(location: CGPoint) {
        if !panelFrameProvider().contains(location) { onOutsideClick() }
    }
}
```

- [ ] **Step 2: 컨트롤러에 배선**

`NotchWindowController`에 프로퍼티와 `init` 끝부분 추가:
```swift
    private var monitors: EventMonitors?
```
`init(timers:)` 마지막에:
```swift
        let monitors = EventMonitors(
            onOutsideClick: { [weak self] in self?.viewModel.send(.clickOutside) },
            onEscape: { [weak self] in self?.viewModel.send(.escape) })
        monitors.panelFrameProvider = { [weak self] in self?.notchPanel.frame ?? .zero }
        monitors.start()
        self.monitors = monitors
```
(펼친 패널 프레임 안 클릭은 뷰가 처리하고, 접힌 상태에서 `clickOutside`는 뷰모델이 무시하므로 상태 검사는 불필요.)

- [ ] **Step 3: 빌드·테스트·수동 확인**

앱 실행 → 노치 클릭으로 펼친 뒤 다른 앱 영역 클릭 → 즉시 접힘. 전체화면 앱(예: Safari 전체화면) 위에서도 노치가 보이고 클릭으로 펼쳐짐. 시스템 설정 > 개인정보 보호 > 손쉬운 사용/입력 모니터링에 OpenNotch가 **나타나지 않아야** 한다.

- [ ] **Step 4: 커밋**

```bash
git add Sources/NotchWindow
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: 바깥 클릭·Esc 이벤트 모니터 배선

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: DropContainerView — 드래그 진입으로 펼치고 두 드롭존에 떨어뜨린다

**Files:**
- Create: `Sources/NotchWindow/DropContainerView.swift`
- Modify: `Sources/NotchWindow/NotchGeometry.swift` (`collapsedDropRect` 추가), `Tests/NotchGeometryTests.swift` (테스트 1개 추가), `Sources/NotchWindow/NotchWindowController.swift` (컨테이너가 contentView), `Sources/NotchWindow/NotchRootView.swift` (접힌 상태 진입 영역), `Sources/App/AppDelegate.swift` (임시 `onDropURLs`)

**Interfaces:**
- Consumes: `NotchViewModel.send(.dragEnter/.dragExit/.drop)`, `NotchGeometry`
- Produces:
  - `final class DropContainerView: NSView { var isCollapsed: () -> Bool; var collapsedActiveRect: CGRect; var onEnter/onExit: () -> Void; var onDrop: ([URL], DropZone) -> Void; func embed(_ view: NSView) }`
  - `NotchGeometry.collapsedDropRect(notch:) -> CGRect` (패널 로컬 좌표, 원점 좌하단)
  - `NotchWindowController.onDropURLs: (([URL], DropZone) -> Void)?` — P2가 셸프/AirDrop 처리를 연결한다.

설계 메모: AppKit은 드래그 목적지를 "커서 아래 가장 깊은 뷰에서 superview로 올라가며 `registerForDraggedTypes`된 첫 뷰"로 찾는다. 그래서 SwiftUI 호스팅 뷰를 감싸는 **최상위 컨테이너**가 등록하면 SwiftUI 콘텐츠 어디에 떨어뜨려도 받는다. 마우스 클릭은 컨테이너를 거치지 않고 SwiftUI 뷰가 처리한다. 접힌 상태에서는 WindowServer가 alpha 0 픽셀 위의 드래그를 우리 창에 주지 않으므로, 노치 좌우 32pt 밴드를 `opacity(0.001)`로 그린다(그 영역의 클릭은 우리 창이 삼키지만 메뉴바 빈 공간이라 무해).

- [ ] **Step 1: 실패하는 테스트 — 접힌 상태 진입 영역(패널 로컬 좌표)**

`Tests/NotchGeometryTests.swift`에 추가:
```swift
    @Test func collapsedDropRectIsPanelLocalNotchBandWithMargins() {
        let n = NotchGeometry.notchRect(Self.notched)
        let r = NotchGeometry.collapsedDropRect(notch: n)
        #expect(r.width == 200 + Constants.dragEnterMargin * 2)
        #expect(r.midX == Constants.panelWidth / 2)
        #expect(r.maxY == 32 + Constants.panelBodyHeight)   // overhang 바로 아래 = 노치 밴드 상단
        #expect(r.height == 32)
    }
```
Run: test 명령. Expected: 컴파일 실패(`collapsedDropRect` 없음).

- [ ] **Step 2: NotchGeometry에 추가**

```swift
    /// 접힌 상태 드래그 진입 영역을 패널 로컬 좌표(원점 좌하단)로. 노치 좌우 32pt, 높이는 노치 높이.
    static func collapsedDropRect(notch: NotchRect) -> CGRect {
        let width = notch.rect.width + Constants.dragEnterMargin * 2
        let totalHeight = notch.rect.height + Constants.panelBodyHeight + Constants.panelTopOverhang
        return CGRect(x: (Constants.panelWidth - width) / 2,
                      y: totalHeight - Constants.panelTopOverhang - notch.rect.height,
                      width: width, height: notch.rect.height)
    }
```
Run: test 명령. Expected: `NotchGeometryTests` 6개 통과.

- [ ] **Step 3: DropContainerView**

`Sources/NotchWindow/DropContainerView.swift`:
```swift
import AppKit

/// 패널의 contentView. SwiftUI 호스팅 뷰를 자식으로 품고 드래그 목적지 역할만 한다.
final class DropContainerView: NSView {
    var isCollapsed: () -> Bool = { true }
    /// 접힌 상태에서 진입을 인정하는 영역(이 뷰 좌표, 원점 좌하단).
    var collapsedActiveRect: CGRect = .zero
    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}
    var onDrop: ([URL], DropZone) -> Void = { _, _ in }
    private var entered = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func embed(_ view: NSView) {
        subviews.forEach { $0.removeFromSuperview() }
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view)
    }

    private func accepts(_ info: NSDraggingInfo) -> Bool {
        if (info.draggingSource as? NSView)?.window === window { return false }   // 자체 셸프에서 시작한 드래그
        let hasFiles = info.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        guard hasFiles else { return false }
        return isCollapsed() ? collapsedActiveRect.contains(convert(info.draggingLocation, from: nil)) : true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { draggingUpdated(sender) }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let ok = accepts(sender)
        if ok, !entered { entered = true; onEnter() }
        if !ok, entered { entered = false; onExit() }
        return ok ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        if entered { entered = false; onExit() }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        if entered { entered = false; onExit() }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let objects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        let urls = (objects as? [URL]) ?? []
        guard !urls.isEmpty else { return false }
        let local = convert(sender.draggingLocation, from: nil)
        entered = false
        onDrop(urls, local.x < bounds.midX ? .airdrop : .shelf)
        return true
    }
}
```

- [ ] **Step 4: 컨트롤러 — 컨테이너를 contentView로, 콜백 배선**

`NotchWindowController`에 프로퍼티 추가:
```swift
    private let container = DropContainerView(frame: .zero)
    /// P2가 연결: 셸프 추가 / AirDrop 전송. 뷰모델 상태 전이는 컨트롤러가 처리한다.
    var onDropURLs: (([URL], DropZone) -> Void)?
```
`init(timers:)` 끝에 추가:
```swift
        container.isCollapsed = { [weak self] in self?.viewModel.state == .collapsed }
        container.onEnter = { [weak self] in self?.viewModel.send(.dragEnter) }
        container.onExit = { [weak self] in self?.viewModel.send(.dragExit) }
        container.onDrop = { [weak self] urls, zone in
            self?.onDropURLs?(urls, zone)
            self?.viewModel.send(.drop(zone))
        }
```
`reposition(force:)`에서 `notchPanel.contentView = NotchHostingView(rootView: makeRootView())` 한 줄을 다음으로 교체:
```swift
        container.collapsedActiveRect = NotchGeometry.collapsedDropRect(notch: notch)
        container.embed(NotchHostingView(rootView: makeRootView()))
        if notchPanel.contentView !== container { notchPanel.contentView = container }
```

- [ ] **Step 5: 루트 뷰 — 접힌 상태 진입 영역(alpha 0.001)**

`NotchRootView.body`의 바깥 `.frame(width: Constants.panelWidth, ...)` 뒤(`.animation` 앞)에 추가:
```swift
        .overlay(alignment: .top) {
            // 접힌 상태 드래그 진입 영역: 노치 좌우 32pt, 노치 높이만. alpha 0.001이라 WindowServer가 드래그를 우리 창에 전달한다.
            if !isOpen {
                Color.black.opacity(0.001)
                    .frame(width: notch.rect.width + Constants.dragEnterMargin * 2, height: notchHeight)
                    .padding(.top, Constants.panelTopOverhang)
                    .allowsHitTesting(false)
            }
        }
```

- [ ] **Step 6: 임시 드롭 처리(P2가 교체)**

`AppDelegate.applicationDidFinishLaunching`의 `controller.show()` 앞에:
```swift
        controller.onDropURLs = { urls, zone in
            controller.showToast("\(urls.count) file(s) → \(zone == .airdrop ? "AirDrop" : "Shelf")", action: nil)
        }
```

- [ ] **Step 7: 빌드·테스트·수동 확인**

테스트 통과(NotchGeometryTests 6). Finder에서 파일을 끌어 노치로 → 닿기 전(좌우 32pt 밴드)부터 패널이 "AirDrop | Keep in Shelf" 두 존으로 펼쳐짐 → 오른쪽에 놓으면 토스트 "1 file(s) → Shelf" 후 패널 유지, 왼쪽에 놓으면 접힘. 드롭 없이 빠져나오면 접힘. 펼친 패널 안에서 마우스 클릭(노치 밴드 클릭으로 접기)이 여전히 동작. 접힌 상태에서 노치 좌우 32pt 밖 메뉴바 클릭 정상.

- [ ] **Step 8: 커밋**

```bash
git add Sources Tests
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: 드래그 진입 자동 펼침과 AirDrop/셸프 두 드롭존

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: 메뉴바 메뉴 + 설정 창(일반·정보) + 로그인 항목 + reopen + 첫 실행

**Files:**
- Create: `Sources/App/SettingsView.swift`, `Sources/App/LaunchAtLogin.swift`
- Modify: `Sources/App/OpenNotchApp.swift`, `Sources/App/AppDelegate.swift`

**Interfaces:**
- Consumes: `PrefKey`, `NotchWindowController.viewModel`, `showVirtualNotch`
- Produces: `enum LaunchAtLogin { static var isEnabled: Bool { get }; static func set(_:) throws }`, `struct SettingsView: View`, `extension Notification.Name { static let openNotchTogglePanel }`

- [ ] **Step 1: LaunchAtLogin**

`Sources/App/LaunchAtLogin.swift`:
```swift
import ServiceManagement

/// 로그인 시 실행 — 사용자 토글로만 켠다(Guideline 2.4.5 iii). 헬퍼 번들 없음.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    /// 사용자가 시스템 설정에서 거부한 상태면 그 화면을 열어 준다.
    static var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }
    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
```

- [ ] **Step 2: SettingsView**

`Sources/App/SettingsView.swift`:
```swift
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
```

- [ ] **Step 3: App — MenuBarExtra + Settings 씬**

`Sources/App/OpenNotchApp.swift` 전체 교체:
```swift
import SwiftUI

extension Notification.Name {
    static let openNotchTogglePanel = Notification.Name("com.holyshine11.opennotch.togglePanel")
}

@main
struct OpenNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(PrefKey.showMenuBarIcon) private var showMenuBarIcon = true

    var body: some Scene {
        MenuBarExtra("OpenNotch", systemImage: "rectangle.topthird.inset.filled", isInserted: $showMenuBarIcon) {
            Button("Open Panel") {
                NotificationCenter.default.post(name: .openNotchTogglePanel, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.control, .option])
            Divider()
            SettingsLink { Text("Settings…") }
                .keyboardShortcut(",", modifiers: .command)
            Button("About OpenNotch") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Divider()
            Button("Quit OpenNotch") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}
```

- [ ] **Step 4: AppDelegate — 알림·reopen·첫 실행·설정 변화 반영**

`Sources/App/AppDelegate.swift` 전체 교체:
```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private(set) var notchController: NotchWindowController?
    private var observers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        PrefKey.registerDefaults()
        guard !Self.isRunningTests else { return }

        let controller = NotchWindowController()
        applyPreferences(to: controller)
        controller.onDropURLs = { urls, zone in   // P2가 교체
            controller.showToast("\(urls.count) file(s) → \(zone == .airdrop ? "AirDrop" : "Shelf")", action: nil)
        }
        controller.show()
        notchController = controller

        observers.append(NotificationCenter.default.addObserver(
            forName: .openNotchTogglePanel, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.notchController?.viewModel.send(.toggleRequested) }
            })
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let controller = self.notchController else { return }
                    self.applyPreferences(to: controller)
                }
            })

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: PrefKey.firstLaunchDone) {
            defaults.set(true, forKey: PrefKey.firstLaunchDone)
            controller.viewModel.send(.toggleRequested)
        }
    }

    /// Dock에 없는 앱을 다시 실행하면 패널을 펼친다.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if notchController?.viewModel.state == .collapsed { notchController?.viewModel.send(.toggleRequested) }
        return false
    }

    private func applyPreferences(to controller: NotchWindowController) {
        let defaults = UserDefaults.standard
        let hover = defaults.bool(forKey: PrefKey.hoverToOpen)
        if controller.viewModel.hoverToOpen != hover { controller.viewModel.hoverToOpen = hover }
        let virtual = defaults.bool(forKey: PrefKey.showVirtualNotch)
        if controller.showVirtualNotch != virtual { controller.showVirtualNotch = virtual }
    }
}
```

- [ ] **Step 5: 빌드·테스트·수동 확인**

메뉴바 아이콘 좌클릭 → 4개 항목. "Open Panel" → 펼침/접힘 토글. "Settings…" → 설정 창이 **앞에** 뜸(뒤에 뜨면 `SettingsLink` 앞에 `NSApp.activate(ignoringOtherApps: true)`를 호출하는 Button으로 감싼 뒤 `openSettings` 환경값 사용). "Show menu bar icon" 끄기 → 확인 대화상자 → 숨김 → 앱 아이콘을 Finder에서 다시 열면 패널 펼침. "Launch at login" 켜기 → 시스템 설정 > 일반 > 로그인 항목에 OpenNotch 표시. "Open on hover" 켜고 노치에 0.4초 머물면 펼침, 벗어나면 0.3초 후 접힘. Quit 동작.

- [ ] **Step 6: 커밋**

```bash
git add Sources
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: 메뉴바 메뉴, 설정 창(일반·정보), 로그인 항목, reopen, 첫 실행 펼침

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: 전역 단축키 ⌃⌥N (Carbon, 권한 불필요)

**Files:**
- Create: `Sources/App/HotKey.swift`
- Modify: `Sources/App/AppDelegate.swift`

**Interfaces:**
- Produces: `@MainActor final class HotKey { init?(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void); deinit unregisters }`

- [ ] **Step 1: 구현**

`Sources/App/HotKey.swift`:
```swift
import Carbon.HIToolbox

/// Carbon RegisterEventHotKey 기반 전역 단축키. 샌드박스에서 Accessibility 없이 동작한다.
/// 앱 전체에서 한 개만 쓴다(핸들러가 정적).
@MainActor
final class HotKey {
    private static var action: (@MainActor () -> Void)?
    private static var handlerRef: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?

    static let controlOption: UInt32 = UInt32(controlKey | optionKey)
    static let keyN: UInt32 = UInt32(kVK_ANSI_N)

    init?(keyCode: UInt32 = HotKey.keyN, modifiers: UInt32 = HotKey.controlOption, action: @escaping @MainActor () -> Void) {
        Self.action = action
        if Self.handlerRef == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                MainActor.assumeIsolated { HotKey.action?() }
                return noErr
            }, 1, &spec, nil, &Self.handlerRef)
            guard status == noErr else { return nil }
        }
        let signature = OSType(0x4F4E4348)   // 'ONCH'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        hotKeyRef = ref
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    }
}
```
(`0x4F4E4348`은 문자 'ONCH'의 코드 — 매직 넘버 규칙 대상 이름(`port/timeout/…`)이 아니며 주석으로 의미를 남긴다.)

- [ ] **Step 2: AppDelegate 배선**

프로퍼티 추가:
```swift
    private var hotKey: HotKey?
```
`applyPreferences(to:)` 끝에:
```swift
        let wantsHotKey = defaults.bool(forKey: PrefKey.hotkeyEnabled)
        if wantsHotKey, hotKey == nil {
            hotKey = HotKey { [weak controller] in controller?.viewModel.send(.toggleRequested) }
        } else if !wantsHotKey {
            hotKey = nil
        }
```

- [ ] **Step 3: 빌드·수동 확인**

다른 앱이 앞에 있을 때 ⌃⌥N → 패널 토글. 설정에서 끄면 동작 안 함, 다시 켜면 동작. 시스템 설정 손쉬운 사용 목록에 OpenNotch 없음.

- [ ] **Step 4: 커밋**

```bash
git add Sources/App
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: 전역 단축키 ⌃⌥N (Carbon)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: 공개 저장소 문서 + 심사 리허설 스크립트

**Files:**
- Create: `LICENSE`, `README.md`, `PRIVACY.md`, `scripts/review-check.sh`

- [ ] **Step 1: 문서**

`LICENSE`: MIT 전문, `Copyright (c) 2026 holyshine11`.

`README.md`:
```markdown
# OpenNotch

A free, open-source utility that turns the MacBook notch into a tiny control center — AirDrop drop zone, YouTube / YouTube Music controls, clipboard history, and a file shelf. Sandboxed, no private APIs, built for the Mac App Store.

## Status
Work in progress (P1: notch window). See `docs/strategy` and `docs/superpowers` for the plan.

## Build
Requires Xcode 26.6+ and [xcodegen](https://github.com/yonaskolb/XcodeGen).
```
```bash
xcodegen generate
xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -destination 'platform=macOS' test
```
```markdown
## License
MIT — see `LICENSE`.
```

`PRIVACY.md`:
```markdown
# OpenNotch Privacy Policy

OpenNotch does not collect, store, or transmit any personal data. It has no network access and no analytics.

- Clipboard history and the file shelf are stored only on your Mac, inside the app's sandbox container, and can be cleared at any time from Settings.
- Items marked as concealed or transient by other apps (e.g. password managers) are never stored.
- YouTube controls talk only to the browser tabs you already have open, and only after you turn the feature on.

Contact: open an issue on GitHub.
```

- [ ] **Step 2: 심사 리허설 스크립트**

`scripts/review-check.sh`:
```bash
#!/bin/bash
# 빌드된 앱의 entitlements와 사설 심볼을 점검한다. 사용: scripts/review-check.sh path/to/OpenNotch.app
set -euo pipefail
APP="${1:?usage: review-check.sh <OpenNotch.app>}"
BIN="$APP/Contents/MacOS/OpenNotch"
echo "== entitlements =="
codesign -d --entitlements :- "$APP" 2>/dev/null | plutil -p - | sed 's/^/  /'
echo "== private symbols (must be empty) =="
if nm -u "$BIN" 2>/dev/null | grep -E 'MRMediaRemote|_SLS|_CGS[A-Z]' ; then echo "FAIL: private symbols found"; exit 1; fi
if otool -L "$BIN" | grep -iE 'PrivateFrameworks|MediaRemote|SkyLight' ; then echo "FAIL: private framework linked"; exit 1; fi
echo "  none"
echo "== Info.plist required keys =="
for key in LSUIElement LSApplicationCategoryType LSMinimumSystemVersion ITSAppUsesNonExemptEncryption; do
  printf '  %s = ' "$key"; /usr/libexec/PlistBuddy -c "Print :$key" "$APP/Contents/Info.plist"
done
echo "OK"
```
`chmod +x scripts/review-check.sh` 후 Debug 빌드 앱에 실행 → entitlements 3개 + Debug 키만, 사설 심볼 없음, plist 키 4개 출력.

- [ ] **Step 3: 커밋**

```bash
git add LICENSE README.md PRIVACY.md scripts
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "docs: MIT 라이선스, README, 개인정보 처리방침, 심사 리허설 스크립트

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## P1 완료 기준

- `xcodebuild test` 통과(EntitlementsTests 2, NotchGeometryTests 6, NotchViewModelTests 12).
- 노치 있는 화면·없는 화면(외장 모니터만 연결) 양쪽에서: 클릭/⌃⌥N/메뉴로 펼침, 바깥 클릭·6초 유휴로 접힘, 드래그 진입 시 두 드롭존, 호버 옵션 동작.
- 시스템 설정 개인정보 보호의 손쉬운 사용·입력 모니터링·자동화 목록에 OpenNotch가 없음.
- `scripts/review-check.sh`가 OK.
- 다음 계획: P2 셸프/AirDrop (`onDropURLs`·`paneProvider.shelf` 연결), P3 클립보드(`paneProvider.clipboard`, `NotchHost.setWantsKey`), P4 미디어(`paneProvider.media`, entitlements 키 추가, `EntitlementsTests` 확장).
