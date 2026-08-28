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

    @Test func nowPlayingDecodesAndCleansTitle() throws {
        let json = #"{"title":"Song","artist":"Band","artwork":"data:image/png;base64,QUJD","playing":false,"position":12.5,"duration":200,"site":"youtube_music"}"#
        let np = try JSONDecoder().decode(NowPlaying.self, from: Data(json.utf8))
        #expect(np.artist == "Band")
        #expect(np.siteName == "YouTube Music")
        #expect(np.artworkData == Data("ABC".utf8))
        #expect(MediaScript.cleanTitle("Song - YouTube Music") == "Song")
        #expect(MediaScript.cleanTitle("Clip - YouTube") == "Clip")
        #expect(MediaScript.cleanTitle("Plain") == "Plain")
    }
}
