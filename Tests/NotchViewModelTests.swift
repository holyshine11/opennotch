import Foundation
import Testing
@testable import OpenNotch

@MainActor
final class FakeTimers: NotchTimers {
    var scheduled: [NotchTimerKind: (seconds: TimeInterval, action: @MainActor () -> Void)] = [:]
    var cancelled: [NotchTimerKind] = []
    func schedule(_ kind: NotchTimerKind, seconds: TimeInterval, action: @escaping @MainActor () -> Void) {
        scheduled[kind] = (seconds, action)
    }
    func cancel(_ kind: NotchTimerKind) { scheduled[kind] = nil; cancelled.append(kind) }
    func fire(_ kind: NotchTimerKind) {
        guard let entry = scheduled.removeValue(forKey: kind) else { return }
        entry.action()
    }
}

@MainActor
@Suite struct NotchViewModelTests {
    func make(hover: Bool = false) -> (NotchViewModel, FakeTimers) {
        let timers = FakeTimers()
        let vm = NotchViewModel(timers: timers)
        vm.hoverToOpen = hover
        return (vm, timers)
    }

    @Test func clickTogglesAndStartsIdleTimer() {
        let (vm, timers) = make()
        vm.send(.clickNotch)
        #expect(vm.state == .expanded)
        #expect(timers.scheduled[.idle]?.seconds == Constants.idleCollapseDelay)
        vm.send(.clickNotch)
        #expect(vm.state == .collapsed)
        #expect(timers.cancelled.contains(.idle))
    }

    @Test func hoverIsIgnoredWhenDisabled() {
        let (vm, timers) = make(hover: false)
        vm.send(.hoverEnter)
        #expect(timers.scheduled[.hoverOpen] == nil)
        #expect(vm.state == .collapsed)
    }

    @Test func hoverOpensAfterDelayAndClosesAfterExitDelay() {
        let (vm, timers) = make(hover: true)
        vm.send(.hoverEnter)
        #expect(vm.state == .collapsed)
        #expect(timers.scheduled[.hoverOpen]?.seconds == Constants.hoverOpenDelay)
        timers.fire(.hoverOpen)
        #expect(vm.state == .expanded)
        vm.send(.hoverExit)
        #expect(timers.scheduled[.hoverClose]?.seconds == Constants.hoverCloseDelay)
        timers.fire(.hoverClose)
        #expect(vm.state == .collapsed)
    }

    @Test func hoverExitBeforeOpenCancelsOpen() {
        let (vm, timers) = make(hover: true)
        vm.send(.hoverEnter)
        vm.send(.hoverExit)
        #expect(timers.scheduled[.hoverOpen] == nil)
        #expect(vm.state == .collapsed)
    }

    @Test func clickOutsideAndEscapeCollapse() {
        let (vm, _) = make()
        vm.send(.clickNotch)
        vm.send(.clickOutside)
        #expect(vm.state == .collapsed)
        vm.send(.clickNotch)
        vm.wantsKey = true
        vm.send(.escape)
        #expect(vm.state == .collapsed)
    }

    @Test func escapeIgnoredWithoutKeyWindow() {
        let (vm, _) = make()
        vm.send(.clickNotch)
        vm.wantsKey = false
        vm.send(.escape)
        #expect(vm.state == .expanded)
    }

    @Test func idleCollapsesUnlessKeyOrDropTargeting() {
        let (vm, timers) = make()
        vm.send(.clickNotch)
        timers.fire(.idle)
        #expect(vm.state == .collapsed)

        vm.send(.clickNotch)
        vm.wantsKey = true
        #expect(timers.scheduled[.idle] == nil)   // 키 윈도우면 타이머 정지
        vm.wantsKey = false
        #expect(timers.scheduled[.idle] != nil)   // 해제되면 재개
    }

    @Test func dragEnterFromAnyStateTargetsAndExitCollapses() {
        let (vm, timers) = make()
        vm.send(.dragEnter)
        #expect(vm.state == .dropTargeting)
        #expect(timers.scheduled[.idle] == nil)
        vm.send(.dragExit)
        #expect(vm.state == .collapsed)

        vm.send(.clickNotch)
        vm.send(.dragEnter)
        #expect(vm.state == .dropTargeting)
    }

    @Test func dropOnShelfExpandsAndDropOnAirDropCollapses() {
        let (vm, timers) = make()
        var dropped: [DropZone] = []
        vm.onDrop = { dropped.append($0) }

        vm.send(.dragEnter)
        vm.send(.drop(.shelf))
        #expect(vm.state == .expanded)
        #expect(timers.scheduled[.idle] != nil)

        vm.send(.dragEnter)
        vm.send(.drop(.airdrop))
        #expect(vm.state == .collapsed)
        #expect(dropped == [.shelf, .airdrop])
    }

    @Test func eventsIgnoredWhileDropTargeting() {
        let (vm, timers) = make(hover: true)
        vm.send(.dragEnter)
        for event in [NotchEvent.clickNotch, .hoverEnter, .hoverExit, .clickOutside, .escape, .toggleRequested] {
            vm.send(event)
            #expect(vm.state == .dropTargeting)
        }
        timers.fire(.idle)
        #expect(vm.state == .dropTargeting)
    }

    @Test func toggleAndScreenChanged() {
        let (vm, _) = make()
        vm.send(.toggleRequested)
        #expect(vm.state == .expanded)
        vm.send(.toggleRequested)
        #expect(vm.state == .collapsed)

        vm.send(.dragEnter)
        vm.send(.screenChanged)
        #expect(vm.state == .collapsed)
        vm.send(.clickNotch)
        vm.send(.screenChanged)
        #expect(vm.state == .expanded)
    }

    @Test func resetIdleReschedules() {
        let (vm, timers) = make()
        vm.send(.clickNotch)
        timers.scheduled[.idle] = nil
        vm.resetIdle()
        #expect(timers.scheduled[.idle] != nil)
    }
}
