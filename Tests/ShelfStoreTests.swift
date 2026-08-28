import Foundation
import Testing
@testable import OpenNotch

@MainActor
@Suite struct ShelfStoreTests {
    /// 테스트마다 독립된 임시 디렉터리(샌드박스 컨테이너 안이라 bookmark 생성이 가능하다).
    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("shelf-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func makeFile(in dir: URL, name: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try Data("x".utf8).write(to: url)
        return url
    }

    @Test func addResolvesAndPersistsAcrossReload() throws {
        let dir = try makeDir()
        let file = try makeFile(in: dir, name: "a.txt")
        let store = ShelfStore(directory: dir)
        store.add(urls: [file])
        #expect(store.items.count == 1)
        #expect(store.items[0].displayName == "a.txt")
        #expect(store.url(for: store.items[0].id)?.lastPathComponent == "a.txt")

        let reloaded = ShelfStore(directory: dir)
        #expect(reloaded.items.count == 1)
        #expect(reloaded.url(for: reloaded.items[0].id)?.lastPathComponent == "a.txt")
    }

    @Test func capacityDropsOldest() throws {
        let dir = try makeDir()
        let store = ShelfStore(directory: dir)
        let files = try (0..<(Constants.shelfCapacity + 2)).map { try makeFile(in: dir, name: "f\($0).txt") }
        store.add(urls: files)
        #expect(store.items.count == Constants.shelfCapacity)
        #expect(store.items.first?.displayName == "f2.txt")   // 가장 오래된 f0, f1이 제거됨
        #expect(store.items.last?.displayName == "f\(Constants.shelfCapacity + 1).txt")
    }

    @Test func duplicateURLIsNotAddedTwice() throws {
        let dir = try makeDir()
        let file = try makeFile(in: dir, name: "dup.txt")
        let store = ShelfStore(directory: dir)
        store.add(urls: [file])
        store.add(urls: [file])
        #expect(store.items.count == 1)
    }

    @Test func removeAndRemoveAll() throws {
        let dir = try makeDir()
        let store = ShelfStore(directory: dir)
        store.add(urls: [try makeFile(in: dir, name: "1.txt"), try makeFile(in: dir, name: "2.txt")])
        store.remove(id: store.items[0].id)
        #expect(store.items.map(\.displayName) == ["2.txt"])
        store.removeAll()
        #expect(store.items.isEmpty)
        #expect(ShelfStore(directory: dir).items.isEmpty)
    }

    @Test func missingFileIsPrunedOnReload() throws {
        let dir = try makeDir()
        let file = try makeFile(in: dir, name: "gone.txt")
        let store = ShelfStore(directory: dir)
        store.add(urls: [file])
        try FileManager.default.removeItem(at: file)
        let reloaded = ShelfStore(directory: dir)
        #expect(reloaded.items.isEmpty)
    }

    @Test func corruptedStoreFileStartsEmpty() throws {
        let dir = try makeDir()
        try Data("not json".utf8).write(to: dir.appendingPathComponent(Constants.shelfStoreFileName))
        let store = ShelfStore(directory: dir)
        #expect(store.items.isEmpty)
    }

    @Test func countCallbackFires() throws {
        let dir = try makeDir()
        let store = ShelfStore(directory: dir)
        var counts: [Int] = []
        store.onCountChanged = { counts.append($0) }
        store.add(urls: [try makeFile(in: dir, name: "c.txt")])
        store.removeAll()
        #expect(counts == [1, 0])
    }
}
