import SwiftUI
import UIKit

struct FeedbackView: View {
    @State private var rating = 0
    @State private var comments = ""
    @State private var sending = false
    @State private var result: String?

    var body: some View {
        Form {
            Section("Your rating") {
                HStack {
                    ForEach(1...5, id: \.self) { value in
                        Button { rating = value } label: {
                            Image(systemName: value <= rating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                        }.buttonStyle(.plain)
                    }
                }
                .accessibilityLabel(rating == 0 ? "No rating selected" : "\(rating) out of 5 stars")
            }
            Section("Comments or suggestions") {
                TextEditor(text: $comments).frame(minHeight: 140)
                Text("Your feedback is sent privately to Richard Hine. The destination email address is not shown by the app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Button {
                    Task { await send() }
                } label: {
                    if sending { ProgressView() } else { Label("Send Feedback", systemImage: "paperplane") }
                }
                .disabled(rating == 0 || sending)
                if let result { Text(result).font(.caption) }
            }
        }
        .navigationTitle("Feedback")
    }

    @MainActor private func send() async {
        sending = true; result = nil
        defer { sending = false }
        do {
            let base = try ServerConfiguration.normalizedURL(from: ServerConfiguration.configuredURLString)
            var request = URLRequest(url: base.appending(path: "api/v1/feedback"))
            request.httpMethod = "POST"; request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "rating": rating, "comments": comments, "platform": "iPhone",
                "version": "\(version) (\(build))", "osVersion": UIDevice.current.systemVersion
            ])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw FeedbackError.sendFailed }
            result = "Thank you. Your feedback has been sent to Richard Hine."
            comments = ""
        } catch {
            result = "Feedback could not be sent. Please try again later."
        }
    }
}

struct AboutView: View {
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown" }
    private var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown" }

    var body: some View {
        List {
            Section("ATOM Monitor") {
                Text("Monitors the operational health and technical status of PilotAware ATOM ground stations.")
                LabeledContent("Version", value: version)
                LabeledContent("Build", value: build)
                LabeledContent("Version / Build", value: "\(version) (\(build))")
                LabeledContent("Platform", value: "iPhone / iOS \(UIDevice.current.systemVersion)")
            }
            Section("Credits") {
                LabeledContent("Created by", value: "Richard Hine")
                Text("PilotAware and ATOM are acknowledged as the technologies and ground-station network monitored by this application.")
            }
            Section("Privacy and scope") {
                Text("ATOM Monitor does not display, record or retain aircraft movements, tracks or aircraft identities.")
                Text("Feedback is sent privately to Richard Hine. The feedback destination email address is not displayed by the app.")
            }
        }
        .navigationTitle("About")
    }
}

private enum FeedbackError: Error { case sendFailed }
