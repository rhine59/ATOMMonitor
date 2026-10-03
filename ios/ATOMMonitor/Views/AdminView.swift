import SwiftUI
import Security

private struct AdminSummary: Decodable {
    struct Replicas: Decodable { let running: Int; let healthy: Int }
    struct Container: Decodable, Identifiable {
        var id: String { name }
        let service: String; let name: String; let state: String; let health: String
        let cpuPercent: Double?; let memoryUsedBytes: Int64?
    }
    let status: String; let apiReplicas: Replicas; let containers: [Container]
}

private struct ScaleResult: Decodable {
    let previousReplicas: Int; let requestedReplicas: Int; let runningReplicas: Int; let healthyReplicas: Int
}

private enum AdminKeychain {
    static let service = "uk.co.rhine59.ATOMMonitor.admin"
    static let account = "ATOM_ADMIN_TOKEN"
    static func load() -> String {
        let query: [String: Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,
            kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var value: CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary,&value)==errSecSuccess,
            let data=value as? Data else{return ""}; return String(data:data,encoding:.utf8) ?? ""
    }
    static func save(_ token: String) {
        delete(); guard let data=token.data(using:.utf8) else{return}
        SecItemAdd([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,
            kSecAttrAccount as String:account,kSecValueData as String:data] as CFDictionary,nil)
    }
    static func delete() {
        SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,
            kSecAttrAccount as String:account] as CFDictionary)
    }
}

@MainActor private final class AdminModel: ObservableObject {
    @Published var token=AdminKeychain.load(); @Published var summary:AdminSummary?
    @Published var busy=false; @Published var message:String?; @Published var target=2
    private var baseURL:String { UserDefaults.standard.string(forKey:ServerConfiguration.key) ?? ATOMMonitorApp.defaultServerURL }
    private func request(_ path:String,method:String="GET",body:Data?=nil) async throws -> Data {
        let base=baseURL.hasSuffix("/") ? baseURL : baseURL+"/"
        guard let url=URL(string:base+path) else{throw URLError(.badURL)}
        var req=URLRequest(url:url); req.httpMethod=method; req.timeoutInterval=75
        req.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization"); req.setValue("application/json",forHTTPHeaderField:"Content-Type")
        req.setValue("ios-admin",forHTTPHeaderField:"X-ATOM-Admin-Actor"); req.httpBody=body
        let (data,response)=try await URLSession.shared.data(for:req)
        guard let http=response as? HTTPURLResponse,(200..<300).contains(http.statusCode) else {
            let code=(response as? HTTPURLResponse)?.statusCode ?? 0; throw NSError(domain:"ATOMAdmin",code:code,userInfo:[NSLocalizedDescriptionKey:"Admin request failed (HTTP \(code))"])
        }
        return data
    }
    func authenticate() async { AdminKeychain.save(token); await refresh() }
    func refresh() async {
        guard !token.isEmpty else{return}; busy=true; defer{busy=false}
        do { let data=try await request("api/v1/admin/summary"); summary=try JSONDecoder().decode(AdminSummary.self,from:data)
            target=summary?.apiReplicas.running ?? 2; message=nil }
        catch { summary=nil; message=error.localizedDescription }
    }
    func scale() async {
        busy=true; defer{busy=false}
        do { let data=try JSONSerialization.data(withJSONObject:["replicas":target,"confirmed":true])
            let result=try JSONDecoder().decode(ScaleResult.self,from:try await request("api/v1/admin/api-scale",method:"POST",body:data))
            await refresh(); message="Scaled \(result.previousReplicas) → \(result.runningReplicas); \(result.healthyReplicas) healthy" }
        catch { message=error.localizedDescription }
    }
    func logout(){AdminKeychain.delete();token="";summary=nil;message=nil}
}

struct AdminView: View {
    @StateObject private var model = AdminModel()
    @State private var confirming = false

    var body: some View {
        content
            .navigationTitle("Admin")
            .overlay { progressOverlay }
            .task {
                if !model.token.isEmpty {
                    await model.refresh()
                }
            }
            .confirmationDialog(
                "Scale API to \(model.target) replicas?",
                isPresented: $confirming,
                titleVisibility: .visible
            ) {
                Button("Apply \(model.target) replicas", role: .destructive) {
                    Task { await model.scale() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Only atom-api will change. The server waits for all requested replicas to become healthy.")
            }
    }

    @ViewBuilder
    private var content: some View {
        if let summary = model.summary {
            summaryView(summary)
        } else {
            lockedView
        }
    }

    private func summaryView(_ summary: AdminSummary) -> some View {
        List {
            apiSection(summary)
            containersSection(summary.containers)

            if let message = model.message {
                Section {
                    Text(message)
                }
            }

            Section {
                Button("Refresh") {
                    Task { await model.refresh() }
                }
                Button("Lock Admin", role: .destructive) {
                    model.logout()
                }
            }
        }
        .refreshable {
            await model.refresh()
        }
    }

    private func apiSection(_ summary: AdminSummary) -> some View {
        Section("API service") {
            LabeledContent("Running", value: "\(summary.apiReplicas.running)")
            LabeledContent("Healthy", value: "\(summary.apiReplicas.healthy)")
            Stepper(
                "Target replicas: \(model.target)",
                value: $model.target,
                in: 1...4
            )
            Button("Apply change", role: .destructive) {
                confirming = true
            }
            .disabled(model.busy || model.target == summary.apiReplicas.running)
        }
    }

    private func containersSection(_ containers: [AdminSummary.Container]) -> some View {
        Section("ATOM Monitor containers") {
            ForEach(containers) { item in
                containerRow(item)
            }
        }
    }

    private func containerRow(_ item: AdminSummary.Container) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                Text(item.health)
                    .foregroundStyle(item.health == "healthy" ? Color.green : Color.orange)
            }

            Text("\(item.service) • \(item.state)")
                .font(.caption)
                .foregroundStyle(.secondary)

            resourceUsage(item)
        }
    }

    @ViewBuilder
    private func resourceUsage(_ item: AdminSummary.Container) -> some View {
        if let cpu = item.cpuPercent, let memory = item.memoryUsedBytes {
            Text(
                String(
                    format: "CPU %.1f%% • Memory %.1f MB",
                    cpu,
                    Double(memory) / 1_048_576
                )
            )
            .font(.caption)
        }
    }

    private var lockedView: some View {
        Form {
            Section("Restricted administration") {
                SecureField("Administrator token", text: $model.token)
                    .textContentType(.password)

                Button("Unlock") {
                    Task { await model.authenticate() }
                }
                .disabled(model.token.isEmpty || model.busy)

                Text("The administrator token is stored in the iPhone Keychain and is separate from the collector token.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let message = model.message {
                Section {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var progressOverlay: some View {
        if model.busy {
            ProgressView()
                .controlSize(.large)
        }
    }
}
