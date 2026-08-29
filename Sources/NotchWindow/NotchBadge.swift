import Observation

/// 접힌 노치 날개에 표시할 상태. 루트 뷰가 관찰한다(트리 재생성 없이 갱신).
@MainActor
@Observable
final class NotchBadge {
    var shelfCount: Int = 0
}
