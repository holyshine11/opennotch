import AppKit
import SwiftUI

/// 노치 위에 항상 떠 있는 비활성화 패널. 속성 순서·값은 스펙 §4.4 그대로.
final class NotchPanel: NSPanel {
    var wantsKey = false
    override var canBecomeKey: Bool { wantsKey }
    override var canBecomeMain: Bool { false }

    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isFloatingPanel = true            // level보다 먼저
        level = .mainMenu + 3
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // ignoresMouseEvents 는 절대 대입하지 않는다.
    }
}

/// 비활성화 패널에서 첫 클릭을 뷰로 전달한다.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    required init(rootView: Content) { super.init(rootView: rootView) }
    @MainActor required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
