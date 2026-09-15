import SwiftUI
import MapKit

struct StationMapView: View {
    @ObservedObject var store: StationStore
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 54.2, longitude: -2.5), span: MKCoordinateSpan(latitudeDelta: 7.5, longitudeDelta: 7.5))
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position, selection: $store.selectedStation) {
                ForEach(store.filteredStations) { station in
                    Marker(station.name, systemImage: station.health.symbol, coordinate: station.coordinate)
                        .tint(tint(for: station.health))
                        .tag(station)
                }
            }
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .searchable(text: $store.searchText, prompt: "Find an ATOM station")

            if let station = store.selectedStation {
                StationSummaryCard(station: station)
                    .padding()
            }
        }
        .overlay {
            if store.isLoading { ProgressView("Loading stations…") }
        }
        .alert("Unable to load stations", isPresented: .constant(store.errorMessage != nil)) {
            Button("OK") { }
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
    }

    private func tint(for health: StationHealth) -> Color {
        switch health {
        case .healthy: .green
        case .warning: .orange
        case .noRecentHeartbeat: .red
        case .unknown: .gray
        }
    }
}

private struct StationSummaryCard: View {
    let station: ATOMStation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(station.name).font(.headline)
                Spacer()
                Label(station.health.title, systemImage: station.health.symbol).font(.caption)
            }
            Text(String(format: "%.4f°, %.4f°", station.latitude, station.longitude))
                .font(.caption).foregroundStyle(.secondary)
            NavigationLink("View Details") { StationDetailView(station: station) }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
