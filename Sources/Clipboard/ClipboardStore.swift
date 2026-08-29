import AppKit
import Foundation
import Observation
import os

@MainActor
@Observable
final class ClipboardStore {
    private(set) var items: [ClipItem] = []
    var limit: Int = Constants.clipboardDefaultLimit { didSet { trim(); persist() } }
    /// macOS 15.4+ 프라이버시 게이트에 막혀 내용을 읽지 못하는 상태(UI 안내용).
    var pasteboardBlocked = false

    private let storeFileURL: URL
    private let imageDirectory: URL
    private let logger = Logger(subsystem: "com.holyshine11.opennotch", category: "clipboard")

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenNotch", isDirectory: true)
        storeFileURL = dir.appendingPathComponent(Constants.clipboardStoreFileName)
        imageDirectory = dir.appendingPathComponent(Constants.clipboardImageDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        load()
    }

    // MARK: 조회

    func search(_ query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return items }
        return items.filter { ($0.text ?? $0.title).localizedCaseInsensitiveContains(q) }
    }

    func imageURL(for id: UUID) -> URL? {
        guard let name = items.first(where: { $0.id == id })?.imageFile else { return nil }
        return imageDirectory.appendingPathComponent(name)
    }

    // MARK: 변경

    func insert(_ item: ClipItem, imagePNG: Data?) {
        if let first = items.first, first.kind == item.kind, first.kind != .image, first.text == item.text, first.filePaths == item.filePaths {
            items[0].createdAt = item.createdAt      // 연속 중복은 시각만 갱신
            persist()
            return
        }
        if let imagePNG, let name = item.imageFile {
            do { try imagePNG.write(to: imageDirectory.appendingPathComponent(name), options: .atomic) }
            catch { logger.error("image write failed: \(error.localizedDescription)"); return }
        }
        items.insert(item, at: 0)
        trim()
        persist()
    }

    func remove(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        deleteImage(of: items.remove(at: index))
        persist()
    }

    func removeAll() {
        items.forEach(deleteImage)
        items.removeAll()
        persist()
    }

    /// 항목을 클립보드에 쓴다(마커 포함). 붙여넣기는 사용자가 ⌘V.
    /// 모든 종류를 NSPasteboardItem 한 경로로 통일해 legacy API(setString(forType:))와
    /// item API(writeObjects)를 한 세션에 섞지 않는다.
    func write(_ item: ClipItem, to pasteboard: NSPasteboard = .general) {
        var pbItems: [NSPasteboardItem] = []
        switch item.kind {
        case .text, .url:
            let pi = NSPasteboardItem()
            pi.setString(item.text ?? "", forType: .string)
            pbItems = [pi]
        case .image:
            guard let url = imageURL(for: item.id), let data = try? Data(contentsOf: url) else { return }
            let pi = NSPasteboardItem()
            pi.setData(data, forType: .png)
            pbItems = [pi]
        case .files:
            pbItems = (item.filePaths ?? []).map { path in
                let pi = NSPasteboardItem()
                pi.setString(URL(fileURLWithPath: path).absoluteString, forType: .fileURL)
                return pi
            }
        }
        guard !pbItems.isEmpty else { return }
        pbItems.forEach { $0.setString("1", forType: .openNotchSource) }
        pasteboard.clearContents()
        pasteboard.writeObjects(pbItems)
    }

    // MARK: 내부

    private func trim() {
        while items.count > max(limit, 1) { deleteImage(of: items.removeLast()) }
    }

    private func deleteImage(of item: ClipItem) {
        guard let name = item.imageFile else { return }
        try? FileManager.default.removeItem(at: imageDirectory.appendingPathComponent(name))
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeFileURL),
              let decoded = try? JSONDecoder().decode([ClipItem].self, from: data) else { items = []; return }
        items = decoded
        let before = items.count
        trim()
        if items.count != before { persist() }
    }

    private func persist() {
        do { try JSONEncoder().encode(items).write(to: storeFileURL, options: .atomic) }
        catch { logger.error("clipboard persist failed: \(error.localizedDescription)") }
    }
}
