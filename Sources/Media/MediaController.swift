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
        if case .nowPlaying(var np) = state, cmd == .play || cmd == .pause {
            np.playing = cmd == .play
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

    func poll() {
        guard isEnabled, !inFlight, Date() >= backoffUntil else { return }
        let browsers = enabledBrowsers.filter(\.isRunning).sorted { $0.rawValue < $1.rawValue }
        guard !browsers.isEmpty else { apply(nil); return }
        inFlight = true
        Task {
            defer { inFlight = false }
            var best: (BrowserKind, MediaScript.ProbeResult)?
            var denied: BrowserKind?
            for browser in browsers {
                switch await AppleScriptRunner.run(MediaScript.probe(browser: browser), timeout: Constants.mediaScriptTimeout) {
                case .success(let out):
                    guard let probe = MediaScript.parseProbe(out) else { continue }
                    if best == nil || probe.json.contains("\"playing\":true") { best = (browser, probe) }
                case .failure(let f):
                    switch f.code {
                    case AppleScriptFailure.permissionDenied: denied = browser
                    case AppleScriptFailure.notRunning, AppleScriptFailure.cantGet, AppleScriptFailure.invalidIndex: continue
                    default:
                        logger.error("probe failed: \(f.code) \(f.message, privacy: .public)")
                        backoffUntil = Date().addingTimeInterval(Constants.mediaErrorBackoff)
                    }
                }
                if best != nil, probeIsPlaying(best) { break }
            }
            if best == nil, let denied { state = .permissionDenied(denied); current = nil; return }
            apply(best)
        }
    }

    // MARK: 내부

    private func probeIsPlaying(_ best: (BrowserKind, MediaScript.ProbeResult)?) -> Bool {
        best?.1.json.contains("\"playing\":true") ?? false
    }

    private func apply(_ best: (BrowserKind, MediaScript.ProbeResult)?) {
        guard let best else { state = .idle; current = nil; return }
        let (browser, probe) = best
        current = (browser, probe.window, probe.tab)
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
