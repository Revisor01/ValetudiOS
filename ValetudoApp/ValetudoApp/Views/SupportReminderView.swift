import SwiftUI

struct SupportReminderView: View {
    @Binding var isPresented: Bool
    @State private var showSupportView = false

    private let supportManager = SupportManager.shared

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.pink)

                Text("support.reminder.title")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }

            // Message
            Text("support.reminder.message")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Buttons
            VStack(spacing: 12) {
                Button {
                    supportManager.markReminderShown()
                    isPresented = false
                    showSupportView = true
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("support.reminder.support")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    supportManager.markAlreadySupported()
                    isPresented = false
                } label: {
                    Text("support.reminder.already")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    supportManager.markReminderShown()
                    isPresented = false
                } label: {
                    Text("support.reminder.later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 20)
        .padding(32)
        .sheet(isPresented: $showSupportView) {
            SupportView()
        }
    }
}

struct SupportReminderOverlay: ViewModifier {
    @State private var showReminder = false
    private let supportManager = SupportManager.shared

    func body(content: Content) -> some View {
        content
            .onAppear {
                supportManager.incrementLaunchCount()
                if supportManager.shouldShowReminder {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.spring(duration: 0.4)) {
                            showReminder = true
                        }
                    }
                }
            }
            .overlay {
                if showReminder {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .onTapGesture {
                                // Don't dismiss on background tap
                            }

                        SupportReminderView(isPresented: $showReminder)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
    }
}

extension View {
    func supportReminder() -> some View {
        modifier(SupportReminderOverlay())
    }
}
