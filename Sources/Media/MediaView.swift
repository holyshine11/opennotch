#if MEDIA_ENABLED
import AppKit
import SwiftUI

/// 상단 왼쪽 칸: YouTube/YouTube Music 재생 정보와 제어. 나타나는 동안만 폴링한다(접히면 뷰가 사라진다).
struct MediaView: View {
    let controller: MediaController
    @Environment(\.notchHost) private var host

    var body: some View {
        Group {
            switch controller.state {
            case .off: offView
            case .idle:
                Text("Open YouTube or YouTube Music in your browser").font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .nowPlaying(let np): nowPlayingView(np)
            case .readOnly(let title, let hint): readOnlyView(title: title, hint: hint)
            case .permissionDenied(let browser): permissionView(browser)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .onAppear { controller.setPanelOpen(true) }
        .onDisappear { controller.setPanelOpen(false) }
    }

    private var offView: some View {
        VStack(spacing: 6) {
            Text("YouTube & YouTube Music").font(.caption).foregroundStyle(.secondary)
            // 켜는 순간 안내 창을 같이 연다 — 권한 프롬프트와 브라우저 토글을 한 화면에서 보게.
            Button("Use YouTube controls") { controller.enableWithUserAction(); openGuide() }.buttonStyle(.bordered)
            Button("How to set up…") { openGuide() }.buttonStyle(.link).font(.caption2)
        }
    }

    private func nowPlayingView(_ np: NowPlaying) -> some View {
        HStack(spacing: 8) {
            artwork(np)
            VStack(alignment: .leading, spacing: 3) {
                Text(np.title).font(.caption.bold()).lineLimit(1)
                HStack(spacing: 4) {
                    Text(np.artist ?? np.siteName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    if let name = controller.sourceName {
                        Spacer(minLength: 2)
                        // 어느 브라우저를 제어 중인지 항상 보여 준다. 후보가 둘 이상이면 눌러서 전환.
                        Button { controller.cycleSource() } label: {
                            Label(name, systemImage: controller.sourceCount > 1 ? "arrow.left.arrow.right" : "globe").font(.caption2)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain).disabled(controller.sourceCount < 2).help("Switch browser")
                    }
                }
                HStack(spacing: 14) {
                    control("backward.fill") { controller.send(.prev) }
                    control(np.playing ? "pause.fill" : "play.fill") { controller.send(np.playing ? .pause : .play) }
                    control("forward.fill") { controller.send(.next) }
                    Spacer()
                    control("arrow.up.forward.app") { reveal() }
                        .help("Show tab in browser")
                }
                .padding(.top, 2)
                seekBar(np)
            }
        }
    }

    private func seekBar(_ np: NowPlaying) -> some View {
        SeekSlider(value: np.duration > 0 ? min(max(np.position / np.duration, 0), 1) : 0,
                   onDrag: { host?.resetIdle() },
                   onSeek: { controller.send(.seek($0)) })
            .disabled(np.duration <= 0)
    }

    private func artwork(_ np: NowPlaying) -> some View {
        Group {
            if let image = controller.artworkImage {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "play.rectangle.fill").font(.title2).foregroundStyle(.secondary)
            }
        }
        .frame(width: Constants.mediaArtworkSize, height: Constants.mediaArtworkSize)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func control(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.body) }
            .buttonStyle(.plain)
    }

    private func readOnlyView(title: String, hint: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.bold()).lineLimit(2)
            if let name = controller.sourceName {
                Text(name).font(.caption2).foregroundStyle(.secondary)
            }
            if hint != nil {
                Text("Controls need “Allow JavaScript from Apple Events”").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                if hint != nil { Button("How to set up…") { openGuide() } }
                Button("Show tab") { reveal() }
            }
            .buttonStyle(.link).font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openGuide() {
        NotificationCenter.default.post(name: .openNotchShowMediaSetup, object: nil)
        host?.collapse()
    }

    /// 브라우저 탭을 앞으로 가져오고 패널은 접는다(패널이 브라우저 위를 가리지 않게).
    private func reveal() {
        controller.revealCurrentTab()
        host?.collapse()
    }

    private func permissionView(_ browser: BrowserKind) -> some View {
        VStack(spacing: 6) {
            Text("Allow OpenNotch to control \(browser.displayName)").font(.caption).multilineTextAlignment(.center)
            Button("Open System Settings") {
                if let url = URL(string: Constants.automationPrivacySettingsURL) { NSWorkspace.shared.open(url) }
            }
            .buttonStyle(.bordered)
            Button("How to set up…") { openGuide() }.buttonStyle(.link).font(.caption2)
        }
    }
}
/// 진행 바. 비활성 패널에서 첫 클릭을 받고, NSSlider의 모달 추적 루프(마우스 업을 못 받으면 메인 스레드가 멈춤) 대신
/// mouseDown/Dragged/Up 이벤트만 처리한다. 드래그 중에는 폴링 값으로 덮어쓰지 않는다.
private struct SeekSlider: NSViewRepresentable {
    var value: Double
    var onDrag: () -> Void
    var onSeek: (Double) -> Void

    final class BarView: NSView {
        var onDrag: () -> Void = {}
        var onSeek: (Double) -> Void = { _ in }
        var fraction: Double = 0 { didSet { needsDisplay = true } }
        private(set) var dragging = false

        override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: Constants.mediaSeekHitHeight) }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        private func fraction(at event: NSEvent) -> Double {
            let x = convert(event.locationInWindow, from: nil).x
            return bounds.width > 0 ? min(max(x / bounds.width, 0), 1) : 0
        }
        override func mouseDown(with event: NSEvent) { dragging = true; fraction = fraction(at: event); onDrag() }
        override func mouseDragged(with event: NSEvent) { fraction = fraction(at: event); onDrag() }
        override func mouseUp(with event: NSEvent) { dragging = false; fraction = fraction(at: event); onSeek(fraction) }

        override func draw(_ dirtyRect: NSRect) {
            let h = Constants.mediaSeekBarHeight
            let track = NSRect(x: 0, y: (bounds.height - h) / 2, width: bounds.width, height: h)
            NSColor.white.withAlphaComponent(0.2).setFill()
            NSBezierPath(roundedRect: track, xRadius: h / 2, yRadius: h / 2).fill()
            var fill = track; fill.size.width = track.width * fraction
            NSColor.white.setFill()
            NSBezierPath(roundedRect: fill, xRadius: h / 2, yRadius: h / 2).fill()
        }
    }

    func makeNSView(context: Context) -> BarView { BarView() }

    func updateNSView(_ view: BarView, context: Context) {
        view.onDrag = onDrag
        view.onSeek = onSeek
        if !view.dragging { view.fraction = value }
    }
}
#endif
