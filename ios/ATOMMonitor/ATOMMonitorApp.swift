import SwiftUI

@main
struct ATOMMonitorApp: App {
    static let defaultServerURL = "https://atom.example.net/"

    private var repository: any StationRepository {
        if ProcessInfo.processInfo.arguments.contains("--demo-mode") {
            return FixtureStationRepository(resourceName: "demo-stations")
        }
        return ConfigurableAPIStationRepository()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(repository: repository)
        }
    }
}
