import SwiftUI

struct ContentView: View {
    @StateObject private var store: StationStore

    init(repository: any StationRepository) {
        _store = StateObject(wrappedValue: StationStore(repository: repository))
    }

    var body: some View {
        TabView {
            NavigationStack {
                StationMapView(store: store)
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
                HelpView()
                    .navigationTitle("ATOM Stations")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Help", systemImage: "questionmark.circle.fill") }
        }
        .task { await store.load() }
    }
}

private struct HelpView: View {
    private let userGuideURL = URL(string: "https://github.com/rhine59/ATOMMonitor/blob/main/docs/USER-GUIDE.md")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("ATOM Monitor Help", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.title2.bold())

                Text("ATOM Monitor displays the operational health and technical status of PilotAware ATOM ground stations. It does not display or record aircraft movements.")

                Link(destination: userGuideURL) {
                    Label("Open User Guide", systemImage: "book.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Text("The User Guide is maintained with the application documentation and opens in your browser.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
