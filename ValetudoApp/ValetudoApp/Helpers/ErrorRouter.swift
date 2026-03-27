import SwiftUI

@MainActor
final class ErrorRouter: ObservableObject {
    @Published var currentError: Error?
    var retryAction: (() async -> Void)?

    func show(_ error: Error, retry: (() async -> Void)? = nil) {
        currentError = error
        retryAction = retry
    }

    func dismiss() {
        currentError = nil
        retryAction = nil
    }
}

extension View {
    func withErrorAlert(router: ErrorRouter) -> some View {
        self.alert(
            String(localized: "error.title"),
            isPresented: Binding(
                get: { router.currentError != nil },
                set: { if !$0 { router.dismiss() } }
            ),
            presenting: router.currentError
        ) { _ in
            if router.retryAction != nil {
                Button(String(localized: "error.retry")) {
                    Task { await router.retryAction?() }
                    router.dismiss()
                }
            }
            Button("OK", role: .cancel) { router.dismiss() }
        } message: { error in
            Text((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
