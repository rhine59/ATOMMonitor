import Foundation

protocol StationRepository { func stations() async throws -> [ATOMStation] }

struct APIStationRepository: StationRepository {
    let baseURL: URL
    private let cacheURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheURL = dir.appendingPathComponent("atom-stations-cache.json")
    }

    func stations() async throws -> [ATOMStation] {
        do {
            let url = baseURL.appending(path: "api/v1/stations")
            var request = URLRequest(url: url); request.timeoutInterval = 12
            let (data,response) = try await URLSession.shared.data(for: request)
            guard let http=response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw RepositoryError.badResponse }
            let stations=try decoder.decode([ATOMStation].self,from:data)
            try? data.write(to:cacheURL,options:.atomic)
            cacheFavouriteStations(from: stations)
            return stations
        } catch {
            if let data=try? Data(contentsOf:cacheURL), let stations=try? decoder.decode([ATOMStation].self,from:data) { return stations }
            throw error
        }
    }

    private var decoder: JSONDecoder { let d=JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }

    private func cacheFavouriteStations(from stations:[ATOMStation]) {
        let raw=UserDefaults.standard.string(forKey:"favouriteStationIDs") ?? ""
        let ids=Set(raw.split(separator:",").map(String.init))
        let favourites=stations.filter { ids.contains($0.id) }
        guard let data=try? JSONEncoder.atomEncoder.encode(favourites) else { return }
        let dir=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first!
        try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        try? data.write(to:dir.appendingPathComponent("atom-favourites-cache.json"),options:.atomic)
    }
}

struct FixtureStationRepository: StationRepository {
    func stations() async throws -> [ATOMStation] {
        guard let url=Bundle.main.url(forResource:"stations",withExtension:"json") else { throw RepositoryError.missingFixture }
        let data=try Data(contentsOf:url); let decoder=JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ATOMStation].self,from:data)
    }
}

private extension JSONEncoder {
    static var atomEncoder: JSONEncoder { let e=JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e }
}

enum RepositoryError: LocalizedError {
    case missingFixture, badResponse
    var errorDescription:String? { switch self { case .missingFixture:"The bundled ATOM station fixture could not be found."; case .badResponse:"The ATOM Monitor server returned an invalid response." } }
}
