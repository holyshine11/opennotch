import AppKit

/// NSScreen에서 계산에 필요한 값만 뽑은 값 타입. 테스트에서 픽스처로 만든다.
struct ScreenMetrics: Equatable, Sendable {
    var frame: CGRect
    var visibleFrame: CGRect
    var safeAreaTop: CGFloat
    var auxLeftWidth: CGFloat
    var auxRightWidth: CGFloat
    var menuBarHeight: CGFloat

    var hasNotch: Bool {
        safeAreaTop > 0 && auxLeftWidth > 0 && auxRightWidth > 0
    }
}

extension NSScreen {
    @MainActor var metrics: ScreenMetrics {
        ScreenMetrics(
            frame: frame,
            visibleFrame: visibleFrame,
            safeAreaTop: safeAreaInsets.top,
            auxLeftWidth: auxiliaryTopLeftArea?.width ?? 0,
            auxRightWidth: auxiliaryTopRightArea?.width ?? 0,
            menuBarHeight: NSStatusBar.system.thickness)
    }
}
