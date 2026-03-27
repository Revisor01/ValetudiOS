import SwiftUI

@main
struct ValetudoApp: App {
    @StateObject private var robotManager = RobotManager()
    @StateObject private var errorRouter = ErrorRouter()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(robotManager)
                    .environmentObject(errorRouter)
                    .withErrorAlert(router: errorRouter)
            } else {
                OnboardingView()
                    .environmentObject(robotManager)
                    .environmentObject(errorRouter)
                    .withErrorAlert(router: errorRouter)
            }
        }
    }
}
