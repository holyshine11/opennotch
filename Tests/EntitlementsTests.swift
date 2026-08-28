import Foundation
import Testing

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

    @Test func mediaEntitlementsAreExactlyBasePlusMediaKeys() throws {
        // P1: 기본 3개. P4가 apple-events 키 2개를 추가하면 이 집합을 갱신한다.
        let dict = try entitlements(of: "OpenNotch")
        #expect(Set(dict.keys) == Self.base)
        for key in Self.base { #expect(dict[key] as? Bool == true) }
    }

    @Test func noMediaEntitlementsAreExactlyBase() throws {
        let dict = try entitlements(of: "OpenNotch-NoMedia")
        #expect(Set(dict.keys) == Self.base)
        for key in Self.base { #expect(dict[key] as? Bool == true) }
    }
}

private final class BundleToken {}
