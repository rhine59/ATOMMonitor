import SwiftUI
import MapKit

struct StationMapView: View {
    @ObservedObject var store: StationStore
    let homeStationID: String
    @Binding var favouriteStationIDs: String

    @State private var position: MapCameraPosition = .region(Self.defaultRegion)
    @State private var visibleRegion = Self.defaultRegion
    @State private var hasAppliedInitialHome = false

    private static let defaultRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 54.2, longitude: -2.5), span: MKCoordinateSpan(latitudeDelta: 7.5, longitudeDelta: 7.5))
    private var favouriteIDs: Set<String> { Set(favouriteStationIDs.split(separator: ",").map(String.init)) }

    var body: some View {
        Map(position: $position, selection: $store.selectedStation) {
            ForEach(mapItems) { item in
                switch item {
                case .station(let station):
                    Marker(station.name, systemImage: station.health.symbol, coordinate: station.coordinate).tint(tint(for: station.health)).tag(station)
                case .cluster(let cluster):
                    Annotation("\(cluster.stations.count) stations", coordinate: cluster.coordinate) {
                        Button { zoomInto(cluster) } label: {
                            ZStack {
                                Circle().fill(.blue).frame(width: 44, height: 44)
                                Text("\(cluster.stations.count)").font(.headline.bold()).foregroundStyle(.white)
                            }.shadow(radius: 2, y: 1)
                        }.buttonStyle(.plain).accessibilityLabel("\(cluster.stations.count) ATOM stations. Double tap to zoom in.")
                    }
                }
            }
        }
        .onMapCameraChange(frequency: .onEnd) { visibleRegion = $0.region }
        .onAppear { applyHomeIfNeeded() }
        .onChange(of: store.stations) { _, _ in applyHomeIfNeeded() }
        .onChange(of: homeStationID) { _, _ in hasAppliedInitialHome = false; applyHomeIfNeeded() }
        .mapControls { MapCompass(); MapScaleView() }
        .safeAreaInset(edge: .top, spacing: 0) { searchBar.padding(.horizontal, 12).padding(.vertical, 8).background(.ultraThinMaterial) }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let station = store.selectedStation {
                StationSummaryCard(station: station, isFavourite: favouriteIDs.contains(station.id)) { addFavourite(station.id) }
                    .padding(.horizontal, 12).padding(.vertical, 8)
            }
        }
        .overlay { if store.isLoading { ProgressView("Loading stations…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
        .alert("Unable to load stations", isPresented: errorPresented) { Button("OK") { store.clearError() } } message: { Text(store.errorMessage ?? "Unknown error") }
        .animation(.easeInOut(duration: 0.2), value: store.selectedStation)
    }

    private var mapItems: [StationMapItem] { cluster(store.filteredStations, in: visibleRegion) }

    private func cluster(_ stations: [ATOMStation], in region: MKCoordinateRegion) -> [StationMapItem] {
        guard stations.count > 1 else { return stations.map { .station($0) } }
        let latCell = max(region.span.latitudeDelta / 7.0, 0.0008)
        let lonCell = max(region.span.longitudeDelta / 5.0, 0.0008)
        let groups = Dictionary(grouping: stations) { GridKey(latitude: Int(floor($0.latitude / latCell)), longitude: Int(floor($0.longitude / lonCell))) }
        return groups.values.map { group in group.count == 1 ? .station(group[0]) : .cluster(StationCluster(stations: group)) }
    }

    private func zoomInto(_ cluster: StationCluster) {
        let lats = cluster.stations.map(\.latitude), lons = cluster.stations.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else { return }
        let region = MKCoordinateRegion(center: cluster.coordinate, span: MKCoordinateSpan(latitudeDelta: max((maxLat-minLat)*2.5, visibleRegion.span.latitudeDelta/3.0, 0.01), longitudeDelta: max((maxLon-minLon)*2.5, visibleRegion.span.longitudeDelta/3.0, 0.01)))
        withAnimation { position = .region(region) }
    }

    private func applyHomeIfNeeded() {
        guard !hasAppliedInitialHome, !store.stations.isEmpty else { return }
        hasAppliedInitialHome = true
        guard !homeStationID.isEmpty, let home = store.stations.first(where: { $0.id == homeStationID }) else { return }
        let region = MKCoordinateRegion(center: home.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8))
        visibleRegion = region; position = .region(region)
    }

    private func addFavourite(_ id: String) {
        var ids = favouriteIDs; ids.insert(id); favouriteStationIDs = ids.sorted().joined(separator: ",")
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find an ATOM station", text: $store.searchText).textInputAutocapitalization(.never).autocorrectionDisabled()
            if !store.searchText.isEmpty { Button { store.searchText = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }
        }.padding(.horizontal, 12).frame(minHeight: 40).background(.regularMaterial, in: Capsule())
    }

    private var errorPresented: Binding<Bool> { Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.clearError() } }) }
    private func tint(for health: StationHealth) -> Color { switch health { case .healthy: .green; case .warning: .orange; case .noRecentHeartbeat: .red; case .unknown: .gray } }
}

private struct GridKey: Hashable { let latitude: Int; let longitude: Int }
private struct StationCluster: Identifiable {
    let stations: [ATOMStation]
    var id: String { stations.map(\.id).sorted().joined(separator: "|") }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: stations.map(\.latitude).reduce(0,+)/Double(stations.count), longitude: stations.map(\.longitude).reduce(0,+)/Double(stations.count)) }
}
private enum StationMapItem: Identifiable {
    case station(ATOMStation); case cluster(StationCluster)
    var id: String { switch self { case .station(let s): "station:\(s.id)"; case .cluster(let c): "cluster:\(c.id)" } }
}

private struct StationSummaryCard: View {
    let station: ATOMStation
    let isFavourite: Bool
    let addFavourite: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(station.name).font(.headline).lineLimit(1)
                Label(station.health.title, systemImage: station.health.symbol).font(.caption)
            }
            Spacer(minLength: 6)
            Button(action: addFavourite) {
                Image(systemName: isFavourite ? "star.fill" : "star").foregroundStyle(isFavourite ? .yellow : .primary).font(.title3)
            }.buttonStyle(.plain).disabled(isFavourite).accessibilityLabel(isFavourite ? "Already a favourite" : "Add \(station.name) to favourites")
            NavigationLink("Details") { StationDetailView(station: station) }.font(.subheadline.weight(.semibold))
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
