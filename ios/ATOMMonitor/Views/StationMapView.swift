import SwiftUI
import MapKit

struct StationMapView: View {
    @ObservedObject var store: StationStore
    let homeStationID: String
    @Binding var favouriteStationIDs: String
    @AppStorage("stationMapLayer") private var mapLayerRawValue = StationMapLayer.standard.rawValue
    @AppStorage(MapIconColourPreferences.healthyKey) private var healthyColour = MapIconColour.green.rawValue
    @AppStorage(MapIconColourPreferences.backLevelKey) private var backLevelColour = MapIconColour.purple.rawValue
    @AppStorage(MapIconColourPreferences.noRecentHeartbeatKey) private var noRecentHeartbeatColour = MapIconColour.blue.rawValue
    @AppStorage(MapIconColourPreferences.inactiveKey) private var inactiveColour = MapIconColour.red.rawValue
    @AppStorage(MapIconColourPreferences.warningKey) private var warningColour = MapIconColour.orange.rawValue
    @AppStorage(MapIconColourPreferences.unknownKey) private var unknownColour = MapIconColour.gray.rawValue
    @State private var position: MapCameraPosition = .region(Self.defaultRegion)
    @State private var visibleRegion = Self.defaultRegion
    @State private var hasAppliedInitialHome = false
    @State private var detailStation: ATOMStation?
    @State private var homeMessage: String?
    @State private var showingFilters = false

