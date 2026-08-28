import Foundation
import Testing
@testable import OpenNotch

@Suite struct NotchGeometryTests {
    /// 14" MacBook Pro 기본 해상도(1512×982), 노치 높이 32, 보조 영역 좌우 각 ~656.
    static let notched = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 950),
        safeAreaTop: 32, auxLeftWidth: 656, auxRightWidth: 656, menuBarHeight: 32)

    /// 외장 모니터(노치 없음), 메뉴바 24pt.
    static let external = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1416),
        safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0, menuBarHeight: 24)

    /// 메뉴바가 숨겨진 노치 없는 화면: visibleFrame이 frame과 같다.
    static let externalHiddenMenuBar = ScreenMetrics(
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
        safeAreaTop: 0, auxLeftWidth: 0, auxRightWidth: 0, menuBarHeight: 24)

    @Test func realNotchIsCenteredAtTop() {
        let n = NotchGeometry.notchRect(Self.notched)
        #expect(n.isVirtual == false)
        #expect(n.rect == CGRect(x: 656, y: 950, width: 200, height: 32))
    }

    @Test func virtualNotchUsesMenuBarHeightAndFixedWidth() {
        let n = NotchGeometry.notchRect(Self.external)
        #expect(n.isVirtual == true)
        #expect(n.rect.width == Constants.virtualNotchWidth)
        #expect(n.rect.height == 24)
        #expect(n.rect.midX == 1280)
        #expect(n.rect.maxY == 1440)
    }

    @Test func virtualNotchNeverCollapsesWhenMenuBarHidden() {
        let n = NotchGeometry.notchRect(Self.externalHiddenMenuBar)
        #expect(n.rect.height == 24)
    }

    @Test func panelFrameIsExpandedSizeCenteredOnNotchWithOverhang() {
        let n = NotchGeometry.notchRect(Self.notched)
        let f = NotchGeometry.panelFrame(Self.notched, notch: n)
        #expect(f.width == Constants.panelWidth)
        #expect(f.height == 32 + Constants.panelBodyHeight + Constants.panelTopOverhang)
        #expect(f.midX == 756)
        #expect(f.maxY == 982 + Constants.panelTopOverhang)
    }

    @Test func dragEnterRectExtendsSidewaysOnly() {
        let n = NotchGeometry.notchRect(Self.notched)
        let d = NotchGeometry.dragEnterRect(notch: n)
        #expect(d.minX == 656 - Constants.dragEnterMargin)
        #expect(d.maxX == 856 + Constants.dragEnterMargin)
        #expect(d.height == 32)
    }
}
