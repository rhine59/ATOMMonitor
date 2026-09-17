import SwiftUI

struct StationListView: View {
    @ObservedObject var store: StationStore
    @Binding var favouriteStationIDs: String
    @State private var showingFilters = false

    private var favouriteIDs: Set<String> { Set(favouriteStationIDs.split(separator: ",").map(String.init)) }

    var body: some View {
        List {
            if store.hasActiveFilters {
                HStack {
                    Label("\(store.filteredStations.count) of \(store.stations.count) stations", systemImage: "line.3.horizontal.decrease.circle.fill")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear") { store.clearFilters() }.font(.caption)
                }
            }
            ForEach(store.filteredStations) { station in
                HStack(spacing: 10) {
                    NavigationLink { StationDetailView(station: station) } label: {
                        HStack {
                            Image(systemName: station.health.symbol)
                            VStack(alignment: .leading) {
                                Text(station.name).font(.headline)
                                Text("\(station.health.title) • \(station.pilotAwareVersion ?? "Version not reported")").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button { addFavourite(station.id) } label: {
                        Image(systemName: favouriteIDs.contains(station.id) ? "star.fill" : "star").foregroundStyle(favouriteIDs.contains(station.id) ? .yellow : .secondary).font(.title3)
                    }
                    .buttonStyle(.borderless).disabled(favouriteIDs.contains(station.id)).accessibilityLabel(favouriteIDs.contains(station.id) ? "Already a favourite" : "Add \(station.name) to favourites")
                }
            }
        }
        .searchable(text: $store.searchText, prompt: "Find an ATOM station")
        .refreshable { await store.load() }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showingFilters = true } label: { Image(systemName: store.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") }
                    .accessibilityLabel("Filter stations")
                Button { Task { await store.load() } } label: {
                    if store.isLoading { ProgressView().controlSize(.small) } else { Image(systemName: "arrow.clockwise") }
                }
                .disabled(store.isLoading).accessibilityLabel("Refresh stations")
            }
        }
        .sheet(isPresented: $showingFilters) { StationFilterView(store: store) }
    }

    private func addFavourite(_ id: String) { var ids=favouriteIDs;ids.insert(id);favouriteStationIDs=ids.sorted().joined(separator:",") }
}

struct StationFilterView: View {
    @ObservedObject var store: StationStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    ForEach(store.availableHealthValues, id: \.self) { health in
                        filterRow(health.title, selected: store.selectedHealthFilters.contains(health)) {
                            if store.selectedHealthFilters.contains(health) { store.selectedHealthFilters.remove(health) } else { store.selectedHealthFilters.insert(health) }
                        }
                    }
                }
                Section("PilotAware version") {
                    ForEach(store.availablePilotAwareVersions, id: \.self) { version in
                        filterRow(version, selected: store.selectedPilotAwareVersions.contains(version)) {
                            if store.selectedPilotAwareVersions.contains(version) { store.selectedPilotAwareVersions.remove(version) } else { store.selectedPilotAwareVersions.insert(version) }
                        }
                    }
                    if store.availablePilotAwareVersions.isEmpty { Text("No versions reported").foregroundStyle(.secondary) }
                }
                Section { Text("With nothing selected in a section, all values in that section are shown. Status and version selections are combined.").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Filter stations")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Clear") { store.clearFilters() }.disabled(!store.hasActiveFilters) }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func filterRow(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { HStack { Text(title).foregroundStyle(.primary); Spacer(); if selected { Image(systemName: "checkmark").fontWeight(.semibold) } } }
    }
}
