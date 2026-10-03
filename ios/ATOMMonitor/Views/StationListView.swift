import SwiftUI

struct StationListView: View {
    @ObservedObject var store: StationStore
    @Binding var favouriteStationIDs: String
    @State private var showingFilters = false
    private var favouriteIDs: Set<String> { Set(favouriteStationIDs.split(separator: ",").map(String.init)) }

    var body: some View {
        List {
            if store.hasActiveFilters { HStack { Label("\(store.filteredStations.count) of \(store.stations.count) stations", systemImage:"line.3.horizontal.decrease.circle.fill").font(.caption).foregroundStyle(.secondary);Spacer();Button("Clear"){store.clearFilters()}.font(.caption) } }
            ForEach(store.filteredStations) { station in
                let health=store.displayHealth(for:station)
                HStack(spacing:10){NavigationLink{StationDetailView(station:station,displayHealth:health,isBackLevelSoftware:store.isBackLevelSoftware(station))}label:{HStack{Image(systemName:health.symbol).foregroundStyle(colour(health));VStack(alignment:.leading){Text(station.name).font(.headline);Text("\(health.title) • \(station.pilotAwareVersion ?? "Version not reported")").font(.caption).foregroundStyle(.secondary)}}};Button{addFavourite(station.id)}label:{Image(systemName:favouriteIDs.contains(station.id) ? "star.fill":"star").foregroundStyle(favouriteIDs.contains(station.id) ? .yellow:.secondary).font(.title3)}.buttonStyle(.borderless).disabled(favouriteIDs.contains(station.id))}
            }
        }
        .searchable(text:$store.searchText,prompt:"Find an ATOM station").refreshable{await store.load()}
        .toolbar{ToolbarItemGroup(placement:.topBarTrailing){Button{showingFilters=true}label:{Image(systemName:store.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill":"line.3.horizontal.decrease.circle")};Button{Task{await store.load()}}label:{if store.isLoading{ProgressView().controlSize(.small)}else{Image(systemName:"arrow.clockwise")}}.disabled(store.isLoading)}}
        .sheet(isPresented:$showingFilters){StationFilterView(store:store)}
    }
    private func addFavourite(_ id:String){var ids=favouriteIDs;ids.insert(id);favouriteStationIDs=ids.sorted().joined(separator:",")}
    private func colour(_ h:StationHealth)->Color{switch h{case .healthy:return .green;case .warning:return .orange;case .noRecentHeartbeat:return .blue;case .inactive:return .red;case .unknown:return .gray}}
}

struct StationFilterView: View {
    @ObservedObject var store:StationStore;@Environment(\.dismiss) private var dismiss
    var body:some View{NavigationStack{List{Section("Status"){ForEach(store.availableHealthValues,id:\.self){h in filterRow(h.title,selected:store.selectedHealthFilters.contains(h)){if store.selectedHealthFilters.contains(h){store.selectedHealthFilters.remove(h)}else{store.selectedHealthFilters.insert(h)}}}};Section("PilotAware version"){ForEach(store.availablePilotAwareVersions,id:\.self){v in filterRow(v,selected:store.selectedPilotAwareVersions.contains(v)){store.filterPilotAwareVersionNotReported=false;if store.selectedPilotAwareVersions.contains(v){store.selectedPilotAwareVersions.remove(v)}else{store.selectedPilotAwareVersions.insert(v)}}};filterRow("Not reported",selected:store.filterPilotAwareVersionNotReported){store.selectedPilotAwareVersions.removeAll();store.filterPilotAwareVersionNotReported.toggle()}};Section{Text("With nothing selected in a section, all values are shown. Status and version selections are combined.").font(.caption).foregroundStyle(.secondary)}}.navigationTitle("Filter stations").toolbar{ToolbarItem(placement:.topBarLeading){Button("Clear"){store.clearFilters()}.disabled(!store.hasActiveFilters)};ToolbarItem(placement:.topBarTrailing){Button("Done"){dismiss()}}}}.presentationDetents([.medium,.large])}
    private func filterRow(_ title:String,selected:Bool,action:@escaping()->Void)->some View{Button(action:action){HStack{Text(title).foregroundStyle(.primary);Spacer();if selected{Image(systemName:"checkmark").fontWeight(.semibold)}}}}
}
