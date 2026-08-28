import SwiftUI

/// 패널 콘텐츠. 좌표계는 SwiftUI(원점 좌상단), 크기 = 패널 frame.
struct NotchRootView: View {
    let viewModel: NotchViewModel
    let toast: ToastCenter
    let notch: NotchRect          // 화면 좌표 — 여기서는 크기만 쓴다
    let badge: NotchBadge
    /// 가상 노치 표시가 꺼졌을 때 접힌 검은 모양과 드래그 진입 밴드를 숨긴다(§3.1). 펼침에는 영향 없다.
    var hideCollapsedShape: Bool = false
    /// 모듈 뷰는 P2~P4에서 주입된다. nil이면 자리 표시.
    var mediaPane: AnyView?
    var shelfPane: AnyView?
    var clipboardPane: AnyView?

    @Environment(\.openSettings) private var openSettings
    @Environment(\.notchHost) private var host

    private var isOpen: Bool { viewModel.state != .collapsed }
    private var notchHeight: CGFloat { notch.rect.height }
    private var showsCollapsedVisuals: Bool { isOpen || !hideCollapsedShape }

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
            .contentShape(NotchShape(bottomRadius: isOpen ? Constants.panelCornerRadius : Constants.collapsedCornerRadius))
            .allowsHitTesting(showsCollapsedVisuals)
            .onTapGesture(coordinateSpace: .local) { location in
                guard showsCollapsedVisuals else { return }
                if !isOpen || location.y <= notchHeight { viewModel.send(.clickNotch) }
            }
            .onHover { inside in
                guard showsCollapsedVisuals else { return }
                viewModel.send(inside ? .hoverEnter : .hoverExit)
            }
            Spacer(minLength: 0)
        }
        .frame(width: Constants.panelWidth,
               height: notchHeight + Constants.panelBodyHeight + Constants.panelTopOverhang,
               alignment: .top)
        .onChange(of: viewModel.state) { _, newState in
            if newState == .collapsed { host?.setWantsKey(false) }
        }
        .overlay(alignment: .top) {
            // 접힌 상태 드래그 진입 영역: 노치 좌우 32pt, 노치 높이만. alpha 0.001이라 WindowServer가 드래그를 우리 창에 전달한다.
            // 가상 노치가 꺼지면(hideCollapsedShape) 진입 밴드도 함께 숨긴다 — §3.1 "끄면 메뉴바 아이콘·단축키로만 연다".
            if !isOpen && showsCollapsedVisuals {
                Color.black.opacity(0.001)
                    .frame(width: notch.rect.width + Constants.dragEnterMargin * 2, height: notchHeight)
                    .padding(.top, Constants.panelTopOverhang)
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: Constants.expandAnimationDuration), value: viewModel.state)
        .overlay(alignment: .bottom) {
            if isOpen {
                ToastView(center: toast).padding(.bottom, 8)
                    .animation(.easeInOut(duration: 0.2), value: toast.message)
            }
        }
    }

    private var shape: some View {
        NotchShape(bottomRadius: isOpen ? Constants.panelCornerRadius : Constants.collapsedCornerRadius)
            .fill(Color.black)
            .opacity(showsCollapsedVisuals ? 1 : 0)
            .overlay(alignment: .trailing) {
                // 접힌 상태 오른쪽 날개: 셸프 개수. 검은 불투명이라 alpha-0 규칙과 무관.
                if !isOpen, badge.shelfCount > 0, showsCollapsedVisuals {
                    Text("\(badge.shelfCount)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: Constants.shelfWingWidth, height: notchHeight)
                        .background(NotchShape(bottomRadius: Constants.collapsedCornerRadius).fill(Color.black))
                        .offset(x: Constants.shelfWingWidth)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.send(.clickNotch) }
                }
            }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchHeight)   // 노치 밴드: 펼친 상태에서 다시 클릭하면 접힌다(부모 ZStack의 탭 제스처가 처리)
            if viewModel.state == .dropTargeting {
                dropZones
            } else {
                panes
            }
        }
        .foregroundStyle(.white)
        .simultaneousGesture(TapGesture().onEnded { viewModel.resetIdle() })
        .onContinuousHover { phase in if case .active = phase { viewModel.resetIdle() } }
    }

    private var panes: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                (mediaPane ?? AnyView(placeholder("Media")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                (shelfPane ?? AnyView(placeholder("Shelf")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack(spacing: 8) {
                (clipboardPane ?? AnyView(placeholder("Clipboard")))
                    .frame(height: 44)
                gearMenu
            }
        }
        .padding(12)
    }

    private var gearMenu: some View {
        Menu {
            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            Button("About OpenNotch") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Divider()
            Button("Quit OpenNotch") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "gearshape")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Settings")
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
