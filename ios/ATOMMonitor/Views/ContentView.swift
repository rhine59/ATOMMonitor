import SwiftUI

struct ContentView: View {
    @StateObject private var store: StationStore
    @AppStorage("homeStationID") private var homeStationID = ""
    @AppStorage("favouriteStationIDs") private var favouriteStationIDs = ""
    @AppStorage("stationRefreshMinutes") private var stationRefreshMinutes = 5
    @AppStorage("inactiveAfterDays") private var inactiveAfterDays = 2

    init(repository: any StationRepository) { _store = StateObject(wrappedValue: StationStore(repository: repository)) }

    var body: some View {
        TabView {
            StationMapView(store: store, homeStationID: homeStationID, favouriteStationIDs: $favouriteStationIDs).tabItem { Label("Map", systemImage: "map.fill") }
            NavigationStack { StationListView(store: store, favouriteStationIDs: $favouriteStationIDs).navigationTitle("Stations").navigationBarTitleDisplayMode(.inline) }.tabItem { Label("Stations", systemImage: "list.bullet") }
            NavigationStack { FavouritesView(store: store, favouriteStationIDs: favouriteStationIDs).navigationTitle("Favourites").navigationBarTitleDisplayMode(.inline) }.tabItem { Label("Favourites", systemImage: "star.fill") }
            NavigationStack { SettingsView(store: store, homeStationID: $homeStationID, favouriteStationIDs: $favouriteStationIDs, stationRefreshMinutes: $stationRefreshMinutes, inactiveAfterDays: $inactiveAfterDays).navigationTitle("Settings").navigationBarTitleDisplayMode(.inline) }.tabItem { Label("Settings", systemImage: "gearshape.fill") }
            NavigationStack { HelpView().navigationTitle("Help").navigationBarTitleDisplayMode(.inline) }.tabItem { Label("Help", systemImage: "questionmark.circle.fill") }
        }
        .onChange(of:inactiveAfterDays){_,_ in store.inactiveThresholdChanged()}
        .task(id: stationRefreshMinutes) { await store.load(); while !Task.isCancelled { let minutes=min(max(stationRefreshMinutes,1),10);do{try await Task.sleep(for:.seconds(Double(minutes*60)))}catch{return};guard !Task.isCancelled else{return};await store.load()} }
    }
}

private struct FavouritesView: View {
    @ObservedObject var store: StationStore; let favouriteStationIDs: String
    private var ids:Set<String>{Set(favouriteStationIDs.split(separator:",").map(String.init))}
    private var favourites:[ATOMStation]{store.stations.filter{ids.contains($0.id)}.sorted{$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}}
    var body:some View{Group{if favourites.isEmpty{ContentUnavailableView("No Favourite Stations",systemImage:"star",description:Text("Add favourites from Map or Stations."))}else{List(favourites){station in let health=store.displayHealth(for:station);NavigationLink{StationDetailView(station:station)}label:{VStack(alignment:.leading,spacing:7){HStack{Text(station.name).font(.headline);Spacer();Label(health.title,systemImage:health.symbol).font(.caption.weight(.semibold)).foregroundStyle(colour(health))};Text(station.lastHeartbeat.map{"Last heartbeat: \($0.formatted(date:.abbreviated,time:.standard))"} ?? "Last heartbeat: Not reported").font(.caption).foregroundStyle(.secondary);Text(location(station)).font(.caption2).foregroundStyle(.secondary)}}}}}}
    private func location(_ s:ATOMStation)->String{guard let a=s.latitude,let o=s.longitude else{return "Location: Not reported"};return String(format:"%.4f°, %.4f°",a,o)}
    private func colour(_ h:StationHealth)->Color{switch h{case .healthy:return .green;case .warning:return .orange;case .noRecentHeartbeat,.inactive:return .red;case .unknown:return .gray}}
}

