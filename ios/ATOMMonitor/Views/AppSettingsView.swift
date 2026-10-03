import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var store: StationStore
    @AppStorage(ServerConfiguration.key) private var server = ATOMMonitorApp.defaultServerURL
    @AppStorage("refreshIntervalMinutes") private var refreshMinutes = 5
    @AppStorage("inactiveAfterDays") private var inactiveAfterDays = 2
    @AppStorage("highlightBackLevelSoftware") private var highlightBackLevelSoftware = false
    @State private var testing = false
    @State private var connectionResult: String?

    var body: some View {
        Form {
            Section("Server") {
                TextField("Server address", text: $server)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button {
                    Task { await testConnection() }
                } label: {
                    if testing { ProgressView() } else { Text("Test Connection") }
                }.disabled(testing)
                if let connectionResult { Text(connectionResult).font(.caption) }
            }
            Section("Refresh") {
                Stepper("Every \(refreshMinutes) minutes", value: $refreshMinutes, in: 1...10)
            }
            Section("Station status") {
                Stepper("Inactive after \(inactiveAfterDays) days", value: $inactiveAfterDays, in: 1...30)
                    .onChange(of: inactiveAfterDays) { _, _ in store.inactiveThresholdChanged() }
                Text("Stations not seen for this many days are shown Inactive. Default 2 days.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Highlight back-level software", isOn: $highlightBackLevelSoftware)
                    .onChange(of: highlightBackLevelSoftware) { _, _ in store.backLevelPreferenceChanged() }
                Text("Off by default. When enabled, otherwise Healthy stations running an older reported PilotAware version are shown using the configured back-level colour. Operational status always takes precedence.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
    }

    @MainActor private func testConnection() async {
        testing = true; defer { testing = false }
        do {
            let result = try await APIStationRepository.testConnection(to: server)
            connectionResult = result.confirmedStations.map { "Connection OK • \($0) confirmed stations" } ?? "Connection OK"
        } catch { connectionResult = "Connection failed: \(error.localizedDescription)" }
    }
}
