import SwiftUI
import MapKit

struct StationMapView: View {
    @ObservedObject var store: StationStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 54.2, longitude: -2.5),
            span: MKCoordinateSpan(latitudeDelta: 7.5, longitudeDelta: 7.5)
        )
    )

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Map(position: $position, selection: $store.selectedStation) {
                    ForEach(store.filteredStations) { station in
                        Marker(
                            station.name,
                            systemImage: station.health.symbol,
                            coordinate: station.coordinate
                        )
                        .tint(tint(for: station.health))
                        .tag(station)
                    }
                }
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .ignoresSafeArea(.container, edges: [.top, .horizontal])

                if let station = store.selectedStation {
                    StationSummaryCard(station: station, availableWidth: geometry.size.width)
                        .padding(.horizontal, horizontalPadding(for: geometry.size.width))
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .searchable(text: $store.searchText, prompt: "Find an ATOM station")
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

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.clearError() } }
        )
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        switch width {
        case ..<360: 8
        case ..<430: 12
        default: horizontalSizeClass == .compact ? 16 : 24
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
    let availableWidth: CGFloat

    private var compact: Bool { availableWidth < 375 }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(station.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Label(station.health.title, systemImage: station.health.symbol)
                        .font(.caption)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(station.name).font(.headline)
                    Label(station.health.title, systemImage: station.health.symbol)
                        .font(.caption)
                }
            }

            HStack {
                Text(String(format: "%.4f°, %.4f°", station.latitude, station.longitude))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if let altitude = station.altitudeMetres {
                    Text("\(Int(altitude.rounded())) m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            NavigationLink {
                StationDetailView(station: station)
            } label: {
                HStack {
                    Spacer()
                    Text("View Details")
                    Image(systemName: "chevron.right")
                }
                .contentShape(Rectangle())
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(compact ? 10 : 14)
        .frame(maxWidth: min(availableWidth, 620), alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: compact ? 14 : 18))
        .shadow(radius: 3, y: 1)
    }
}
