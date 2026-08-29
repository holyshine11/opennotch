import Foundation
import Testing
@testable import OpenNotch

@Suite struct MediaScriptTests {
    @Test func escapeQuotesAndBackslashes() {
        #expect(MediaScript.escape(#"a"b\c"#) == #"a\"b\\c"#)
    }

    @Test func probeScriptTargetsBrowserByBundleIDAndUsesItsJSCommand() {
        let whale = MediaScript.probe(browser: .whale)
        #expect(whale.contains(#"tell application id "com.naver.Whale""#))
        #expect(whale.contains("execute t javascript \""))
        #expect(whale.contains("title of t"))
        let safari = MediaScript.probe(browser: .safari)
        #expect(safari.contains("do JavaScript \""))
        #expect(safari.contains("name of t"))
    }

    @Test func jsPayloadIsSingleLineWithNoPlaceholdersLeft() {
        let js = MediaScript.probeJSOneLine
        #expect(!js.contains("\n"))
        #expect(!js.contains("__ART_"))
        #expect(js.contains("\(Constants.mediaArtworkMaxBytes)"))
        let cmd = MediaScript.command(browser: .chrome, window: 2, tab: 3, .next)
        #expect(cmd.contains("execute tab 3 of window 2 javascript"))
        #expect(cmd.contains("const cmd = 'next'"))
        #expect(MediaScript.probeJSOneLine.contains("navigator.mediaSession.playbackState"))
        #expect(!cmd.contains("__CMD__"))
        let seek = MediaScript.command(browser: .whale, window: 1, tab: 1, .seek(0.25))
        #expect(seek.contains("const cmd = 'seek'") && seek.contains("const arg = 0.25"))
        #expect(MediaScript.Command.seek(1.7).argument == 1)
    }

    @Test func probePrefersGivenTabAndActivateSelectsTab() {
        let script = MediaScript.probe(browser: .chrome, prefer: (window: 2, tab: 5))
        #expect(script.contains("set pw to 2") && script.contains("set pt to 5"))
        #expect(script.contains("(wi = pw and ti = pt)"))
        #expect(MediaScript.probe(browser: .chrome).contains("set pw to 0"))
        #expect(script.hasPrefix("set sep") && script.contains("with timeout of \(Int(Constants.mediaScriptTimeout)) seconds") && script.hasSuffix("end timeout"))
        #expect(MediaScript.command(browser: .chrome, window: 1, tab: 1, .play).contains("with timeout of"))
        let activate = MediaScript.activate(browser: .whale, window: 1, tab: 3)
        #expect(activate.contains("set active tab index of window 1 to 3") && activate.contains("activate"))
        #expect(MediaScript.activate(browser: .safari, window: 1, tab: 3).contains("set current tab of window 1 to tab 3"))
    }

    @Test func parseProbeLine() {
        let line = "FOUND\t1\t4\thttps://music.youtube.com/watch?v=x\tSong - YouTube Music\t\t{\"playing\":true}"
        let r = MediaScript.parseProbe(line)
        #expect(r == .init(window: 1, tab: 4, url: "https://music.youtube.com/watch?v=x", title: "Song - YouTube Music", jsErrorCode: nil, json: "{\"playing\":true}"))
        let disabled = MediaScript.parseProbe("FOUND\t1\t1\tu\tt\t12\t")
        #expect(disabled?.jsErrorCode == 12)
        #expect(MediaScript.parseProbe("NONE") == nil)
        #expect(MediaScript.parseProbe("FOUND\t1") == nil)
    }

    @Test func appleMusicScriptsAndParsing() throws {
        let probe = MediaScript.probe(browser: .appleMusic)
        #expect(probe.contains(#"tell application id "com.apple.Music""#) && probe.contains("tell current track to set {n, a, d, pid}"))
        // 저장된 트랙 참조(`of t`)로 다시 접근하면 샌드박스가 -10004로 막는다 — 항상 `current track`을 거친다.
        #expect(!probe.contains(" of t") && !MediaScript.musicArtwork.contains(" of t"))
        #expect(!probe.contains("javascript") && probe.contains("with timeout of"))
        #expect(MediaScript.command(browser: .appleMusic, window: 0, tab: 0, .next).contains("next track"))
        #expect(MediaScript.command(browser: .appleMusic, window: 0, tab: 0, .seek(0.5)).contains("if d is not missing value then set player position to d * 0.5"))
        #expect(MediaScript.activate(browser: .appleMusic, window: 0, tab: 0) == #"tell application id "com.apple.Music" to activate"#)
        #expect(MediaScript.musicArtwork.contains("raw data of artwork 1 of current track"))

        // AppleScript는 1만 이상 실수를 "1.0E+4"로 돌려준다.
        let r = try #require(MediaScript.parseProbe("MUSIC\ttrue\t12.5\t1.0E+4\tSong\tArtist\tABC123"))
        #expect(r.trackID == "ABC123" && r.title == "Song" && r.window == 0 && r.jsErrorCode == nil)
        let np = try JSONDecoder().decode(NowPlaying.self, from: Data(r.json.utf8))
        #expect(np.playing && np.position == 12.5 && np.duration == 10000 && np.artist == "Artist" && np.site == NowPlaying.appleMusicSite)
        #expect(np.siteName == nil)
        #expect(MediaScript.parseProbe("MUSIC\tfalse\t0\t0\tSong\t\tID")?.trackID == "ID")
        #expect(MediaScript.parseProbe("MUSIC\ttrue") == nil)
        #expect(BrowserKind.browsers.count == BrowserKind.allCases.count - 1 && !BrowserKind.appleMusic.isBrowser)
        #expect(BrowserKind.appleMusic.setupSteps.isEmpty && BrowserKind.appleMusic.menuPath.isEmpty)
    }

