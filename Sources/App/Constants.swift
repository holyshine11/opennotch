import Foundation

/// 모든 수치 상수. 타입을 명시하고 서술적 이름을 쓴다(D10).
enum Constants {
    static let hoverOpenDelay: TimeInterval = 0.4
    static let hoverCloseDelay: TimeInterval = 0.3
    static let idleCollapseDelay: TimeInterval = 6
    static let expandAnimationDuration: TimeInterval = 0.35
    static let toastDuration: TimeInterval = 3
    static let dragEnterMargin: CGFloat = 32
    static let virtualNotchWidth: CGFloat = 180
    static let panelWidth: CGFloat = 440
    static let panelBodyHeight: CGFloat = 160
    static let panelTabBarHeight: CGFloat = 24
    static let panelCornerRadius: CGFloat = 14
    static let collapsedCornerRadius: CGFloat = 8
    static let panelTopOverhang: CGFloat = 1
    static let shelfCapacity: Int = 12
    static let shelfStoreFileName: String = "shelf.json"
    static let shelfThumbnailSize: CGFloat = 48
    static let shelfWingWidth: CGFloat = 30
    static let shelfGridColumns: Int = 4
    static let clipboardDefaultLimit: Int = 100
    static let clipboardLimitRange: ClosedRange<Int> = 20...500
    static let clipboardLimitStep: Int = 10
    static let clipboardStoreFileName: String = "clipboard.json"
    static let clipboardImageDirectoryName: String = "clipboard"
    static let clipboardMaxImageBytes: Int = 10_000_000
    static let clipboardPollInterval: TimeInterval = 0.75
    static let clipboardTitleMaxLength: Int = 60
    static let mediaPollInterval: TimeInterval = 2
    static let mediaScriptTimeout: TimeInterval = 3
    static let mediaErrorBackoff: TimeInterval = 30
    static let mediaBrowserBackoff: TimeInterval = 15
    static let mediaTickInterval: TimeInterval = 0.5
    static let mediaCommandRefreshDelay: TimeInterval = 0.5
    static let mediaArtworkMaxBytes: Int = 200_000
    static let mediaArtworkTargetPixels: Int = 144
    static let mediaArtworkSize: CGFloat = 72
    static let mediaSeekBarHeight: CGFloat = 4
    static let mediaSeekHitHeight: CGFloat = 14
    static let youtubeMusicHost: String = "music.youtube.com"
    static let youtubeWatchPath: String = "youtube.com/watch"
    static let automationPrivacySettingsURL: String = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    static let pasteboardPrivacySettingsURL: String = "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard"
}
