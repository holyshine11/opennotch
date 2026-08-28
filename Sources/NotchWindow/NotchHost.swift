import AppKit
import SwiftUI

struct ToastAction {
    let title: String
    let handler: @MainActor () -> Void
}

/// 기능 모듈(셸프·클립보드·미디어)이 노치 윈도우에 요구하는 것.
@MainActor
protocol NotchHost: AnyObject {
    func resetIdle()
    func setWantsKey(_ wants: Bool)
    func showToast(_ text: String, action: ToastAction?)
    func collapse()
    func setShelfBadge(_ count: Int)
    var panel: NSWindow { get }
}

private struct NotchHostKey: EnvironmentKey {
    // NotchHost는 @MainActor 프로토콜이라 Sendable이 아니다.
    // EnvironmentKey.defaultValue는 격리 컨텍스트가 없는 프로토콜 요구사항이므로
    // 항상 nil인 이 상수에 한해 nonisolated(unsafe)로 표시한다.
    nonisolated(unsafe) static let defaultValue: NotchHost? = nil
}

extension EnvironmentValues {
    var notchHost: NotchHost? {
        get { self[NotchHostKey.self] }
        set { self[NotchHostKey.self] = newValue }
    }
}
