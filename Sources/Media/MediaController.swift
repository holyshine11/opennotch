#if MEDIA_ENABLED
import AppKit
import Foundation
import os

struct AppleScriptFailure: Error, Equatable, Sendable {
    let code: Int
    let message: String

    static let permissionDenied = -1743   // 자동화 권한 거부
    static let notRunning = -600
    static let cantGet = -1728            // 창/탭 없음
    static let invalidIndex = -1719
    static let timedOut = -1              // 우리가 부여한 코드
}

/// NSAppleScript를 전용 직렬 큐에서 실행한다. 타임아웃이 지나면 결과를 버린다.
/// ponytail: 멈춘 스크립트는 큐를 계속 점유한다(취소 API 없음). 문제가 되면 큐를 브라우저별로 나눈다.
enum AppleScriptRunner {
    private static let queue = DispatchQueue(label: "com.holyshine11.opennotch.applescript", qos: .userInitiated)

    static func run(_ source: String, timeout: TimeInterval) async -> Result<String, AppleScriptFailure> {
        await withTaskGroup(of: Result<String, AppleScriptFailure>.self) { group in
            group.addTask { await execute(source) }
            group.addTask {
                try? await Task.sleep(for: .seconds(timeout))
                return .failure(AppleScriptFailure(code: AppleScriptFailure.timedOut, message: "timeout"))
            }
            let first = await group.next() ?? .failure(AppleScriptFailure(code: 0, message: ""))
            group.cancelAll()
            return first
        }
    }

    private static func execute(_ source: String) async -> Result<String, AppleScriptFailure> {
        await withCheckedContinuation { cont in
            queue.async {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: source) else {
                    return cont.resume(returning: .failure(AppleScriptFailure(code: 0, message: "compile")))
                }
                let result = script.executeAndReturnError(&error)
                if let error {
                    cont.resume(returning: .failure(AppleScriptFailure(
                        code: error[NSAppleScript.errorNumber] as? Int ?? 0,
                        message: error[NSAppleScript.errorMessage] as? String ?? "")))
                } else {
                    cont.resume(returning: .success(result.stringValue ?? ""))
                }
            }
        }
    }
}

enum MediaState: Equatable {
    case off
    case idle
    case nowPlaying(NowPlaying)
    /// JS 실패 → 탭 제목만. `hint`는 JS 허용 토글 위치.
    case readOnly(title: String, hint: String?)
    case permissionDenied(BrowserKind)
}

/// 패널이 펼쳐진 동안 2초마다 켜진 브라우저의 YouTube 탭을 probe한다. 접히면 Apple Event 0회.
@MainActor @Observable
final class MediaController {
    var isEnabled = false {
        didSet {
            guard isEnabled else { disable(); return }
            if state == .off { state = .idle }   // 첫 probe가 권한 프롬프트에 막혀도 버튼이 남지 않게
            if panelOpen { startPolling() }
        }
    }
    var enabledBrowsers: Set<BrowserKind> = []
    private(set) var state: MediaState = .off
    /// 현재 표시 중인 브라우저 이름과, YouTube 탭을 가진 브라우저 수(2 이상이면 전환 버튼 표시).
    private(set) var sourceName: String?
    private(set) var sourceCount: Int = 0
    private var candidates: [(BrowserKind, MediaScript.ProbeResult)] = []
    /// 사용자가 전환 버튼으로 고른 브라우저. 그 브라우저에 탭이 있는 한 재생 여부와 무관하게 유지.
    private var pinned: BrowserKind?

    private var panelOpen = false
    private var timer: Timer?
    private var inFlight = false
    private var backoffUntil: Date = .distantPast
    private var current: (browser: BrowserKind, window: Int, tab: Int)?
    private let logger = Logger(subsystem: "com.holyshine11.opennotch", category: "media")

    func setPanelOpen(_ open: Bool) {
        panelOpen = open
        if open, isEnabled { startPolling() } else { stopPolling() }
    }

    /// 패널의 [Use YouTube controls]: 실행 중인 지원 브라우저를 켠다(없으면 설치된 것 전부). 설정에 기록하면 AppDelegate가 되돌려 준다.
    func enableWithUserAction(defaults: UserDefaults = .standard) {
        let running = BrowserKind.allCases.filter(\.isRunning)
        let chosen = running.isEmpty ? BrowserKind.allCases.filter(\.isInstalled) : running
        let merged = enabledBrowsers.union(chosen)
        defaults.set(merged.map(\.rawValue).sorted().joined(separator: ","), forKey: PrefKey.enabledBrowsers)
        defaults.set(true, forKey: PrefKey.mediaEnabled)
    }

