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
    static let mediaArtworkRetryDelay: TimeInterval = 0.7
    static let mediaArtworkMaxBytes: Int = 200_000
    static let mediaArtworkTargetPixels: Int = 256   // mediaArtworkSize @2x
    static let mediaArtworkSize: CGFloat = 128       // = panelBodyHeight − 페인 패딩(6+10) − MediaView 패딩(8×2): 본문 높이를 꽉 채운다
    static let mediaSetupWindowWidth: CGFloat = 520
    static let mediaSetupWindowMargin: CGFloat = 80    // 안내 창이 화면 높이에서 남겨 두는 여백
    static let mediaSetupFallbackHeight: CGFloat = 800 // 화면 정보를 못 얻을 때의 안내 창 높이 상한
    static let mediaSeekBarHeight: CGFloat = 4
    static let mediaSeekHitHeight: CGFloat = 14
    static let youtubeMusicHost: String = "music.youtube.com"
    /// 안내 창의 [브라우저에서 YouTube 열기]가 여는 확인용 페이지. 호스트 상수로 조립한다(URL 리터럴 금지).
    static let mediaSetupCheckURL: URL? = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = youtubeMusicHost
        return components.url
    }()
    static let youtubeWatchPath: String = "youtube.com/watch"
    static let spotifyWebHost: String = "open.spotify.com"
    /// 손쉬운 사용 도우미(SetupAssistant): AX 응답 대기 상한과, 메뉴·창이 그려질 때까지 기다리는 시간.
    static let assistMessagingTimeout: Float = 2
    static let assistActivateDelay: TimeInterval = 0.4
    static let assistMenuOpenDelay: TimeInterval = 0.3
    static let assistSettleDelay: TimeInterval = 0.6
    static let assistPermissionPollInterval: TimeInterval = 1
    static let assistMenuPollInterval: TimeInterval = 0.5   // 펼쳐 둔 메뉴가 닫혔는지 확인하는 주기
    static let assistSearchDepth: Int = 8   // Safari 설정 창에서 체크박스를 찾을 때 내려갈 최대 깊이
    static let automationPrivacySettingsURL: String = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
    static let accessibilityPrivacySettingsURL: String = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    static let pasteboardPrivacySettingsURL: String = "x-apple.systempreferences:com.apple.preference.security?Privacy_Pasteboard"
}
