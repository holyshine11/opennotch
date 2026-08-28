import AppKit

/// 패널의 contentView. SwiftUI 호스팅 뷰를 자식으로 품고 드래그 목적지 역할만 한다.
final class DropContainerView: NSView {
    var isCollapsed: () -> Bool = { true }
    /// 접힌 상태에서 진입을 인정하는 영역(이 뷰 좌표, 원점 좌하단).
    var collapsedActiveRect: CGRect = .zero
    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}
    var onDrop: ([URL], DropZone) -> Void = { _, _ in }
    private var entered = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func embed(_ view: NSView) {
        subviews.forEach { $0.removeFromSuperview() }
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view)
    }

    private func accepts(_ info: NSDraggingInfo) -> Bool {
        if (info.draggingSource as? NSView)?.window === window { return false }   // 자체 셸프에서 시작한 드래그
        let hasFiles = info.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        guard hasFiles else { return false }
        return isCollapsed() ? collapsedActiveRect.contains(convert(info.draggingLocation, from: nil)) : true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { draggingUpdated(sender) }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let ok = accepts(sender)
        if ok, !entered { entered = true; onEnter() }
        if !ok, entered { entered = false; onExit() }
        return ok ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        if entered { entered = false; onExit() }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        if entered { entered = false; onExit() }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let objects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
        let urls = (objects as? [URL]) ?? []
        guard !urls.isEmpty else { return false }
        let local = convert(sender.draggingLocation, from: nil)
        entered = false
        onDrop(urls, local.x < bounds.midX ? .airdrop : .shelf)
        return true
    }
}
