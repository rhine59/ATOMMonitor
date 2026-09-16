import Foundation

protocol StationRepository {
    func stations() async throws -> [ATOMStation]
}

struct APIStationRepository: StationRepository {
    let baseURL: URL
    private let cacheURL: URL
    private let favouritesCacheURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheURL = cacheDir.appendingPathComponent("atom-stations-cache.json")

        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: nil)
        self.favouritesCacheURL = supportDir.appendingPathComponent("atom-favourites-cache.json")
    }

    func stations() async throws -> [ATOMStation] {
        do {
            let url = baseURL.appending(path: "api/v1/stations")
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                throw RepositoryError.badResponse
            }

            let stations = try decoder.decode([ATOMStation].self, from: data)
            try? data.write(to: cacheURL, options: .atomic)
            cacheFavouriteStations(from: stations)
            return stations
        } catch {
            let general = loadStations(from: cacheURL)
            let favourites = loadStations(from: favouritesCacheURL)
            let merged = merge(general, favourites)
            if !merged.isEmpty { return merged }
            throw error
        }
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func loadStations(from url: URL) -> [ATOMStation] {
        guard let data = try? Data(contentsOf: url),
              let stations = try? decoder.decode([ATOMStation].self, from: data) else {
            return []
        }
        return stations
    }

    private func merge(_ primary: [ATOMStation], _ durableFavourites: [ATOMStation]) -> [ATOMStation] {
        var byID = Dictionary(uniqueKeysWithValues: primary.map { ($0.id, $0) })
        for station in durableFavourites where byID[station.id] == nil {
            byID[station.id] = station
        }
        return Array(byID.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func cacheFavouriteStations(from stations: [ATOMStation]) {
        let raw = UserDefaults.standard.string(forKey: "favouriteStationIDs") ?? ""
        let ids = Set(raw.split(separator: ",").map(String.init))
        guard !ids.isEmpty else { return }

        let current = stations.filter { ids.contains($0.id) }
        let previous = loadStations(from: favouritesCacheURL)
        let merged = merge(current, previous.filter { ids.contains($0.id) })
        guard let data = try? JSONEncoder.atomEncoder.encode(merged) else { return }
        try? data.write(to: favouritesCacheURL, options: .atomic)
    }
}

struct FixtureStationRepository: StationRepository {
    func stations() async throws -> [ATOMStation] {
        guard let url = Bundle.main.url(forResource: "stations", withExtension: "json") else {
            throw RepositoryError.missingFixture
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ATOMStation].self, from: data)
    }
}

private extension JSONEncoder {
    static var atomEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

enum RepositoryError: LocalizedError {
    case missingFixture, badResponse

    var errorDescription: String? {
        switch self {
        case .missingFixture: return "The bundled ATOM station fixture could not be found."
        case .badResponse: return "The ATOM Monitor server returned an invalid response."
        }
    }
}
