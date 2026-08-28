import AppKit
import os

/// AirDrop 전송. 공개 API(NSSharingService)만 쓰며 추가 entitlement가 없다.
/// LSUIElement 앱은 호출 전 activate가 필요하고, 시트 앵커로 노치 패널을 돌려준다.
@MainActor
final class AirDropService: NSObject, NSSharingServiceDelegate {
    static let shared = AirDropService()
    private weak var anchorWindow: NSWindow?
    /// perform(withItems:)는 비동기라 강한 참조가 없으면 서비스가 완료 전에 해제될 수 있다.
    private var activeService: NSSharingService?
    private let logger = Logger(subsystem: "com.holyshine11.opennotch", category: "airdrop")

    private var service: NSSharingService? { NSSharingService(named: .sendViaAirDrop) }

    func canSend(urls: [URL]) -> Bool {
        guard !urls.isEmpty, let service else { return false }
        return service.canPerform(withItems: urls)
    }

    func send(urls: [URL], from window: NSWindow) {
        guard let service else { return }
        anchorWindow = window
        service.delegate = self
        activeService = service
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
    }

    // MARK: NSSharingServiceDelegate

    nonisolated func sharingService(_ sharingService: NSSharingService, sourceWindowForShareItems items: [Any], sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
        MainActor.assumeIsolated { anchorWindow }
    }

    nonisolated func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        MainActor.assumeIsolated { activeService = nil }
    }

    nonisolated func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        MainActor.assumeIsolated {
            activeService = nil
            logger.error("airdrop failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
