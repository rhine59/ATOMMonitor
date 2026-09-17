import SwiftUI
import UIKit

struct ReportView: View {
    @ObservedObject var store: StationStore
    @State private var sharePayload: SharePayload?
    @State private var reportError: String?

    private struct CountRow: Identifiable {
        let id: String
        let title: String
        let count: Int
    }

    private struct SharePayload: Identifiable {
        let id = UUID()
        let items: [Any]
    }

    private var statusCounts: [CountRow] {
        StationHealth.allCases.map { health in
            CountRow(id: health.rawValue, title: health.title, count: store.stations.filter { store.displayHealth(for: $0) == health }.count)
        }
    }

    private var versionCounts: [CountRow] {
        let groups = Dictionary(grouping: store.stations) { station in
            let value = station.pilotAwareVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? "Not reported" : value
        }
        return groups.map { CountRow(id: $0.key, title: $0.key, count: $0.value.count) }.sorted {
            if $0.title == "Not reported" { return false }
            if $1.title == "Not reported" { return true }
            return $0.title.compare($1.title, options: [.numeric, .caseInsensitive]) == .orderedDescending
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
                ForEach(statusCounts) { row in reportRow(row.title, value: row.count) }
            }

            Section("PilotAware versions") {
                ForEach(versionCounts) { row in reportRow(row.title, value: row.count) }
            }

            Section {
                Button { prepareAndShare() } label: { Label("Share report", systemImage: "square.and.arrow.up") }
                    .disabled(store.stations.isEmpty)
            } footer: {
                Text("Creates a formatted HTML report with bar graphs and a CSV station-data attachment, then opens the standard iPhone share sheet for Mail, Messages, AirDrop, Files and other available services.")
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sharePayload) { payload in
            ActivityView(activityItems: payload.items)
        }
        .alert("Unable to create report", isPresented: Binding(get: { reportError != nil }, set: { if !$0 { reportError = nil } })) {
            Button("OK") { reportError = nil }
        } message: { Text(reportError ?? "Unknown error") }
    }

    private func reportRow(_ title: String, value: Int) -> some View {
        HStack { Text(title); Spacer(); Text(String(value)).fontWeight(.semibold).monospacedDigit() }
    }

    private func prepareAndShare() {
        do {
            let files = try StationReportGenerator.makeReport(store: store)
            // Present from the payload itself so the first UIActivityViewController is
            // created only after both generated file URLs are available.
            sharePayload = SharePayload(items: [files.html, files.csv])
        } catch { reportError = error.localizedDescription }
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
        let statusChart = barChart(statuses, total: max(store.stations.count, 1))
        let versionChart = barChart(versions, total: max(store.stations.count, 1))
        let updated = store.lastSuccessfulRefresh?.formatted(date: .abbreviated, time: .standard) ?? "Not reported"
        let generated = now.formatted(date: .long, time: .standard)

        let html = """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#f3f5f7;color:#17202a;margin:0;padding:24px}.card{max-width:720px;margin:auto;background:white;border-radius:18px;padding:24px;box-shadow:0 4px 18px rgba(0,0,0,.08)}h1{margin:0 0 4px;font-size:28px}h2{margin-top:28px;font-size:19px;color:#334155}.meta{color:#64748b;font-size:14px;margin-bottom:20px}.total{font-size:38px;font-weight:700;margin:10px 0 2px}.caption{color:#64748b}table{width:100%;border-collapse:collapse;margin-top:8px}td{padding:10px 8px;border-bottom:1px solid #e5e7eb}.number{text-align:right;font-weight:700}.chart{margin:14px 0 20px}.barrow{display:grid;grid-template-columns:minmax(110px,1.35fr) minmax(120px,3fr) 42px;gap:10px;align-items:center;margin:9px 0}.barlabel{font-size:13px;overflow-wrap:anywhere}.bartrack{height:18px;background:#e8edf3;border-radius:9px;overflow:hidden}.barfill{height:100%;min-width:0;background:linear-gradient(90deg,#2563eb,#60a5fa);border-radius:9px}.barvalue{text-align:right;font-weight:700;font-variant-numeric:tabular-nums}.footer{margin-top:28px;color:#64748b;font-size:12px}@media(max-width:520px){body{padding:10px}.card{padding:18px;border-radius:12px}.barrow{grid-template-columns:minmax(90px,1.2fr) minmax(80px,2fr) 36px;gap:7px}}
        </style></head>
        <body><div class="card"><h1>ATOM Monitor Report</h1><div class="meta">Generated \(htmlEscape(generated))</div><div class="total">\(store.stations.count)</div><div class="caption">ground stations in the current dataset</div><div class="caption">Data last updated: \(htmlEscape(updated))</div><h2>Status</h2><div class="chart">\(statusChart)</div><table>\(statusRows)</table><h2>PilotAware versions</h2><div class="chart">\(versionChart)</div><table>\(versionRows)</table><div class="footer">ATOM Monitor reports PilotAware ATOM ground-station operational health only. It does not display or record aircraft movements. A CSV containing the station-level data used for this report is supplied separately.</div></div></body></html>
        """
        try html.write(to: htmlURL, atomically: true, encoding: .utf8)

        var csv = "Station,Status,PilotAware Version,Last Seen,Last Heartbeat,Last Position,Last Technical Status,Latitude,Longitude\r\n"
        for station in store.stations.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let values: [String] = [
                station.name,
                store.displayHealth(for: station).title,
                station.pilotAwareVersion ?? "Not reported",
                csvDate(station.lastSeen), csvDate(station.lastHeartbeat), csvDate(station.lastPosition), csvDate(station.lastTechnicalStatus),
                station.latitude.map { String($0) } ?? "",
                station.longitude.map { String($0) } ?? ""
            ]
            csv += values.map(csvEscape).joined(separator: ",") + "\r\n"
        }
        try csv.write(to: csvURL, atomically: true, encoding: .utf8)
        return Files(html: htmlURL, csv: csvURL)
    }

    private static func barChart(_ rows: [(String, Int)], total: Int) -> String {
        rows.map { title, count in
            let percentage = min(100, max(0, Double(count) / Double(total) * 100))
            let width = String(format: "%.2f", percentage)
            return "<div class=\"barrow\"><div class=\"barlabel\">\(htmlEscape(title))</div><div class=\"bartrack\"><div class=\"barfill\" style=\"width:\(width)%\"></div></div><div class=\"barvalue\">\(count)</div></div>"
        }.joined()
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
