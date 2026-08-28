import Carbon.HIToolbox

/// Carbon RegisterEventHotKey 기반 전역 단축키. 샌드박스에서 Accessibility 없이 동작한다.
/// 앱 전체에서 한 개만 쓴다(핸들러가 정적).
@MainActor
final class HotKey {
    private static var action: (@MainActor () -> Void)?
    private static var handlerRef: EventHandlerRef?
    // deinit은 @MainActor 클래스라도 nonisolated로 실행되어 non-Sendable인
    // EventHotKeyRef(OpaquePointer)를 격리 없이 읽어야 한다. init에서 한 번만 쓰고
    // deinit에서 한 번만 읽으므로(동시 접근 없음) nonisolated(unsafe)로 표시한다.
    private nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?

    // 기본 인자식은 이니셜라이저가 @MainActor여도 nonisolated 컨텍스트에서 평가되므로
    // (Swift 6), 불변 Sendable 값인 이 두 상수는 nonisolated로 선언한다.
    nonisolated static let controlOption: UInt32 = UInt32(controlKey | optionKey)
    nonisolated static let keyN: UInt32 = UInt32(kVK_ANSI_N)

    init?(keyCode: UInt32 = HotKey.keyN, modifiers: UInt32 = HotKey.controlOption, action: @escaping @MainActor () -> Void) {
        Self.action = action
        if Self.handlerRef == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                MainActor.assumeIsolated { HotKey.action?() }
                return noErr
            }, 1, &spec, nil, &Self.handlerRef)
            guard status == noErr else { return nil }
        }
        let signature = OSType(0x4F4E4348)   // 'ONCH'
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else { return nil }
        hotKeyRef = ref
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    }
}
