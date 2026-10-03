import Foundation

protocol StationRepository { func stations() async throws -> [ATOMStation] }

struct ServerConnectionResult {
    let confirmedStations: Int?
    let status: String
}

enum ServerConfiguration {
    static let key = "serverBaseURL"
    static var configuredURLString: String {
        let saved = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return saved.isEmpty ? ATOMMonitorApp.defaultServerURL : saved
    }
    static func normalizedURL(from value: String) throws -> URL {
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw RepositoryError.invalidServerURL }
        if !text.contains("://") { text = "https://" + text }
        guard var components = URLComponents(string: text), let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme), components.host != nil else { throw RepositoryError.invalidServerURL }
        if components.path.isEmpty { components.path = "/" }
        guard let url = components.url else { throw RepositoryError.invalidServerURL }
        return url
    }
}

struct ConfigurableAPIStationRepository: StationRepository {
    func stations() async throws -> [ATOMStation] {
        let url = try ServerConfiguration.normalizedURL(from: ServerConfiguration.configuredURLString)
        return try await APIStationRepository(baseURL: url).stations()
    }
}

struct APIStationRepository: StationRepository {
    let baseURL: URL
    private let cacheURL: URL
    private let favouritesCacheURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheURL = cacheDir.appendingPathComponent("atom-stations-cache.json")
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: nil)
        favouritesCacheURL = supportDir.appendingPathComponent("atom-favourites-cache.json")
    }

    func stations() async throws -> [ATOMStation] {
        do {
            let endpoint = baseURL.appending(path: "api/v1/stations")
            var request = URLRequest(url: endpoint); request.timeoutInterval = 12
            let (data,response) = try await URLSession.shared.data(for: request)
            guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode) else { throw RepositoryError.badResponse }
            let stations=try decoder.decode([ATOMStation].self,from:data)
            try? data.write(to:cacheURL,options:.atomic); cacheFavouriteStations(from:stations); return stations
        } catch {
            let merged=merge(loadStations(from:cacheURL),loadStations(from:favouritesCacheURL))
            if !merged.isEmpty{return merged}; throw error
        }
    }

    static func testConnection(to value: String) async throws -> ServerConnectionResult {
        let base = try ServerConfiguration.normalizedURL(from: value)
        var request = URLRequest(url: base.appending(path: "ready")); request.timeoutInterval = 10
        let (data,response) = try await URLSession.shared.data(for: request)
        guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode) else { throw RepositoryError.badResponse }
        struct Readiness: Decodable { let confirmedStations: Int?; let status: String? }
        let readiness = try JSONDecoder().decode(Readiness.self, from: data)
        guard readiness.status?.lowercased() == "ready" else { throw RepositoryError.unhealthyServer }
        return ServerConnectionResult(confirmedStations: readiness.confirmedStations, status: readiness.status ?? "ready")
    }

    private var decoder:JSONDecoder{let d=JSONDecoder();d.dateDecodingStrategy = .iso8601;return d}
    private func loadStations(from url:URL)->[ATOMStation]{guard let data=try? Data(contentsOf:url),let s=try? decoder.decode([ATOMStation].self,from:data) else{return []};return s}
    private func merge(_ a:[ATOMStation],_ b:[ATOMStation])->[ATOMStation]{var d=Dictionary(uniqueKeysWithValues:a.map{($0.id,$0)});for s in b where d[s.id]==nil{d[s.id]=s};return Array(d.values).sorted{$0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending}}
    private func cacheFavouriteStations(from stations:[ATOMStation]){let ids=Set((UserDefaults.standard.string(forKey:"favouriteStationIDs") ?? "").split(separator:",").map(String.init));guard !ids.isEmpty else{return};let merged=merge(stations.filter{ids.contains($0.id)},loadStations(from:favouritesCacheURL).filter{ids.contains($0.id)});guard let data=try? JSONEncoder.atomEncoder.encode(merged) else{return};try? data.write(to:favouritesCacheURL,options:.atomic)}
}


struct DemoStationRepository: StationRepository {
    private let stationCount = 250

    func stations() async throws -> [ATOMStation] {
        let now = Date()
        return (1...stationCount).map { index in makeStation(index: index, now: now) }
    }

