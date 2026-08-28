import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private(set) var notchController: NotchWindowController?
    private var observers: [NSObjectProtocol] = []
    private var hotKey: HotKey?
    private var shelfStore: ShelfStore?
    private var clipboardStore: ClipboardStore?
    private var clipboardMonitor: ClipboardMonitor?
    #if MEDIA_ENABLED
    private var mediaController: MediaController?
    private var mediaSetupWindow: NSWindow?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        PrefKey.registerDefaults()
        guard !Self.isRunningTests else { return }

        let controller = NotchWindowController()
        let shelf = ShelfStore()
        shelfStore = shelf
        shelf.onCountChanged = { [weak controller] count in controller?.setShelfBadge(count) }
        controller.setShelfBadge(shelf.items.count)
        let clipboard = ClipboardStore()
        let monitor = ClipboardMonitor(store: clipboard)
        clipboardStore = clipboard
        clipboardMonitor = monitor
        monitor.start()
        #if MEDIA_ENABLED
        let media = MediaController()
        mediaController = media
        let mediaPane: AnyView? = AnyView(MediaView(controller: media))
        observers.append(NotificationCenter.default.addObserver(forName: .openNotchShowMediaSetup, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.showMediaSetup() }
        })
        #else
        let mediaPane: AnyView? = nil
        #endif
        applyPreferences(to: controller)
        controller.paneProvider = { (media: mediaPane, shelf: AnyView(ShelfView(store: shelf)), clipboard: AnyView(ClipboardView(store: clipboard, monitor: monitor))) }
        observers.append(NotificationCenter.default.addObserver(forName: .openNotchClearClipboard, object: nil, queue: .main) { [weak clipboard] _ in
            MainActor.assumeIsolated { clipboard?.removeAll() }
        })
        controller.onDropURLs = { [weak controller, weak shelf] urls, zone in
            guard let controller, let shelf else { return false }
            switch zone {
            case .shelf:
                shelf.add(urls: urls)
                return true
            case .airdrop:
                guard AirDropService.shared.canSend(urls: urls) else {
                    controller.showToast(String(localized: "AirDrop is unavailable. Turn on Wi‑Fi and Bluetooth."), action: nil)
                    return false
                }
                // QA#7: 드래그 세션이 아직 살아있는 동안 AirDrop 피커를 동기로 띄우면 드롭 콜백이
                // 끝나지 않아 드래그가 멈춘다. true를 먼저 반환해 뷰모델이 접히게 하고, 전송은 다음 런루프로 미룬다.
                Task { @MainActor in AirDropService.shared.send(urls: urls, from: controller.panel) }
                return true
            }
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

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
    }

    #if MEDIA_ENABLED
    /// 설정 안내 창. 한 번 만들어 두고 닫아도 유지한다(닫기 = 숨김).
    private func showMediaSetup() {
        guard let mediaController else { return }
        if mediaSetupWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: MediaSetupGuideView(controller: mediaController)))
            window.title = String(localized: "YouTube controls setup")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            mediaSetupWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        mediaSetupWindow?.makeKeyAndOrderFront(nil)
    }
    #endif

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

        if let clipboardMonitor, let clipboardStore {
            let enabled = defaults.bool(forKey: PrefKey.clipboardEnabled)
            if clipboardMonitor.isEnabled != enabled { clipboardMonitor.isEnabled = enabled }
            let limit = defaults.integer(forKey: PrefKey.clipboardLimit)
            if limit > 0, clipboardStore.limit != limit { clipboardStore.limit = limit }
        }
        #if MEDIA_ENABLED
        if let mediaController {
            let ids = (defaults.string(forKey: PrefKey.disabledBrowsers) ?? "").split(separator: ",")
            let browsers = Set(ids.compactMap { BrowserKind(rawValue: String($0)) })
            if mediaController.disabledBrowsers != browsers { mediaController.disabledBrowsers = browsers }
            let enabled = defaults.bool(forKey: PrefKey.mediaEnabled)
            if mediaController.isEnabled != enabled { mediaController.isEnabled = enabled }
        }
        #endif
    }
}
