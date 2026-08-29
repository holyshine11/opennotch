#if MEDIA_ENABLED
import AppKit
import SwiftUI

extension Notification.Name {
    /// 패널·설정에서 안내 창을 열 때. AppDelegate가 창을 띄운다.
    static let openNotchShowMediaSetup = Notification.Name("com.holyshine11.opennotch.showMediaSetup")
}

/// "메뉴 열어 주기"를 누른 뒤 카드가 지나가는 단계. 뷰 안에서만 쓴다.
private enum AssistPhase: Equatable {
    case consent, waitingForPermission, running, clickTheItem, done, failed, automationDenied
}

/// 처음 쓰는 사람을 위한 한 화면 안내. 브라우저마다 지금 상태와 다음에 할 일 하나(탭 열기 / 메뉴 켜기 / 권한 열기)를 같이 보여 주고,
/// 창이 열려 있는 동안 계속 probe해서 사용자가 토글을 켜는 즉시 체크가 바뀐다. 높이는 내용에 맞춘다(설치된 브라우저 수만큼).
struct MediaSetupGuideView: View {
    let controller: MediaController
    /// 첫 실행에서만 환영 인사를 붙인다.
    var showWelcome = false

    /// 손쉬운 사용 도우미의 브라우저별 진행 단계. 값이 없으면 평소처럼 메뉴 경로 칩을 보여 준다.
    @State private var assist: [BrowserKind: AssistPhase] = [:]

