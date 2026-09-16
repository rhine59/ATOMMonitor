import SwiftUI

@main
struct ATOMMonitorApp: App {
    private let defaultServerURL = URL(string: "http://192.168.1.99:8080/")!

    var body: some Scene {
        WindowGroup {
            ContentView(repository: APIStationRepository(baseURL: defaultServerURL))
        }
    }
}
