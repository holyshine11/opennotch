# OpenNotch P2 — 셸프 + AirDrop 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 노치에 떨어뜨린 파일을 참조(security-scoped bookmark)로 보관하는 셸프와, 드롭/셸프 항목에서 바로 보내는 AirDrop을 완성한다. 앱 재시작 후에도 셸프가 유지되고, 접힌 노치 오른쪽 날개에 개수 배지가 보인다.

**Architecture:** `ShelfStore`(@Observable, JSON 파일 + bookmark, 항목마다 security-scoped access를 셸프에 있는 동안 유지)가 데이터를 소유한다. `ShelfView`(SwiftUI)가 썸네일 그리드·우클릭 메뉴·드래그 아웃을 제공하고, `AirDropService`/`QuickLookController`는 얇은 AppKit 래퍼다. P1의 `NotchWindowController.onDropURLs`와 `paneProvider`에 `AppDelegate`가 연결한다. 접힌 상태 배지는 `NotchHost.setShelfBadge`로 전달돼 루트 뷰가 날개를 그린다.

**Tech Stack:** Swift 6.3(언어 모드 6), SwiftUI + AppKit, QuickLookThumbnailing, Quartz(QLPreviewPanel), Swift Testing. 외부 의존성 0.

**Spec:** `docs/superpowers/specs/2026-08-28-opennotch-design.md` v1.2 — §3.1(배지), §3.3(드롭존), §3.4(AirDrop·셸프), §4.3(계약), §4.6(셸프), §4.10(entitlements)

## Global Constraints

- 최소 macOS **14.0**, Swift 언어 모드 **6**, 외부 의존성 **0개**. 사설 API·Accessibility·temporary-exception **금지**.
- 셸프는 파일을 **절대 복사·이동·이름변경하지 않는다.** 참조(bookmark)만 보관. 존재 판정은 `checkResourceIsReachable()`(타임스탬프 API 호출 금지 — PrivacyInfo와 일치).
- Entitlements는 P1 그대로(`app-sandbox`, `files.user-selected.read-only`, `files.bookmarks.app-scope`) — **추가 금지**. AirDrop은 추가 entitlement가 필요 없다.
- 접힌 상태 alpha-0 규칙 유지: 날개 배지는 **검은 불투명** 형태로만 그린다(그림자·블러 금지).
- quality-gate(D10): 수치 상수는 `Constants.swift`에 타입 명시 + 서술적 이름. 소스에 `https://` 금지. Swift enum 허용.
- 문자열은 영어 소스(`String(localized:)`/`Text`), 한국어는 P5.
- 커밋: 각 태스크 끝, 한국어 메시지, 꼬리말 `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`, `git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit`. `OpenNotch.xcodeproj`는 커밋 금지.
- 명령(루트 `/Users/Dev/Notch_app`): `xcodegen generate`(파일 추가 후) · `xcodebuild -project OpenNotch.xcodeproj -scheme OpenNotch -destination 'platform=macOS' test 2>&1 | tail -40; echo "rc=${PIPESTATUS[0]}"` — 성공은 rc=0 + 테스트 목록으로 판정(`-quiet`는 배너를 숨김).
- P1 인터페이스(변경 금지, 확장만): `NotchWindowController.onDropURLs: (([URL], DropZone) -> Bool)?`(false → `.dropRejected`), `paneProvider: (() -> (media: AnyView?, shelf: AnyView?, clipboard: AnyView?))?`, `protocol NotchHost { resetIdle(); setWantsKey(_:); showToast(_:action:); collapse(); panel }`, 환경값 `\.notchHost`, `Constants.shelfCapacity = 12`.
- 시작 브랜치: `main`(P1 병합 후)에서 `feat/p2-shelf-airdrop`.

---

## 파일 구조

