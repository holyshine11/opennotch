#if MEDIA_ENABLED
import AppKit
import Foundation
import os

/// NSAppleScript를 한 번에 하나씩만 실행한다(AppleScript 컴포넌트는 스레드 간 동시 사용이 안 된다).
/// 명령은 probe보다 우선순위가 높아 줄 앞으로 끼어든다. 타임아웃이 지나면 결과를 기다리지 않고 실패를 돌려주며,
/// 아직 시작하지 않은 작업은 취소한다. 스크립트 자체에도 `with timeout`이 걸려 있어 큐가 오래 막히지 않는다.
enum AppleScriptRunner {
    private static let queue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.holyshine11.opennotch.applescript"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()

    /// continuation을 정확히 한 번만 재개하기 위한 게이트. 타임아웃 쪽이 이기면 작업을 취소한다.
    private final class Ticket: @unchecked Sendable {
        private let lock = NSLock()
        private var fired = false
        let operation = BlockOperation()
        func claim() -> Bool { lock.lock(); defer { lock.unlock() }; if fired { return false }; fired = true; return true }
    }

    /// 결과의 문자열·바이트를 모두 담는다 — NSAppleEventDescriptor는 Sendable이 아니라 큐 안에서 뽑아 둔다.
    private struct Output: Sendable {
        let string: String
        let data: Data
    }

    static func run(_ source: String, timeout: TimeInterval, urgent: Bool = false) async -> Result<String, AppleScriptFailure> {
        await runRaw(source, timeout: timeout, urgent: urgent).map(\.string)
    }

    /// 이미지 등 바이너리 결과(Apple Music 아트워크).
    static func runData(_ source: String, timeout: TimeInterval) async -> Result<Data, AppleScriptFailure> {
        await runRaw(source, timeout: timeout, urgent: false).map(\.data)
    }

    private static func runRaw(_ source: String, timeout: TimeInterval, urgent: Bool) async -> Result<Output, AppleScriptFailure> {
        await withCheckedContinuation { cont in
            let ticket = Ticket()
            ticket.operation.queuePriority = urgent ? .veryHigh : .normal
            ticket.operation.addExecutionBlock {
                let result = execute(source)
                if ticket.claim() { cont.resume(returning: result) }
            }
            queue.addOperation(ticket.operation)
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if ticket.claim() {
                    ticket.operation.cancel()
                    cont.resume(returning: .failure(AppleScriptFailure(code: AppleScriptFailure.timedOut, message: "timeout")))
                }
            }
        }
    }

    private static func execute(_ source: String) -> Result<Output, AppleScriptFailure> {
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
        return .success(Output(string: result.stringValue ?? "", data: result.data))
    }
}

enum MediaState: Equatable {
    case off
    case idle
    /// `artwork` 문자열은 비워서 담는다 — 디코딩한 이미지는 `MediaController.artworkImage`.
    case nowPlaying(NowPlaying)
    /// JS 실패 → 탭 제목만. `hint`가 있으면 JS 허용 토글이 꺼진 것(안내 버튼 표시).
    case readOnly(title: String, hint: String?)
    case permissionDenied(BrowserKind)
}

/// 패널(또는 설정 안내 창)이 열려 있는 동안 2초마다 켜진 브라우저의 YouTube 탭을 probe한다. 접히면 Apple Event 0회.
@MainActor @Observable
final class MediaController {
    var isEnabled = false {
        didSet {
            guard isEnabled else { disable(); return }
            if state == .off { state = .idle }   // 첫 probe가 권한 프롬프트에 막혀도 버튼이 남지 않게
            if openCount > 0 { startPolling() }
        }
    }
    /// 설정에서 끈 브라우저. 나머지 지원 브라우저는 실행 중이면 모두 훑는다.
    var disabledBrowsers: Set<BrowserKind> = []
    private(set) var state: MediaState = .off
    /// 현재 표시 중인 브라우저 이름과, YouTube 탭을 가진 브라우저 수(2 이상이면 전환 버튼 표시).
    private(set) var sourceName: String?
    private(set) var sourceCount: Int = 0
    /// 브라우저별 JS 토글 상태(마지막 probe 기준): true = 제어 가능, false = 토글 꺼짐, 없음 = YouTube 탭을 아직 못 봄.
    private(set) var jsReady: [BrowserKind: Bool] = [:]
    /// 자동화 권한이 거부된 브라우저. 안내 창이 브라우저마다 다른 안내를 고르는 데 쓴다.
    private(set) var deniedBrowsers: Set<BrowserKind> = []
    /// 디코딩한 아트워크. 문자열이 바뀔 때만 다시 만든다(0.5초 틱마다 base64 디코딩을 반복하지 않게).
    private(set) var artworkImage: NSImage?
    private var artworkKey: String?
    private var artworkRetryScheduled = false

