import Foundation

protocol StationRepository {
    func stations() async throws -> [ATOMStation]
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

enum RepositoryError: LocalizedError {
    case missingFixture

    var errorDescription: String? {
        switch self {
        case .missingFixture: "The bundled ATOM station fixture could not be found."
        }
    }
}
