import AppKit
import Foundation
import Testing
@testable import OpenNotch

@MainActor
@Suite struct ClipboardStoreTests {
    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("clip-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func text(_ s: String) -> ClipItem { ClipItem.text(s) }

    @Test func insertPutsNewestFirstAndPersists() throws {
        let dir = try makeDir()
        let store = ClipboardStore(directory: dir)
        store.insert(text("one"), imagePNG: nil)
        store.insert(text("two"), imagePNG: nil)
        #expect(store.items.map(\.text) == ["two", "one"])
        #expect(ClipboardStore(directory: dir).items.map(\.text) == ["two", "one"])
    }

    @Test func consecutiveDuplicateTextIsMergedNotDuplicated() throws {
        let store = ClipboardStore(directory: try makeDir())
        store.insert(text("same"), imagePNG: nil)
        store.insert(text("same"), imagePNG: nil)
        #expect(store.items.count == 1)
    }

    @Test func limitEvictsOldestAndDeletesImageFile() throws {
        let dir = try makeDir()
        let store = ClipboardStore(directory: dir)
        store.limit = 2
        let png = Data([0x89, 0x50, 0x4E, 0x47])
        store.insert(ClipItem.image(byteCount: png.count), imagePNG: png)
        let imageID = store.items[0].id
        let imageURL = try #require(store.imageURL(for: imageID))
        #expect(FileManager.default.fileExists(atPath: imageURL.path))
        store.insert(text("a"), imagePNG: nil)
        store.insert(text("b"), imagePNG: nil)
        #expect(store.items.count == 2)
        #expect(store.items.map(\.text) == ["b", "a"])
        #expect(!FileManager.default.fileExists(atPath: imageURL.path))
    }

    @Test func removeAndRemoveAll() throws {
        let dir = try makeDir()
        let store = ClipboardStore(directory: dir)
        store.insert(text("x"), imagePNG: nil)
        store.insert(text("y"), imagePNG: nil)
        store.remove(id: store.items[0].id)
        #expect(store.items.map(\.text) == ["x"])
        store.removeAll()
        #expect(store.items.isEmpty)
        #expect(ClipboardStore(directory: dir).items.isEmpty)
    }

    @Test func searchIsCaseInsensitiveSubstring() throws {
        let store = ClipboardStore(directory: try makeDir())
        store.insert(text("Hello World"), imagePNG: nil)
        store.insert(text("other"), imagePNG: nil)
        #expect(store.search("world").map(\.text) == ["Hello World"])
        #expect(store.search("").count == 2)
    }

    @Test func titleIsTruncatedAndKindSpecific() throws {
        let long = String(repeating: "a", count: Constants.clipboardTitleMaxLength + 10)
        #expect(text(long).title.count == Constants.clipboardTitleMaxLength + 1)   // + ellipsis
        #expect(ClipItem.files(["/a/b.txt", "/c/d.png"]).title == "2 files")
        #expect(ClipItem.image(byteCount: 1).title == "Image")
        #expect(ClipItem.url("https://example.com/x").kind == .url)
    }

    @Test func writeToPasteboardIncludesMarkerAndContent() throws {
        let store = ClipboardStore(directory: try makeDir())
        let pb = NSPasteboard(name: NSPasteboard.Name("com.holyshine11.opennotch.test.write"))
        store.write(text("copied"), to: pb)
        #expect(pb.string(forType: .string) == "copied")
        #expect(pb.types?.contains(.openNotchSource) == true)
    }

    @Test func corruptedStoreStartsEmpty() throws {
        let dir = try makeDir()
        try Data("nope".utf8).write(to: dir.appendingPathComponent(Constants.clipboardStoreFileName))
        #expect(ClipboardStore(directory: dir).items.isEmpty)
    }
}