| 파일 | 책임 |
|---|---|
| `Sources/Shelf/ShelfItem.swift` | Codable 값 타입(id, bookmark, displayName, addedAt) |
| `Sources/Shelf/ShelfStore.swift` | 로드/저장(JSON), bookmark 생성·해석·access 유지, 상한, 제거 |
| `Sources/Shelf/AirDropService.swift` | `NSSharingService(.sendViaAirDrop)` 래퍼 + 델리게이트 |
| `Sources/Shelf/QuickLookController.swift` | `QLPreviewPanel` 데이터소스 |
| `Sources/Shelf/ShelfView.swift` | 그리드, 우클릭 메뉴, 드래그 아웃, 빈 상태 |
| `Sources/NotchWindow/NotchHost.swift` (수정) | `setShelfBadge(_:)` 추가 |
| `Sources/NotchWindow/NotchBadge.swift` | @Observable 배지 개수 |
| `Sources/NotchWindow/NotchRootView.swift` (수정) | 접힌 상태 오른쪽 날개 배지 |
| `Sources/NotchWindow/NotchWindowController.swift` (수정) | `badge` 소유, `setShelfBadge` 구현, 루트 뷰에 전달 |
| `Sources/App/Constants.swift` (수정) | 썸네일 크기, 날개 폭 등 |
| `Sources/App/AppDelegate.swift` (수정) | `ShelfStore` 생성, `paneProvider`·`onDropURLs` 연결 |
| `Tests/ShelfStoreTests.swift` | 임시 디렉터리에서 bookmark 왕복·상한·제거·손상 JSON·누락 파일 |

---

### Task 1: ShelfItem + ShelfStore (bookmark 참조 보관, JSON 영속)

**Files:**
- Create: `Sources/Shelf/ShelfItem.swift`, `Sources/Shelf/ShelfStore.swift`
- Modify: `Sources/App/Constants.swift`
- Test: `Tests/ShelfStoreTests.swift`

**Interfaces:**
- Produces:
  - `struct ShelfItem: Codable, Identifiable, Equatable { let id: UUID; var bookmark: Data; var displayName: String; let addedAt: Date }`
  - `@MainActor @Observable final class ShelfStore { init(directory: URL? = nil); private(set) var items: [ShelfItem]; var onCountChanged: ((Int) -> Void)?; func add(urls: [URL]); func remove(id: UUID); func removeAll(); func url(for id: UUID) -> URL?; var storeFileURL: URL }`
  - `Constants.shelfStoreFileName: String = "shelf.json"`, `Constants.shelfThumbnailSize: CGFloat = 48`, `Constants.shelfWingWidth: CGFloat = 30`

- [ ] **Step 1: 실패하는 테스트**

`Tests/ShelfStoreTests.swift`:
```swift
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
```

- [ ] **Step 2: 실패 확인** — `xcodegen generate` 후 test 명령 → 컴파일 실패(`ShelfStore` 없음).

- [ ] **Step 3: 구현**

`Sources/App/Constants.swift`에 추가(기존 `shelfCapacity` 아래):
```swift
    static let shelfStoreFileName: String = "shelf.json"
    static let shelfThumbnailSize: CGFloat = 48
    static let shelfWingWidth: CGFloat = 30
    static let shelfGridColumns: Int = 4
```

`Sources/Shelf/ShelfItem.swift`:
```swift
import Foundation

/// 셸프 항목 — 파일 참조(security-scoped bookmark)만 보관한다. 복사·이동·이름변경은 하지 않는다.
struct ShelfItem: Codable, Identifiable, Equatable {
    let id: UUID
    var bookmark: Data
    var displayName: String
    let addedAt: Date
}
```

`Sources/Shelf/ShelfStore.swift`:
```swift
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

    // MARK: 변경

    func add(urls: [URL]) {
        var changed = false
        for url in urls {
            let standardized = url.standardizedFileURL
            if resolved.values.contains(where: { $0.standardizedFileURL == standardized }) { continue }
            guard let bookmark = try? standardized.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else {
                logger.error("bookmark creation failed for \(standardized.lastPathComponent, privacy: .public)")
                continue
            }
            let item = ShelfItem(id: UUID(), bookmark: bookmark, displayName: standardized.lastPathComponent, addedAt: Date())
            _ = standardized.startAccessingSecurityScopedResource()
            resolved[item.id] = standardized
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
        for var item in decoded {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: item.bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource(),
                  (try? url.checkResourceIsReachable()) == true else {
                logger.info("pruned unreachable shelf item \(item.displayName, privacy: .public)")
                continue
            }
            if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                item.bookmark = fresh
            }
            resolved[item.id] = url
            kept.append(item)
        }
        items = kept
        if kept.count != decoded.count { persist() }
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
```

- [ ] **Step 4: 테스트 통과 확인** — `ShelfStoreTests` 7개 통과, 기존 24개 유지(총 31).

- [ ] **Step 5: 커밋**

