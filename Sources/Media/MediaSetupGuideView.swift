#if MEDIA_ENABLED
import AppKit
import SwiftUI

extension Notification.Name {
    /// 패널·설정에서 안내 창을 열 때. AppDelegate가 창을 띄운다.
    static let openNotchShowMediaSetup = Notification.Name("com.holyshine11.opennotch.showMediaSetup")
}

/// 처음 쓰는 사람을 위한 한 화면 안내. 브라우저마다 지금 상태(제어 가능 / 꺼짐 / 탭 없음)와 켤 메뉴 위치를 같이 보여 주고,
/// 창이 열려 있는 동안 계속 probe해서 사용자가 토글을 켜는 즉시 체크가 바뀐다. 높이는 내용에 맞춘다(설치된 브라우저 수만큼).
struct MediaSetupGuideView: View {
    let controller: MediaController

    private var browsers: [BrowserKind] { BrowserKind.browsers.filter(\.isInstalled) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("One-time setup for each browser.").foregroundStyle(.secondary)

            step(1, "Allow control in macOS") {
                Text("Click Allow when macOS asks. If you missed it:")
                Button("Open System Settings › Automation") {
                    if let url = URL(string: Constants.automationPrivacySettingsURL) { NSWorkspace.shared.open(url) }
                }
            }

            step(2, "Turn on this menu item in the browser") {
                ForEach(browsers, id: \.rawValue, content: browserRow)
            }

            Text("Open a YouTube tab — the check turns green as soon as it’s on.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(width: 500)
        .onAppear { controller.setPanelOpen(true) }
        .onDisappear { controller.setPanelOpen(false) }
    }

    private func step<Content: View>(_ n: Int, _ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(n)").font(.caption.bold()).frame(width: 20, height: 20).background(Color.accentColor, in: Circle()).foregroundStyle(.white)
                Text(title).font(.headline)
            }
            VStack(alignment: .leading, spacing: 8, content: content).padding(.leading, 28)
        }
    }

    private func browserRow(_ browser: BrowserKind) -> some View {
        let ready = controller.jsReady[browser]
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: ready == true ? "checkmark.circle.fill" : ready == false ? "xmark.circle.fill" : "circle.dashed")
                    .foregroundStyle(ready == true ? .green : ready == false ? .orange : .secondary)
                Text(browser.displayName).font(.body.bold())
                Text(status(browser, ready: ready)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if ready != true {
                    Button("Open \(browser.displayName)") { browser.activate() }.font(.caption)
                }
            }
            menuPath(browser)
            if browser.isSafari {
                Text("No Developer tab? In Advanced, turn on “Show features for web developers” first.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    /// 클릭 경로를 메뉴 조각으로 그린다: [보기] › [개발자 정보] › [☐ Apple Events의 자바스크립트 허용]. 마지막 조각이 켤 항목.
    private func menuPath(_ browser: BrowserKind) -> some View {
        let parts = browser.menuPath
        return HStack(spacing: 4) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, part in
                if i > 0 { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary) }
                let last = i == parts.count - 1
                HStack(spacing: 4) {
                    if last { Image(systemName: "checkmark.square").font(.caption) }
                    Text(part).font(.callout.weight(last ? .semibold : .regular))
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(last ? Color.accentColor.opacity(0.25) : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func status(_ browser: BrowserKind, ready: Bool?) -> String {
        switch ready {
        case true: String(localized: "Ready")
        case false: String(localized: "Off")
        default: browser.isRunning ? String(localized: "Open a YouTube tab to check") : String(localized: "Not running")
        }
    }
}
#endif
