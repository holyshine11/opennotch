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
            Button("Use YouTube controls") { controller.enableWithUserAction() }.buttonStyle(.bordered)
        }
    }

    private func nowPlayingView(_ np: NowPlaying) -> some View {
        HStack(spacing: 8) {
            artwork(np)
            VStack(alignment: .leading, spacing: 3) {
                Text(np.title).font(.caption.bold()).lineLimit(1)
                Text(np.artist ?? np.siteName).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 14) {
                    control("backward.fill") { controller.send(.prev) }
                    control(np.playing ? "pause.fill" : "play.fill") { controller.send(np.playing ? .pause : .play) }
                    control("forward.fill") { controller.send(.next) }
                }
                .padding(.top, 2)
                ProgressView(value: min(np.position, max(np.duration, 1)), total: max(np.duration, 1))
                    .tint(.white)
            }
        }
    }

    private func artwork(_ np: NowPlaying) -> some View {
        Group {
            if let data = np.artworkData, let image = NSImage(data: data) {
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
            if let hint {
                Text("Controls need “Allow JavaScript from Apple Events”").font(.caption2).foregroundStyle(.secondary)
                Button("Where is it?") { host?.showToast(hint, action: nil) }.buttonStyle(.link).font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func permissionView(_ browser: BrowserKind) -> some View {
        VStack(spacing: 6) {
            Text("Allow OpenNotch to control \(browser.displayName)").font(.caption).multilineTextAlignment(.center)
            Button("Open System Settings") {
                if let url = URL(string: Constants.automationPrivacySettingsURL) { NSWorkspace.shared.open(url) }
            }
            .buttonStyle(.bordered)
        }
    }
}
#endif
