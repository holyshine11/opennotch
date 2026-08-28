import AppKit
import Foundation

enum ClipKind: String, Codable, Sendable { case text, url, image, files }

extension NSPasteboard.PasteboardType {
    /// 우리가 쓴 항목 표시 — 모니터가 다시 캡처하지 않는다.
    static let openNotchSource = NSPasteboard.PasteboardType("org.opennotch.source")
}

struct ClipItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var createdAt: Date
    let kind: ClipKind
    let text: String?
    let imageFile: String?
    let filePaths: [String]?
    let byteCount: Int

    static func text(_ s: String) -> ClipItem {
        let isURL = URL(string: s).flatMap { $0.scheme != nil && $0.host != nil } ?? false
        return ClipItem(id: UUID(), createdAt: Date(), kind: isURL ? .url : .text, text: s, imageFile: nil, filePaths: nil, byteCount: s.utf8.count)
    }
    static func url(_ s: String) -> ClipItem { text(s) }
    static func image(byteCount: Int) -> ClipItem {
        let id = UUID()
        return ClipItem(id: id, createdAt: Date(), kind: .image, text: nil, imageFile: "\(id.uuidString).png", filePaths: nil, byteCount: byteCount)
    }
    static func files(_ paths: [String]) -> ClipItem {
        ClipItem(id: UUID(), createdAt: Date(), kind: .files, text: nil, imageFile: nil, filePaths: paths, byteCount: paths.reduce(0) { $0 + $1.utf8.count })
    }

    /// 칩·목록에 보이는 한 줄 제목.
    var title: String {
        switch kind {
        case .text, .url:
            let oneLine = (text ?? "").replacingOccurrences(of: "\n", with: " ")
            if oneLine.count > Constants.clipboardTitleMaxLength {
                return String(oneLine.prefix(Constants.clipboardTitleMaxLength)) + "…"
            }
            return oneLine
        case .image: return "Image"
        case .files:
            let paths = filePaths ?? []
            return paths.count == 1 ? (paths[0] as NSString).lastPathComponent : "\(paths.count) files"
        }
    }
}
