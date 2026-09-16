import SwiftUI

struct ContentView: View {
    @StateObject private var store: StationStore
    @AppStorage("homeStationID") private var homeStationID = ""
    @AppStorage("favouriteStationIDs") private var favouriteStationIDs = ""
    @AppStorage("stationRefreshMinutes") private var stationRefreshMinutes = 1

    init(repository: any StationRepository) { _store = StateObject(wrappedValue: StationStore(repository: repository)) }

    var body: some View {
        TabView {
            StationMapView(store: store, homeStationID: homeStationID, favouriteStationIDs: $favouriteStationIDs).tabItem { Label("Map", systemImage: "map.fill") }
            NavigationStack { StationListView(store: store, favouriteStationIDs: $favouriteStationIDs).navigationTitle("ATOM Stations").navigationBarTitleDisplayMode(.inline) }.tabItem { Label("Stations", systemImage: "list.bullet") }
            NavigationStack { FavouritesView(store: store, favouriteStationIDs: favouriteStationIDs).navigationTitle("Favourites").navigationBarTitleDisplayMode(.inline) }.tabItem { Label("Favourites", systemImage: "star.fill") }
            NavigationStack { SettingsView(store: store, homeStationID: $homeStationID, favouriteStationIDs: $favouriteStationIDs, stationRefreshMinutes: $stationRefreshMinutes).navigationTitle("Settings").navigationBarTitleDisplayMode(.inline) }.tabItem { Label("Settings", systemImage: "gearshape.fill") }
            NavigationStack { HelpView().navigationTitle("ATOM Stations").navigationBarTitleDisplayMode(.inline) }.tabItem { Label("Help", systemImage: "questionmark.circle.fill") }
        }
        .task(id: stationRefreshMinutes) {
            // Always fetch immediately at startup (and when the interval changes),
            // then continue while this task/app scene remains active.
            await store.load()
            while !Task.isCancelled {
                let minutes = min(max(stationRefreshMinutes, 1), 10)
                do { try await Task.sleep(for: .seconds(Double(minutes * 60))) }
                catch { return }
                guard !Task.isCancelled else { return }
                await store.load()
            }
        }
    }
}

private struct FavouritesView: View {
    @ObservedObject var store: StationStore; let favouriteStationIDs: String
    private var ids:Set<String>{Set(favouriteStationIDs.split(separator:",").map(String.init))}
    private var favourites:[ATOMStation]{store.stations.filter{ids.contains($0.id)}.sorted{$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}}
    var body:some View{Group{if favourites.isEmpty{ContentUnavailableView("No Favourite Stations",systemImage:"star",description:Text("Add favourites from Map or Stations."))}else{List(favourites){station in NavigationLink{StationDetailView(station:station)}label:{VStack(alignment:.leading,spacing:7){HStack{Text(station.name).font(.headline);Spacer();Label(station.health.title,systemImage:station.health.symbol).font(.caption.weight(.semibold)).foregroundStyle(colour(station.health))};Text(station.lastHeartbeat.map{"Last heartbeat: \($0.formatted(date:.abbreviated,time:.standard))"} ?? "Last heartbeat: Not reported").font(.caption).foregroundStyle(.secondary);Text(location(station)).font(.caption2).foregroundStyle(.secondary)}}}}}}
    private func location(_ s:ATOMStation)->String{guard let a=s.latitude,let o=s.longitude else{return "Location: Not reported"};return String(format:"%.4f°, %.4f°",a,o)}
    private func colour(_ h:StationHealth)->Color{switch h{case .healthy:return .green;case .warning:return .orange;case .noRecentHeartbeat:return .red;case .unknown:return .gray}}
}

private struct SettingsView: View {
    @ObservedObject var store: StationStore
    @Binding var homeStationID:String
    @Binding var favouriteStationIDs:String
    @Binding var stationRefreshMinutes:Int
    @AppStorage(ServerConfiguration.key) private var savedServerURL = ""
    @State private var serverURL = ServerConfiguration.configuredURLString
    @State private var isTesting = false
    @State private var connectionMessage:String?
    @State private var connectionSucceeded = false