```bash
git add Sources/Shelf Sources/App/Constants.swift Tests/ShelfStoreTests.swift
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: ShelfStore — bookmark 참조 보관, JSON 영속, 상한·제거 + 테스트

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: 접힌 노치 날개 배지 (NotchBadge, NotchHost.setShelfBadge)

**Files:**
- Create: `Sources/NotchWindow/NotchBadge.swift`
- Modify: `Sources/NotchWindow/NotchHost.swift`, `Sources/NotchWindow/NotchWindowController.swift`, `Sources/NotchWindow/NotchRootView.swift`

**Interfaces:**
- Produces: `@MainActor @Observable final class NotchBadge { var shelfCount: Int = 0 }`; `NotchHost.setShelfBadge(_ count: Int)`; `NotchRootView.badge: NotchBadge`

- [ ] **Step 1: NotchBadge + 프로토콜 확장**

`Sources/NotchWindow/NotchBadge.swift`:
```swift
import Observation

/// 접힌 노치 날개에 표시할 상태. 루트 뷰가 관찰한다(트리 재생성 없이 갱신).
@MainActor
@Observable
final class NotchBadge {
    var shelfCount: Int = 0
}
```
`NotchHost.swift`의 프로토콜에 추가:
```swift
    func setShelfBadge(_ count: Int)
```
`NotchWindowController.swift`: 프로퍼티 `let badge = NotchBadge()` 추가, `makeRootView()`의 `NotchRootView(...)` 호출에 `badge: badge` 인자 추가, `// MARK: NotchHost` 아래에:
```swift
    func setShelfBadge(_ count: Int) { badge.shelfCount = count }
```

- [ ] **Step 2: 루트 뷰 날개**

`NotchRootView.swift`: 프로퍼티 `let badge: NotchBadge` 추가(`notch` 다음). `shape` 계산 프로퍼티를 다음으로 교체:
```swift
    private var shape: some View {
        NotchShape(bottomRadius: isOpen ? Constants.panelCornerRadius : Constants.collapsedCornerRadius)
            .fill(Color.black)
            .overlay(alignment: .trailing) {
                // 접힌 상태 오른쪽 날개: 셸프 개수. 검은 불투명이라 alpha-0 규칙과 무관.
                if !isOpen, badge.shelfCount > 0, showsCollapsedVisuals {
                    Text("\(badge.shelfCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: Constants.shelfWingWidth, height: notchHeight)
                        .background(NotchShape(bottomRadius: Constants.collapsedCornerRadius).fill(Color.black))
                        .offset(x: Constants.shelfWingWidth)
                }
            }
    }
```
(`showsCollapsedVisuals`는 P1 수정 웨이브에서 추가된 프로퍼티. 날개는 노치 오른쪽 바깥에 붙으며 윈도우 폭 560 안에 있다. 탭 영역(`contentShape`)은 노치만 유지.)

- [ ] **Step 3: 빌드·테스트** — rc=0, 31개 통과. 앱 실행 후 접힌 상태에 날개가 없어야 한다(개수 0).

- [ ] **Step 4: 커밋**

```bash
git add Sources/NotchWindow
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: 접힌 노치 오른쪽 날개에 셸프 개수 배지

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: AirDropService + QuickLookController

**Files:**
- Create: `Sources/Shelf/AirDropService.swift`, `Sources/Shelf/QuickLookController.swift`

**Interfaces:**
- Produces:
  - `@MainActor final class AirDropService: NSObject, NSSharingServiceDelegate { static let shared; func canSend(urls: [URL]) -> Bool; func send(urls: [URL], from window: NSWindow) }`
  - `@MainActor final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate { static let shared; func preview(_ url: URL) }`

- [ ] **Step 1: AirDropService**

`Sources/Shelf/AirDropService.swift`:
```swift
import AppKit
import os

/// AirDrop 전송. 공개 API(NSSharingService)만 쓰며 추가 entitlement가 없다.
/// LSUIElement 앱은 호출 전 activate가 필요하고, 시트 앵커로 노치 패널을 돌려준다.
@MainActor
final class AirDropService: NSObject, NSSharingServiceDelegate {
    static let shared = AirDropService()
    private weak var anchorWindow: NSWindow?
    private let logger = Logger(subsystem: "com.holyshine11.opennotch", category: "airdrop")

    private var service: NSSharingService? { NSSharingService(named: .sendViaAirDrop) }

