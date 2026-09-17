import SwiftUI

enum MapIconColour: String, CaseIterable, Identifiable {
    case green, purple, blue, red, orange, gray, yellow, teal, pink, indigo

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .green: return .green
        case .purple: return .purple
        case .blue: return .blue
        case .red: return .red
        case .orange: return .orange
        case .gray: return .gray
        case .yellow: return .yellow
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }
}

enum MapIconColourPreferences {
    static let healthyKey = "mapIconColourHealthy"
    static let backLevelKey = "mapIconColourBackLevel"
    static let noRecentHeartbeatKey = "mapIconColourNoRecentHeartbeat"
    static let inactiveKey = "mapIconColourInactive"
    static let warningKey = "mapIconColourWarning"
    static let unknownKey = "mapIconColourUnknown"

    static let defaults: [(key: String, colour: MapIconColour)] = [
        (healthyKey, .green),
        (backLevelKey, .purple),
        (noRecentHeartbeatKey, .blue),
        (inactiveKey, .red),
        (warningKey, .orange),
        (unknownKey, .gray)
    ]

    static func colour(forKey key: String, fallback: MapIconColour) -> Color {
        let raw = UserDefaults.standard.string(forKey: key) ?? fallback.rawValue
        return (MapIconColour(rawValue: raw) ?? fallback).color
    }

    static func restoreDefaults() {
        for item in defaults { UserDefaults.standard.set(item.colour.rawValue, forKey: item.key) }
    }
}
