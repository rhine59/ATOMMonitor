import SwiftUI

struct ContentView: View {
    @StateObject private var store: StationStore
    @AppStorage("homeStationID") private var homeStationID = ""
    @AppStorage("favouriteStationIDs") private var favouriteStationIDs = ""

    init(repository: any StationRepository) {
        _store = StateObject(wrappedValue: StationStore(repository: repository))
    }

    var body: some View {
        TabView {
            NavigationStack { StationMapView(store: store, homeStationID: homeStationID, favouriteStationIDs: $favouriteStationIDs) }
                .tabItem { Label("Map", systemImage: "map") }

            NavigationStack { StationListView(store: store, favouriteStationIDs: $favouriteStationIDs) }
                .tabItem { Label("Stations", systemImage: "list.bullet") }

            NavigationStack { FavouritesView(store: store, favouriteStationIDs: $favouriteStationIDs) }
                .tabItem { Label("Favourites", systemImage: "star") }

            NavigationStack { ReportView(store: store) }
                .tabItem { Label("Report", systemImage: "chart.bar") }

            NavigationStack { AppSettingsView(store: store) }
                .tabItem { Label("Settings", systemImage: "gearshape") }

            NavigationStack { HelpView() }
                .tabItem { Label("Help", systemImage: "questionmark.circle") }

            NavigationStack { FeedbackView() }
                .tabItem { Label("Feedback", systemImage: "star.bubble") }

            NavigationStack { AboutView() }
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .task { await store.load() }
    }
}

private struct FavouritesView: View {
    @ObservedObject var store: StationStore
    @Binding var favouriteStationIDs: String
    private var favouriteIDs: Set<String> { Set(favouriteStationIDs.split(separator: ",").map(String.init)) }
    private var favouriteStations: [ATOMStation] { store.stations.filter { favouriteIDs.contains($0.id) } }

    var body: some View {
        List {
            if favouriteStations.isEmpty {
                ContentUnavailableView("No Favourites", systemImage: "star", description: Text("Mark a ground station as a favourite from Station Detail."))
            } else {
                ForEach(favouriteStations) { station in
                    NavigationLink {
                        StationDetailView(
                            station: station,
                            displayHealth: store.displayHealth(for: station),
                            isBackLevelSoftware: store.isBackLevelSoftware(station)
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(station.name).font(.headline)
                            Text("\(store.displayHealth(for: station).title) • \(station.pilotAwareVersion ?? "Version not reported")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Favourites")
    }
}

private struct HelpView: View {
    var body: some View {
        List {
            Section("What ATOM Monitor does") {
                Text("ATOM Monitor monitors the operational health and technical status of PilotAware ATOM ground stations. It does not display or record aircraft movements, tracks or aircraft identities.")
            }

            Section("Map and Stations") {
                Text("Map and Stations use the same station dataset and the same Status and PilotAware-version filters. Find searches station names. An empty filter means all values are included.")
                Text("The Map Home control centres on the configured Home ATOM station. Device location is not required. With filters active, the map focuses on the matching station nearest Home; if Home is not configured it falls back to the UK view.")
                Text("The status line shows the last successful update and station count. If the network is unavailable, the most recent cached station data remains available and No Network is shown.")
            }

            Section("Station status") {
                Text("Healthy means a recent PilotAware heartbeat has been received with no current operational warning. Warning means the station is reporting but its heartbeat is becoming stale or telemetry indicates a warning. No recent heartbeat means the recent-heartbeat threshold has been exceeded. Unknown means there is insufficient recent information.")
                Text("Inactive is derived on the phone when the latest station record is at least the configured Inactive-after age. The default is 2 days.")
                Text("A Healthy station may also be shown as back-level software when its reported PilotAware version is older than the newest version currently seen. This does not change its operational health state.")
            }

            Section("Station details") {
                Text("Station Detail repeats the effective map/status icon in its configured colour and explains what the icon means. It shows an absolute local Record date & time and relative ages for heartbeat, seen, position and technical reports.")
                Text("Available station, location, system, time and radio telemetry is shown; missing optional values appear as Not reported. Uptime, supply voltage and frequency correction are deliberately not displayed because the live station feed does not populate them reliably. RF correction is a separate radio field and remains available when reported.")
                Text("When station coordinates are available, View satellite location in Google Maps opens the exact latitude/longitude with a map pin and requests satellite imagery at zoom 18.")
            }

            Section("Favourites") {
                Text("Favourite ground stations are stored locally and remain available between launches. Open a station and use the star control to add or remove it.")
            }

            Section("Report") {
                Text("Report summarises the current station dataset by operational status and PilotAware software version. Share creates a formatted HTML report with responsive bar graphs plus a station-level CSV attachment and opens the iPhone share sheet.")
            }

            Section("Settings") {
                Text("The production service uses the configured HTTPS server. Test Connection checks server/database readiness and reports the confirmed station count. Refresh interval is configurable from 1 to 10 minutes and automatic refresh runs while the app is in the foreground.")
                Text("Inactive after is configurable from 1 to 30 days. Map layer and map/status colours are stored locally.")
            }


            Section("Privacy and scope") {
                Text("ATOM Monitor stores ground-station status, preferences, favourites and a station cache. It does not request device location for Home behaviour and must not be used to display or retain aircraft movements or aircraft identities.")
            }
        }
        .navigationTitle("User Guide")
    }
}
