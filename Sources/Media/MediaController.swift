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
    static let eventTimedOut = -1712      // AppleScript `with timeout` 초과
    static let timedOut = -1              // 우리가 부여한 코드
}

/// NSAppleScript를 전용 직렬 큐에서 실행한다. 타임아웃이 지나면 결과를 기다리지 않고 실패를 돌려준다
/// (TaskGroup은 자식이 끝날 때까지 반환하지 않으므로 쓰지 않는다). 스크립트 자체에도 `with timeout`이 걸려 있어 큐가 오래 막히지 않는다.
enum AppleScriptRunner {
    private static let queue = DispatchQueue(label: "com.holyshine11.opennotch.applescript", qos: .userInitiated)

    /// continuation을 정확히 한 번만 재개하기 위한 게이트.
    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var fired = false
        func claim() -> Bool { lock.lock(); defer { lock.unlock() }; if fired { return false }; fired = true; return true }
    }

    static func run(_ source: String, timeout: TimeInterval) async -> Result<String, AppleScriptFailure> {
        await withCheckedContinuation { cont in
            let once = Once()
            queue.async {
                let result = execute(source)
                if once.claim() { cont.resume(returning: result) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if once.claim() { cont.resume(returning: .failure(AppleScriptFailure(code: AppleScriptFailure.timedOut, message: "timeout"))) }
            }
        }
    }

    private static func execute(_ source: String) -> Result<String, AppleScriptFailure> {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure(AppleScriptFailure(code: 0, message: "compile"))
        }
        let result = script.executeAndReturnError(&error)
        if let error {
            return .failure(AppleScriptFailure(
                code: error[NSAppleScript.errorNumber] as? Int ?? 0,
                message: error[NSAppleScript.errorMessage] as? String ?? ""))
        }
        return .success(result.stringValue ?? "")
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
    /// 설정에서 끈 브라우저. 나머지 지원 브라우저는 실행 중이면 모두 훑는다.
    var disabledBrowsers: Set<BrowserKind> = []
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
    /// 응답 없는 브라우저는 잠시 건너뛴다 — 한 브라우저의 타임아웃이 다른 브라우저의 갱신을 늦추지 않게.
    private var browserBackoff: [BrowserKind: Date] = [:]
    private var lastPollDate = Date()
    private var tickTimer: Timer?
    private var current: (browser: BrowserKind, window: Int, tab: Int)?
    private let logger = Logger(subsystem: "com.holyshine11.opennotch", category: "media")

    func setPanelOpen(_ open: Bool) {
        panelOpen = open
        if open, isEnabled { startPolling() } else { stopPolling() }
    }

    /// 패널의 [Use YouTube controls]. 설정에 기록하면 AppDelegate가 `isEnabled`로 되돌려 준다.
    /// 자동화 권한 프롬프트는 브라우저별로 첫 probe 때 1회 뜬다.
    func enableWithUserAction(defaults: UserDefaults = .standard) {
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
        let now = Date()
        let browsers = BrowserKind.allCases.filter { !disabledBrowsers.contains($0) && $0.isRunning && (browserBackoff[$0] ?? .distantPast) <= now }.sorted {
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
                    case AppleScriptFailure.timedOut, AppleScriptFailure.eventTimedOut:
                        // 권한 프롬프트가 떠 있거나 브라우저가 바쁜 경우. 이 브라우저만 잠시 건너뛴다.
                        logger.info("probe timed out for \(browser.rawValue, privacy: .public)")
                        browserBackoff[browser] = Date().addingTimeInterval(Constants.mediaBrowserBackoff)
                    default:
                        logger.error("probe failed: \(f.code) \(f.message, privacy: .public)")
                        backoffUntil = Date().addingTimeInterval(Constants.mediaErrorBackoff)
                    }
                }
            }
            // 타임아웃으로 건너뛴 브라우저의 직전 결과는 유지한다(화면이 깜빡이지 않게).
            let skipped = candidates.filter { c in !browsers.contains(c.0) && (browserBackoff[c.0] ?? .distantPast) > Date() }
            candidates = found + skipped
            // 우선순위: 고정 > 재생 중 > 제어 가능(JSON 있음, 현재 브라우저 먼저) > 현재 브라우저 > 첫 번째.
            let best = candidates.first { $0.0 == pinned }
                ?? candidates.first { probeIsPlaying($0) }
                ?? candidates.first { $0.1.jsErrorCode == nil && $0.0 == current?.browser }
                ?? candidates.first { $0.1.jsErrorCode == nil }
                ?? candidates.first { $0.0 == current?.browser }
                ?? candidates.first
            lastPollDate = Date()
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
        // 폴링 사이에는 진행 위치를 로컬로 흘려 보낸다(Apple Event 없음).
        let tick = Timer(timeInterval: Constants.mediaTickInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(tick, forMode: .common)
        tickTimer = tick
    }

    private func tick() {
        guard case .nowPlaying(var np) = state, np.playing, np.duration > 0 else { return }
        np.position = min(np.position + Constants.mediaTickInterval, np.duration)
        state = .nowPlaying(np)
    }

    private func stopPolling() {
        timer?.invalidate(); timer = nil
        tickTimer?.invalidate(); tickTimer = nil
    }
}
#endif