    private func makeStation(index: Int, now: Date) -> ATOMStation {
        let health: StationHealth
        switch index % 10 {
        case 0: health = .unknown
        case 1, 2, 3, 4, 5: health = .healthy
        case 6, 7: health = .warning
        case 8: health = .noRecentHeartbeat
        default: health = .inactive
        }

        let names = [
            1: "PW Demo Healthy",
            2: "PW Demo Warning",
            3: "PW Demo No Heartbeat",
            4: "PW Demo Unknown",
            5: "PW Demo No Position"
        ]
        let name = names[index] ?? String(format: "PW Demo Station %03d", index)
        let row = Double((index - 1) / 25)
        let column = Double((index - 1) % 25)
        let missingPosition = index == 5 || index % 37 == 0
        let latitude = missingPosition ? nil : 50.15 + row * 0.82 + Double(index % 3) * 0.035
        let longitude = missingPosition ? nil : -5.75 + column * 0.325 + Double(index % 5) * 0.012

        let age: TimeInterval
        switch health {
        case .healthy: age = TimeInterval(60 + (index % 8) * 45)
        case .warning: age = TimeInterval(18 * 60 + (index % 12) * 60)
        case .noRecentHeartbeat: age = TimeInterval(4 * 60 * 60 + index * 20)
        case .inactive: age = TimeInterval((3 + index % 8) * 24 * 60 * 60)
        case .unknown: age = TimeInterval(45 * 60)
        }
        let lastSeen = health == .unknown && index % 20 == 0 ? nil : now.addingTimeInterval(-age)
        let heartbeat = health == .unknown ? nil : lastSeen
        let positionTime = latitude == nil ? nil : lastSeen?.addingTimeInterval(-30)
        let technicalTime = health == .unknown ? nil : lastSeen?.addingTimeInterval(-75)
        let versions: [String?] = ["v20260920", "v20260707", "v20260707", "v20260515", nil]
        let version = versions[index % versions.count]
        let hasTelemetry = health != .unknown && index % 9 != 0

        return ATOMStation(
            id: String(format: "PWDEMO%03d", index),
            name: name,
            latitude: latitude,
            longitude: longitude,
            altitudeMetres: latitude == nil ? nil : Double(35 + (index * 17) % 430),
            health: health,
            lastPosition: positionTime,
            lastHeartbeat: heartbeat,
            lastTechnicalStatus: technicalTime,
            pilotAwareVersion: version,
            softwareVersion: hasTelemetry ? "v0.3.\(index % 4).ARM" : nil,
            cpuLoadPercent: hasTelemetry ? Double(8 + (index * 7) % 78) : nil,
            ramUsedMB: hasTelemetry ? Double(320 + (index * 13) % 460) : nil,
            ramTotalMB: hasTelemetry ? 1024 : nil,
            cpuTemperatureC: hasTelemetry ? Double(38 + (index * 3) % 31) : nil,
            ntpOffsetMS: hasTelemetry ? Double((index % 17) - 8) / 2.0 : nil,
            ntpCorrectionPPM: hasTelemetry ? Double((index % 13) - 6) / 10.0 : nil,
            frequencyCorrectionKHz: nil,
            rfCorrectionPPM: hasTelemetry ? Double((index % 15) - 7) / 10.0 : nil,
            signalQualityDB: hasTelemetry ? Double(10 + (index * 2) % 19) : nil,
            voltageV: nil,
            uptimeMinutes: nil,
            lastSeen: lastSeen
        )
    }
}

struct FixtureStationRepository: StationRepository {
    let resourceName:String
    init(resourceName:String="stations"){self.resourceName=resourceName}
    func stations() async throws -> [ATOMStation] {
        guard let url=Bundle.main.url(forResource:resourceName,withExtension:"json") else{throw RepositoryError.missingFixture}
        let data=try Data(contentsOf:url);let d=JSONDecoder();d.dateDecodingStrategy = .iso8601;return try d.decode([ATOMStation].self,from:data)
    }
}
private extension JSONEncoder{static var atomEncoder:JSONEncoder{let e=JSONEncoder();e.dateEncodingStrategy = .iso8601;return e}}
enum RepositoryError:LocalizedError{
    case missingFixture,badResponse,invalidServerURL,unhealthyServer
    var errorDescription:String?{switch self{
    case .missingFixture:return "The bundled ATOM station fixture could not be found."
    case .badResponse:return "The ATOM Monitor server returned an invalid response."
    case .invalidServerURL:return "Enter a valid server address, for example https://atom.example.net/."
    case .unhealthyServer:return "The server responded but did not report a ready ATOM Monitor service."
    }}
}
