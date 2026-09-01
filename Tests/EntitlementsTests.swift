import Foundation
import Testing
@testable import OpenNotch

/// 소스의 entitlements 파일(테스트 번들에 리소스로 복사됨)이 정확히 기대한 키만 갖는지 검증한다.
/// 샌드박스 안에서는 소스 트리를 읽을 수 없으므로 번들 리소스를 읽는다.
@Suite struct EntitlementsTests {
    static let base: Set<String> = [
        "com.apple.security.app-sandbox",
        "com.apple.security.files.user-selected.read-only",
        "com.apple.security.files.bookmarks.app-scope",
    ]

    private func entitlements(of resource: String) throws -> [String: Any] {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: resource, withExtension: "entitlements"))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        return try #require(plist as? [String: Any])
    }

    static let mediaKeys: Set<String> = [
        "com.apple.security.automation.apple-events",
        "com.apple.security.temporary-exception.apple-events",
        "com.apple.security.scripting-targets",
    ]

    @Test func mediaEntitlementsAreExactlyBasePlusMediaKeys() throws {
        let dict = try entitlements(of: "OpenNotch")
        #expect(Set(dict.keys) == Self.base.union(Self.mediaKeys))
        for key in Self.base { #expect(dict[key] as? Bool == true) }
        #expect(dict["com.apple.security.automation.apple-events"] as? Bool == true)
    }

    /// 임시 예외 = 브라우저 전부. System Events는 심사에서 거부되어 뺐다(2026-09-01, 2.4.5(i)) — 그 밖의 대상은 없어야 한다.
    @Test func temporaryExceptionListMatchesBrowsers() throws {
        let dict = try entitlements(of: "OpenNotch")
        let ids = try #require(dict["com.apple.security.temporary-exception.apple-events"] as? [String])
        #expect(Set(ids) == Set(BrowserKind.browsers.map(\.rawValue)))
        #expect(ids.count == BrowserKind.browsers.count)
    }

    /// 브라우저가 아닌 소스(Apple Music)는 임시 예외가 아니라 정식 scripting-targets로 — Music.sdef의 access-group과 일치해야 한다.
    @Test func scriptingTargetsCoverNonBrowserSources() throws {
        let dict = try entitlements(of: "OpenNotch")
        let targets = try #require(dict["com.apple.security.scripting-targets"] as? [String: [String]])
        #expect(Set(targets.keys) == Set(BrowserKind.allCases.filter { !$0.isBrowser }.map(\.rawValue)))
        #expect(targets[BrowserKind.appleMusic.rawValue] == ["com.apple.Music.playback", "com.apple.Music.library.read"])
    }

    @Test func noMediaEntitlementsAreExactlyBase() throws {
        let dict = try entitlements(of: "OpenNotch-NoMedia")
        #expect(Set(dict.keys) == Self.base)
        for key in Self.base { #expect(dict[key] as? Bool == true) }
    }
}

private final class BundleToken {}