    private struct Candidate {
        let browser: BrowserKind
        let probe: MediaScript.ProbeResult
        /// probe가 끝난 시각. 적용 시점까지 흐른 시간만큼 위치를 보정한다.
        let at: Date
    }
    private var candidates: [Candidate] = []
    /// 사용자가 전환 버튼으로 고른 브라우저. 그 브라우저에 탭이 있는 한 재생 여부와 무관하게 유지.
    private var pinned: BrowserKind?

    /// 패널과 안내 창이 각각 1씩 더한다. 0이 되면 폴링을 멈춘다.
    private var openCount = 0
    private var timer: Timer?
    private var inFlight = false
    private var pollRequested = false
    /// 명령을 보낼 때마다 증가. 명령 전에 시작된 probe 결과는 낡은 것이므로 버린다(버튼이 되돌아갔다 다시 바뀌는 깜빡임 방지).
    private var commandSerial = 0
    private var backoffUntil: Date = .distantPast
    /// 응답 없는 브라우저는 잠시 건너뛴다 — 한 브라우저의 타임아웃이 다른 브라우저의 갱신을 늦추지 않게.
    private var browserBackoff: [BrowserKind: Date] = [:]
    private var tickTimer: Timer?
    private var lastTick = Date()
    private var current: (browser: BrowserKind, window: Int, tab: Int)?
    private let logger = Logger(subsystem: "com.holyshine11.opennotch", category: "media")

    func setPanelOpen(_ open: Bool) {
        openCount = max(0, openCount + (open ? 1 : -1))
        if openCount > 0, isEnabled {
            if timer == nil { startPolling() }
        } else {
            stopPolling()
        }
    }

