import Foundation

@MainActor
final class StationStore: ObservableObject {
    @Published private(set) var stations: [ATOMStation] = []
    @Published var searchText = ""
    @Published var selectedStation: ATOMStation?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let repository: any StationRepository

    init(repository: any StationRepository) {
        self.repository = repository
    }

    var filteredStations: [ATOMStation] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return stations }
        return stations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            stations = try await repository.stations().sorted { $0.name < $1.name }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
