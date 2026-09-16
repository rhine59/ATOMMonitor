import Foundation
import CoreLocation

struct ATOMStation: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let altitudeMetres: Double?
    let health: StationHealth
    let lastHeartbeat: Date?
    let softwareVersion: String?
    let cpuLoadPercent: Double?
    let ramUsedMB: Double?
    let ramTotalMB: Double?
    let cpuTemperatureC: Double?
    let ntpOffsetMS: Double?
    let ntpCorrectionPPM: Double?
    let frequencyCorrectionKHz: Double?
    let rfCorrectionPPM: Double?
    let signalQualityDB: Double?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum StationHealth: String, Codable, CaseIterable {
    case healthy, warning, noRecentHeartbeat, unknown

    var title: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .noRecentHeartbeat: return "No recent heartbeat"
        case .unknown: return "Unknown"
        }
    }

    var symbol: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .noRecentHeartbeat: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}
