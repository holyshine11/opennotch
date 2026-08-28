import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// 테스트 호스트로 실행될 때는 UI를 만들지 않는다.
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private(set) var notchController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PrefKey.registerDefaults()
        guard !Self.isRunningTests else { return }

        let controller = NotchWindowController()
        controller.viewModel.hoverToOpen = UserDefaults.standard.bool(forKey: PrefKey.hoverToOpen)
        controller.showVirtualNotch = UserDefaults.standard.bool(forKey: PrefKey.showVirtualNotch)
        controller.show()
        notchController = controller
    }
}
