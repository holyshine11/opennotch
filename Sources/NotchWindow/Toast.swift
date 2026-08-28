import SwiftUI
import Observation

@MainActor
@Observable
final class ToastCenter {
    private(set) var message: String?
    private(set) var action: ToastAction?
    private var hideTask: Task<Void, Never>?

    func show(_ text: String, action: ToastAction? = nil) {
        message = text
        self.action = action
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.toastDuration))
            guard !Task.isCancelled else { return }
            self?.message = nil
            self?.action = nil
        }
    }
}

struct ToastView: View {
    let center: ToastCenter

    var body: some View {
        if let message = center.message {
            HStack(spacing: 8) {
                Text(message).font(.caption).lineLimit(1)
                if let action = center.action {
                    Button(action.title) { action.handler() }
                        .buttonStyle(.link).font(.caption)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