    private var ids:Set<String>{Set(favouriteStationIDs.split(separator:",").map(String.init))}
    private var sortedStations:[ATOMStation]{store.stations.sorted{$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}}
    private var favourites:[ATOMStation]{sortedStations.filter{ids.contains($0.id)}}

    var body:some View{
        Form{
            Section("Server") {
                TextField("https://atom.example.net/", text:$serverURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                HStack {
                    Button("Save") { saveServer() }.disabled(serverURL.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    Spacer()
                    Button { Task { await testServer() } } label: { if isTesting { ProgressView() } else { Label("Test Connection",systemImage:"network") } }.disabled(isTesting)
                }
                if let message=connectionMessage { Label(message,systemImage:connectionSucceeded ? "checkmark.circle.fill":"xmark.circle.fill").foregroundStyle(connectionSucceeded ? .green:.red).font(.footnote) }
                Text("Use the public HTTPS DNS name for normal operation. A local HTTP address may be retained temporarily for LAN diagnostics.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Data refresh") {
                Stepper(value:$stationRefreshMinutes,in:1...10,step:1) {
                    HStack { Text("Refresh interval"); Spacer(); Text("\(stationRefreshMinutes) min").foregroundStyle(.secondary) }
                }
                Text("Station data is fetched once when ATOM Monitor starts, then automatically every \(stationRefreshMinutes) minute\(stationRefreshMinutes == 1 ? "" : "s"). The interval can be set from 1 to 10 minutes and is remembered on this iPhone.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Map") { Picker("Home station",selection:$homeStationID){Text("Default UK view").tag("");ForEach(sortedStations.filter{$0.coordinate != nil}){Text($0.name).tag($0.id)}};Text("The Map tab opens centred and zoomed around the selected home station.").font(.footnote).foregroundStyle(.secondary) }
            Section("Favourite stations") { if favourites.isEmpty{Text("No favourites selected. Add them from Map or Stations.").foregroundStyle(.secondary)}else{ForEach(favourites){s in HStack{VStack(alignment:.leading){Text(s.name);Text(s.health.title).font(.caption).foregroundStyle(.secondary)};Spacer();Button(role:.destructive){remove(s.id)}label:{Image(systemName:"minus.circle.fill")}.buttonStyle(.borderless)}}};Text("Add favourites from Map or Stations. Remove them here in Settings.").font(.footnote).foregroundStyle(.secondary) }
        }
    }

    private func saveServer(){do{let url=try ServerConfiguration.normalizedURL(from:serverURL);serverURL=url.absoluteString;savedServerURL=url.absoluteString;connectionMessage="Saved. Reloading stations from the new server…";connectionSucceeded=true;Task{await store.load()}}catch{connectionMessage=error.localizedDescription;connectionSucceeded=false}}
    private func testServer() async {isTesting=true;defer{isTesting=false};do{let result=try await APIStationRepository.testConnection(to:serverURL);let count=result.confirmedStations.map{" — \($0) confirmed stations"} ?? "";connectionMessage="Connected: \(result.status)\(count)";connectionSucceeded=true}catch{connectionMessage=error.localizedDescription;connectionSucceeded=false}}
    private func remove(_ id:String){var u=ids;u.remove(id);favouriteStationIDs=u.sorted().joined(separator:",")}
}

private struct HelpView:View{private let url=URL(string:"https://github.com/rhine59/ATOMMonitor/blob/main/docs/USER-GUIDE.md")!;var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){Label("ATOM Monitor Help",systemImage:"antenna.radiowaves.left.and.right").font(.title2.bold());Text("ATOM Monitor displays the operational health and technical status of PilotAware ATOM ground stations. It does not display or record aircraft movements.");Link(destination:url){Label("Open User Guide",systemImage:"book.fill").font(.headline).frame(maxWidth:.infinity).padding(.vertical,12)}.buttonStyle(.borderedProminent)}.padding()}}}
