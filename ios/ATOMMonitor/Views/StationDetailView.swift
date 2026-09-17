import SwiftUI

struct StationDetailView: View {
    let station: ATOMStation
    var displayHealth: StationHealth? = nil
    var isBackLevelSoftware: Bool = false

    @AppStorage(MapIconColourPreferences.healthyKey) private var healthyColour = MapIconColour.green.rawValue
    @AppStorage(MapIconColourPreferences.backLevelKey) private var backLevelColour = MapIconColour.purple.rawValue
    @AppStorage(MapIconColourPreferences.noRecentHeartbeatKey) private var noRecentHeartbeatColour = MapIconColour.blue.rawValue
    @AppStorage(MapIconColourPreferences.inactiveKey) private var inactiveColour = MapIconColour.red.rawValue
    @AppStorage(MapIconColourPreferences.warningKey) private var warningColour = MapIconColour.orange.rawValue
    @AppStorage(MapIconColourPreferences.unknownKey) private var unknownColour = MapIconColour.gray.rawValue

    private var effectiveHealth: StationHealth { displayHealth ?? station.health }

    var body: some View {
        List {
            Section("Health") {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: effectiveHealth.symbol)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(iconColour, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .accessibilityLabel(iconTitle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(iconTitle).font(.headline)
                        Text(iconExplanation).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                LabeledContent("Status", value: effectiveHealth.title)
                LabeledContent("Record date & time", value: absolute(station.lastSeen))
                LabeledContent("Last heartbeat", value: relative(station.lastHeartbeat))
                LabeledContent("Last seen", value: relative(station.lastSeen))
                LabeledContent("Last position", value: relative(station.lastPosition))
                LabeledContent("Last technical status", value: relative(station.lastTechnicalStatus))
            }

            Section("Station") {
                LabeledContent("Station ID", value: station.id)
                LabeledContent("PilotAware version", value: station.pilotAwareVersion ?? "Not reported")
                LabeledContent("Receiver software", value: station.softwareVersion ?? "Not reported")
            }

            Section("Location") {
                LabeledContent("Latitude", value: coordinate(station.latitude))
                LabeledContent("Longitude", value: coordinate(station.longitude))
                LabeledContent("Altitude", value: text(station.altitudeMetres, suffix: " m", decimals: 0))
                if let googleMapsURL {
                    Link(destination: googleMapsURL) {
                        Label("View satellite location in Google Maps", systemImage: "mappin.and.ellipse")
                    }
                }
            }

            Section("System") {
                LabeledContent("CPU load", value: text(station.cpuLoadPercent, suffix: "%", decimals: 1))
                LabeledContent("Memory", value: memory)
                LabeledContent("CPU temperature", value: text(station.cpuTemperatureC, suffix: " °C", decimals: 1))
            }

            Section("Time") {
                LabeledContent("NTP offset", value: text(station.ntpOffsetMS, suffix: " ms", decimals: 1))
                LabeledContent("NTP correction", value: text(station.ntpCorrectionPPM, suffix: " ppm", decimals: 1))
            }

            Section("Radio") {
                LabeledContent("RF correction", value: text(station.rfCorrectionPPM, suffix: " ppm", decimals: 1))
                LabeledContent("Signal quality", value: text(station.signalQualityDB, suffix: " dB", decimals: 1))
            }
        }
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var iconTitle: String {
        isBackLevelSoftware && effectiveHealth == .healthy ? "Healthy — back-level software" : effectiveHealth.title
    }

    private var iconExplanation: String {
        if isBackLevelSoftware && effectiveHealth == .healthy {
            return "The station is operational, but its reported PilotAware software version is older than the newest version currently seen by ATOM Monitor."
        }
        switch effectiveHealth {
        case .healthy: return "A recent PilotAware heartbeat has been received and no operational warning is currently indicated."
        case .warning: return "The station is reporting, but its heartbeat is becoming stale or reported telemetry indicates a warning condition."
        case .noRecentHeartbeat: return "No PilotAware heartbeat has been received within the recent-heartbeat threshold."
        case .inactive: return "The station's latest record is older than the configured Inactive after period."
        case .unknown: return "There is not enough recent station information to determine its operational health."
        }
    }

    private var iconColour: Color {
        if isBackLevelSoftware && effectiveHealth == .healthy { return selected(backLevelColour, .purple) }
        switch effectiveHealth {
        case .healthy: return selected(healthyColour, .green)
        case .warning: return selected(warningColour, .orange)
        case .noRecentHeartbeat: return selected(noRecentHeartbeatColour, .blue)
        case .inactive: return selected(inactiveColour, .red)
        case .unknown: return selected(unknownColour, .gray)
        }
    }

    private func selected(_ raw: String, _ fallback: MapIconColour) -> Color {
        (MapIconColour(rawValue: raw) ?? fallback).color
    }

    private var googleMapsURL: URL? {
        guard let latitude = station.latitude, let longitude = station.longitude else { return nil }
        var components = URLComponents(string: "https://www.google.com/maps")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "t", value: "k"),
            URLQueryItem(name: "z", value: "18")
        ]
        return components?.url
    }

    private var memory: String {
        guard let used = station.ramUsedMB, let total = station.ramTotalMB else { return "Not reported" }
        return String(format: "%.0f / %.0f MB", used, total)
    }

    private func coordinate(_ value: Double?) -> String {
        guard let value else { return "Not reported" }
        return String(format: "%.5f°", value)
    }

    private func text(_ value: Double?, suffix: String, decimals: Int) -> String {
        guard let value else { return "Not reported" }
        return String(format: "%.*f%@", decimals, value, suffix)
    }

    private func relative(_ date: Date?) -> String {
        guard let date else { return "Not reported" }
        return date.formatted(.relative(presentation: .named))
    }

    private func absolute(_ date: Date?) -> String {
        guard let date else { return "Not reported" }
        return date.formatted(date: .abbreviated, time: .standard)
    }
}
