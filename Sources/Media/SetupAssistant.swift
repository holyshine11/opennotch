#if MEDIA_ENABLED
import AppKit
import ApplicationServices
import os

/// 손쉬운 사용 권한으로 브라우저 메뉴를 대신 열어 주는 도우미. 권한이 없으면 아무것도 하지 않는다.
/// 샌드박스 앱은 직접 AX API가 전부 거부되므로(-25204, 2026-08-29 실측) System Events에 UI 스크립팅을 부탁한다 —
/// 엔타이틀먼트 temporary-exception에 `com.apple.systemevents`가 있어야 하고, macOS가 호출 앱의 손쉬운 사용 권한을 본다.
/// 메뉴 막대·메뉴 항목·Safari 설정 창의 체크박스만 누르고, 창은 Safari 설정 창의 닫기 버튼만 누른다. 실패하면 아무것도 바꾸지 않는다.
enum SetupAssistant {
    enum Outcome: Sendable, Equatable {
        /// 항목이 이미 켜져 있었다(메뉴는 닫음).
        case alreadyOn
        /// 우리가 눌러서 켜졌다(메뉴는 닫음) — Safari, 또는 합성 클릭을 받아 주는 크로미움.
        case turnedOn
        /// 크로미움이 합성 클릭을 무시했다(Whale 실측) → 서브메뉴를 펼쳐 둔 채 사용자가 마지막 항목을 클릭한다.
        case menuLeftOpen
        /// 메뉴·체크박스를 찾지 못함(다른 언어 등) → 수동 경로 안내.
        case notFound
        /// 손쉬운 사용 권한 없음.
        case noPermission
        /// 자동화(System Events) 권한이 거부됨 → 시스템 설정 › 자동화 안내.
        case automationDenied
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }
    private static let logger = Logger(subsystem: "com.holyshine11.opennotch", category: "assist")

    /// 시스템 프롬프트를 요청한다. 샌드박스 앱에는 뜨지 않는 것으로 실측됐지만(수동 추가 안내로 보완) 뜨는 환경을 위해 남긴다.
    /// `kAXTrustedCheckOptionPrompt`는 strict concurrency에서 쓸 수 없는 전역이라 키 문자열을 직접 쓴다.
    static func requestPermission() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// 브라우저를 앞으로 가져온 뒤 JS 허용 토글까지 간다. 크로미움은 메뉴를, Safari는 설정 창의 체크박스를 다룬다.
    @MainActor
    static func revealJSToggle(in browser: BrowserKind) async -> Outcome {
        guard isTrusted else { logger.notice("reveal \(browser.rawValue, privacy: .public): not trusted"); return .noPermission }
        guard browser.isRunning else { logger.notice("reveal \(browser.rawValue, privacy: .public): not running"); return .notFound }
        let script = browser.isSafari ? safariScript(browser) : chromiumScript(browser)
        let outcome: Outcome
        // 스크립트 자체의 `with timeout`이 먼저 끝나도록 Swift 쪽 상한은 조금 더 길게 — 첫 자동화 프롬프트를 기다리다 거짓 실패하지 않게.
        switch await AppleScriptRunner.run(script, timeout: Constants.assistScriptTimeout + Constants.assistScriptGrace, urgent: true) {
        case .success(let out):
            switch out {
            case "ALREADYON": outcome = .alreadyOn
            case "TURNEDON": outcome = .turnedOn
            case "LEFTOPEN": outcome = .menuLeftOpen
            default: logger.notice("reveal \(browser.rawValue, privacy: .public): script said \(out, privacy: .public)"); outcome = .notFound
            }
        case .failure(let f):
            logger.error("reveal \(browser.rawValue, privacy: .public) failed: \(f.code) \(f.message, privacy: .public)")
            outcome = f.code == AppleScriptFailure.permissionDenied ? .automationDenied : .notFound
        }
        logger.notice("reveal \(browser.rawValue, privacy: .public): \(String(describing: outcome), privacy: .public)")
        return outcome
    }

