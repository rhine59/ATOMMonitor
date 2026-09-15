import SwiftUI

struct StationListView: View {
    @ObservedObject var store: StationStore

    var body: some View {
        List(store.filteredStations) { station in
            NavigationLink {
                StationDetailView(station: station)
            } label: {
                HStack {
                    Image(systemName: station.health.symbol)
                    VStack(alignment: .leading) {
                        Text(station.name).font(.headline)
                        Text(station.health.title).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Stations")
        .searchable(text: $store.searchText, prompt: "Find an ATOM station")
    }
}
