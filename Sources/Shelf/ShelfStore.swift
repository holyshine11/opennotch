import Foundation
import Observation
import os

/// 셸프 데이터 소유자. JSON 파일 + bookmark. 셸프에 있는 동안 security-scoped access를 유지하고
/// 제거/종료 시 균형 맞춰 해제한다.
@MainActor
@Observable
final class ShelfStore {
    private(set) var items: [ShelfItem] = []
    /// 개수 변경 알림(배지용). 저장 성공 여부와 무관하게 호출된다.
    var onCountChanged: ((Int) -> Void)?
    let storeFileURL: URL

    /// id → 해석된 URL(access 시작됨)
    private var resolved: [UUID: URL] = [:]
    private let logger = Logger(subsystem: "com.holyshine11.opennotch", category: "shelf")

    /// - Parameter directory: nil이면 Application Support/OpenNotch. 테스트는 임시 디렉터리를 준다.
    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenNotch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        storeFileURL = dir.appendingPathComponent(Constants.shelfStoreFileName)
        load()
    }

    // MARK: 조회

    func url(for id: UUID) -> URL? { resolved[id] }

    /// 사용 시점에 원본 도달성을 재검사한다(§3.4). 삭제·이동돼 더 이상 열 수 없으면
    /// 항목을 제거하고 nil을 반환한다 — 호출자는 nil이면 사용자에게 알려야 한다.
    func validatedURL(for id: UUID) -> URL? {
        guard let url = resolved[id] else { return nil }
        guard (try? url.checkResourceIsReachable()) == true else {
            remove(id: id)
            return nil
        }
        return url
    }

    // MARK: 변경

    func add(urls: [URL]) {
        var changed = false
        for url in urls {
            let standardized = url.standardizedFileURL
            if resolved.values.contains(where: { $0.standardizedFileURL == standardized }) { continue }
            guard let bookmark = try? standardized.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else {
                logger.error("bookmark creation failed for \(standardized.lastPathComponent)")
                continue
            }
            // 드롭으로 받은 URL은 security-scoped가 아니므로, bookmark를 다시 해석해서 얻은
            // scoped URL에 대해 access를 시작해야 release()의 stop과 짝이 맞는다.
            var stale = false
            guard let scoped = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
                  scoped.startAccessingSecurityScopedResource() else {
                logger.error("access start failed for \(standardized.lastPathComponent)")
                continue
            }
            let item = ShelfItem(id: UUID(), bookmark: bookmark, displayName: standardized.lastPathComponent, addedAt: Date())
            resolved[item.id] = scoped
            items.append(item)
            changed = true
        }
        while items.count > Constants.shelfCapacity {
            release(items.removeFirst())
        }
        if changed { persist(); onCountChanged?(items.count) }
    }

    func remove(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        release(items.remove(at: index))
        persist()
        onCountChanged?(items.count)
    }

    func removeAll() {
        items.forEach(release)
        items.removeAll()
        persist()
        onCountChanged?(0)
    }

    // MARK: 내부

    private func release(_ item: ShelfItem) {
        resolved.removeValue(forKey: item.id)?.stopAccessingSecurityScopedResource()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeFileURL),
              let decoded = try? JSONDecoder().decode([ShelfItem].self, from: data) else {
            items = []
            return
        }
        var kept: [ShelfItem] = []
        var needsPersist = false
        for var item in decoded {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: item.bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else {
                logger.info("pruned unreachable shelf item \(item.displayName)")
                needsPersist = true
                continue
            }
            guard url.startAccessingSecurityScopedResource() else {
                logger.info("pruned unreachable shelf item \(item.displayName)")
                needsPersist = true
                continue
            }
            guard (try? url.checkResourceIsReachable()) == true else {
                url.stopAccessingSecurityScopedResource()
                logger.info("pruned unreachable shelf item \(item.displayName)")
                needsPersist = true
                continue
            }
            if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                item.bookmark = fresh
                needsPersist = true
            }
            resolved[item.id] = url
            kept.append(item)
        }
        items = kept
        if needsPersist { persist() }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storeFileURL, options: .atomic)
        } catch {
            logger.error("shelf persist failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
