import SwiftUI

// MARK: - Pulse Animation for Live Indicator
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(
                .easeInOut(duration: 0.8)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Control Button
struct ControlButton<MenuContent: View>: View {
    let title: String
    let icon: String
    let color: Color
    var badge: String? = nil
    let action: () async -> Void
    let menuContent: (() -> MenuContent)?

    init(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () async -> Void) where MenuContent == EmptyView {
        self.title = title
        self.icon = icon
        self.color = color
        self.badge = badge
        self.action = action
        self.menuContent = nil
    }

    init(title: String, icon: String, color: Color, badge: String? = nil, action: @escaping () async -> Void, @ViewBuilder menu: @escaping () -> MenuContent) {
        self.title = title
        self.icon = icon
        self.color = color
        self.badge = badge
        self.action = action
        self.menuContent = menu
    }

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                // Badge inside button at top right corner
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color)
                        .clipShape(Capsule())
                        .padding(.top, 4)
                        .padding(.trailing, 4)
                }
            }
        }
        .if(menuContent != nil) { view in
            view.contextMenu {
                if let menuContent = menuContent {
                    menuContent()
                }
            }
        }
    }
}

// Helper extension for conditional modifiers
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Dock Action Button
struct DockActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: 60, maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