    func send(_ cmd: MediaScript.Command) {
        guard let current else { return }
        if case .nowPlaying(var np) = state {
            switch cmd {
            case .play, .pause: np.playing = cmd == .play
            case .seek(let f): np.position = f * np.duration
            default: break
            }
            state = .nowPlaying(np)
        }
        Task {
            let script = MediaScript.command(browser: current.browser, window: current.window, tab: current.tab, cmd)
            if case .failure(let f) = await AppleScriptRunner.run(script, timeout: Constants.mediaScriptTimeout) {
                logger.error("command failed: \(f.code)")
            }
            try? await Task.sleep(for: .seconds(Constants.mediaCommandRefreshDelay))
            poll()
        }
    }

    /// 브라우저를 앞으로 가져오고 현재 탭을 활성화한다(JS 토글 없이도 동작).
    func revealCurrentTab() {
        guard let current else { return }
        Task { _ = await AppleScriptRunner.run(MediaScript.activate(browser: current.browser, window: current.window, tab: current.tab), timeout: Constants.mediaScriptTimeout) }
    }

    func poll() {
        guard isEnabled, !inFlight, Date() >= backoffUntil else { return }
        // 마지막으로 제어한 브라우저를 먼저 훑는다 — 아무것도 재생 중이 아닐 때 그 탭이 유지된다.
        let browsers = enabledBrowsers.filter(\.isRunning).sorted {
            ($0 == current?.browser ? 0 : 1, $0.rawValue) < ($1 == current?.browser ? 0 : 1, $1.rawValue)
        }
        guard !browsers.isEmpty else { apply(nil); return }
        inFlight = true
        Task {
            defer { inFlight = false }
            var found: [(BrowserKind, MediaScript.ProbeResult)] = []
            var denied: BrowserKind?
            for browser in browsers {
                let prefer = current.flatMap { $0.browser == browser ? (window: $0.window, tab: $0.tab) : nil }
                switch await AppleScriptRunner.run(MediaScript.probe(browser: browser, prefer: prefer), timeout: Constants.mediaScriptTimeout) {
                case .success(let out):
                    if let probe = MediaScript.parseProbe(out) { found.append((browser, probe)) }
                case .failure(let f):
                    switch f.code {
                    case AppleScriptFailure.permissionDenied: denied = browser
                    case AppleScriptFailure.notRunning, AppleScriptFailure.cantGet, AppleScriptFailure.invalidIndex: continue
                    default:
                        logger.error("probe failed: \(f.code) \(f.message, privacy: .public)")
                        backoffUntil = Date().addingTimeInterval(Constants.mediaErrorBackoff)
                    }
                }
            }
            candidates = found
            // 재생 중인 것 우선(현재 브라우저가 앞에 정렬돼 있어 sticky), 없으면 현재 브라우저, 없으면 첫 번째.
            let best = found.first { $0.0 == pinned } ?? found.first { probeIsPlaying($0) }
                ?? found.first { $0.0 == current?.browser } ?? found.first
            if best == nil, let denied { state = .permissionDenied(denied); current = nil; return }
            apply(best)
        }
    }

    // MARK: 내부

    private func probeIsPlaying(_ entry: (BrowserKind, MediaScript.ProbeResult)) -> Bool {
        entry.1.json.contains("\"playing\":true")
    }

    /// 여러 브라우저에 YouTube 탭이 있을 때 다음 브라우저로 표시를 바꾼다.
    func cycleSource() {
        guard candidates.count > 1 else { return }
        let i = candidates.firstIndex { $0.0 == current?.browser } ?? -1
        let next = candidates[(i + 1) % candidates.count]
        pinned = next.0
        apply(next)
    }

    private func apply(_ best: (BrowserKind, MediaScript.ProbeResult)?) {
        guard let best else { state = .idle; current = nil; sourceName = nil; sourceCount = 0; return }
        let (browser, probe) = best
        current = (browser, probe.window, probe.tab)
        sourceName = browser.displayName
        sourceCount = candidates.count
        let title = MediaScript.cleanTitle(probe.title)
        if probe.jsErrorCode != nil {
            state = .readOnly(title: title, hint: browser.jsToggleHint)
        } else if let data = probe.json.data(using: .utf8), let np = try? JSONDecoder().decode(NowPlaying.self, from: data) {
            state = .nowPlaying(np)
        } else {
            state = .readOnly(title: title, hint: nil)
        }
    }

    private func disable() {
        stopPolling()
        state = .off
        current = nil
    }

    private func startPolling() {
        stopPolling()
        poll()
        let t = Timer(timeInterval: Constants.mediaPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
}
#endif