    @Test func spotifyWebIsProbedThroughTheBrowserPath() throws {
        // 2026-08-29 Whale 실측: <video> 없음, mediaSession.playbackState "none", 제목은 재생 중 "제목 • 아티스트"/일시정지 시 "Spotify - Web Player…",
        // 진행 바 input[type=range]의 max=길이(ms), React setter + input/change 이벤트로 seek.
        let probe = MediaScript.probe(browser: .whale)
        #expect(probe.contains(#"u contains "open.spotify.com""#))
        let js = MediaScript.probeJSOneLine
        #expect(js.contains("location.host === 'open.spotify.com'") && !js.contains("__SPOTIFY_HOST__"))
        #expect(js.contains("playback-progressbar") && js.contains("' • '") && js.contains("'spotify'"))
        let cmd = MediaScript.command(browser: .chrome, window: 1, tab: 1, .seek(0.5))
        #expect(cmd.contains("control-button-playpause") && cmd.contains("HTMLInputElement.prototype") && !cmd.contains("__SPOTIFY_HOST__"))
        let np = try JSONDecoder().decode(NowPlaying.self, from: Data(#"{"title":"t","playing":true,"position":1,"duration":2,"site":"spotify"}"#.utf8))
        #expect(np.siteName == "Spotify")
        // 라디오(URL track)는 길이·위치가 missing value → 0.
        #expect(MediaScript.musicProbe.contains("if d is missing value then set d to 0"))
    }

    @Test func artworkURLIsResizedAndErrorsAreClassified() {
        let js = MediaScript.probeJSOneLine
        // YouTube Music은 544px 원본 하나뿐이라 크기 파라미터를 바꿔 받는다(2026-08-29: 101KB → 상한 초과로 아트워크가 영영 비었음).
        #expect(js.contains("=w\(Constants.mediaArtworkTargetPixels)-h\(Constants.mediaArtworkTargetPixels)"))
        #expect(MediaScript.isTransientJSError(AppleScriptFailure.eventTimedOut))
        #expect(MediaScript.isTransientJSError(AppleScriptFailure.timedOut))
        #expect(!MediaScript.isTransientJSError(MediaScript.chromiumJSDisabledCode))
        #expect(MediaScript.isJSDisabled(MediaScript.chromiumJSDisabledCode, browser: .whale))
        #expect(!MediaScript.isJSDisabled(AppleScriptFailure.eventTimedOut, browser: .whale))
        #expect(!MediaScript.isJSDisabled(-1708, browser: .chrome))
        #expect(MediaScript.isJSDisabled(-1708, browser: .safari))
        #expect(!MediaScript.isJSDisabled(AppleScriptFailure.eventTimedOut, browser: .safari))
        #expect(BrowserKind.chrome.setupSteps.count == 1 && BrowserKind.safari.setupSteps.count == 2)
    }

    @Test func nowPlayingDecodesAndCleansTitle() throws {
        let json = #"{"title":"Song","artist":"Band","artwork":"data:image/png;base64,QUJD","playing":false,"position":12.5,"duration":200,"site":"youtube_music"}"#
        let np = try JSONDecoder().decode(NowPlaying.self, from: Data(json.utf8))
        #expect(np.artist == "Band")
        #expect(np.siteName == "YouTube Music")
        #expect(np.artworkData == Data("ABC".utf8))
        #expect(MediaScript.cleanTitle("Song - YouTube Music") == "Song")
        #expect(MediaScript.cleanTitle("Clip - YouTube") == "Clip")
        #expect(MediaScript.cleanTitle("Song | YouTube Music") == "Song")
        #expect(MediaScript.cleanTitle("Plain") == "Plain")
    }
}
