import Foundation

/// 셸프 항목 — 파일 참조(security-scoped bookmark)만 보관한다. 복사·이동·이름변경은 하지 않는다.
struct ShelfItem: Codable, Identifiable, Equatable {
    let id: UUID
    var bookmark: Data
    var displayName: String
    let addedAt: Date
}