private struct SettingsView: View {
    @ObservedObject var store: StationStore;@Binding var homeStationID:String;@Binding var favouriteStationIDs:String;@Binding var stationRefreshMinutes:Int;@Binding var inactiveAfterDays:Int
    @AppStorage(ServerConfiguration.key) private var savedServerURL = "";@State private var serverURL=ServerConfiguration.configuredURLString;@State private var isTesting=false;@State private var connectionMessage:String?;@State private var connectionSucceeded=false
    private var ids:Set<String>{Set(favouriteStationIDs.split(separator:",").map(String.init))};private var sortedStations:[ATOMStation]{store.stations.sorted{$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}};private var favourites:[ATOMStation]{sortedStations.filter{ids.contains($0.id)}}
    var body:some View{Form{
        Section("Server"){TextField("https://atom.example.net/",text:$serverURL).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL);HStack{Button("Save"){saveServer()};Spacer();Button{Task{await testServer()}}label:{if isTesting{ProgressView()}else{Label("Test Connection",systemImage:"network")}}};if let m=connectionMessage{Label(m,systemImage:connectionSucceeded ? "checkmark.circle.fill":"xmark.circle.fill").foregroundStyle(connectionSucceeded ? .green:.red).font(.footnote)}}
        Section("Data refresh"){Stepper(value:$stationRefreshMinutes,in:1...10){HStack{Text("Refresh interval");Spacer();Text("\(stationRefreshMinutes) min").foregroundStyle(.secondary)}};Text("Default 5 minutes. Station data is fetched at startup and while the app is active.").font(.footnote).foregroundStyle(.secondary)}
        Section("Station status"){Stepper(value:$inactiveAfterDays,in:1...30){HStack{Text("Inactive after");Spacer();Text("\(inactiveAfterDays) day\(inactiveAfterDays == 1 ? "":"s")").foregroundStyle(.secondary)}};Text("A station whose latest record has not been seen for this many days is shown as Inactive. Default: 2 days. Inactive stations use a red map icon.").font(.footnote).foregroundStyle(.secondary)}
        Section("Map"){Picker("Home station",selection:$homeStationID){Text("Default UK view").tag("");ForEach(sortedStations.filter{$0.coordinate != nil}){Text($0.name).tag($0.id)}}}
        Section("Favourite stations"){if favourites.isEmpty{Text("No favourites selected.").foregroundStyle(.secondary)}else{ForEach(favourites){s in HStack{Text(s.name);Spacer();Button(role:.destructive){remove(s.id)}label:{Image(systemName:"minus.circle.fill")}.buttonStyle(.borderless)}}}}
    }}
    private func saveServer(){do{let url=try ServerConfiguration.normalizedURL(from:serverURL);serverURL=url.absoluteString;savedServerURL=url.absoluteString;connectionMessage="Saved. Reloading stations…";connectionSucceeded=true;Task{await store.load()}}catch{connectionMessage=error.localizedDescription;connectionSucceeded=false}}
    private func testServer() async{isTesting=true;defer{isTesting=false};do{let r=try await APIStationRepository.testConnection(to:serverURL);let status=r.status.uppercased();connectionMessage=r.confirmedStations.map{"\(status) — \($0) stations"} ?? "\(status) — station count not reported";connectionSucceeded=true}catch{connectionMessage=error.localizedDescription;connectionSucceeded=false}}
    private func remove(_ id:String){var u=ids;u.remove(id);favouriteStationIDs=u.sorted().joined(separator:",")}
}

private struct HelpView:View{var body:some View{List{Section{NavigationLink{UserGuideView()}label:{Label("User Guide",systemImage:"book.fill")}};Section("About"){Text("ATOM Monitor displays the operational health and technical status of PilotAware ATOM ground stations. It does not display or record aircraft movements.")}}}}
private struct UserGuideView:View{var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){guideSection("What ATOM Monitor does","ATOM Monitor monitors PilotAware ATOM ground-station operational health only. It does not display, record or retain aircraft movements, tracks or aircraft identities.");guideSection("Map","Green means Healthy, amber Warning, red No recent heartbeat or Inactive, and grey Unknown. A cluster containing both green Healthy and red Inactive stations is yellow. Clusters separate as the map is zoomed.");guideSection("Filters","Map and Stations share Status and PilotAware version filters. Status includes Inactive when inactive stations exist. Version choices come from values already collected. Find combines with these filters.");guideSection("Inactive stations","Settings contains Inactive after, default 2 days. If a station's latest lastSeen record is at least that old it is displayed as Inactive, overriding its live server health for presentation/filtering. Change the threshold from 1 to 30 days.");guideSection("Station details","Record date & time shows the exact local date/time of the latest station record. Other observation ages remain relative. Missing values display Not reported.");guideSection("Cached data","The latest successful station snapshot remains visible after a connection failure. It is not a history database and contains no aircraft data.");guideSection("Privacy","Aircraft traffic is outside ATOM Monitor's scope.")}.padding()}.navigationTitle("User Guide").navigationBarTitleDisplayMode(.inline)};private func guideSection(_ t:String,_ x:String)->some View{VStack(alignment:.leading,spacing:6){Text(t).font(.headline);Text(x).foregroundStyle(.secondary)}}}
