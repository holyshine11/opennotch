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