    /// 패널의 [Use music controls]. 설정에 기록하면 AppDelegate가 `isEnabled`로 되돌려 준다.
    /// 자동화 권한 프롬프트는 브라우저별로 첫 probe 때 1회 뜬다.
    func enableWithUserAction(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: PrefKey.mediaEnabled)
    }

    func send(_ cmd: MediaScript.Command) {
        guard let current else { return }
        commandSerial += 1
        if case .nowPlaying(var np) = state {
            switch cmd {
            case .play, .pause: np.playing = cmd == .play
            case .seek(let f): np.position = f * np.duration
            default: break
            }
            state = .nowPlaying(np)
            lastTick = Date()
        }
        Task {
            let script = MediaScript.command(browser: current.browser, window: current.window, tab: current.tab, cmd)
            if case .failure(let f) = await AppleScriptRunner.run(script, timeout: Constants.mediaScriptTimeout, urgent: true) {
                logger.error("command \(cmd.name, privacy: .public) failed: \(f.code)")
            }
            try? await Task.sleep(for: .seconds(Constants.mediaCommandRefreshDelay))
            poll()
        }
    }

    /// 브라우저를 앞으로 가져오고 현재 탭을 활성화한다(JS 토글 없이도 동작).
    func revealCurrentTab() {
        guard let current else { return }
        Task { _ = await AppleScriptRunner.run(MediaScript.activate(browser: current.browser, window: current.window, tab: current.tab), timeout: Constants.mediaScriptTimeout, urgent: true) }
    }

    func poll() {
        guard isEnabled, Date() >= backoffUntil else { return }
        if inFlight { pollRequested = true; return }   // 명령 직후 요청이면 진행 중인 probe가 끝난 뒤 한 번 더 돈다
        // 마지막으로 제어한 브라우저를 먼저 훑는다 — 아무것도 재생 중이 아닐 때 그 탭이 유지된다.
        let now = Date()
        let browsers = BrowserKind.allCases.filter { !disabledBrowsers.contains($0) && $0.isRunning && (browserBackoff[$0] ?? .distantPast) <= now }.sorted {
            ($0 == current?.browser ? 0 : 1, $0.rawValue) < ($1 == current?.browser ? 0 : 1, $1.rawValue)
        }
        guard !browsers.isEmpty else { apply(nil); return }
        inFlight = true
        let serial = commandSerial
        Task {
            defer {
                inFlight = false
                if pollRequested { pollRequested = false; poll() }
            }
            var found: [Candidate] = []
            var denied: BrowserKind?
            for browser in browsers {
                let started = Date()
                switch await AppleScriptRunner.run(MediaScript.probe(browser: browser, prefer: current.flatMap { $0.browser == browser ? (window: $0.window, tab: $0.tab) : nil }), timeout: Constants.mediaScriptTimeout) {
                case .success(let out):
                    deniedBrowsers.remove(browser)
                    // 탭이 없어졌으면 이전 JS 판정도 지운다 — 안내 창이 옛 결과로 "메뉴를 켜세요"를 보여 주지 않게(2026-08-29 Safari 실기).
                    if MediaScript.parseProbe(out) == nil { jsReady[browser] = nil }
                    if let probe = MediaScript.parseProbe(out) {
                        found.append(Candidate(browser: browser, probe: probe, at: Date()))
                        if let code = probe.jsErrorCode {
                            if !MediaScript.isTransientJSError(code) { setJSReady(browser, !MediaScript.isJSDisabled(code, browser: browser)) }
                        } else {
                            setJSReady(browser, true)
                        }
                    }
                case .failure(let f):
                    switch f.code {
                    case AppleScriptFailure.permissionDenied: denied = browser; deniedBrowsers.insert(browser)
                    case AppleScriptFailure.notRunning, AppleScriptFailure.cantGet, AppleScriptFailure.invalidIndex: continue
                    case AppleScriptFailure.timedOut, AppleScriptFailure.eventTimedOut:
                        // 권한 프롬프트가 떠 있거나 브라우저가 바쁜 경우. 이 브라우저만 잠시 건너뛴다.
                        logger.notice("probe timed out for \(browser.rawValue, privacy: .public)")
                        browserBackoff[browser] = Date().addingTimeInterval(Constants.mediaBrowserBackoff)
                    default:
                        // 한 소스의 오류가 다른 소스까지 멈추지 않게 그 소스만 쉰다(2026-08-29: Music 권한 위반이 전체를 30초 막아 화면이 느려졌음).
                        logger.error("probe failed for \(browser.rawValue, privacy: .public): \(f.code) \(f.message, privacy: .public)")
                        browserBackoff[browser] = Date().addingTimeInterval(Constants.mediaErrorBackoff)
                    }
                }
                let elapsed = Date().timeIntervalSince(started)
                if elapsed > Constants.mediaPollInterval / 2 {
                    logger.notice("slow probe \(browser.rawValue, privacy: .public): \(Int(elapsed * 1000)) ms")
                }
            }
            // 이 probe가 도는 동안 명령이 나갔으면 결과가 낡았다 — 명령 뒤에 예약된 poll이 새로 가져온다.
            guard serial == commandSerial else { return }
            // 타임아웃으로 건너뛴 브라우저의 직전 결과는 유지한다(화면이 깜빡이지 않게).
            let skipped = candidates.filter { c in !browsers.contains(c.browser) && (browserBackoff[c.browser] ?? .distantPast) > Date() }
            candidates = found + skipped
            // 제어 가능 = JSON이 있거나 잠깐 지나가는 오류. 진짜 토글 꺼짐만 뒤로 민다.
            let usable: (Candidate) -> Bool = { $0.probe.jsErrorCode.map(MediaScript.isTransientJSError) ?? true }
            let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier.flatMap(BrowserKind.init(rawValue:))
            // 우선순위: 고정 > 재생 중 > 제어 가능(현재 브라우저 > 맨 앞 브라우저 > 아무거나) > 현재 브라우저 > 첫 번째.
            let best = candidates.first { $0.browser == pinned }
                ?? candidates.first { probeIsPlaying($0) }
                ?? candidates.first { usable($0) && $0.browser == current?.browser }
                ?? candidates.first { usable($0) && $0.browser == frontmost }
                ?? candidates.first { usable($0) }
                ?? candidates.first { $0.browser == current?.browser }
                ?? candidates.first
            if best == nil, let denied { state = .permissionDenied(denied); current = nil; return }
            apply(best)
        }
    }

    /// 백오프를 무시하고 이 브라우저를 바로 다시 묻는다 — 도우미가 메뉴를 펼쳐 둔 동안 크로미움은 Apple Event에 답하지 않아
    /// probe가 타임아웃되고 15초 쉬는데, 사용자가 항목을 누른 뒤 몇 초 안에 초록 체크가 되어야 하므로 안내 창이 주기적으로 부른다.
    func retryNow(_ browser: BrowserKind) {
        browserBackoff[browser] = nil
        backoffUntil = .distantPast
        poll()
    }

    /// 안내 창이 브라우저마다 "지금 할 일 하나"를 고르는 기준.
    func setupStatus(_ browser: BrowserKind) -> BrowserSetupStatus {
        .derive(jsReady: jsReady[browser], denied: deniedBrowsers.contains(browser), running: browser.isRunning)
    }

    // MARK: 내부

    /// 제어에 한 번이라도 성공하면 설정을 마쳤다고 기록한다 — 패널의 첫 실행 안내 카드가 이 값을 보고 사라진다.
    private func setJSReady(_ browser: BrowserKind, _ ready: Bool) {
        jsReady[browser] = ready
        let defaults = UserDefaults.standard
        if ready, !defaults.bool(forKey: PrefKey.mediaSetupDone) { defaults.set(true, forKey: PrefKey.mediaSetupDone) }
    }

    private func probeIsPlaying(_ c: Candidate) -> Bool {
        c.probe.json.contains("\"playing\":true")
    }

    /// 여러 브라우저에 YouTube 탭이 있을 때 다음 브라우저로 표시를 바꾼다.
    func cycleSource() {
        guard candidates.count > 1 else { return }
        // 후보 배열은 폴링마다 현재 소스가 앞으로 오도록 재정렬되므로, 전환 순서는 `BrowserKind` 선언 순서로 고정한다(3개일 때 되돌아가지 않게).
        let order = BrowserKind.allCases
        let ordered = candidates.sorted { order.firstIndex(of: $0.browser)! < order.firstIndex(of: $1.browser)! }
        let i = ordered.firstIndex { $0.browser == current?.browser } ?? -1
        let next = ordered[(i + 1) % ordered.count]
        pinned = next.browser
        apply(next)
    }

    private func apply(_ best: Candidate?) {
        guard let best else { state = .idle; current = nil; sourceName = nil; sourceCount = 0; setArtwork(nil); return }
        let probe = best.probe
        let sameTab = current.map { $0.browser == best.browser && $0.window == probe.window && $0.tab == probe.tab } ?? false
        if current?.browser != best.browser { logger.notice("source → \(best.browser.rawValue, privacy: .public)") }
        current = (best.browser, probe.window, probe.tab)
        sourceName = best.browser.displayName
        sourceCount = candidates.count
        let title = MediaScript.cleanTitle(probe.title)
        if let code = probe.jsErrorCode {
            if MediaScript.isTransientJSError(code) {
                // 탭 절전·로딩 중 타임아웃: 같은 탭이면 직전 재생 정보를 그대로 둔다(안내를 띄우지 않는다).
                if sameTab, case .nowPlaying = state { return }
                state = .readOnly(title: title, hint: nil)
            } else {
                state = .readOnly(title: title, hint: MediaScript.isJSDisabled(code, browser: best.browser) ? best.browser.jsToggleHint : nil)
            }
            setArtwork(nil)
        } else if let data = probe.json.data(using: .utf8), var np = try? JSONDecoder().decode(NowPlaying.self, from: data) {
            if let id = probe.trackID { fetchMusicArtwork(id) } else { setArtwork(np.artwork) }
            // 브라우저 아트워크는 페이지가 비동기로 받아 다음 probe에 실린다 — 2초를 기다리지 말고 곧 한 번 더 묻는다.
            if np.artPending == true, !artworkRetryScheduled {
                artworkRetryScheduled = true
                Task { try? await Task.sleep(for: .seconds(Constants.mediaArtworkRetryDelay)); artworkRetryScheduled = false; poll() }
            }
            np.artwork = nil
            // probe 뒤 다른 브라우저를 훑는 동안 흐른 시간만큼 앞으로 — 폴링마다 진행 바가 뒤로 튀지 않게.
            if np.playing, np.duration > 0 { np.position = min(np.position + Date().timeIntervalSince(best.at), np.duration) }
            state = .nowPlaying(np)
            lastTick = Date()
        } else {
            state = .readOnly(title: title, hint: nil)
            setArtwork(nil)
        }
    }

    private func setArtwork(_ artwork: String?) {
        guard artwork != artworkKey else { return }
        artworkKey = artwork
        artworkImage = artwork.flatMap(NowPlaying.decodeArtwork).flatMap(NSImage.init(data:))
    }

    /// Apple Music: 트랙(persistent ID)이 바뀔 때만 아트워크 바이트를 1회 읽는다. 결과가 올 때 다른 트랙이면 버린다.
    private func fetchMusicArtwork(_ id: String) {
        guard id != artworkKey else { return }
        artworkKey = id
        artworkImage = nil
        Task {
            let result = await AppleScriptRunner.runData(MediaScript.musicArtwork, timeout: Constants.mediaScriptTimeout)
            guard artworkKey == id, case .success(let data) = result, !data.isEmpty else { return }
            artworkImage = NSImage(data: data)
        }
    }

    private func disable() {
        stopPolling()
        state = .off
        current = nil
        candidates = []
        jsReady = [:]
        deniedBrowsers = []
        setArtwork(nil)
    }

    private func startPolling() {
        stopPolling()
        lastTick = Date()
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
        let now = Date()
        defer { lastTick = now }
        guard case .nowPlaying(var np) = state, np.playing, np.duration > 0 else { return }
        // 타이머 간격이 아니라 실제 흐른 시간을 더한다(타이머 지연이 쌓여도 어긋나지 않게).
        np.position = min(np.position + now.timeIntervalSince(lastTick), np.duration)
        state = .nowPlaying(np)
    }

    private func stopPolling() {
        timer?.invalidate(); timer = nil
        tickTimer?.invalidate(); tickTimer = nil
    }
}
#endif