    func canSend(urls: [URL]) -> Bool {
        guard !urls.isEmpty, let service else { return false }
        return service.canPerform(withItems: urls)
    }

    func send(urls: [URL], from window: NSWindow) {
        guard let service else { return }
        anchorWindow = window
        service.delegate = self
        NSApp.activate(ignoringOtherApps: true)
        service.perform(withItems: urls)
    }

    // MARK: NSSharingServiceDelegate

    nonisolated func sharingService(_ sharingService: NSSharingService, sourceWindowForShareItems items: [Any], sharingContentScope: UnsafeMutablePointer<NSSharingService.SharingContentScope>) -> NSWindow? {
        MainActor.assumeIsolated { anchorWindow }
    }

    nonisolated func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        MainActor.assumeIsolated { logger.error("airdrop failed: \(error.localizedDescription, privacy: .public)") }
    }
}
```

- [ ] **Step 2: QuickLookController**

`Sources/Shelf/QuickLookController.swift`:
```swift
import AppKit
import Quartz

/// 셸프 항목 미리보기. 셸프가 access를 유지하는 URL만 받는다.
@MainActor
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookController()
    private var current: URL?

    func preview(_ url: URL) {
        current = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.reloadData()
    }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { current == nil ? 0 : 1 }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated { current as NSURL? }
    }
}
```
(`QLPreviewPanel` 데이터소스 메서드는 `nonisolated`로 선언하고 `MainActor.assumeIsolated`로 상태를 읽는다 — 패널은 메인 스레드에서 호출한다. 컴파일러가 서명을 거부하면 `@preconcurrency import Quartz`를 쓰고 리포트에 남긴다.)

- [ ] **Step 3: 빌드** — rc=0(테스트 31개 유지). 두 클래스는 아직 호출부가 없다.

- [ ] **Step 4: 커밋**

```bash
git add Sources/Shelf
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: AirDropService·QuickLookController (공개 API 래퍼)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: ShelfView + 드롭/페인 배선 — 셸프가 실제로 동작한다

**Files:**
- Create: `Sources/Shelf/ShelfView.swift`
- Modify: `Sources/App/AppDelegate.swift`

**Interfaces:**
- Consumes: `ShelfStore`, `AirDropService.shared`, `QuickLookController.shared`, `NotchHost`(환경값), `NotchWindowController.onDropURLs/paneProvider/setShelfBadge/showToast/panel`
- Produces: `struct ShelfView: View { let store: ShelfStore }`

- [ ] **Step 1: ShelfView**

`Sources/Shelf/ShelfView.swift`:
```swift
import AppKit
import QuickLookThumbnailing
import SwiftUI

/// 셸프 페인: 썸네일 그리드, 우클릭 메뉴(AirDrop / Finder에서 보기 / 미리보기 / 제거), 드래그 아웃.
struct ShelfView: View {
    let store: ShelfStore
    @Environment(\.notchHost) private var host

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: Constants.shelfGridColumns)

    var body: some View {
        Group {
            if store.items.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down").font(.title2)
                    Text("Drop files here").font(.caption)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(store.items) { item in
                            ShelfItemView(item: item, url: store.url(for: item.id))
                                .contextMenu { menu(for: item) }
                                .onDrag {
                                    host?.resetIdle()
                                    guard let url = store.url(for: item.id) else { return NSItemProvider() }
                                    return NSItemProvider(contentsOf: url) ?? NSItemProvider()
                                }
                        }
                    }
                    .padding(4)
                }
            }
        }
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder private func menu(for item: ShelfItem) -> some View {
        Button("AirDrop") {
            guard let url = store.url(for: item.id), let host else { return }
            if AirDropService.shared.canSend(urls: [url]) {
                AirDropService.shared.send(urls: [url], from: host.panel)
                host.collapse()
            } else {
                host.showToast(String(localized: "AirDrop is unavailable. Turn on Wi‑Fi and Bluetooth."), action: nil)
            }
        }
        Button("Reveal in Finder") {
            if let url = store.url(for: item.id) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        }
        Button("Quick Look") {
            if let url = store.url(for: item.id) { QuickLookController.shared.preview(url) }
        }
        Divider()
        Button("Remove", role: .destructive) { store.remove(id: item.id) }
    }
}

/// 썸네일 + 이름. 썸네일은 QuickLookThumbnailing, 실패 시 파일 아이콘.
struct ShelfItemView: View {
    let item: ShelfItem
    let url: URL?
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 2) {
            Group {
                if let image {
                    Image(nsImage: image).resizable().scaledToFit()
                } else {
                    Image(systemName: "doc").font(.title2).foregroundStyle(.secondary)
                }
            }
            .frame(width: Constants.shelfThumbnailSize, height: Constants.shelfThumbnailSize)
            Text(item.displayName).font(.system(size: 9)).lineLimit(1).truncationMode(.middle)
        }
        .frame(maxWidth: .infinity)
        .help(item.displayName)
        .task(id: url) { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        guard let url else { return }
        let size = CGSize(width: Constants.shelfThumbnailSize, height: Constants.shelfThumbnailSize)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 2, representationTypes: .thumbnail)
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            image = rep.nsImage
        } else {
            image = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
}
```

