import Testing
@testable import OpenNotch

/// 안내 창이 브라우저마다 고르는 "지금 할 일 하나".
@Suite struct BrowserSetupStatusTests {
    @Test func deriveChoosesOneStatePerBrowser() {
        // 권한 거부가 가장 먼저 — 토글이 켜져 있어도 Apple Event 자체가 막힌 상태다.
        #expect(BrowserSetupStatus.derive(jsReady: true, denied: true, running: true) == .permissionDenied)
        #expect(BrowserSetupStatus.derive(jsReady: true, denied: false, running: true) == .ready)
        #expect(BrowserSetupStatus.derive(jsReady: false, denied: false, running: true) == .jsOff)
        #expect(BrowserSetupStatus.derive(jsReady: nil, denied: false, running: true) == .noTab)
        #expect(BrowserSetupStatus.derive(jsReady: nil, denied: false, running: false) == .notRunning)
    }
}
