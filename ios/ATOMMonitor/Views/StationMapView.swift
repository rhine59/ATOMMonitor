import SwiftUI
import MapKit

struct StationMapView: View {
    @ObservedObject var store: StationStore
    let homeStationID: String
    @Binding var favouriteStationIDs: String
    @State private var position: MapCameraPosition = .region(Self.defaultRegion)
    @State private var visibleRegion = Self.defaultRegion
    @State private var hasAppliedInitialHome = false
    private static let defaultRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude:54.2,longitude:-2.5),span:MKCoordinateSpan(latitudeDelta:7.5,longitudeDelta:7.5))
    private var favouriteIDs:Set<String>{Set(favouriteStationIDs.split(separator:",").map(String.init))}
    private var positionedStations:[ATOMStation]{store.filteredStations.filter{$0.coordinate != nil}}

    var body: some View {
        Map(position:$position,selection:$store.selectedStation){
            ForEach(mapItems){item in
                switch item {
                case .station(let station):
                    if let coordinate=station.coordinate { Marker(station.name,systemImage:station.health.symbol,coordinate:coordinate).tint(tint(for:station.health)).tag(station) }
                case .cluster(let cluster):
                    Annotation("\(cluster.stations.count) stations",coordinate:cluster.coordinate){
                        Button{zoomInto(cluster)}label:{ZStack{Circle().fill(.blue).frame(width:44,height:44);Text("\(cluster.stations.count)").font(.headline.bold()).foregroundStyle(.white)}}.buttonStyle(.plain)
                    }
                }
            }
        }
        .onMapCameraChange(frequency:.onEnd){visibleRegion=$0.region}
        .onAppear{applyHomeIfNeeded()}.onChange(of:store.stations){_,_ in applyHomeIfNeeded()}.onChange(of:homeStationID){_,_ in hasAppliedInitialHome=false;applyHomeIfNeeded()}
        .mapControls{MapCompass();MapScaleView()}
        .safeAreaInset(edge:.top,spacing:0){searchBar.padding(.horizontal,12).padding(.vertical,8).background(.ultraThinMaterial)}
        .safeAreaInset(edge:.bottom,spacing:0){if let station=store.selectedStation{StationSummaryCard(station:station,isFavourite:favouriteIDs.contains(station.id)){addFavourite(station.id)}.padding(.horizontal,12).padding(.vertical,8)}}
        .overlay{if store.isLoading{ProgressView("Loading stations…").padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:14))}}
        .alert("Unable to load stations",isPresented:errorPresented){Button("OK"){store.clearError()}}message:{Text(store.errorMessage ?? "Unknown error")}
    }
    private var mapItems:[StationMapItem]{cluster(positionedStations,in:visibleRegion)}
    private func cluster(_ stations:[ATOMStation],in region:MKCoordinateRegion)->[StationMapItem]{
        guard stations.count>1 else{return stations.map{.station($0)}}
        let a=max(region.span.latitudeDelta/7,0.0008),b=max(region.span.longitudeDelta/5,0.0008)
        let groups=Dictionary(grouping:stations){s->GridKey in let c=s.coordinate!;return GridKey(latitude:Int(floor(c.latitude/a)),longitude:Int(floor(c.longitude/b)))}
        return groups.values.map{$0.count==1 ? .station($0[0]):.cluster(StationCluster(stations:$0))}
    }
    private func zoomInto(_ c:StationCluster){
        let coords=c.stations.compactMap(\.coordinate),lats=coords.map(\.latitude),lons=coords.map(\.longitude)
        guard let minA=lats.min(),let maxA=lats.max(),let minO=lons.min(),let maxO=lons.max() else{return}
        let lat=max(max((maxA-minA)*2.5,visibleRegion.span.latitudeDelta/3),0.01),lon=max(max((maxO-minO)*2.5,visibleRegion.span.longitudeDelta/3),0.01)
        withAnimation{position = .region(MKCoordinateRegion(center:c.coordinate,span:MKCoordinateSpan(latitudeDelta:lat,longitudeDelta:lon)))}
    }
    private func applyHomeIfNeeded(){
        guard !hasAppliedInitialHome,!store.stations.isEmpty else{return};hasAppliedInitialHome=true
        guard !homeStationID.isEmpty,let home=store.stations.first(where:{$0.id==homeStationID}),let c=home.coordinate else{return}
        let r=MKCoordinateRegion(center:c,span:MKCoordinateSpan(latitudeDelta:0.8,longitudeDelta:0.8));visibleRegion=r;position = .region(r)
    }
    private func addFavourite(_ id:String){var ids=favouriteIDs;ids.insert(id);favouriteStationIDs=ids.sorted().joined(separator:",")}
    private var searchBar:some View{HStack(spacing:10){Image(systemName:"magnifyingglass").foregroundStyle(.secondary);TextField("Find an ATOM station",text:$store.searchText).textInputAutocapitalization(.never).autocorrectionDisabled();if !store.searchText.isEmpty{Button{store.searchText=""}label:{Image(systemName:"xmark.circle.fill").foregroundStyle(.secondary)}.buttonStyle(.plain)}}.padding(.horizontal,12).frame(minHeight:40).background(.regularMaterial,in:Capsule())}
    private var errorPresented:Binding<Bool>{Binding(get:{store.errorMessage != nil},set:{if !$0{store.clearError()}})}
    private func tint(for h:StationHealth)->Color{switch h{case .healthy:return .green;case .warning:return .orange;case .noRecentHeartbeat:return .red;case .unknown:return .gray}}
}
private struct GridKey:Hashable{let latitude:Int;let longitude:Int}
private struct StationCluster:Identifiable{let stations:[ATOMStation];var id:String{stations.map(\.id).sorted().joined(separator:"|")};var coordinate:CLLocationCoordinate2D{let c=stations.compactMap(\.coordinate);return CLLocationCoordinate2D(latitude:c.map(\.latitude).reduce(0,+)/Double(c.count),longitude:c.map(\.longitude).reduce(0,+)/Double(c.count))}}
private enum StationMapItem:Identifiable{case station(ATOMStation);case cluster(StationCluster);var id:String{switch self{case .station(let s):return "station:\(s.id)";case .cluster(let c):return "cluster:\(c.id)"}}}
private struct StationSummaryCard:View{let station:ATOMStation;let isFavourite:Bool;let addFavourite:()->Void;var body:some View{HStack(spacing:12){VStack(alignment:.leading,spacing:3){Text(station.name).font(.headline).lineLimit(1);Label(station.health.title,systemImage:station.health.symbol).font(.caption)};Spacer(minLength:6);Button(action:addFavourite){Image(systemName:isFavourite ? "star.fill":"star").foregroundStyle(isFavourite ? .yellow:.primary).font(.title3)}.buttonStyle(.plain).disabled(isFavourite);NavigationLink("Details"){StationDetailView(station:station)}.font(.subheadline.weight(.semibold))}.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.regularMaterial,in:RoundedRectangle(cornerRadius:16))}}