    /// 보기 메뉴가 아직 펼쳐져 있는지(메뉴 막대 항목의 AXSelected). 사용자가 항목을 눌러 메뉴가 닫히는 순간을 잡는다.
    @MainActor
    static func isMenuOpen(in browser: BrowserKind) async -> Bool {
        guard isTrusted, browser.isRunning else { return false }
        if case .success(let out) = await AppleScriptRunner.run(menuOpenScript(browser), timeout: Constants.mediaScriptTimeout, urgent: true) {
            return out == "true"
        }
        return false
    }

    // MARK: 스크립트

    /// AppleScript 리스트 리터럴: {"View", "보기"}.
    private static func list(_ names: [String]) -> String {
        "{" + names.map { "\"\(MediaScript.escape($0))\"" }.joined(separator: ", ") + "}"
    }

    private static func processRef(_ browser: BrowserKind) -> String {
        "(first process whose bundle identifier is \"\(browser.rawValue)\")"
    }

    /// 보기 › 개발자 서브메뉴를 펼치고 토글의 체크 표시(AXMenuItemMarkChar)를 본다. 꺼져 있으면 한 번 눌러 보고, 다시 열어 확인한다.
    /// 크로미움이 클릭을 무시하면 두 번째 판에서 서브메뉴를 펼쳐 둔 채 LEFTOPEN을 돌려준다.
    /// 토글을 이름으로 못 찾으면(다른 언어) 아무것도 누르지 않고 서브메뉴만 펼쳐 둔다 — 엉뚱한 항목을 실행하지 않게.
    /// `it`은 AppleScript 예약어라 루프 변수는 `mi`. 체크 표시가 없으면 `missing value`가 오므로 텍스트로 바꾸기 전에 걸러야 한다.
    static func chromiumScript(_ browser: BrowserKind) -> String {
        """
        on markOf(t)
            tell application "System Events"
                set m to value of attribute "AXMenuItemMarkChar" of t
                if m is missing value then return ""
                return m as text
            end tell
        end markOf
        set viewNames to \(list(MenuTitles.view))
        set devNames to \(list(MenuTitles.developer))
        set allowNames to \(list(MenuTitles.allowJS))
        with timeout of \(Int(Constants.assistScriptTimeout)) seconds
        tell application "System Events"
            tell \(processRef(browser))
                set frontmost to true
                delay \(Constants.assistActivateDelay)
                set mb to menu bar 1
                set viewItem to missing value
                repeat with mi in (every menu bar item of mb)
                    if viewNames contains (name of mi as text) then set viewItem to mi
                end repeat
                if viewItem is missing value then set viewItem to menu bar item \(MenuTitles.viewMenuIndex + 1) of mb
                repeat with pass from 1 to 2
                    click viewItem
                    delay \(Constants.assistMenuOpenDelay)
                    set devItem to missing value
                    repeat with mi in (every menu item of menu 1 of viewItem)
                        try
                            set n to name of mi as text
                            if devNames contains n then set devItem to mi
                        end try
                    end repeat
                    if devItem is missing value then
                        repeat with mi in (every menu item of menu 1 of viewItem)
                            try
                                set n to name of mi as text
                                repeat with cand in devNames
                                    if n contains (cand as text) then set devItem to mi
                                end repeat
                            end try
                        end repeat
                    end if
                    if devItem is missing value then
                        try
                            perform action "AXCancel" of menu 1 of viewItem
                        end try
                        return "NOTFOUND"
                    end if
                    click devItem
                    delay \(Constants.assistMenuOpenDelay)
                    set subItems to every menu item of menu 1 of devItem
                    set toggleItem to missing value
                    repeat with mi in subItems
                        try
                            if allowNames contains (name of mi as text) then set toggleItem to mi
                        end try
                    end repeat
                    if toggleItem is missing value then return "LEFTOPEN"
                    if my markOf(toggleItem) is not "" then
                        perform action "AXCancel" of menu 1 of viewItem
                        if pass is 1 then return "ALREADYON"
                        return "TURNEDON"
                    end if
                    if pass is 2 then return "LEFTOPEN"
                    click toggleItem
                    delay \(Constants.assistSettleDelay)
                    try
                        perform action "AXCancel" of menu 1 of viewItem
                    end try
                    delay \(Constants.assistMenuOpenDelay)
                end repeat
            end tell
        end tell
        end timeout
        """
    }

