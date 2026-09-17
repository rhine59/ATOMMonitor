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
