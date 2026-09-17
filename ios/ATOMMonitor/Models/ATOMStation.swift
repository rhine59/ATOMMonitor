import Foundation
import CoreLocation

struct ATOMStation: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
    let altitudeMetres: Double?
    let health: StationHealth
    let lastPosition: Date?
    let lastHeartbeat: Date?
    let lastTechnicalStatus: Date?
    let pilotAwareVersion: String?
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
    let voltageV: Double?
    let uptimeMinutes: Int?
    let lastSeen: Date?

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func displayHealth(inactiveAfterDays: Int, now: Date = Date()) -> StationHealth {
        guard let lastSeen else { return health }
        let threshold = TimeInterval(max(inactiveAfterDays, 1) * 24 * 60 * 60)
        return now.timeIntervalSince(lastSeen) >= threshold ? .inactive : health
    }
}

enum StationHealth: String, Codable, CaseIterable {
    case healthy, warning, noRecentHeartbeat, inactive, unknown

    var title: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .noRecentHeartbeat: return "No recent heartbeat"
        case .inactive: return "Inactive"
        case .unknown: return "Unknown"
        }
    }

    var symbol: String {
        switch self {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .noRecentHeartbeat: return "xmark.circle.fill"
        case .inactive: return "minus.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}
