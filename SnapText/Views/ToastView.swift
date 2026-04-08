import SwiftUI

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let icon: String
    let tint: Color

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isShowing {
                    HStack(spacing: 8) {
                        Image(systemName: icon)
                        Text(message)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(tint.gradient)
                            .shadow(color: tint.opacity(0.3), radius: 8, y: 4)
                    )
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.spring(duration: 0.3)) { isShowing = false }
                        }
                    }
                }
            }
            .animation(.spring(duration: 0.3), value: isShowing)
    }
}

extension View {
    func toast(isShowing: Binding<Bool>, message: String, icon: String = "checkmark.circle.fill", tint: Color = .green) -> some View {
        modifier(ToastModifier(isShowing: isShowing, message: message, icon: icon, tint: tint))
    }
}

/// Haptic helper
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
