import SwiftUI

@main
struct ATOMMonitorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(repository: FixtureStationRepository())
        }
    }
}
