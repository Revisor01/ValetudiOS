import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        Task { @MainActor in
            await NotificationService.shared.handleNotificationResponse(actionIdentifier: actionIdentifier)
        }
        // completionHandler sofort aufrufen — Task laeuft im Hintergrund
        completionHandler()
    }
}

@main
struct ValetudoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                    .onAppear {
                        NotificationService.robotManagerRef = robotManager
                    }
            } else {
                OnboardingView()
                    .environmentObject(robotManager)
                    .environmentObject(errorRouter)
                    .withErrorAlert(router: errorRouter)
                    .onAppear {
                        NotificationService.robotManagerRef = robotManager
                    }
            }
        }
    }
}
