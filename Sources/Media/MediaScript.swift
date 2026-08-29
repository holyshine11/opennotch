import Foundation

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

/// AppleScript·JS 문자열만 만들고 결과를 파싱한다. 실행은 하지 않는다(테스트 대상).
enum MediaScript {
    enum Command: Equatable, Sendable {
        case play, pause, next, prev
        /// 0...1 비율 위치로 이동.
        case seek(Double)

        var name: String {
            switch self {
            case .play: "play"; case .pause: "pause"; case .next: "next"; case .prev: "prev"; case .seek: "seek"
            }
        }
        var argument: Double { if case .seek(let f) = self { return min(max(f, 0), 1) }; return 0 }
    }

    /// probe 스크립트 출력 한 줄: `FOUND \t 창 \t 탭 \t URL \t 제목 \t JS오류코드 \t JSON` 또는 `NONE`.
    /// 크로미움 계열의 JS-비활성 오류 코드는 12(2026-08-28 Whale 4.39에서 채집). 어떤 코드든 JS 실패면 읽기 전용으로 처리한다.
    struct ProbeResult: Equatable, Sendable {
        var window: Int
        var tab: Int
        var url: String
        var title: String
        var jsErrorCode: Int?
        var json: String
        /// Apple Music만: persistent ID. 바뀔 때만 아트워크를 다시 읽는다.
        var trackID: String? = nil
    }

    /// AppleScript 문자열 리터럴 안에 넣기 위한 이스케이프.
    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// JS를 한 줄로 결합한다(AppleScript 리터럴 안전). JS 안에 `//` 주석을 쓰면 안 된다.
    static func oneLine(_ js: String) -> String {
        js.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
    }

    // MARK: JS 페이로드

