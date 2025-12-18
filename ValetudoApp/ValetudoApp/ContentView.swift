import SwiftUI

struct ContentView: View {
    @EnvironmentObject var robotManager: RobotManager
    @State private var selectedTab = 0

    private var primaryRobot: RobotConfig? {
        robotManager.robots.first
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RobotListView()
            }
            .tabItem {
                Label(String(localized: "tab.robots"), systemImage: "house.fill")
            }
            .tag(0)

            // Map Tab - shows map of primary robot
            if let robot = primaryRobot {
                MapTabView(robot: robot)
                    .tabItem {
                        Label(String(localized: "tab.map"), systemImage: "map.fill")
                    }
                    .tag(1)
            }

            SettingsView()
                .tabItem {
                    Label(String(localized: "tab.settings"), systemImage: "gearshape.fill")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RobotManager())
}
