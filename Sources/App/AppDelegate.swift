import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private(set) var notchController: NotchWindowController?
    private var observers: [NSObjectProtocol] = []
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        PrefKey.registerDefaults()
        guard !Self.isRunningTests else { return }

        let controller = NotchWindowController()
        applyPreferences(to: controller)
        controller.onDropURLs = { [weak controller] urls, zone in   // P2가 교체
            controller?.showToast("\(urls.count) file(s) → \(zone == .airdrop ? "AirDrop" : "Shelf")", action: nil)
            return true
        }
        controller.show()
        notchController = controller

        observers.append(NotificationCenter.default.addObserver(
            forName: .openNotchTogglePanel, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.notchController?.viewModel.send(.toggleRequested) }
            })
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let controller = self.notchController else { return }
                    self.applyPreferences(to: controller)
                }
            })

        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: PrefKey.firstLaunchDone) {
            defaults.set(true, forKey: PrefKey.firstLaunchDone)
            controller.viewModel.send(.toggleRequested)
        }
    }

    /// Dock에 없는 앱을 다시 실행하면 패널을 펼친다.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if notchController?.viewModel.state == .collapsed { notchController?.viewModel.send(.toggleRequested) }
        return false
    }

    private func applyPreferences(to controller: NotchWindowController) {
        let defaults = UserDefaults.standard
        let hover = defaults.bool(forKey: PrefKey.hoverToOpen)
        if controller.viewModel.hoverToOpen != hover { controller.viewModel.hoverToOpen = hover }
        let virtual = defaults.bool(forKey: PrefKey.showVirtualNotch)
        if controller.showVirtualNotch != virtual { controller.showVirtualNotch = virtual }

        let wantsHotKey = defaults.bool(forKey: PrefKey.hotkeyEnabled)
        if wantsHotKey, hotKey == nil {
            hotKey = HotKey { [weak controller] in controller?.viewModel.send(.toggleRequested) }
        } else if !wantsHotKey {
            hotKey = nil
        }
    }
}
