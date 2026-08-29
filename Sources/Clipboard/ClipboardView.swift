import AppKit
import SwiftUI

/// 클립보드 탭: 검색 + 전체 삭제 행, 아래에 히스토리 목록. 항목 클릭 = 복사, 우클릭 = 삭제.
struct ClipboardView: View {
    let store: ClipboardStore
    let monitor: ClipboardMonitor
    @Environment(\.notchHost) private var host
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        Group {
            if store.pasteboardBlocked {
                blockedNotice
            } else if !monitor.isEnabled {
                Button("Enable clipboard history") { monitor.enableWithUserAction() }.buttonStyle(.bordered)
            } else {
                VStack(spacing: 4) {
                    header
                    list
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(6)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private var header: some View {
        HStack(spacing: 6) {
            TextField("Search", text: $query)
                .textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onChange(of: searchFocused) { _, focused in host?.setWantsKey(focused) }
            Text("\(store.items.count)").font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            // 되돌릴 수 없는 동작이라 메뉴 한 단계 뒤에 둔다(오클릭 방지).
            Menu {
                Button("Clear history", role: .destructive) { store.removeAll() }
            } label: {
                Image(systemName: "trash")
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .disabled(store.items.isEmpty)
            .help("Clear history")
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                let items = store.search(query)
                ForEach(items) { item in
                    Button { copy(item) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: icon(for: item.kind)).frame(width: 14).foregroundStyle(.secondary)
                            Text(item.title).lineLimit(1)
                            Spacer()
                            Text(item.createdAt, style: .time).foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu { Button("Delete", role: .destructive) { store.remove(id: item.id) } }
                }
                if items.isEmpty {
                    Text("Copy something to see it here").font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.top, 12)
                }
            }
        }
    }

    private var blockedNotice: some View {
        VStack(spacing: 6) {
            Text("Allow OpenNotch to read the clipboard in System Settings").font(.caption).multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: Constants.pasteboardPrivacySettingsURL) { NSWorkspace.shared.open(url) }
            }
            .buttonStyle(.link).font(.caption)
        }
    }

    private func copy(_ item: ClipItem) {
        store.write(item)
        host?.showToast(String(localized: "Copied — press ⌘V to paste"), action: nil)
        host?.resetIdle()
    }

    private func icon(for kind: ClipKind) -> String {
        switch kind {
        case .text: "text.alignleft"
        case .url: "link"
        case .image: "photo"
        case .files: "doc"
        }
    }
}
