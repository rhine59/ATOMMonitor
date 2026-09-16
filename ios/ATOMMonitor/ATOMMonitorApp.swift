import SwiftUI

@main
struct ATOMMonitorApp: App {
    private let defaultServerURL = URL(string: "http://192.168.1.99:8088/")!

    private var repository: any StationRepository {
        if ProcessInfo.processInfo.arguments.contains("--demo-mode") {
            return FixtureStationRepository(resourceName: "demo-stations")
        }
        return APIStationRepository(baseURL: defaultServerURL)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(repository: repository)
        }
    }
}
