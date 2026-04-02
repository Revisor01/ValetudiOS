import BackgroundTasks
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // BGTask-Handler registrieren — MUSS in didFinishLaunchingWithOptions passieren
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundMonitorService.taskIdentifier,
            using: nil
        ) { task in
            BackgroundMonitorService.shared.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }

        // Initiales Scheduling (fuer frische Installationen die noch nie in den Hintergrund gingen)
        BackgroundMonitorService.shared.scheduleBackgroundRefresh()

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
    @Environment(\.scenePhase) private var scenePhase
    @State private var robotManager = RobotManager()
    @State private var errorRouter = ErrorRouter()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environment(robotManager)
                    .environment(errorRouter)
                    .withErrorAlert(router: errorRouter)
                    .onAppear {
                        NotificationService.robotManagerRef = robotManager
                    }
            } else {
                OnboardingView()
                    .environment(robotManager)
                    .environment(errorRouter)
                    .withErrorAlert(router: errorRouter)
                    .onAppear {
                        NotificationService.robotManagerRef = robotManager
                    }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundMonitorService.shared.scheduleBackgroundRefresh()
            }
        }
    }
}
