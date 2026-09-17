import Foundation

@MainActor
final class StationStore: ObservableObject {
    @Published private(set) var stations: [ATOMStation] = []
    @Published var searchText = ""
    @Published var selectedStation: ATOMStation?
    @Published var selectedHealthFilters: Set<StationHealth> = []
    @Published var selectedPilotAwareVersions: Set<String> = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSuccessfulRefresh: Date?

    private let repository: any StationRepository
    private let cache = StationCache()

    init(repository: any StationRepository) {
        self.repository = repository
        if let snapshot = cache.load() {
            stations = snapshot.stations.sorted { $0.name < $1.name }
            lastSuccessfulRefresh = snapshot.savedAt
        }
    }

    var availableHealthValues: [StationHealth] {
        StationHealth.allCases.filter { health in stations.contains { $0.health == health } }
    }

    var availablePilotAwareVersions: [String] {
        Array(Set(stations.compactMap { $0.pilotAwareVersion?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var hasActiveFilters: Bool { !selectedHealthFilters.isEmpty || !selectedPilotAwareVersions.isEmpty }

    var filteredStations: [ATOMStation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return stations.filter { station in
            let matchesSearch = query.isEmpty || station.name.localizedCaseInsensitiveContains(query)
            let matchesHealth = selectedHealthFilters.isEmpty || selectedHealthFilters.contains(station.health)
            let matchesVersion = selectedPilotAwareVersions.isEmpty || (station.pilotAwareVersion.map { selectedPilotAwareVersions.contains($0) } ?? false)
            return matchesSearch && matchesHealth && matchesVersion
        }
    }

    func clearFilters() {
        selectedHealthFilters.removeAll()
        selectedPilotAwareVersions.removeAll()
    }

    func load() async {
        isLoading = stations.isEmpty
        defer { isLoading = false }
        do {
            let fresh = try await repository.stations().sorted { $0.name < $1.name }
            stations = fresh
            let validVersions = Set(availablePilotAwareVersions)
            selectedPilotAwareVersions.formIntersection(validVersions)
            let validHealth = Set(availableHealthValues)
            selectedHealthFilters.formIntersection(validHealth)
            let now = Date()
            lastSuccessfulRefresh = now
            try cache.save(stations: fresh, at: now)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() { errorMessage = nil }
}

private struct StationCacheSnapshot: Codable {
    let savedAt: Date
    let stations: [ATOMStation]
}

private struct StationCache {
    private let filename = "atom-stations-cache.json"

    private var url: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
    }

    func load() -> StationCacheSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(StationCacheSnapshot.self, from: data)
    }

    func save(stations: [ATOMStation], at date: Date) throws {
        guard let url else { return }
        let data = try encoder.encode(StationCacheSnapshot(savedAt: date, stations: stations))
        try data.write(to: url, options: .atomic)
    }

    private var encoder: JSONEncoder {
        let value = JSONEncoder()
        value.dateEncodingStrategy = .iso8601
        return value
    }

    private var decoder: JSONDecoder {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .iso8601
        return value
    }
}
