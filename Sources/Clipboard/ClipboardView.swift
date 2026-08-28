import AppKit
import SwiftUI

/// 하단 44pt 행: 칩 5개 + ▸(전체 목록) + 검색. 펼치면 위쪽 두 칸을 덮는 overlay 목록(패널 크기 불변).
struct ClipboardView: View {
    let store: ClipboardStore
    let monitor: ClipboardMonitor
    @Environment(\.notchHost) private var host
    @State private var expanded = false
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            if store.pasteboardBlocked {
                blockedNotice
            } else if !monitor.isEnabled {
                Button("Enable clipboard history") { monitor.enableWithUserAction() }.buttonStyle(.bordered)
                Spacer()
            } else {
                chips
                Button { expanded.toggle() } label: { Image(systemName: expanded ? "chevron.down" : "chevron.right") }
                    .buttonStyle(.borderless).help("Show all")
                TextField("Search", text: $query)
                    .textFieldStyle(.roundedBorder).frame(width: 120)
                    .focused($searchFocused)
                    .onChange(of: searchFocused) { _, focused in
                        host?.setWantsKey(focused)
                        if focused { expanded = true }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .bottom) {
            if expanded {
                fullList
                    .frame(height: Constants.clipboardListHeight)
                    .background(Color.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 10))
                    .offset(y: -(Constants.clipboardListHeight + 8))   // 행 위로 올려 상단 두 칸을 덮는다
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: expanded)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.items.prefix(Constants.clipboardChipCount)) { item in
                    chip(item)
                }
                if store.items.isEmpty {
                    Text("Copy something to see it here").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chip(_ item: ClipItem) -> some View {
        Button { copy(item) } label: {
            Label(item.title, systemImage: icon(for: item.kind))
                .font(.caption).lineLimit(1)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.white.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu { Button("Delete", role: .destructive) { store.remove(id: item.id) } }
    }

    private var fullList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(store.search(query)) { item in
                    Button { copy(item) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: icon(for: item.kind)).frame(width: 14)
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
            }
            .padding(4)
        }
    }

    private var blockedNotice: some View {
        HStack(spacing: 8) {
            Text("Allow OpenNotch to read the clipboard in System Settings").font(.caption)
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