- [ ] **Step 2: AppDelegate 배선**

`Sources/App/AppDelegate.swift`: 프로퍼티 `private var shelfStore: ShelfStore?` 추가. `applicationDidFinishLaunching`에서 임시 `controller.onDropURLs = { ... 토스트 ... }` 블록을 다음으로 교체(`controller.show()` 앞):
```swift
        let shelf = ShelfStore()
        shelfStore = shelf
        shelf.onCountChanged = { [weak controller] count in controller?.setShelfBadge(count) }
        controller.setShelfBadge(shelf.items.count)
        controller.paneProvider = { (media: nil, shelf: AnyView(ShelfView(store: shelf)), clipboard: nil) }
        controller.onDropURLs = { [weak controller, weak shelf] urls, zone in
            guard let controller, let shelf else { return false }
            switch zone {
            case .shelf:
                shelf.add(urls: urls)
                return true
            case .airdrop:
                guard AirDropService.shared.canSend(urls: urls) else {
                    controller.showToast(String(localized: "AirDrop is unavailable. Turn on Wi‑Fi and Bluetooth."), action: nil)
                    return false
                }
                AirDropService.shared.send(urls: urls, from: controller.panel)
                return true
            }
        }
```
(`paneProvider`는 `show()` 전에 설정하므로 `notch.rect == .zero` 가드에 걸려 즉시 재구성하지 않고, `show()`의 `reposition(force: true)`가 한 번만 구성한다. 다른 모듈(P3·P4)은 같은 클로저에 페인을 추가한다.)

- [ ] **Step 3: 빌드·테스트·실기 확인**

rc=0, 31개 통과. 앱 실행 후: Finder에서 파일 2개를 노치로 끌어 오른쪽 존에 놓기 → 펼친 패널 오른쪽 셸프에 썸네일 2개, 접으면 날개 배지 "2". 우클릭 → Finder에서 보기(Finder가 파일 선택), Quick Look(미리보기 패널), 제거. 앱 종료 후 재실행 → 셸프 유지. 파일을 왼쪽 존에 놓기 → AirDrop 선택창(Wi‑Fi/BT 켜진 경우) 또는 토스트 후 패널 유지(꺼진 경우). 셸프 항목을 데스크톱으로 드래그 → Finder가 원본 위치의 파일을 복사/이동(원본은 셸프가 건드리지 않음).
Orca(computer-use)로 자동화 가능한 부분: 앱 상태 트리에서 셸프 그리드·배지 확인, 우클릭 메뉴 항목 확인. 앱 간 드래그는 사람이 확인.

- [ ] **Step 4: 커밋**

```bash
git add Sources/Shelf/ShelfView.swift Sources/App/AppDelegate.swift
git -c user.name="holyshine11" -c user.email="anodpark@gmail.com" commit -m "feat: 셸프 페인(썸네일·우클릭 메뉴·드래그 아웃)과 드롭/AirDrop 배선

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## P2 완료 기준

- 테스트 31개 통과(ShelfStoreTests 7 추가).
- 드롭 → 셸프 보관 → 재시작 후 유지 → AirDrop/Finder에서 보기/Quick Look/제거/드래그 아웃 동작. 접힌 상태 배지 표시.
- `scripts/review-check.sh` OK(entitlements 3개 그대로).
- 다음 계획: P3 클립보드(`paneProvider.clipboard`, `NotchHost.setWantsKey`, 검색창 overlay), P4 미디어(`paneProvider.media`, entitlements 추가, NoMedia 구성 빌드 가능하게).