    private var browsers: [BrowserKind] { BrowserKind.browsers.filter(\.isInstalled) }
    private var allReady: Bool { !browsers.isEmpty && browsers.allSatisfy { controller.setupStatus($0) == .ready } }
    private var readyBrowsers: [BrowserKind] { browsers.filter { controller.setupStatus($0) == .ready } }
    private var waitingBrowsers: [BrowserKind] { browsers.filter { assist[$0] == .waitingForPermission } }
    private var clickingBrowsers: [BrowserKind] { browsers.filter { assist[$0] == .clickTheItem } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showWelcome {
                welcome
                Divider()
            }
            header
            ForEach(browsers, id: \.rawValue, content: card)
            footer
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(20)
        .frame(width: Constants.mediaSetupWindowWidth)
        .onAppear { controller.setPanelOpen(true) }
        .onDisappear { controller.setPanelOpen(false) }
        // 권한을 켜는 즉시 이어서 진행한다. 창을 닫으면 `.task`가 취소된다.
        .task(id: waitingBrowsers) { await awaitPermission() }
        .task(id: clickingBrowsers) { await pollWhileMenuOpen() }
        .onChange(of: readyBrowsers) { _, now in
            // 사용자가 메뉴에서 마지막 항목을 눌러 켜진 경우 브라우저가 앞에 있다 — 안내 창을 다시 앞으로 가져온다.
            let finishedByAssistant = now.contains { assist[$0] != nil }
            for browser in now { assist[browser] = nil }
            if finishedByAssistant { bringGuideWindowFront() }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to OpenNotch").font(.title2.bold())
                    Text("Your notch is now a panel.").foregroundStyle(.secondary)
                }
            }
            tip("cursorarrow.click", "Click the notch or press ⌃⌥N to open the panel.")
            tip("square.and.arrow.up", "Drag files onto the notch to AirDrop them or keep them in the shelf.")
            tip("doc.on.clipboard", "Everything you copy is kept in the Clipboard tab.")
        }
    }

    private func tip(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 16)).frame(width: 24)
            Text(text).font(.callout)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Music controls").font(.headline)
            summary
            if !browsers.isEmpty, !allReady {
                Text("Press the button next to a browser to open YouTube in it. If macOS asks to allow control, click Allow. Then turn on the menu item shown under that browser — the check turns green by itself.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var summary: some View {
        if browsers.isEmpty {
            Text("Apple Music works right away. No supported browser is installed.")
                .font(.callout).foregroundStyle(.secondary)
        } else if allReady {
            Label("All set — every browser is ready.", systemImage: "checkmark.circle.fill")
                .font(.callout).foregroundStyle(.green)
        } else {
            Text("Apple Music works right away. Each browser needs one setting turned on — about a minute.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    /// 브라우저 한 칸: 상태 + 지금 누를 버튼 하나 + 켤 메뉴 위치.
    private func card(_ browser: BrowserKind) -> some View {
        let status = controller.setupStatus(browser)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: status.symbol).font(.system(size: 18)).foregroundStyle(status.tint)
                Text(browser.displayName).font(.title3.bold())
                Text(status.label).font(.callout).foregroundStyle(status.tint)
                Spacer(minLength: 8)
                action(browser, status)
            }
            if status == .permissionDenied {
                Text("Turn on \(browser.displayName) under OpenNotch in Privacy & Security › Automation, then come back.")
                    .font(.callout)
            } else if status == .jsOff, let phase = assist[browser] {
                assistBody(browser, phase)
            } else {
                menuPath(browser, ready: status == .ready)
                if browser.isSafari {
                    Text("No Developer tab? In Settings › Advanced, turn on “Show features for web developers” first.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private func action(_ browser: BrowserKind, _ status: BrowserSetupStatus) -> some View {
        switch status {
        case .ready:
            EmptyView()
        case .jsOff:
            // 삼항 연산자를 인자에 바로 쓰면 문자열 리터럴이 `String`으로 추론돼 번역이 빠진다 — 타입을 명시한다.
            let title: LocalizedStringKey = browser.isSafari ? "Turn it on for me" : "Open the menu for me"
            Button(title) {
                if SetupAssistant.isTrusted {
                    Task { await run(browser) }
                } else {
                    assist[browser] = .consent
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(assist[browser] == .running || assist[browser] == .waitingForPermission)
            Button("Show \(browser.displayName)") { browser.activate() }
        case .permissionDenied:
            Button("Open System Settings") {
                if let url = URL(string: Constants.automationPrivacySettingsURL) { NSWorkspace.shared.open(url) }
            }
        case .noTab, .notRunning:
            Button("Open YouTube in \(browser.displayName)") { browser.openCheckPage() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: 손쉬운 사용 도우미

    /// `.jsOff` 카드에서 칩 줄을 대신하는 진행 안내. `.clickTheItem`·`.failed`에서는 칩 줄도 같이 보여 준다.
    @ViewBuilder private func assistBody(_ browser: BrowserKind, _ phase: AssistPhase) -> some View {
        switch phase {
        case .consent:
            VStack(alignment: .leading, spacing: 8) {
                if browser.isSafari {
                    Text("OpenNotch needs the macOS Accessibility permission to turn this on in Safari Settings for you (it also turns on “Show features for web developers” if that is still off).")
                        .font(.callout)
                } else {
                    Text("OpenNotch needs the macOS Accessibility permission to open \(browser.displayName)’s menu for you.")
                        .font(.callout)
                }
                Text("It is used only for this — nothing on your screen is read or recorded, and you can turn it off any time in System Settings.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("macOS doesn’t ask for this one automatically — you add OpenNotch to the list yourself. The next step shows where.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("Allow…") {
                        // 샌드박스 앱에는 손쉬운 사용 프롬프트가 뜨지 않는다(2026-08-29 실측, MAS의 Magnet·Moom도 같은 안내).
                        // 혹시 뜨는 환경을 위해 요청은 하되, 설정 화면을 바로 열어 목록에 직접 추가하게 한다.
                        SetupAssistant.requestPermission()
                        openAccessibilitySettings()
                        assist[browser] = .waitingForPermission
                    }
                    .buttonStyle(.borderedProminent)
                    Button("I’ll do it myself") { assist[browser] = nil }.buttonStyle(.link)
                }
            }
        case .waitingForPermission:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Add OpenNotch to System Settings › Privacy & Security › Accessibility and turn it on — this continues by itself.")
                        .font(.callout)
                }
                Text("Click + under the list and pick OpenNotch in Applications, or drag OpenNotch from Finder onto the list.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    Button("Open System Settings") { openAccessibilitySettings() }
                    Button("Show OpenNotch in Finder") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
                }
                .buttonStyle(.link)
            }
        case .running:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Opening \(browser.displayName)’s menu… If macOS asks to allow control of System Events, click Allow.").font(.callout)
            }
        case .clickTheItem:
            VStack(alignment: .leading, spacing: 8) {
                Text("Click “\(browser.menuPath.last ?? "")” in the menu that just opened — the check turns green by itself.")
                    .font(.callout.weight(.semibold))
                menuPath(browser, ready: false)
            }
        case .done:
            Text("Done — checking…").font(.callout).foregroundStyle(.secondary)
        case .failed:
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn’t find the menu item — please open it yourself:").font(.callout)
                menuPath(browser, ready: false)
            }
        case .automationDenied:
            VStack(alignment: .leading, spacing: 8) {
                Text("macOS blocked OpenNotch from asking System Events to open the menu. Turn on System Events under OpenNotch in Privacy & Security › Automation, then try again.")
                    .font(.callout)
                HStack(spacing: 12) {
                    Button("Open System Settings") {
                        if let url = URL(string: Constants.automationPrivacySettingsURL) { NSWorkspace.shared.open(url) }
                    }
                    Button("I’ll do it myself") { assist[browser] = nil }
                }
                .buttonStyle(.link)
                menuPath(browser, ready: false)
            }
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: Constants.accessibilityPrivacySettingsURL) { NSWorkspace.shared.open(url) }
    }

    /// 도우미를 한 번 돌리고 결과를 단계로 옮긴다. 바로 probe해서 체크가 1초 안에 초록이 되게 한다.
    @MainActor private func run(_ browser: BrowserKind) async {
        assist[browser] = .running
        switch await SetupAssistant.revealJSToggle(in: browser) {
        case .alreadyOn, .turnedOn:
            assist[browser] = .done
            bringGuideWindowFront()
            // 초록 체크는 다음 probe가 올린다. 그래도 안 오면(탭이 닫혔거나 probe 실패) 카드를 되돌려 버튼을 다시 보여 준다.
            Task {
                try? await Task.sleep(for: .seconds(Constants.assistConfirmDelay))
                if assist[browser] == .done { assist[browser] = nil }
            }
        case .menuLeftOpen:
            assist[browser] = .clickTheItem   // 열린 메뉴에는 지금 물어도 답이 없다 — pollWhileMenuOpen이 맡는다
            return
        case .notFound: assist[browser] = .failed
        case .noPermission: assist[browser] = .consent
        case .automationDenied: assist[browser] = .automationDenied
        }
        controller.poll()
    }

    /// 메뉴를 펼쳐 둔 동안 크로미움은 Apple Event에 답하지 않으므로 묻지 않고 기다리다가, 메뉴가 닫히는 순간(사용자가 항목을 누름)
    /// 백오프를 무시하고 바로 묻는다 → 몇 초 안에 초록 체크. 닫혔는데도 안 켜졌으면(다른 곳을 클릭) 버튼을 다시 보여 준다.
    @MainActor private func pollWhileMenuOpen() async {
        for browser in clickingBrowsers {
            while !Task.isCancelled, assist[browser] == .clickTheItem, await SetupAssistant.isMenuOpen(in: browser) {
                try? await Task.sleep(for: .seconds(Constants.assistMenuPollInterval))
            }
            guard !Task.isCancelled, assist[browser] == .clickTheItem else { continue }
            controller.retryNow(browser)
            try? await Task.sleep(for: .seconds(Constants.assistConfirmDelay))
            if !Task.isCancelled, assist[browser] == .clickTheItem { assist[browser] = nil }
        }
    }

    /// 권한 프롬프트에는 콜백이 없어 1초마다 직접 확인한다. 켜지는 즉시 이어서 진행한다.
    @MainActor private func awaitPermission() async {
        guard !waitingBrowsers.isEmpty else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Constants.assistPermissionPollInterval))
            guard !Task.isCancelled else { return }
            guard SetupAssistant.isTrusted else { continue }
            for browser in waitingBrowsers { await run(browser) }
            return
        }
    }

    /// 브라우저가 앞으로 나간 뒤 안내 창을 다시 보여 준다(AppDelegate가 이 뷰를 `ScrollView`로 감싸 띄운다).
    private func bringGuideWindowFront() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.contentViewController is NSHostingController<ScrollView<MediaSetupGuideView>> }?
            .makeKeyAndOrderFront(nil)
    }

    /// 클릭 경로를 메뉴 조각으로 그린다: [보기] › [개발자 정보] › [☐ Apple Events의 자바스크립트 허용]. 마지막 조각이 켤 항목.
    private func menuPath(_ browser: BrowserKind, ready: Bool) -> some View {
        let parts = browser.menuPath
        return FlowLayout(spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                if i > 0 { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary) }
                chip(part, last: i == parts.count - 1, ready: ready)
            }
        }
        .opacity(ready ? 0.55 : 1)
    }

    private func chip(_ text: String, last: Bool, ready: Bool) -> some View {
        HStack(spacing: 4) {
            if last {
                Image(systemName: ready ? "checkmark.square.fill" : "square")
                    .font(.callout).foregroundStyle(ready ? Color.green : .primary)
            }
            Text(text).font(.callout.weight(last ? .semibold : .regular)).fixedSize()
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(last ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 7))
    }

    private var footer: some View {
        HStack {
            Text("This window updates by itself — leave it open while you flip the switch.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Done") { NSApp.keyWindow?.performClose(nil) }.keyboardShortcut(.defaultAction)
        }
    }
}

