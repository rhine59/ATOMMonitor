import SwiftUI
import UIKit

struct ReportView: View {
    @ObservedObject var store: StationStore
    @State private var shareItems: [Any] = []
    @State private var showingShareSheet = false
    @State private var reportError: String?

    private var statusCounts: [(StationHealth, Int)] {
        StationHealth.allCases.map { health in
            (health, store.stations.filter { store.displayHealth(for: $0) == health }.count)
        }
    }

    private var versionCounts: [(String, Int)] {
        let groups = Dictionary(grouping: store.stations) { station in
            let value = station.pilotAwareVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? "Not reported" : value
        }
        return groups.map { ($0.key, $0.value.count) }.sorted {
            if $0.0 == "Not reported" { return false }
            if $1.0 == "Not reported" { return true }
            return $0.0.compare($1.0, options: [.numeric, .caseInsensitive]) == .orderedDescending
        }
    }

    var body: some View {
        List {
            Section("Summary") {
                reportRow("Total stations", value: store.stations.count)
                if let updated = store.lastSuccessfulRefresh {
                    LabeledContent("Data updated", value: updated.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Status") {
                ForEach(statusCounts, id: \.0) { health, count in
                    reportRow(health.title, value: count)
                }
            }

            Section("PilotAware versions") {
                ForEach(versionCounts, id: \.0) { version, count in
                    reportRow(version, value: count)
                }
            }

            Section {
                Button {
                    prepareAndShare()
                } label: {
                    Label("Share report", systemImage: "square.and.arrow.up")
                }
                .disabled(store.stations.isEmpty)
            } footer: {
                Text("Creates a formatted HTML report and a CSV station-data attachment, then opens the standard iPhone share sheet for Mail, Messages, AirDrop, Files and other available services.")
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            ActivityView(activityItems: shareItems)
        }
        .alert("Unable to create report", isPresented: Binding(get: { reportError != nil }, set: { if !$0 { reportError = nil } })) {
            Button("OK") { reportError = nil }
        } message: {
            Text(reportError ?? "Unknown error")
        }
    }

    private func reportRow(_ title: String, value: Int) -> some View {
        HStack { Text(title); Spacer(); Text(String(value)).fontWeight(.semibold).monospacedDigit() }
    }

    private func prepareAndShare() {
        do {
            let files = try StationReportGenerator.makeReport(store: store)
            shareItems = [files.html, files.csv]
            showingShareSheet = true
        } catch {
            reportError = error.localizedDescription
        }
    }
}

private enum StationReportGenerator {
    struct Files { let html: URL; let csv: URL }

    @MainActor
    static func makeReport(store: StationStore, now: Date = Date()) throws -> Files {
        let statuses = StationHealth.allCases.map { health in
            (health.title, store.stations.filter { store.displayHealth(for: $0) == health }.count)
        }
        let versions = Dictionary(grouping: store.stations) { station -> String in
            let value = station.pilotAwareVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? "Not reported" : value
        }.map { ($0.key, $0.value.count) }.sorted {
            if $0.0 == "Not reported" { return false }
            if $1.0 == "Not reported" { return true }
            return $0.0.compare($1.0, options: [.numeric, .caseInsensitive]) == .orderedDescending
        }

        let stamp = fileStamp(now)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ATOMMonitorReport-\(stamp)", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let htmlURL = directory.appendingPathComponent("ATOM-Monitor-Report-\(stamp).html")
        let csvURL = directory.appendingPathComponent("ATOM-Monitor-Stations-\(stamp).csv")

        let statusRows = statuses.map { "<tr><td>\(htmlEscape($0.0))</td><td class=\"number\">\($0.1)</td></tr>" }.joined()
        let versionRows = versions.map { "<tr><td>\(htmlEscape($0.0))</td><td class=\"number\">\($0.1)</td></tr>" }.joined()
        let updated = store.lastSuccessfulRefresh?.formatted(date: .abbreviated, time: .standard) ?? "Not reported"
        let generated = now.formatted(date: .long, time: .standard)

        let html = """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f3f5f7;color:#17202a;margin:0;padding:24px}.card{max-width:720px;margin:auto;background:white;border-radius:18px;padding:24px;box-shadow:0 4px 18px rgba(0,0,0,.08)}h1{margin:0 0 4px;font-size:28px}h2{margin-top:28px;font-size:19px;color:#334155}.meta{color:#64748b;font-size:14px;margin-bottom:20px}.total{font-size:38px;font-weight:700;margin:10px 0 2px}.caption{color:#64748b}table{width:100%;border-collapse:collapse;margin-top:8px}td{padding:10px 8px;border-bottom:1px solid #e5e7eb}.number{text-align:right;font-weight:700}.footer{margin-top:28px;color:#64748b;font-size:12px}</style></head>
        <body><div class="card"><h1>ATOM Monitor Report</h1><div class="meta">Generated \(htmlEscape(generated))</div><div class="total">\(store.stations.count)</div><div class="caption">ground stations in the current dataset</div><div class="caption">Data last updated: \(htmlEscape(updated))</div><h2>Status</h2><table>\(statusRows)</table><h2>PilotAware versions</h2><table>\(versionRows)</table><div class="footer">ATOM Monitor reports PilotAware ATOM ground-station operational health only. It does not display or record aircraft movements. A CSV containing the station-level data used for this report is supplied separately.</div></div></body></html>
        """
        try html.write(to: htmlURL, atomically: true, encoding: .utf8)

        var csv = "Station,Status,PilotAware Version,Last Seen,Last Heartbeat,Last Position,Last Technical Status,Latitude,Longitude\r\n"
        for station in store.stations.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let values = [
                station.name,
                store.displayHealth(for: station).title,
                station.pilotAwareVersion ?? "Not reported",
                csvDate(station.lastSeen), csvDate(station.lastHeartbeat), csvDate(station.lastPosition), csvDate(station.lastTechnicalStatus),
                station.latitude.map(String.init) ?? "", station.longitude.map(String.init) ?? ""
            ]
            csv += values.map(csvEscape).joined(separator: ",") + "\r\n"
        }
        try csv.write(to: csvURL, atomically: true, encoding: .utf8)
        return Files(html: htmlURL, csv: csvURL)
    }

    private static func csvDate(_ date: Date?) -> String { date?.ISO8601Format() ?? "Not reported" }
    private static func csvEscape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
    private static func htmlEscape(_ value: String) -> String { value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;") }
    private static func fileStamp(_ date: Date) -> String { let f=DateFormatter();f.locale=Locale(identifier:"en_US_POSIX");f.dateFormat="yyyyMMdd-HHmmss";return f.string(from:date) }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
