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
            NavigationStack {
                StationMapView(store: store, homeStationID: homeStationID)
                    .navigationTitle("ATOM Stations")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem { Label("Map", systemImage: "map.fill") }

            NavigationStack {
                StationListView(store: store)
                    .navigationTitle("ATOM Stations")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Stations", systemImage: "list.bullet") }

            NavigationStack {
                FavouritesView(store: store, favouriteStationIDs: favouriteStationIDs)
                    .navigationTitle("Favourites")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Favourites", systemImage: "star.fill") }

            NavigationStack {
                SettingsView(store: store, homeStationID: $homeStationID, favouriteStationIDs: $favouriteStationIDs)
                    .navigationTitle("ATOM Stations")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }

            NavigationStack {
                HelpView()
                    .navigationTitle("ATOM Stations")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Help", systemImage: "questionmark.circle.fill") }
        }
        .task { await store.load() }
    }
}

private struct FavouritesView: View {
    @ObservedObject var store: StationStore
    let favouriteStationIDs: String

    private var favouriteIDs: Set<String> {
        Set(favouriteStationIDs.split(separator: ",").map(String.init))
    }

    private var favourites: [ATOMStation] {
        store.stations
            .filter { favouriteIDs.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Group {
            if favourites.isEmpty {
                ContentUnavailableView(
                    "No Favourite Stations",
                    systemImage: "star",
                    description: Text("Choose favourite ATOM stations in Settings.")
                )
            } else {
                List(favourites) { station in
                    NavigationLink {
                        StationDetailView(station: station)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(station.name).font(.headline)
                                Spacer()
                                Label(station.health.title, systemImage: station.health.symbol)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(healthColour(station.health))
                            }
                            if let heartbeat = station.lastHeartbeat {
                                Text("Last heartbeat: \(heartbeat.formatted(date: .abbreviated, time: .standard))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Last heartbeat: Not reported")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(String(format: "%.4f°, %.4f°", station.latitude, station.longitude))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func healthColour(_ health: StationHealth) -> Color {
        switch health {
        case .healthy: .green
        case .warning: .orange
        case .noRecentHeartbeat: .red
        case .unknown: .gray
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var store: StationStore
    @Binding var homeStationID: String
    @Binding var favouriteStationIDs: String

    private var favouriteIDs: Set<String> {
        Set(favouriteStationIDs.split(separator: ",").map(String.init))
    }

    private var sortedStations: [ATOMStation] {
        store.stations.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Form {
            Section("Map") {
                Picker("Home station", selection: $homeStationID) {
                    Text("Default UK view").tag("")
                    ForEach(sortedStations) { station in Text(station.name).tag(station.id) }
                }
                Text("The Map tab opens centred and zoomed around the selected home station.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Favourite stations") {
                if sortedStations.isEmpty {
                    Text("No stations available yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedStations) { station in
                        Button {
                            toggleFavourite(station.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(station.name).foregroundStyle(.primary)
                                    Text(station.health.title).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: favouriteIDs.contains(station.id) ? "star.fill" : "star")
                                    .foregroundStyle(favouriteIDs.contains(station.id) ? .yellow : .secondary)
                            }
                        }
                    }
                }
                Text("Favourites are stored on this iPhone. The list will include all stations as they become available from the station registry.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func toggleFavourite(_ id: String) {
        var ids = favouriteIDs
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        favouriteStationIDs = ids.sorted().joined(separator: ",")
    }
}

private struct HelpView: View {
    private let userGuideURL = URL(string: "https://github.com/rhine59/ATOMMonitor/blob/main/docs/USER-GUIDE.md")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("ATOM Monitor Help", systemImage: "antenna.radiowaves.left.and.right").font(.title2.bold())
                Text("ATOM Monitor displays the operational health and technical status of PilotAware ATOM ground stations. It does not display or record aircraft movements.")
                Link(destination: userGuideURL) {
                    Label("Open User Guide", systemImage: "book.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                }.buttonStyle(.borderedProminent)
                Text("The User Guide is maintained with the application documentation and opens in your browser.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding()
        }
    }
}
