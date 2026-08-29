import AppKit

/// 전역(다른 앱)·로컬(자기 앱) 마우스 다운과 로컬 Esc를 감시한다.
/// 마우스 전역 모니터는 권한이 필요 없다. 키 이벤트는 로컬(자기 앱이 키 윈도우일 때)만 본다.
@MainActor
final class EventMonitors {
    private var globalMouse: Any?
    private var localMouse: Any?
    private var localKey: Any?
    private let onOutsideClick: @MainActor () -> Void
    private let onEscape: @MainActor () -> Void
    var panelFrameProvider: @MainActor () -> CGRect = { .zero }
    /// Esc를 소비할지 판단하기 위한 창 비교 대상. 설정 창 등 다른 창이 키일 때는 이벤트를 그대로 흘려보낸다.
    var panelProvider: @MainActor () -> NSWindow? = { nil }

    private static let escapeKeyCode: UInt16 = 53

    init(onOutsideClick: @escaping @MainActor () -> Void, onEscape: @escaping @MainActor () -> Void) {
        self.onOutsideClick = onOutsideClick
        self.onEscape = onEscape
    }

    func start() {
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        globalMouse = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMouseDown(location: NSEvent.mouseLocation) }
        }
        localMouse = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouseDown(location: NSEvent.mouseLocation) }
            return event
        }
        localKey = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == Self.escapeKeyCode, let self else { return event }
            let isOurPanel = MainActor.assumeIsolated { event.window === self.panelProvider() }
            guard isOurPanel else { return event }
            MainActor.assumeIsolated { self.onEscape() }
            return nil
        }
    }

    func stop() {
        for monitor in [globalMouse, localMouse, localKey].compactMap({ $0 }) {
            NSEvent.removeMonitor(monitor)
        }
        globalMouse = nil; localMouse = nil; localKey = nil
    }

    private func handleMouseDown(location: CGPoint) {
        if !panelFrameProvider().contains(location) { onOutsideClick() }
    }
}
