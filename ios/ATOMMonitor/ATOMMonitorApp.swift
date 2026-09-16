import SwiftUI

@main
struct ATOMMonitorApp: App {
    // Change this to the Synology's LAN IP address or DNS name.
    // A Settings-editable server address is the next UI refinement.
    private let serverURL = URL(string: "http://192.168.1.2:8080/")!

    var body: some Scene {
        WindowGroup {
            ContentView(repository: APIStationRepository(baseURL: serverURL))
        }
    }
}
