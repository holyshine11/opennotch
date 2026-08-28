import Foundation
import Observation

enum NotchState: Equatable, Sendable { case collapsed, expanded, dropTargeting }
enum DropZone: Equatable, Sendable { case airdrop, shelf }
enum NotchTimerKind: Hashable, Sendable { case hoverOpen, hoverClose, idle }

enum NotchEvent: Equatable, Sendable {
    case clickNotch
    case hoverEnter, hoverExit, hoverOpenFired, hoverCloseFired
    case clickOutside, escape, idleFired
    case dragEnter, dragExit
    case drop(DropZone)
    case toggleRequested
    case screenChanged
}

/// 타이머는 뷰모델 밖에서 소유한다(테스트에서 가짜로 대체).
@MainActor
protocol NotchTimers: AnyObject {
    func schedule(_ kind: NotchTimerKind, seconds: TimeInterval, action: @escaping @MainActor () -> Void)
    func cancel(_ kind: NotchTimerKind)
}

@MainActor
@Observable
final class NotchViewModel {
    private(set) var state: NotchState = .collapsed
    var hoverToOpen = false
    /// 클립보드 검색창 등 텍스트 입력이 포커스를 가진 동안 true. 유휴 타이머가 멈춘다.
    var wantsKey = false {
        didSet { guard oldValue != wantsKey, state == .expanded else { return }; wantsKey ? timers.cancel(.idle) : scheduleIdle() }
    }
    var onDrop: ((DropZone) -> Void)?

    private let timers: NotchTimers

    init(timers: NotchTimers) {
        self.timers = timers
    }

    func send(_ event: NotchEvent) {
        switch (state, event) {
        // dropTargeting: 드래그 관련 이벤트만 받는다.
        case (.dropTargeting, .dragExit):
            collapse()
        case (.dropTargeting, .drop(let zone)):
            onDrop?(zone)
            zone == .shelf ? expand() : collapse()
        case (.dropTargeting, .screenChanged):
            collapse()
        case (.dropTargeting, _):
            break

        case (_, .dragEnter):
            timers.cancel(.hoverOpen); timers.cancel(.hoverClose); timers.cancel(.idle)
            state = .dropTargeting

        case (.collapsed, .clickNotch), (.collapsed, .toggleRequested), (.collapsed, .hoverOpenFired):
            expand()
        case (.collapsed, .hoverEnter) where hoverToOpen:
            timers.schedule(.hoverOpen, seconds: Constants.hoverOpenDelay) { [weak self] in self?.send(.hoverOpenFired) }
        case (.collapsed, .hoverExit):
            timers.cancel(.hoverOpen)

        case (.expanded, .clickNotch), (.expanded, .toggleRequested), (.expanded, .clickOutside), (.expanded, .hoverCloseFired):
            collapse()
        case (.expanded, .escape) where wantsKey:
            collapse()
        case (.expanded, .idleFired) where !wantsKey:
            collapse()
        case (.expanded, .hoverExit) where hoverToOpen:
            timers.schedule(.hoverClose, seconds: Constants.hoverCloseDelay) { [weak self] in self?.send(.hoverCloseFired) }
        case (.expanded, .hoverEnter):
            timers.cancel(.hoverClose)

        default:
            break
        }
    }

    /// 사용자 조작이 있을 때 호출 — 유휴 타이머를 다시 시작한다.
    func resetIdle() {
        guard state == .expanded, !wantsKey else { return }
        scheduleIdle()
    }

    private func expand() {
        timers.cancel(.hoverOpen)
        state = .expanded
        if !wantsKey { scheduleIdle() }
    }

    private func collapse() {
        timers.cancel(.hoverOpen); timers.cancel(.hoverClose); timers.cancel(.idle)
        state = .collapsed
    }

    private func scheduleIdle() {
        timers.schedule(.idle, seconds: Constants.idleCollapseDelay) { [weak self] in self?.send(.idleFired) }
    }
}