    /// Safari: 설정(⌘,) › 개발자 탭 › 체크박스. 개발자 탭이 없으면 고급 탭에서 "웹 개발자를 위한 기능 보기"를 먼저 켠다.
    /// 체크박스 경로는 실측(2026-08-29 Safari 26): `checkbox NAME of group 1 of group 1 of window`. 설정 창은 그 창의 닫기 버튼으로만 닫는다.
    static func safariScript(_ browser: BrowserKind) -> String {
        """
        on findCheckbox(w, names)
            tell application "System Events"
                repeat with n in names
                    set nm to n as text
                    try
                        return checkbox nm of group 1 of group 1 of w
                    end try
                    try
                        return checkbox nm of group 1 of w
                    end try
                    try
                        return checkbox nm of w
                    end try
                end repeat
            end tell
            return missing value
        end findCheckbox
        on toolbarButton(w, names)
            tell application "System Events"
                repeat with b in (every button of toolbar 1 of w)
                    if names contains (name of b as text) then return b
                end repeat
            end tell
            return missing value
        end toolbarButton
        set devNames to \(list(MenuTitles.safariDeveloperTab))
        set advNames to \(list(MenuTitles.safariAdvancedTab))
        set showDevNames to \(list(MenuTitles.safariShowDevFeatures))
        set allowNames to \(list(MenuTitles.allowJSSafari))
        with timeout of \(Int(Constants.assistScriptTimeout)) seconds
        tell application "System Events"
            tell \(processRef(browser))
                set frontmost to true
                delay \(Constants.assistActivateDelay)
                set win to missing value
                repeat with attempt from 1 to \(Constants.assistWindowPolls)
                    repeat with w in windows
                        try
                            set names to name of every button of toolbar 1 of w
                            repeat with n in (devNames & advNames)
                                if names contains (n as text) then set win to w
                            end repeat
                        end try
                    end repeat
                    if win is not missing value then exit repeat
                    if attempt is 1 then keystroke "," using command down
                    delay \(Constants.assistMenuOpenDelay)
                end repeat
                if win is missing value then return "NOWINDOW"
                set devBtn to my toolbarButton(win, devNames)
                if devBtn is missing value then
                    set advBtn to my toolbarButton(win, advNames)
                    if advBtn is missing value then return "NOTFOUND"
                    click advBtn
                    delay \(Constants.assistSettleDelay)
                    set showBox to my findCheckbox(win, showDevNames)
                    if showBox is not missing value and (value of showBox as integer) is 0 then click showBox
                    delay \(Constants.assistSettleDelay)
                    set devBtn to my toolbarButton(win, devNames)
                    if devBtn is missing value then return "NOTFOUND"
                end if
                click devBtn
                delay \(Constants.assistSettleDelay)
                set box to my findCheckbox(win, allowNames)
                if box is missing value then
                    set outcome to "NOTFOUND"
                else if (value of box as integer) is 0 then
                    click box
                    set outcome to "TURNEDON"
                else
                    set outcome to "ALREADYON"
                end if
                delay \(Constants.assistMenuOpenDelay)
                try
                    click (first button of win whose subrole is "AXCloseButton")
                end try
                return outcome
            end tell
        end tell
        end timeout
        """
    }

    static func menuOpenScript(_ browser: BrowserKind) -> String {
        """
        set viewNames to \(list(MenuTitles.view))
        with timeout of \(Int(Constants.mediaScriptTimeout)) seconds
        tell application "System Events"
            tell \(processRef(browser))
                set mb to menu bar 1
                set viewItem to missing value
                repeat with mi in (every menu bar item of mb)
                    if viewNames contains (name of mi as text) then set viewItem to mi
                end repeat
                if viewItem is missing value then set viewItem to menu bar item \(MenuTitles.viewMenuIndex + 1) of mb
                return (value of attribute "AXSelected" of viewItem) as text
            end tell
        end tell
        end timeout
        """
    }
}
#endif
