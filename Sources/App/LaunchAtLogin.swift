import ServiceManagement

/// 로그인 시 실행 — 사용자 토글로만 켠다(Guideline 2.4.5 iii). 헬퍼 번들 없음.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    /// 사용자가 시스템 설정에서 거부한 상태면 그 화면을 열어 준다.
    static var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }
    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
