import SwiftUI

struct StationListView: View {
    @ObservedObject var store: StationStore
    @Binding var favouriteStationIDs: String

    private var favouriteIDs: Set<String> {
        Set(favouriteStationIDs.split(separator: ",").map(String.init))
    }

    var body: some View {
        List(store.filteredStations) { station in
            HStack(spacing: 10) {
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

                Button {
                    addFavourite(station.id)
                } label: {
                    Image(systemName: favouriteIDs.contains(station.id) ? "star.fill" : "star")
                        .foregroundStyle(favouriteIDs.contains(station.id) ? .yellow : .secondary)
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .disabled(favouriteIDs.contains(station.id))
                .accessibilityLabel(favouriteIDs.contains(station.id) ? "Already a favourite" : "Add \(station.name) to favourites")
            }
        }
        .searchable(text: $store.searchText, prompt: "Find an ATOM station")
    }

    private func addFavourite(_ id: String) {
        var ids = favouriteIDs
        ids.insert(id)
        favouriteStationIDs = ids.sorted().joined(separator: ",")
    }
}