    /// 재생 정보 JSON을 반환한다. 아트워크는 페이지 컨텍스트에서 비동기로 받아 `window.__onArt`에 캐시하고 다음 폴링에 실린다.
    static let probeJS = #"""
    (() => {
      const v = document.querySelector('video');
      const md = navigator.mediaSession && navigator.mediaSession.metadata;
      const list = (md && md.artwork && md.artwork.length) ? Array.from(md.artwork) : [];
      const pick = list.map(a => ({src: a.src, w: parseInt(a.sizes) || 0})).sort((a, b) => a.w - b.w).find(a => a.w >= __ART_PX__) || list[0] || null;
      const art = pick ? {src: pick.src.replace(/=w\d+-h\d+/, '=w__ART_PX__-h__ART_PX__')} : null;
      const cache = window.__onArt || null;
      if (art && (!cache || cache.src !== art.src) && !window.__onArtBusy) {
        window.__onArtBusy = true;
        fetch(art.src).then(r => r.blob()).then(b => new Promise((res, rej) => {
          if (b.size > __ART_MAX__) return rej();
          const fr = new FileReader(); fr.onload = () => res(fr.result); fr.onerror = rej; fr.readAsDataURL(b);
        })).then(d => { window.__onArt = {src: art.src, data: d}; })
          .catch(() => { window.__onArt = {src: art.src, data: null}; })
          .finally(() => { window.__onArtBusy = false; });
      }
      const ms = navigator.mediaSession && navigator.mediaSession.playbackState;
      const sp = location.host === '__SPOTIFY_HOST__';
      const q = s => document.querySelector(s);
      const clock = t => { const p = (t || '').trim().split(':').map(Number); return p.length && p.every(n => !isNaN(n)) ? p.reduce((a, n) => a * 60 + n, 0) : 0; };
      const range = sp ? q('[data-testid="playback-progressbar"] input[type=range]') : null;
      const playing = sp ? document.title.includes(' • ') : (ms === 'playing' || ms === 'paused') ? ms === 'playing' : !!(v && !v.paused && !v.ended);
      const position = sp ? clock((q('[data-testid="playback-position"]') || {}).textContent) : (v && isFinite(v.currentTime)) ? v.currentTime : 0;
      const duration = sp ? (range ? Number(range.max) / 1000 : clock((q('[data-testid="playback-duration"]') || {}).textContent)) : (v && isFinite(v.duration)) ? v.duration : 0;
      return JSON.stringify({
        title: (md && md.title) || document.title,
        artist: (md && md.artist) || null,
        artwork: (cache && art && cache.src === art.src) ? cache.data : null,
        playing: playing,
        position: position,
        duration: duration,
        site: sp ? 'spotify' : location.host.startsWith('music.') ? 'youtube_music' : 'youtube'
      });
    })()
    """#

    static let commandJS = #"""
    (() => {
      const v = document.querySelector('video');
      const q = s => document.querySelector(s);
      const cmd = '__CMD__';
      const arg = __ARG__;
      if (location.host === '__SPOTIFY_HOST__') {
        const playing = document.title.includes(' • ');
        const inp = q('[data-testid="playback-progressbar"] input[type=range]');
        if (cmd === 'seek' && inp) {
          Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set.call(inp, Math.round(Number(inp.max) * arg));
          inp.dispatchEvent(new Event('input', {bubbles: true}));
          inp.dispatchEvent(new Event('change', {bubbles: true}));
        }
        else if ((cmd === 'play' && !playing) || (cmd === 'pause' && playing)) q('[data-testid="control-button-playpause"]')?.click();
        else if (cmd === 'next') q('[data-testid="control-button-skip-forward"]')?.click();
        else if (cmd === 'prev') q('[data-testid="control-button-skip-back"]')?.click();
        return 'ok';
      }
      const playBtn = () => (q('#play-pause-button') || q('.ytp-play-button'))?.click();
      if (cmd === 'seek' && v && isFinite(v.duration)) v.currentTime = arg * v.duration;
      else if (cmd === 'play' && v) { const p = v.play(); if (p && p.catch) p.catch(() => playBtn()); }
      else if (cmd === 'pause' && v) v.pause();
      else if (cmd === 'next') (q('.ytp-next-button') || q('ytmusic-player-bar .next-button'))?.click();
      else if (cmd === 'prev') (q('.ytp-prev-button') || q('ytmusic-player-bar .previous-button'))?.click();
      return 'ok';
    })()
    """#

    static var probeJSOneLine: String {
        oneLine(probeJS)
            .replacingOccurrences(of: "__ART_PX__", with: "\(Constants.mediaArtworkTargetPixels)")
            .replacingOccurrences(of: "__ART_MAX__", with: "\(Constants.mediaArtworkMaxBytes)")
            .replacingOccurrences(of: "__SPOTIFY_HOST__", with: Constants.spotifyWebHost)
    }
    static var commandJSOneLine: String { oneLine(commandJS).replacingOccurrences(of: "__SPOTIFY_HOST__", with: Constants.spotifyWebHost) }

    // MARK: AppleScript

    /// 브라우저의 모든 탭을 훑어 YouTube·Spotify 웹 탭을 찾고 JS probe를 실행한다. 우선순위: 재생 중 > `prefer`(마지막으로 제어한 탭) > 첫 탭.
    /// JS 실패는 오류 코드로 실어 보낸다.
    static func probe(browser: BrowserKind, prefer: (window: Int, tab: Int)? = nil) -> String {
        if browser == .appleMusic { return musicProbe }
        let js = escape(probeJSOneLine)
        let run = browser.isSafari ? "do JavaScript \"\(js)\" in t" : "execute t javascript \"\(js)\""
        let titleProp = browser.isSafari ? "name" : "title"
        // `tab`은 tell 블록 안에서 브라우저의 tab 클래스로 해석되므로 구분자는 밖에서 묶는다.
        return """
        set sep to ASCII character 9
        set pw to \(prefer?.window ?? 0)
        set pt to \(prefer?.tab ?? 0)
        with timeout of \(Int(Constants.mediaScriptTimeout)) seconds
        tell application id "\(browser.rawValue)"
            set best to ""
            repeat with wi from 1 to count of windows
                try
                    repeat with ti from 1 to count of tabs of window wi
                        set t to tab ti of window wi
                        set u to URL of t
                        if u contains "\(Constants.youtubeMusicHost)" or u contains "\(Constants.youtubeWatchPath)" or u contains "\(Constants.spotifyWebHost)" then
                            set errNum to ""
                            set jsOut to ""
                            try
                                set jsOut to \(run)
                            on error errMsg number n
                                set errNum to n as text
                            end try
                            set found to "FOUND" & sep & wi & sep & ti & sep & u & sep & (\(titleProp) of t) & sep & errNum & sep & jsOut
                            if jsOut contains "\\"playing\\":true" then return found
                            if best is "" or (wi = pw and ti = pt) then set best to found
                        end if
                    end repeat
                end try
            end repeat
            if best is "" then return "NONE"
            return best
        end tell
        end timeout
        """
    }

    static func command(browser: BrowserKind, window: Int, tab: Int, _ cmd: Command) -> String {
        if browser == .appleMusic { return musicCommand(cmd) }
        let js = escape(commandJSOneLine.replacingOccurrences(of: "__CMD__", with: cmd.name)
            .replacingOccurrences(of: "__ARG__", with: String(cmd.argument)))
        let target = "tab \(tab) of window \(window)"
        let run = browser.isSafari ? "do JavaScript \"\(js)\" in \(target)" : "execute \(target) javascript \"\(js)\""
        return """
        with timeout of \(Int(Constants.mediaScriptTimeout)) seconds
        tell application id "\(browser.rawValue)"
            \(run)
        end tell
        end timeout
        """
    }

    /// 브라우저를 앞으로 가져오고 해당 탭을 활성화한다(JS 불필요).
    static func activate(browser: BrowserKind, window: Int, tab: Int) -> String {
        if browser == .appleMusic { return "tell application id \"\(browser.rawValue)\" to activate" }
        let select = browser.isSafari
            ? "set current tab of window \(window) to tab \(tab) of window \(window)"
            : "set active tab index of window \(window) to \(tab)"
        let unminimize = browser.isSafari ? "set miniaturized of window \(window) to false" : "set minimized of window \(window) to false"
        // 최소화·숨김 상태에서도 창이 나타나야 한다. 각 단계는 실패해도 다음으로 넘어간다.
        return """
        with timeout of \(Int(Constants.mediaScriptTimeout)) seconds
        tell application id "\(browser.rawValue)"
            try
                \(unminimize)
            end try
            try
                \(select)
            end try
            try
                set index of window \(window) to 1
            end try
            activate
        end tell
        end timeout
        """
    }

    // MARK: Apple Music (탭·JS 없음, Music 사전 직접)

    /// 한 줄 `MUSIC\t재생중\t위치\t길이\t제목\t아티스트\tpersistentID`. 멈춤(stopped)이면 `NONE`.
    /// 라디오(URL track)는 길이·위치가 `missing value`라 0으로 바꾼다(문자열에 그대로 붙이면 결과가 리스트로 바뀌어 파싱 실패).
    /// **`set t to current track` 뒤 `name of t` 금지** — 저장된 참조는 `URL track id … of source id …`로 풀리고, 샌드박스 scripting-targets는
    /// 이 경로(sdef 포함 관계에 없음)를 권한 위반(-10004)으로 막는다. 매번 `current track`을 거치면 통과한다(2026-08-29 샌드박스 도구로 실측).
    /// 실행 중일 때만 보낸다 — `tell application`은 꺼진 앱을 실행시킨다.
    static let musicProbe: String = """
        set sep to ASCII character 9
        with timeout of \(Int(Constants.mediaScriptTimeout)) seconds
        tell application id "\(BrowserKind.appleMusic.rawValue)"
            if player state is stopped then return "NONE"
            tell current track to set {n, a, d, pid} to {name, artist, duration, persistent ID}
            if d is missing value then set d to 0
            set p to player position
            if p is missing value then set p to 0
            return "MUSIC" & sep & (player state is playing) & sep & p & sep & d & sep & n & sep & a & sep & pid
        end tell
        end timeout
        """

    /// 현재 트랙의 원본 아트워크 바이트(JPEG/PNG). 없으면 빈 문자열.
    static let musicArtwork: String = """
        with timeout of \(Int(Constants.mediaScriptTimeout)) seconds
        tell application id "\(BrowserKind.appleMusic.rawValue)"
            if (count of artworks of current track) is 0 then return ""
            return raw data of artwork 1 of current track
        end tell
        end timeout
        """

    static func musicCommand(_ cmd: Command) -> String {
        let body = switch cmd {
        case .play: "play"
        case .pause: "pause"
        case .next: "next track"
        case .prev: "previous track"
        case .seek: "set d to duration of current track\n            if d is not missing value then set player position to d * \(cmd.argument)"
        }
        return """
        with timeout of \(Int(Constants.mediaScriptTimeout)) seconds
        tell application id "\(BrowserKind.appleMusic.rawValue)"
            \(body)
        end tell
        end timeout
        """
    }

    /// `MUSIC` 줄을 브라우저 probe와 같은 `ProbeResult`로 맞춘다(창·탭 0, JSON은 Swift에서 조립).
    static func parseMusic(_ parts: [String]) -> ProbeResult? {
        guard parts.count == 7 else { return nil }
        let np = NowPlaying(title: parts[4], artist: parts[5].isEmpty ? nil : parts[5], artwork: nil,
                            playing: parts[1] == "true", position: Double(parts[2]) ?? 0, duration: Double(parts[3]) ?? 0,
                            site: NowPlaying.appleMusicSite)
        guard let data = try? JSONEncoder().encode(np) else { return nil }
        return ProbeResult(window: 0, tab: 0, url: "", title: parts[4], jsErrorCode: nil,
                           json: String(decoding: data, as: UTF8.self), trackID: parts[6])
    }

    // MARK: 오류 분류

    /// 크로미움 계열이 "Apple Events의 JavaScript 허용"이 꺼져 있을 때 돌려주는 코드(2026-08-28 Whale 4.39·Chrome에서 채집).
    static let chromiumJSDisabledCode = 12

    /// 잠깐 지나가는 오류(탭 절전·로딩 중 타임아웃). 안내를 띄우지 않고 직전 상태를 유지한다.
    static func isTransientJSError(_ code: Int) -> Bool {
        code == AppleScriptFailure.eventTimedOut || code == AppleScriptFailure.timedOut
    }

    /// JS 토글이 꺼져 있어서 난 오류인지. Safari는 별도 코드가 없어 타임아웃이 아닌 모든 JS 오류를 토글 문제로 본다.
    static func isJSDisabled(_ code: Int, browser: BrowserKind) -> Bool {
        browser.isSafari ? !isTransientJSError(code) : code == chromiumJSDisabledCode
    }

    // MARK: 파싱

    static func parseProbe(_ output: String) -> ProbeResult? {
        let parts = output.split(separator: "\t", maxSplits: 6, omittingEmptySubsequences: false).map(String.init)
        if parts.first == "MUSIC" { return parseMusic(parts) }
        guard parts.count == 7, parts[0] == "FOUND", let w = Int(parts[1]), let t = Int(parts[2]) else { return nil }
        return ProbeResult(window: w, tab: t, url: parts[3], title: parts[4], jsErrorCode: Int(parts[5]), json: parts[6])
    }

    /// 탭 제목에서 사이트 접미사를 뗀다: "제목 - YouTube Music" / "제목 | YouTube Music" → "제목".
    static func cleanTitle(_ title: String) -> String {
        for suffix in [" - YouTube Music", " | YouTube Music", " - YouTube", " | YouTube"] where title.hasSuffix(suffix) {
            return String(title.dropLast(suffix.count))
        }
        return title
    }
}

/// probe JS가 반환하는 JSON.
struct NowPlaying: Codable, Equatable, Sendable {
    var title: String
    var artist: String?
    /// `data:image/…;base64,…` 또는 nil.
    var artwork: String?
    var playing: Bool
    var position: Double
    var duration: Double
    var site: String

    static let appleMusicSite = "apple_music"

    /// 아티스트 옆 배지. Apple Music은 소스 이름이 이미 "Apple Music"이라 비운다.
    var siteName: String? {
        switch site {
        case "youtube_music": "YouTube Music"
        case "spotify": "Spotify"
        case Self.appleMusicSite: nil
        default: "YouTube"
        }
    }

    var artworkData: Data? { artwork.flatMap(Self.decodeArtwork) }

    static func decodeArtwork(_ artwork: String) -> Data? {
        guard let comma = artwork.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(artwork[artwork.index(after: comma)...]))
    }
}
