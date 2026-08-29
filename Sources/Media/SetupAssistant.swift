#if MEDIA_ENABLED
import AppKit
import ApplicationServices

/// 손쉬운 사용 권한으로 브라우저 메뉴를 대신 열어 주는 도우미. 권한이 없으면 아무것도 하지 않는다.
/// 공개 Accessibility API만 쓴다 — 메뉴 막대·메뉴 항목·체크박스를 누르고, Safari 설정 창은 그 창의 닫기 버튼으로만 닫는다.
/// 화면을 읽거나 기록하지 않으며, 실패하면 아무것도 바꾸지 않고 수동 경로 안내로 돌아간다.
/// `AXUIElement`가 Sendable이 아니라 AX 호출은 전용 직렬 큐 안에서 동기로 끝내고 결과 enum만 돌려준다.
enum SetupAssistant {
    enum Outcome: Sendable, Equatable {
        /// 항목이 이미 켜져 있었다(메뉴는 닫음).
        case alreadyOn
        /// 우리가 눌러서 켜졌다(메뉴는 닫음).
        case turnedOn
        /// 크로미움이 합성 클릭을 무시했다 → 서브메뉴를 펼쳐 둔 채 사용자가 마지막 항목을 클릭한다.
        case menuLeftOpen
        /// 메뉴·체크박스를 찾지 못함(다른 언어 등) → 수동 경로 안내.
        case notFound
        case noPermission
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// 시스템 프롬프트를 띄운다(최초 1회만 뜬다 — 그 뒤에는 시스템 설정으로 보내야 한다).
    /// `kAXTrustedCheckOptionPrompt`는 strict concurrency에서 쓸 수 없는 전역이라 키 문자열을 직접 쓴다.
    static func requestPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// 브라우저를 앞으로 가져온 뒤 JS 허용 토글까지 간다. 크로미움은 메뉴를, Safari는 설정 창의 체크박스를 다룬다.
    @MainActor
    static func revealJSToggle(in browser: BrowserKind) async -> Outcome {
        guard isTrusted else { return .noPermission }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: browser.rawValue).first else { return .notFound }
        app.activate()
        let pid = app.processIdentifier
        let safari = browser.isSafari
        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: safari ? runSafari(pid) : runChromium(pid)) }
        }
    }

    /// 보기 메뉴가 아직 펼쳐져 있는지(메뉴 막대 항목의 AXSelected — 2026-08-29 Whale 실측). 사용자가 항목을 눌러 메뉴가 닫히는 순간을 잡는다.
    @MainActor
    static func isMenuOpen(in browser: BrowserKind) async -> Bool {
        guard isTrusted, let app = NSRunningApplication.runningApplications(withBundleIdentifier: browser.rawValue).first else { return false }
        let pid = app.processIdentifier
        return await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: viewMenuIsOpen(pid)) }
        }
    }

    // MARK: 크로미움(보기 › 개발자 정보 › Apple Events의 자바스크립트 허용)

    private static func viewMenuIsOpen(_ pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Constants.assistMessagingTimeout)
        guard let menuBar = child(app, kAXMenuBarAttribute), let viewItem = viewMenuItem(menuBar) else { return false }
        return value(viewItem, kAXSelectedAttribute) as? Bool ?? false
    }

    /// 이름으로 못 찾으면 자리로 찾는다(Apple, 앱, 파일, 편집, 보기).
    private static func viewMenuItem(_ menuBar: AXUIElement) -> AXUIElement? {
        let bar = children(menuBar)
        return bar.first { MenuTitles.match(title($0), MenuTitles.view) }
            ?? (bar.indices.contains(MenuTitles.viewMenuIndex) ? bar[MenuTitles.viewMenuIndex] : nil)
    }

    private static func runChromium(_ pid: pid_t) -> Outcome {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Constants.assistMessagingTimeout)
        Thread.sleep(forTimeInterval: Constants.assistActivateDelay)   // 브라우저가 앞으로 나와 메뉴 막대가 바뀔 때까지
        // 메뉴가 아직 안 열렸을 수 있으므로 전체 순서를 딱 한 번만 다시 시도한다.
        for attempt in 0...1 {
            guard let items = openDeveloperSubmenu(app), let toggle = jsToggle(in: items) else {
                cancelMenus(app)
                if attempt == 0 {
                    Thread.sleep(forTimeInterval: Constants.assistMenuOpenDelay)
                    continue
                }
                return .notFound
            }
            if isChecked(toggle) {
                cancelMenus(app)
                return .alreadyOn
            }
            press(toggle)
            Thread.sleep(forTimeInterval: Constants.assistSettleDelay)
            // 크로미움은 합성 클릭을 무시하기도 한다(그러면 메뉴가 열린 채 남는다). 일단 닫고 다시 열어 체크 표시를 확인하고,
            // 안 켜졌으면 메뉴를 펼친 채로 둔다. 닫지 않고 보기를 다시 누르면 열린 메뉴가 도로 닫혀 못 찾은 것으로 잘못 판정된다.
            cancelMenus(app)
            Thread.sleep(forTimeInterval: Constants.assistMenuOpenDelay)
            guard let reopened = openDeveloperSubmenu(app), let toggleAgain = jsToggle(in: reopened) else {
                cancelMenus(app)
                return .notFound
            }
            if isChecked(toggleAgain) {
                cancelMenus(app)
                return .turnedOn
            }
            return .menuLeftOpen
        }
        return .notFound
    }

    /// 보기 › 개발자 정보 서브메뉴를 열고 그 항목들을 돌려준다.
    private static func openDeveloperSubmenu(_ app: AXUIElement) -> [AXUIElement]? {
        guard let menuBar = child(app, kAXMenuBarAttribute), let viewItem = viewMenuItem(menuBar), press(viewItem) else { return nil }
        Thread.sleep(forTimeInterval: Constants.assistMenuOpenDelay)
        guard let viewMenu = children(viewItem).first else { return nil }
        let items = children(viewMenu)
        guard let developer = items.first(where: { MenuTitles.match(title($0), MenuTitles.developer) })
            ?? items.first(where: { MenuTitles.contains(title($0), MenuTitles.developer) }),
            press(developer) else { return nil }
        Thread.sleep(forTimeInterval: Constants.assistMenuOpenDelay)
        guard let submenu = children(developer).first else { return nil }
        return children(submenu)
    }

    /// 이름으로 못 찾으면 서브메뉴의 마지막 항목이 이 토글이다(크로미움 공통).
    private static func jsToggle(in items: [AXUIElement]) -> AXUIElement? {
        items.first { MenuTitles.match(title($0), MenuTitles.allowJS) } ?? items.last
    }

    /// 열어 둔 메뉴를 닫는다(닫힌 메뉴에는 아무 일도 일어나지 않는다). 창은 건드리지 않는다.
    private static func cancelMenus(_ app: AXUIElement) {
        guard let menuBar = child(app, kAXMenuBarAttribute) else { return }
        for menu in children(menuBar).compactMap({ children($0).first }) {
            perform(menu, kAXCancelAction)
        }
    }

    // MARK: Safari(설정 › 개발자 › Apple 이벤트에서 JavaScript 허용)

    private static func runSafari(_ pid: pid_t) -> Outcome {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, Constants.assistMessagingTimeout)
        Thread.sleep(forTimeInterval: Constants.assistActivateDelay)
        guard openSafariSettings(app) else { return .notFound }
        Thread.sleep(forTimeInterval: Constants.assistSettleDelay)
        guard let window = safariSettingsWindow(app) else { return .notFound }
        guard openSafariDeveloperTab(window) else {
            closeSettingsWindow(window)
            return .notFound
        }
        Thread.sleep(forTimeInterval: Constants.assistActivateDelay)
        guard let toggle = checkbox(window, MenuTitles.allowJSSafari) else {
            closeSettingsWindow(window)
            return .notFound
        }
        let outcome: Outcome = isOn(toggle) ? .alreadyOn : .turnedOn
        if outcome == .turnedOn {
            press(toggle)
            Thread.sleep(forTimeInterval: Constants.assistActivateDelay)
        }
        closeSettingsWindow(window)
        return outcome
    }

    /// Safari 메뉴 › 설정… 을 누른다. 이름을 못 찾으면 단축키가 ⌘,인 항목을 고른다(언어와 무관). 그래도 없으면 아무것도 누르지 않는다.
    private static func openSafariSettings(_ app: AXUIElement) -> Bool {
        guard let menuBar = child(app, kAXMenuBarAttribute) else { return false }
        let bar = children(menuBar)
        guard bar.indices.contains(MenuTitles.appMenuIndex) else { return false }
        let appMenuItem = bar[MenuTitles.appMenuIndex]
        guard press(appMenuItem) else { return false }
        Thread.sleep(forTimeInterval: Constants.assistMenuOpenDelay)
        let items = children(appMenuItem).first.map(children) ?? []
        guard let settings = items.first(where: { MenuTitles.match(title($0), MenuTitles.settings) })
                ?? items.first(where: { value($0, kAXMenuItemCmdCharAttribute) as? String == MenuTitles.settingsShortcut }),
              press(settings) else {
            cancelMenus(app)
            return false
        }
        return true
    }

    /// 툴바에 개발자/고급 탭 버튼이 있는 창 = Safari 설정 창. 다른 창은 찾지도, 건드리지도 않는다.
    private static func safariSettingsWindow(_ app: AXUIElement) -> AXUIElement? {
        let windows = value(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        return windows.first {
            toolbarButton($0, MenuTitles.safariDeveloperTab) != nil || toolbarButton($0, MenuTitles.safariAdvancedTab) != nil
        }
    }

    /// 개발자 탭을 연다. 탭이 없으면 고급 탭에서 "웹 개발자를 위한 기능 보기"를 먼저 켠다.
    private static func openSafariDeveloperTab(_ window: AXUIElement) -> Bool {
        if let developer = toolbarButton(window, MenuTitles.safariDeveloperTab) { return press(developer) }
        guard let advanced = toolbarButton(window, MenuTitles.safariAdvancedTab), press(advanced) else { return false }
        Thread.sleep(forTimeInterval: Constants.assistActivateDelay)
        if let show = checkbox(window, MenuTitles.safariShowDevFeatures), !isOn(show) {
            press(show)
            Thread.sleep(forTimeInterval: Constants.assistActivateDelay)
        }
        guard let developer = toolbarButton(window, MenuTitles.safariDeveloperTab) else { return false }
        return press(developer)
    }

    /// 우리가 연 설정 창만, 그것도 그 창의 닫기 버튼으로만 닫는다.
    private static func closeSettingsWindow(_ window: AXUIElement) {
        guard let button = child(window, kAXCloseButtonAttribute) else { return }
        press(button)
    }

    /// 창의 `AXToolbar` 속성은 비어 있고(2026-08-29 Safari 26 실측) 툴바는 자식 요소로 달려 있다.
    private static func toolbar(_ window: AXUIElement) -> AXUIElement? {
        children(window).first { value($0, kAXRoleAttribute) as? String == kAXToolbarRole }
    }

    private static func toolbarButton(_ window: AXUIElement, _ candidates: [String]) -> AXUIElement? {
        guard let toolbar = toolbar(window) else { return nil }
        // 툴바 항목의 역할은 macOS 버전마다 달라(AXButton·AXRadioButton) 이름만 본다.
        return find(toolbar, role: nil, titles: candidates, depth: Constants.assistSearchDepth)
    }

    private static func checkbox(_ window: AXUIElement, _ candidates: [String]) -> AXUIElement? {
        find(window, role: kAXCheckBoxRole, titles: candidates, depth: Constants.assistSearchDepth)
    }

    // MARK: AX 접근(모두 `queue` 안에서만 호출한다)

    /// 큐 하나로 직렬화한다 — AX 호출은 응답을 기다리는 동안 막히므로 메인 스레드에서 하면 안 된다.
    private static let queue = DispatchQueue(label: "com.holyshine11.opennotch.setupassistant")

    private static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private static func child(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let raw = value(element, attribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        return (raw as! AXUIElement)   // 바로 위에서 타입 ID를 확인했다
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        value(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private static func title(_ element: AXUIElement) -> String? {
        value(element, kAXTitleAttribute) as? String
    }

    /// 이름(과 필요하면 역할)이 맞는 요소를 깊이 우선으로 찾는다. 설정 창 계층은 얕아 상한을 둔다.
    private static func find(_ element: AXUIElement, role: String?, titles: [String], depth: Int) -> AXUIElement? {
        guard depth > 0 else { return nil }
        for candidate in children(element) {
            if role == nil || value(candidate, kAXRoleAttribute) as? String == role,
               MenuTitles.match(title(candidate), titles) { return candidate }
            if let found = find(candidate, role: role, titles: titles, depth: depth - 1) { return found }
        }
        return nil
    }

    @discardableResult
    private static func perform(_ element: AXUIElement, _ action: String) -> Bool {
        AXUIElementPerformAction(element, action as CFString) == .success
    }

    @discardableResult
    private static func press(_ element: AXUIElement) -> Bool { perform(element, kAXPressAction) }

    /// 메뉴 항목의 체크 표시(✓). 빈 문자열이면 꺼진 것.
    private static func isChecked(_ item: AXUIElement) -> Bool {
        (value(item, kAXMenuItemMarkCharAttribute) as? String).map { !$0.isEmpty } ?? false
    }

    private static func isOn(_ element: AXUIElement) -> Bool {
        (value(element, kAXValueAttribute) as? Int ?? 0) != 0
    }
}
#endif
