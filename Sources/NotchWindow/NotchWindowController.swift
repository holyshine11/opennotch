import AppKit
import SwiftUI

/// 실제 타이머 구현. 뷰모델이 요구한 타이머를 종류별로 하나씩만 유지한다.
@MainActor
final class MainThreadTimers: NotchTimers {
    private var tasks: [NotchTimerKind: Task<Void, Never>] = [:]

    func schedule(_ kind: NotchTimerKind, seconds: TimeInterval, action: @escaping @MainActor () -> Void) {
        tasks[kind]?.cancel()
        tasks[kind] = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel(_ kind: NotchTimerKind) {
        tasks[kind]?.cancel()
        tasks[kind] = nil
    }
}

@MainActor
final class NotchWindowController: NotchHost {
    let viewModel: NotchViewModel
    let toast = ToastCenter()
    let badge = NotchBadge()
    private let notchPanel = NotchPanel()
    private let container = DropContainerView(frame: .zero)
    private(set) var notch = NotchRect(rect: .zero, isVirtual: true)
    private var currentScreenKey: String = ""
    private var screenObserver: NSObjectProtocol?
    private var monitors: EventMonitors?

    var panel: NSWindow { notchPanel }
    var showVirtualNotch = true { didSet { reposition(force: true) } }
    /// P2가 연결: 셸프 추가 / AirDrop 전송. `false`를 반환하면 `.dropRejected`로 전이한다(예: AirDrop 불가 시 토스트).
    var onDropURLs: (([URL], DropZone) -> Bool)?
    /// 가상 노치가 꺼졌을 때 접힌 검은 모양·드래그 밴드만 숨긴다(§3.1). 펼친 패널은 항상 정상 렌더링된다.
    private var hideCollapsedShape: Bool { notch.isVirtual && !showVirtualNotch }

    init(timers: NotchTimers = MainThreadTimers()) {
        viewModel = NotchViewModel(timers: timers)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screenParametersChanged() }
        }
        let monitors = EventMonitors(
            onOutsideClick: { [weak self] in self?.viewModel.send(.clickOutside) },
            onEscape: { [weak self] in self?.viewModel.send(.escape) })
        monitors.panelFrameProvider = { [weak self] in self?.notchPanel.frame ?? .zero }
        monitors.panelProvider = { [weak self] in self?.notchPanel }
        monitors.start()
        self.monitors = monitors

        container.isCollapsed = { [weak self] in self?.viewModel.state == .collapsed }
        container.onEnter = { [weak self] in self?.viewModel.send(.dragEnter) }
        container.onExit = { [weak self] in self?.viewModel.send(.dragExit) }
        container.onDrop = { [weak self] urls, zone in
            let handled = self?.onDropURLs?(urls, zone) ?? true
            self?.viewModel.send(handled ? .drop(zone) : .dropRejected)
        }
    }

    // MARK: 화면 선택

    /// 노치가 있는 화면 중 첫 번째, 없으면 메뉴바가 있는 screens[0].
    static func targetScreen(_ screens: [NSScreen]) -> NSScreen? {
        screens.first { $0.metrics.hasNotch } ?? screens.first
    }

    func show() {
        reposition(force: true)
        notchPanel.orderFrontRegardless()
    }

    func reposition(force: Bool = false) {
        guard let screen = Self.targetScreen(NSScreen.screens) else { return }
        let metrics = screen.metrics
        // 실제 노치가 있는 화면은 safeAreaTop만, 없는 화면(가상 노치)은 visibleFrame.maxY만 키에 넣는다.
        // visibleFrame 전체를 넣으면 Dock/메뉴바 자동 숨김마다 SwiftUI 트리가 통째로 재생성된다.
        let variablePart: CGFloat = metrics.hasNotch ? metrics.safeAreaTop : metrics.visibleFrame.maxY
        let key = "\(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] ?? "")|\(metrics.frame)|\(variablePart)"
        guard force || key != currentScreenKey else { return }
        currentScreenKey = key

        notch = NotchGeometry.notchRect(metrics)
        notchPanel.setFrame(NotchGeometry.panelFrame(metrics, notch: notch), display: true)
        rebuildContent()
    }

    private func screenParametersChanged() {
        viewModel.send(.screenChanged)
        reposition()
    }

    private func rebuildContent() {
        container.collapsedActiveRect = hideCollapsedShape ? .zero : NotchGeometry.collapsedDropRect(notch: notch)
        container.embed(NotchHostingView(rootView: makeRootView()))
        if notchPanel.contentView !== container { notchPanel.contentView = container }
    }

    /// P2~P4가 모듈 뷰를 끼워 넣을 수 있도록 오버라이드 지점을 둔다.
    var paneProvider: (() -> (media: AnyView?, shelf: AnyView?, clipboard: AnyView?))? {
        didSet { guard notch.rect != .zero else { return }; rebuildContent() }
    }

    private func makeRootView() -> some View {
        let panes: (media: AnyView?, shelf: AnyView?, clipboard: AnyView?) = paneProvider?() ?? (nil, nil, nil)
        return NotchRootView(viewModel: viewModel, toast: toast, notch: notch, badge: badge, hideCollapsedShape: hideCollapsedShape,
                             mediaPane: panes.media, shelfPane: panes.shelf, clipboardPane: panes.clipboard)
            .environment(\.notchHost, self)
    }

    // MARK: NotchHost

    func resetIdle() { viewModel.resetIdle() }

    func setWantsKey(_ wants: Bool) {
        viewModel.wantsKey = wants
        notchPanel.wantsKey = wants
        if wants { notchPanel.makeKey() } else if notchPanel.isKeyWindow { notchPanel.resignKey() }
    }

    func showToast(_ text: String, action: ToastAction?) { toast.show(text, action: action) }

    func collapse() { viewModel.send(.clickOutside) }

    func setShelfBadge(_ count: Int) { badge.shelfCount = count }

}
