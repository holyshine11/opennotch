#if MEDIA_ENABLED
import AppKit
import SwiftUI

extension Notification.Name {
    /// 패널·설정에서 안내 창을 열 때. AppDelegate가 창을 띄운다.
    static let openNotchShowMediaSetup = Notification.Name("com.holyshine11.opennotch.showMediaSetup")
}

/// 처음 쓰는 사람을 위한 한 화면 안내. 브라우저마다 지금 상태와 다음에 할 일 하나(탭 열기 / 메뉴 켜기 / 권한 열기)를 같이 보여 주고,
/// 창이 열려 있는 동안 계속 probe해서 사용자가 토글을 켜는 즉시 체크가 바뀐다. 높이는 내용에 맞춘다(설치된 브라우저 수만큼).
struct MediaSetupGuideView: View {
    let controller: MediaController
    /// 첫 실행에서만 환영 인사를 붙인다.
    var showWelcome = false

    private var browsers: [BrowserKind] { BrowserKind.browsers.filter(\.isInstalled) }
    private var allReady: Bool { !browsers.isEmpty && browsers.allSatisfy { controller.setupStatus($0) == .ready } }

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
