import SwiftUI
import MapKit

struct StationMapView: View {
    @ObservedObject var store: StationStore

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 54.2, longitude: -2.5),
            span: MKCoordinateSpan(latitudeDelta: 7.5, longitudeDelta: 7.5)
        )
    )

    var body: some View {
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
        .safeAreaInset(edge: .top, spacing: 0) {
            searchBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let station = store.selectedStation {
                StationSummaryCard(station: station)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
        }
        .overlay {
            if store.isLoading {
                ProgressView("Loading stations…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .alert("Unable to load stations", isPresented: errorPresented) {
            Button("OK") { store.clearError() }
        } message: {
            Text(store.errorMessage ?? "Unknown error")
        }
        .animation(.easeInOut(duration: 0.2), value: store.selectedStation)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Find an ATOM station", text: $store.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(.regularMaterial, in: Capsule())
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.clearError() } }
        )
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
        ViewThatFits(in: .vertical) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(station.name).font(.headline).lineLimit(1)
                    Label(station.health.title, systemImage: station.health.symbol)
                        .font(.caption)
                }
                Spacer(minLength: 8)
                NavigationLink("Details") {
                    StationDetailView(station: station)
                }
                .font(.subheadline.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(station.name).font(.headline)
                Label(station.health.title, systemImage: station.health.symbol).font(.caption)
                NavigationLink("View Details") { StationDetailView(station: station) }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
