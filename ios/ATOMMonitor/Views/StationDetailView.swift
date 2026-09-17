import SwiftUI

struct StationDetailView: View {
    let station: ATOMStation

    var body: some View {
        List {
            Section("Health") {
                LabeledContent("Status", value: station.health.title)
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