private extension BrowserSetupStatus {
    var symbol: String {
        switch self {
        case .ready: "checkmark.circle.fill"
        case .jsOff: "exclamationmark.circle.fill"
        case .permissionDenied: "xmark.shield.fill"
        case .noTab, .notRunning: "circle.dashed"
        }
    }

    var tint: Color {
        switch self {
        case .ready: .green
        case .jsOff: .orange
        case .permissionDenied: .red
        case .noTab, .notRunning: .secondary
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .ready: "Ready"
        case .jsOff: "Turn on the menu item below"
        case .permissionDenied: "Blocked in System Settings"
        case .noTab: "Waiting for a YouTube tab"
        case .notRunning: "Not running"
        }
    }
}

/// 한 줄에 안 들어가는 칩을 다음 줄로 넘긴다(한국어 Safari 메뉴 경로는 한 줄에 안 들어간다).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(_ subviews: Subviews, limit: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            let width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty, width > limit {
                rows.append(row)
                row = Row(indices: [i], width: size.width, height: size.height)
            } else {
                row.indices.append(i)
                row.width = width
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }

    private func height(_ rows: [Row]) -> CGFloat {
        rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(subviews, limit: proposal.width ?? .infinity)
        return CGSize(width: rows.map(\.width).max() ?? 0, height: height(rows))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(subviews, limit: bounds.width) {
            var x = bounds.minX
            for i in row.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                  anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
}
#endif
