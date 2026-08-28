#if MEDIA_ENABLED
import AppKit
import SwiftUI

extension Notification.Name {
    /// 패널·설정에서 안내 창을 열 때. AppDelegate가 창을 띄운다.
    static let openNotchShowMediaSetup = Notification.Name("com.holyshine11.opennotch.showMediaSetup")
}

/// 처음 쓰는 사람을 위한 한 화면 안내. 브라우저마다 지금 상태(제어 가능 / 토글 꺼짐 / 탭 없음)와 켜는 순서를 같이 보여 주고,
/// 창이 열려 있는 동안 계속 probe해서 사용자가 토글을 켜는 즉시 체크가 바뀐다.
struct MediaSetupGuideView: View {
    let controller: MediaController

    private var browsers: [BrowserKind] { BrowserKind.allCases.filter(\.isInstalled) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Set up YouTube controls").font(.title2.bold())
                Text("Two one-time settings per browser. OpenNotch only reads the title and playback state of YouTube tabs and sends play/pause/next/previous.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

                step(1, "Allow OpenNotch to control the browser") {
                    Text("macOS asks “OpenNotch wants to control …” the first time. Click Allow. If you clicked Don’t Allow, turn it on in System Settings › Privacy & Security › Automation › OpenNotch.")
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open System Settings › Automation") {
                        if let url = URL(string: Constants.automationPrivacySettingsURL) { NSWorkspace.shared.open(url) }
                    }
                }

                step(2, "Turn on “Allow JavaScript from Apple Events” in the browser") {
                    Text("Without it OpenNotch can only show the tab title. The switch stays on — you do it once.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    ForEach(browsers, id: \.rawValue, content: browserRow)
                }

                Text("Check: open a YouTube or YouTube Music tab — the row above turns green as soon as the setting is on.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(22)
        }
        .frame(width: 540, height: 600)
        .onAppear { controller.setPanelOpen(true) }
        .onDisappear { controller.setPanelOpen(false) }
    }

    private func step<Content: View>(_ n: Int, _ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("\(n)").font(.caption.bold()).frame(width: 22, height: 22).background(Color.accentColor, in: Circle()).foregroundStyle(.white)
                Text(title).font(.headline)
            }
            VStack(alignment: .leading, spacing: 8, content: content).padding(.leading, 30)
        }
    }

    private func browserRow(_ browser: BrowserKind) -> some View {
        let ready = controller.jsReady[browser]
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: ready == true ? "checkmark.circle.fill" : ready == false ? "xmark.circle.fill" : "circle.dashed")
                .foregroundStyle(ready == true ? .green : ready == false ? .orange : .secondary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(browser.displayName).font(.body.bold())
                    Text(status(browser, ready: ready)).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Open \(browser.displayName)") { browser.activate() }.font(.caption)
                }
                ForEach(Array(browser.setupSteps.enumerated()), id: \.offset) { i, text in
                    Text("\(i + 1). \(text)").font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private func status(_ browser: BrowserKind, ready: Bool?) -> String {
        switch ready {
        case true: String(localized: "Ready — controls work")
        case false: String(localized: "Setting is off")
        default: browser.isRunning ? String(localized: "Open a YouTube tab to check") : String(localized: "Not running")
        }
    }
}
#endif