    private static let defaultRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude:54.2,longitude:-2.5),span:MKCoordinateSpan(latitudeDelta:7.5,longitudeDelta:7.5))
    private var positionedStations:[ATOMStation]{store.filteredStations.filter{$0.coordinate != nil}}
    private var mapLayer:StationMapLayer{StationMapLayer(rawValue:mapLayerRawValue) ?? .standard}

    var body:some View{
        GeometryReader{geometry in ZStack(alignment:.top){
            Map(position:$position){ForEach(mapItems){item in switch item{
            case .station(let station): if let coordinate=station.coordinate{let health=store.displayHealth(for:station);Annotation(station.name,coordinate:coordinate){Button{detailStation=station}label:{Image(systemName:health.symbol).font(.title2.weight(.bold)).foregroundStyle(.white).frame(width:42,height:42).background(tint(for:station),in:Circle()).overlay(Circle().stroke(.white,lineWidth:3))}.buttonStyle(.plain)}}
            case .cluster(let cluster):Annotation("stations",coordinate:cluster.coordinate){Button{zoomInto(cluster)}label:{Text(String(cluster.stations.count)).font(.headline.bold()).foregroundStyle(.white).frame(width:48,height:48).background(clusterTint(cluster),in:Circle())}.buttonStyle(.plain)}
            }}}
            .mapStyle(mapLayer.style).frame(width:geometry.size.width,height:geometry.size.height).ignoresSafeArea(.container,edges:.all).onMapCameraChange(frequency:.onEnd){visibleRegion=$0.region}.onAppear{applyHomeIfNeeded()}.onChange(of:store.stations){_,_ in applyHomeIfNeeded();if store.hasActiveFilters{applyFilterFocus()}}.onChange(of:homeStationID){_,_ in hasAppliedInitialHome=false;applyHomeIfNeeded();if store.hasActiveFilters{applyFilterFocus()}}.onChange(of:store.selectedHealthFilters){_,_ in applyFilterFocus()}.onChange(of:store.selectedPilotAwareVersions){_,_ in applyFilterFocus()}.mapControls{MapCompass();MapScaleView()}
            mapChrome(topInset:geometry.safeAreaInsets.top,width:geometry.size.width)
        }.frame(width:geometry.size.width,height:geometry.size.height)}
        .ignoresSafeArea(.container,edges:.all)
        .overlay{if store.isLoading{ProgressView("Loading stations…").padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:14))}}
        .sheet(item:$detailStation){station in NavigationStack{StationDetailView(station:station,displayHealth:store.displayHealth(for:station),isBackLevelSoftware:store.isBackLevelSoftware(station)).toolbar{ToolbarItem(placement:.topBarTrailing){Button("Done"){detailStation=nil}}}}.presentationDetents([.medium,.large]).presentationDragIndicator(.visible)}
        .sheet(isPresented:$showingFilters){StationFilterView(store:store)}
        .alert("Unable to load stations",isPresented:errorPresented){Button("OK"){store.clearError()}}message:{Text(store.errorMessage ?? "Unknown error")}
        .alert("Home station",isPresented:homeMessagePresented){Button("OK"){homeMessage=nil}}message:{Text(homeMessage ?? "")}
    }

    private func mapChrome(topInset:CGFloat,width:CGFloat)->some View{
        VStack(alignment:.leading,spacing:6){
            HStack(alignment:.center){Text("Stations").font(.title2.bold()).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.75);Spacer(minLength:4);mapLayerMenu;chromeButton(systemName:store.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill":"line.3.horizontal.decrease.circle",accessibilityLabel:"Filter stations",disabled:false){showingFilters=true};chromeButton(systemName:"house.fill",accessibilityLabel:"Go to home station",disabled:false){goHome()};Button{Task{await store.load()}}label:{if store.isLoading{ProgressView().controlSize(.small).frame(width:28,height:28)}else{Image(systemName:"arrow.clockwise").font(.subheadline.weight(.semibold)).frame(width:28,height:28)}}.buttonStyle(.bordered).buttonBorderShape(.circle).disabled(store.isLoading).accessibilityLabel("Refresh stations")}.padding(.horizontal,2)
            connectionStatus
            if store.hasActiveFilters { HStack { Text("Filtered: \(store.filteredStations.count) of \(store.stations.count)").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Clear filters"){store.clearFilters()}.font(.caption) }.padding(.horizontal,2) }
            searchBar
        }.padding(.horizontal,adaptiveHorizontalPadding(for:width)).padding(.top,max(topInset,50)+6)
    }

    private var connectionStatus:some View{Group{if store.errorMessage != nil {Text("No Network • \(store.stations.count) stations").foregroundStyle(.red).accessibilityLabel("No Network, \(store.stations.count) stations cached")}else if let updated=store.lastSuccessfulRefresh {Text("Last updated: \(updated.formatted(date:.omitted,time:.shortened)) • \(store.stations.count) stations").foregroundStyle(.secondary).accessibilityLabel("Last updated \(updated.formatted(date:.abbreviated,time:.shortened)), \(store.stations.count) stations")}else{Text("Last updated: — • \(store.stations.count) stations").foregroundStyle(.secondary)}}.font(.caption).lineLimit(1).padding(.horizontal,2)}
    private var mapLayerMenu:some View{Menu{ForEach(StationMapLayer.allCases){layer in Button{mapLayerRawValue=layer.rawValue}label:{Label(layer.title,systemImage:mapLayer==layer ? "checkmark":"map")}}}label:{Image(systemName:"square.3.layers.3d").font(.subheadline.weight(.semibold)).frame(width:28,height:28)}.buttonStyle(.bordered).buttonBorderShape(.circle).accessibilityLabel("Map layers")}
    private func chromeButton(systemName:String,accessibilityLabel:String,disabled:Bool,action:@escaping()->Void)->some View{Button(action:action){Image(systemName:systemName).font(.subheadline.weight(.semibold)).frame(width:28,height:28)}.buttonStyle(.bordered).buttonBorderShape(.circle).disabled(disabled).accessibilityLabel(accessibilityLabel)}
    private func goHome(){guard !homeStationID.isEmpty else{homeMessage="No home station set";return};guard let station=store.stations.first(where:{$0.id==homeStationID}),let coordinate=station.coordinate else{homeMessage="Home station location not reported";return};focus(on:coordinate)}
    private func adaptiveHorizontalPadding(for width:CGFloat)->CGFloat{width<390 ? 8:12}
    private var mapItems:[StationMapItem]{cluster(positionedStations,in:visibleRegion)}
    private func cluster(_ stations:[ATOMStation],in region:MKCoordinateRegion)->[StationMapItem]{guard stations.count>1 else{return stations.map{.station($0)}};let a=max(region.span.latitudeDelta/7,0.0008),b=max(region.span.longitudeDelta/5,0.0008);let groups=Dictionary(grouping:stations){s->GridKey in let c=s.coordinate!;return GridKey(latitude:Int(floor(c.latitude/a)),longitude:Int(floor(c.longitude/b)))};return groups.values.map{$0.count==1 ? .station($0[0]):.cluster(StationCluster(stations:$0))}}
    private func clusterTint(_ cluster:StationCluster)->Color{let healths=Set(cluster.stations.map{store.displayHealth(for:$0)});if healths.contains(.noRecentHeartbeat){return .yellow};if healths.contains(.inactive)&&healths.contains(.healthy){return .yellow};if healths.contains(.inactive){return selected(inactiveColour,.red)};if healths.contains(.warning){return selected(warningColour,.orange)};if healths.contains(.healthy){return selected(healthyColour,.green)};return selected(unknownColour,.gray)}
    private func zoomInto(_ cluster:StationCluster){let c=cluster.stations.compactMap(\.coordinate),a=c.map(\.latitude),o=c.map(\.longitude);guard let amin=a.min(),let amax=a.max(),let omin=o.min(),let omax=o.max() else{return};let lat=max(max((amax-amin)*2.5,visibleRegion.span.latitudeDelta/3),0.01),lon=max(max((omax-omin)*2.5,visibleRegion.span.longitudeDelta/3),0.01);withAnimation{position = .region(MKCoordinateRegion(center:cluster.coordinate,span:MKCoordinateSpan(latitudeDelta:lat,longitudeDelta:lon)))}}
    private func applyHomeIfNeeded(){guard !hasAppliedInitialHome,!store.stations.isEmpty else{return};hasAppliedInitialHome=true;guard !homeStationID.isEmpty,let h=store.stations.first(where:{$0.id==homeStationID}),let c=h.coordinate else{return};focus(on:c,animated:false)}
    private func applyFilterFocus(){
        guard store.hasActiveFilters else{returnToUK();return}
        guard !homeStationID.isEmpty,let home=store.stations.first(where:{$0.id==homeStationID}),let homeCoordinate=home.coordinate else{returnToUK();return}
        let origin=CLLocation(latitude:homeCoordinate.latitude,longitude:homeCoordinate.longitude)
        let nearest=store.filteredStations.compactMap{station->(ATOMStation,CLLocationDistance)? in guard let c=station.coordinate else{return nil};let d=origin.distance(from:CLLocation(latitude:c.latitude,longitude:c.longitude));return(station,d)}.min{$0.1<$1.1}?.0
        guard let coordinate=nearest?.coordinate else{returnToUK();return}
        focus(on:coordinate)
    }
    private func focus(on coordinate:CLLocationCoordinate2D,animated:Bool=true){let r=MKCoordinateRegion(center:coordinate,span:MKCoordinateSpan(latitudeDelta:0.8,longitudeDelta:0.8));visibleRegion=r;if animated{withAnimation{position = .region(r)}}else{position = .region(r)}}
    private func returnToUK(){visibleRegion=Self.defaultRegion;withAnimation{position = .region(Self.defaultRegion)}}
    private var searchBar:some View{HStack(spacing:10){Image(systemName:"magnifyingglass").foregroundStyle(.secondary);TextField("Find",text:$store.searchText).textInputAutocapitalization(.never).autocorrectionDisabled();if !store.searchText.isEmpty{Button{store.searchText=""}label:{Image(systemName:"xmark.circle.fill").foregroundStyle(.secondary)}.buttonStyle(.plain)}}.padding(.horizontal,16).frame(height:46).background(.regularMaterial,in:Capsule())}
    private var errorPresented:Binding<Bool>{Binding(get:{store.errorMessage != nil},set:{if !$0{store.clearError()}})}
    private var homeMessagePresented:Binding<Bool>{Binding(get:{homeMessage != nil},set:{if !$0{homeMessage=nil}})}
    private func selected(_ raw:String,_ fallback:MapIconColour)->Color{(MapIconColour(rawValue:raw) ?? fallback).color}
    private func tint(for station:ATOMStation)->Color{let h=store.displayHealth(for:station);switch h{case .inactive:return selected(inactiveColour,.red);case .noRecentHeartbeat:return selected(noRecentHeartbeatColour,.blue);case .warning:return selected(warningColour,.orange);case .unknown:return selected(unknownColour,.gray);case .healthy:return store.isBackLevelSoftware(station) ? selected(backLevelColour,.purple):selected(healthyColour,.green)}}
}

private enum StationMapLayer:String,CaseIterable,Identifiable{case standard,hybrid,imagery;var id:String{rawValue};var title:String{switch self{case .standard:return "Standard";case .hybrid:return "Satellite + Labels";case .imagery:return "Satellite"}};var style:MapStyle{switch self{case .standard:return .standard(elevation:.realistic);case .hybrid:return .hybrid(elevation:.realistic);case .imagery:return .imagery(elevation:.realistic)}}}
private struct GridKey:Hashable{let latitude:Int;let longitude:Int}
private struct StationCluster:Identifiable{let stations:[ATOMStation];var id:String{stations.map(\.id).sorted().joined(separator:"|")};var coordinate:CLLocationCoordinate2D{let c=stations.compactMap(\.coordinate);return CLLocationCoordinate2D(latitude:c.map(\.latitude).reduce(0,+)/Double(c.count),longitude:c.map(\.longitude).reduce(0,+)/Double(c.count))}}
private enum StationMapItem:Identifiable{case station(ATOMStation);case cluster(StationCluster);var id:String{switch self{case .station(let s):return "station:"+s.id;case .cluster(let c):return "cluster:"+c.id}}}
