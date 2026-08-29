import Foundation

struct NotchRect: Equatable, Sendable {
    var rect: CGRect
    var isVirtual: Bool
}

/// 화면 좌표(원점 좌하단) 기준 순수 계산.
enum NotchGeometry {
    static func notchRect(_ m: ScreenMetrics) -> NotchRect {
        if m.hasNotch {
            let width = m.frame.width - m.auxLeftWidth - m.auxRightWidth
            let rect = CGRect(x: m.frame.midX - width / 2,
                              y: m.frame.maxY - m.safeAreaTop,
                              width: width, height: m.safeAreaTop)
            return NotchRect(rect: rect, isVirtual: false)
        }
        let height = max(m.frame.maxY - m.visibleFrame.maxY, m.menuBarHeight)
        let width = Constants.virtualNotchWidth
        let rect = CGRect(x: m.frame.midX - width / 2,
                          y: m.frame.maxY - height,
                          width: width, height: height)
        return NotchRect(rect: rect, isVirtual: true)
    }

    /// 패널은 항상 펼친 크기. 상단이 화면 위로 overhang만큼 나간다.
    static func panelFrame(_ m: ScreenMetrics, notch: NotchRect) -> CGRect {
        let height = notch.rect.height + Constants.panelBodyHeight + Constants.panelTopOverhang
        return CGRect(x: notch.rect.midX - Constants.panelWidth / 2,
                      y: m.frame.maxY + Constants.panelTopOverhang - height,
                      width: Constants.panelWidth, height: height)
    }

    /// 드래그 진입 판정 영역: 노치를 좌우로만 margin 확장(아래로는 확장하지 않는다).
    static func dragEnterRect(notch: NotchRect) -> CGRect {
        notch.rect.insetBy(dx: -Constants.dragEnterMargin, dy: 0)
    }

    /// 접힌 상태 드래그 진입 영역을 패널 로컬 좌표(원점 좌하단)로. 노치 좌우 32pt, 높이는 노치 높이.
    static func collapsedDropRect(notch: NotchRect) -> CGRect {
        let width = notch.rect.width + Constants.dragEnterMargin * 2
        let totalHeight = notch.rect.height + Constants.panelBodyHeight + Constants.panelTopOverhang
        return CGRect(x: (Constants.panelWidth - width) / 2,
                      y: totalHeight - Constants.panelTopOverhang - notch.rect.height,
                      width: width, height: notch.rect.height)
    }
}
