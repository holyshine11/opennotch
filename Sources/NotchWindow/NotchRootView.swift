import SwiftUI

/// 패널 콘텐츠. 좌표계는 SwiftUI(원점 좌상단), 크기 = 패널 frame.
struct NotchRootView: View {
    let viewModel: NotchViewModel
    let toast: ToastCenter
    let notch: NotchRect          // 화면 좌표 — 여기서는 크기만 쓴다
    /// 모듈 뷰는 P2~P4에서 주입된다. nil이면 자리 표시.
    var mediaPane: AnyView?
    var shelfPane: AnyView?
    var clipboardPane: AnyView?

    private var isOpen: Bool { viewModel.state != .collapsed }
    private var notchHeight: CGFloat { notch.rect.height }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: Constants.panelTopOverhang)
            ZStack(alignment: .top) {
                shape
                if isOpen {
                    content
                        .frame(width: Constants.panelWidth, height: notchHeight + Constants.panelBodyHeight)
                        .transition(.opacity)
                }
            }
            .frame(width: isOpen ? Constants.panelWidth : notch.rect.width,
                   height: isOpen ? notchHeight + Constants.panelBodyHeight : notchHeight)
            .contentShape(NotchShape(bottomRadius: isOpen ? Constants.panelCornerRadius : 8))
            .onTapGesture { if !isOpen { viewModel.send(.clickNotch) } }
            .onHover { inside in viewModel.send(inside ? .hoverEnter : .hoverExit) }
            Spacer(minLength: 0)
        }
        .frame(width: Constants.panelWidth,
               height: notchHeight + Constants.panelBodyHeight + Constants.panelTopOverhang,
               alignment: .top)
        .animation(.spring(duration: Constants.expandAnimationDuration), value: viewModel.state)
        .overlay(alignment: .bottom) {
            ToastView(center: toast).padding(.bottom, 8)
                .animation(.easeInOut(duration: 0.2), value: toast.message)
        }
    }

    private var shape: some View {
        NotchShape(bottomRadius: isOpen ? Constants.panelCornerRadius : 8)
            .fill(Color.black)
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)   // 노치 밴드: 펼친 상태에서 다시 클릭하면 접힌다
                .contentShape(Rectangle())
                .onTapGesture { viewModel.send(.clickNotch) }
            if viewModel.state == .dropTargeting {
                dropZones
            } else {
                panes
            }
        }
        .foregroundStyle(.white)
    }

    private var panes: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                (mediaPane ?? AnyView(placeholder("Media")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                (shelfPane ?? AnyView(placeholder("Shelf")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            (clipboardPane ?? AnyView(placeholder("Clipboard")))
                .frame(height: 44)
        }
        .padding(12)
    }

    private var dropZones: some View {
        HStack(spacing: 8) {
            dropZoneLabel("AirDrop", systemImage: "airplayaudio")
            dropZoneLabel("Keep in Shelf", systemImage: "tray.and.arrow.down")
        }
        .padding(12)
    }

    private func dropZoneLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage).font(.title)
            Text(title).font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func placeholder(_ title: LocalizedStringKey) -> some View {
        Text(title).font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}
