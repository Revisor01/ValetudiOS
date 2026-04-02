import SwiftUI
import StoreKit

struct SupportView: View {
    @Bindable private var supportManager = SupportManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.pink)

                        Text("support.header")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("support.message")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)

                    // Support Options
                    if supportManager.isLoading {
                        ProgressView()
                            .padding(40)
                    } else if supportManager.products.isEmpty {
                        ContentUnavailableView(
                            "support.unavailable",
                            systemImage: "exclamationmark.triangle",
                            description: Text("support.unavailable.description")
                        )
                    } else {
                        VStack(spacing: 12) {
                            ForEach(supportManager.products, id: \.id) { product in
                                SupportButton(product: product) {
                                    Task {
                                        await supportManager.purchase(product)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Footer
                    Text("support.footer")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("support.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.done") { dismiss() }
                }
            }
            .task {
                await supportManager.loadProducts()
            }
            .alert("support.error", isPresented: .init(
                get: { supportManager.purchaseError != nil },
                set: { if !$0 { supportManager.purchaseError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(supportManager.purchaseError ?? "")
            }
            .alert("support.thankyou.title", isPresented: $supportManager.showThankYou) {
                Button("button.done") { }
            } message: {
                Text("support.thankyou.message")
            }
        }
    }
}

struct SupportButton: View {
    let product: Product
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(product.tierColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: product.symbolName)
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.supportName)
                        .font(.headline)
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
