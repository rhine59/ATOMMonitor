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
                    .toolbar(.hidden, for: .navigationBar)
            }
            .tabItem { Label("Map", systemImage: "map.fill") }

            NavigationStack {
                StationListView(store: store)
            }
            .tabItem { Label("Stations", systemImage: "list.bullet") }
        }
        .ignoresSafeArea(.container, edges: [.top, .horizontal])
        .task { await store.load() }
    }
}
