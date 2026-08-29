import Testing
@testable import OpenNotch

/// 손쉬운 사용 도우미가 브라우저 메뉴 이름을 알아보는 규칙. 여기서 틀리면 도우미가 엉뚱한 항목을 누르거나 그냥 포기한다.
@Suite struct MenuTitlesTests {
    @Test func matchIgnoresCaseWhitespaceAndEllipsis() {
        #expect(MenuTitles.match("View", MenuTitles.view))
        #expect(MenuTitles.match("보기", MenuTitles.view))
        #expect(MenuTitles.match("view", MenuTitles.view))
        #expect(MenuTitles.match("  View  ", MenuTitles.view))
        // Settings… / Settings... / Settings 는 같은 항목이다.
        #expect(MenuTitles.match("Settings…", MenuTitles.settings))
        #expect(MenuTitles.match("Settings...", MenuTitles.settings))
        #expect(MenuTitles.match("설정...", MenuTitles.settings))
        #expect(MenuTitles.match(nil, MenuTitles.view) == false)
        #expect(MenuTitles.match("", MenuTitles.view) == false)
        #expect(MenuTitles.match("Window", MenuTitles.view) == false)
    }

    @Test func containsAcceptsLongerTitlesButNotEmptyOnes() {
        #expect(MenuTitles.contains("Developer Tools", MenuTitles.developer))
        #expect(MenuTitles.contains("개발자 정보", MenuTitles.developer))
        #expect(MenuTitles.contains(nil, MenuTitles.developer) == false)
        // 메뉴 구분선은 이름이 비어 있다 — 아무 후보에도 걸리면 안 된다.
        #expect(MenuTitles.contains("", MenuTitles.developer) == false)
        #expect(MenuTitles.contains("   ", MenuTitles.developer) == false)
        #expect(MenuTitles.contains("Bookmarks", MenuTitles.developer) == false)
    }

    /// 브라우저가 한국어로 떠 있을 때도 찾아야 하므로 후보에는 영어와 한국어가 모두 있어야 한다.
    @Test func everyCandidateListHasEnglishAndKorean() {
        let lists = [MenuTitles.view, MenuTitles.developer, MenuTitles.allowJS, MenuTitles.settings,
                     MenuTitles.safariDeveloperTab, MenuTitles.safariAdvancedTab,
                     MenuTitles.safariShowDevFeatures, MenuTitles.allowJSSafari]
        for list in lists {
            #expect(list.contains { !isKorean($0) })
            #expect(list.contains { isKorean($0) })
        }
    }

    /// "Settings…"처럼 ASCII 밖 문장부호가 섞인 영어 이름과 구별하려고 글자만 본다.
    private func isKorean(_ text: String) -> Bool { text.contains { $0.isLetter && !$0.isASCII } }
}
