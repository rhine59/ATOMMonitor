import Foundation
import CoreLocation

struct ATOMStation: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum StationHealth: String, Codable, CaseIterable {
    case healthy
    case warning
    case noRecentHeartbeat
    case unknown

    var title: String {
        switch self {
        case .healthy: "Healthy"
        case .warning: "Warning"
        case .noRecentHeartbeat: "No recent heartbeat"
        case .unknown: "Unknown"
        }
    }

    var symbol: String {
        switch self {
        case .healthy: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .noRecentHeartbeat: "xmark.circle.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}
