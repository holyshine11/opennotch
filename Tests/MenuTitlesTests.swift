import Testing
@testable import OpenNotch

/// 도우미가 메뉴·체크박스를 찾는 이름 후보는 영어(심사자)와 한국어(주 사용자)를 모두 담아야 한다.
@Suite struct MenuTitlesTests {
    @Test func candidateListsCoverEnglishAndKorean() {
        let lists = [MenuTitles.view, MenuTitles.developer, MenuTitles.allowJS, MenuTitles.safariDeveloperTab,
                     MenuTitles.safariAdvancedTab, MenuTitles.safariShowDevFeatures, MenuTitles.allowJSSafari]
        for list in lists {
            #expect(list.contains { $0.unicodeScalars.allSatisfy { $0.isASCII } })
            #expect(list.contains { $0.unicodeScalars.contains { !$0.isASCII } })
        }
        #expect(MenuTitles.viewMenuIndex == 4)
    }
}
