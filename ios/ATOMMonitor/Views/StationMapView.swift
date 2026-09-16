import SwiftUI
import MapKit

struct StationMapView: View {
    @ObservedObject var store: StationStore
    let homeStationID: String
    @Binding var favouriteStationIDs: String
    @State private var position: MapCameraPosition = .region(Self.defaultRegion)
    @State private var visibleRegion = Self.defaultRegion
    @State private var hasAppliedInitialHome = false
    @State private var detailStation: ATOMStation?

    private static let defaultRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 54.2, longitude: -2.5), span: MKCoordinateSpan(latitudeDelta: 7.5, longitudeDelta: 7.5))
    private var positionedStations: [ATOMStation] { store.filteredStations.filter { $0.coordinate != nil } }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Map(position: $position) {
                    ForEach(mapItems) { item in
                        switch item {
                        case .station(let station):
                            if let coordinate = station.coordinate {
                                Annotation(station.name, coordinate: coordinate) {
                                    Button { detailStation = station } label: {
                                        Image(systemName: station.health.symbol)
                                            .font(.title2.weight(.bold)).foregroundStyle(.white)
                                            .frame(width: 42, height: 42)
                                            .background(tint(for: station.health), in: Circle())
                                            .overlay(Circle().stroke(.white, lineWidth: 3))
                                    }.buttonStyle(.plain)
                                }
                            }
                        case .cluster(let cluster):
                            Annotation("stations", coordinate: cluster.coordinate) {
                                Button { zoomInto(cluster) } label: {
                                    Text(String(cluster.stations.count)).font(.headline.bold()).foregroundStyle(.white)
                                        .frame(width: 48, height: 48).background(.blue, in: Circle())
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .frame(width: geometry.size.width, height: geometry.size.height)
                .ignoresSafeArea(.container, edges: .all)
                .onMapCameraChange(frequency: .onEnd) { visibleRegion = $0.region }
                .onAppear { applyHomeIfNeeded() }
                .onChange(of: store.stations) { _, _ in applyHomeIfNeeded() }
                .onChange(of: homeStationID) { _, _ in hasAppliedInitialHome = false; applyHomeIfNeeded() }
                .mapControls { MapCompass(); MapScaleView() }

                mapChrome(topInset: geometry.safeAreaInsets.top, width: geometry.size.width)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(.container, edges: .all)
        .overlay { if store.isLoading { ProgressView("Loading stations…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
        .sheet(item: $detailStation) { station in
            NavigationStack {
                StationDetailView(station: station)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { detailStation = nil } } }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Unable to load stations", isPresented: errorPresented) { Button("OK") { store.clearError() } } message: { Text(store.errorMessage ?? "Unknown error") }
    }

    private func mapChrome(topInset: CGFloat, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ATOM Stations")
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 4)
            searchBar
        }
        .padding(.horizontal, adaptiveHorizontalPadding(for: width))
        // GeometryReader itself ignores the safe area, so its safeAreaInsets can
        // be zero on a physical device. Reserve a status-area floor while still
        // honouring a larger reported inset (e.g. Dynamic Island devices).
        .padding(.top, max(topInset, 50) + 6)
    }

    private func adaptiveHorizontalPadding(for width: CGFloat) -> CGFloat { width < 390 ? 12 : 16 }
    private var mapItems: [StationMapItem] { cluster(positionedStations, in: visibleRegion) }
    private func cluster(_ stations: [ATOMStation], in region: MKCoordinateRegion) -> [StationMapItem] {
        guard stations.count > 1 else { return stations.map { .station($0) } }
        let a=max(region.span.latitudeDelta/7,0.0008),b=max(region.span.longitudeDelta/5,0.0008)
        let groups=Dictionary(grouping:stations){s->GridKey in let c=s.coordinate!;return GridKey(latitude:Int(floor(c.latitude/a)),longitude:Int(floor(c.longitude/b)))}
        return groups.values.map{$0.count == 1 ? .station($0[0]) : .cluster(StationCluster(stations:$0))}
    }
    private func zoomInto(_ cluster:StationCluster){let c=cluster.stations.compactMap(\.coordinate),a=c.map(\.latitude),o=c.map(\.longitude);guard let amin=a.min(),let amax=a.max(),let omin=o.min(),let omax=o.max() else{return};let lat=max(max((amax-amin)*2.5,visibleRegion.span.latitudeDelta/3),0.01),lon=max(max((omax-omin)*2.5,visibleRegion.span.longitudeDelta/3),0.01);withAnimation{position = .region(MKCoordinateRegion(center:cluster.coordinate,span:MKCoordinateSpan(latitudeDelta:lat,longitudeDelta:lon)))}}
    private func applyHomeIfNeeded(){guard !hasAppliedInitialHome,!store.stations.isEmpty else{return};hasAppliedInitialHome=true;guard !homeStationID.isEmpty,let h=store.stations.first(where:{$0.id==homeStationID}),let c=h.coordinate else{return};let r=MKCoordinateRegion(center:c,span:MKCoordinateSpan(latitudeDelta:0.8,longitudeDelta:0.8));visibleRegion=r;position = .region(r)}
    private var searchBar:some View{HStack(spacing:10){Image(systemName:"magnifyingglass").foregroundStyle(.secondary);TextField("Find",text:$store.searchText).textInputAutocapitalization(.never).autocorrectionDisabled();if !store.searchText.isEmpty{Button{store.searchText=""}label:{Image(systemName:"xmark.circle.fill").foregroundStyle(.secondary)}.buttonStyle(.plain)}}.padding(.horizontal,16).frame(height:46).background(.regularMaterial,in:Capsule())}
    private var errorPresented:Binding<Bool>{Binding(get:{store.errorMessage != nil},set:{if !$0{store.clearError()}})}
    private func tint(for h:StationHealth)->Color{switch h{case .healthy:return .green;case .warning:return .orange;case .noRecentHeartbeat:return .red;case .unknown:return .gray}}
}
private struct GridKey:Hashable{let latitude:Int;let longitude:Int}
private struct StationCluster:Identifiable{let stations:[ATOMStation];var id:String{stations.map(\.id).sorted().joined(separator:"|")};var coordinate:CLLocationCoordinate2D{let c=stations.compactMap(\.coordinate);return CLLocationCoordinate2D(latitude:c.map(\.latitude).reduce(0,+)/Double(c.count),longitude:c.map(\.longitude).reduce(0,+)/Double(c.count))}}
private enum StationMapItem:Identifiable{case station(ATOMStation);case cluster(StationCluster);var id:String{switch self{case .station(let s):return "station:"+s.id;case .cluster(let c):return "cluster:"+c.id}}}
