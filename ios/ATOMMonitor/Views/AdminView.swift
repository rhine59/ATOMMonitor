import SwiftUI
import Security
import LocalAuthentication

private struct AdminSummary: Decodable {
    struct Replicas: Decodable { let running: Int; let healthy: Int }
    struct Container: Decodable, Identifiable {
        var id: String { name }
        let service: String; let name: String; let state: String; let health: String
        let cpuPercent: Double?; let memoryUsedBytes: Int64?
    }
    let status: String; let apiReplicas: Replicas; let containers: [Container]
}
private struct ScaleResult: Decodable { let previousReplicas: Int; let requestedReplicas: Int; let runningReplicas: Int; let healthyReplicas: Int }
private struct PairResult: Decodable { let deviceToken: String; let deviceName: String }

private enum AdminKeychain {
    static let service="uk.co.rhine59.ATOMMonitor.admin", account="device-credential"
    static func load()->String {
        let query:[String:Any]=[kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var value:CFTypeRef?; guard SecItemCopyMatching(query as CFDictionary,&value)==errSecSuccess,let data=value as? Data else{return ""}
        return String(data:data,encoding:.utf8) ?? ""
    }
    static func save(_ value:String){delete();guard let data=value.data(using:.utf8) else{return};SecItemAdd([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account,kSecValueData as String:data] as CFDictionary,nil)}
    static func delete(){SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:account] as CFDictionary)}
}

@MainActor private final class AdminModel:ObservableObject {
    @Published var token=AdminKeychain.load(), pairingCode=""
    @Published var summary:AdminSummary?; @Published var busy=false; @Published var message:String?; @Published var target=2
    private var baseURL:String{UserDefaults.standard.string(forKey:ServerConfiguration.key) ?? ATOMMonitorApp.defaultServerURL}
    private func request(_ path:String,method:String="GET",body:Data?=nil) async throws->Data {
        let base=baseURL.hasSuffix("/") ? baseURL:baseURL+"/"; guard let url=URL(string:base+path) else{throw URLError(.badURL)}
        var req=URLRequest(url:url);req.httpMethod=method;req.timeoutInterval=75;req.httpBody=body
        if !token.isEmpty{req.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")}
        req.setValue("application/json",forHTTPHeaderField:"Content-Type");req.setValue("ios-admin",forHTTPHeaderField:"X-ATOM-Admin-Actor")
        let(data,response)=try await URLSession.shared.data(for:req);let code=(response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else{throw NSError(domain:"ATOMAdmin",code:code,userInfo:[NSLocalizedDescriptionKey:"Admin request failed (HTTP \(code))"])}
        return data
    }
    func pairDevice() async {busy=true;defer{busy=false};do{let body=try JSONSerialization.data(withJSONObject:["code":pairingCode,"deviceName":"iPhone"]);let result=try JSONDecoder().decode(PairResult.self,from:try await request("api/v1/admin/pair/exchange",method:"POST",body:body));token=result.deviceToken;AdminKeychain.save(token);pairingCode="";message=nil;await unlock()}catch{message=error.localizedDescription}}
    func unlock() async {guard !token.isEmpty else{return};let context=LAContext();var error:NSError?;guard context.canEvaluatePolicy(.deviceOwnerAuthentication,error:&error) else{message="Device authentication is unavailable.";return};do{if try await context.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"Unlock ATOMMonitor administration"){await refresh()}}catch{message=error.localizedDescription}}
    func refresh() async {guard !token.isEmpty else{return};busy=true;defer{busy=false};do{summary=try JSONDecoder().decode(AdminSummary.self,from:try await request("api/v1/admin/summary"));target=summary?.apiReplicas.running ?? 2;message=nil}catch{summary=nil;message=error.localizedDescription}}
    func scale() async {busy=true;defer{busy=false};do{let body=try JSONSerialization.data(withJSONObject:["replicas":target,"confirmed":true]);let result=try JSONDecoder().decode(ScaleResult.self,from:try await request("api/v1/admin/api-scale",method:"POST",body:body));await refresh();message="Scaled \(result.previousReplicas) → \(result.runningReplicas); \(result.healthyReplicas) healthy"}catch{message=error.localizedDescription}}
    func lock(){summary=nil;message=nil}
    func removeAccess() async {if !token.isEmpty{_=try? await request("api/v1/admin/device",method:"DELETE")};AdminKeychain.delete();token="";summary=nil;message=nil}
}

struct AdminView:View {
    @StateObject private var model=AdminModel();@State private var confirming=false
    var body:some View {
        content.navigationTitle("Admin").overlay{progressOverlay}.task{if !model.token.isEmpty{await model.unlock()}}
            .confirmationDialog("Scale API to \(model.target) replicas?",isPresented:$confirming,titleVisibility:.visible){Button("Apply \(model.target) replicas",role:.destructive){Task{await model.scale()}};Button("Cancel",role:.cancel){}}message:{Text("Only atom-api will change. The server waits for all requested replicas to become healthy.")}
    }
    @ViewBuilder private var content:some View {if let summary=model.summary{summaryView(summary)}else{lockedView}}
    private func summaryView(_ summary:AdminSummary)->some View {List{apiSection(summary);containersSection(summary.containers);if let message=model.message{Section{Text(message)}};Section{Button("Refresh"){Task{await model.refresh()}};Button("Lock Admin"){model.lock()};Button("Remove administrator access",role:.destructive){Task{await model.removeAccess()}}}}.refreshable{await model.refresh()}}
    private func apiSection(_ summary:AdminSummary)->some View {Section("API service"){LabeledContent("Running",value:"\(summary.apiReplicas.running)");LabeledContent("Healthy",value:"\(summary.apiReplicas.healthy)");Stepper("Target replicas: \(model.target)",value:$model.target,in:1...4);Button("Apply change",role:.destructive){confirming=true}.disabled(model.busy || model.target==summary.apiReplicas.running)}}
    private func containersSection(_ containers:[AdminSummary.Container])->some View {Section("ATOM Monitor containers"){ForEach(containers){item in containerRow(item)}}}
    private func containerRow(_ item:AdminSummary.Container)->some View {VStack(alignment:.leading,spacing:4){HStack{Text(item.name).font(.headline);Spacer();Text(item.health).foregroundStyle(item.health=="healthy" ? Color.green:Color.orange)};Text("\(item.service) • \(item.state)").font(.caption).foregroundStyle(.secondary);resourceUsage(item)}}
    @ViewBuilder private func resourceUsage(_ item:AdminSummary.Container)->some View {if let cpu=item.cpuPercent,let memory=item.memoryUsedBytes{Text(String(format:"CPU %.1f%% • Memory %.1f MB",cpu,Double(memory)/1_048_576)).font(.caption)}}
    private var lockedView:some View {Form{Section("Restricted administration"){pairingControls};if let message=model.message{Section{Text(message).foregroundStyle(.red)}}}}
    @ViewBuilder private var pairingControls:some View {if model.token.isEmpty{TextField("One-time pairing code",text:$model.pairingCode).textInputAutocapitalization(.characters).autocorrectionDisabled();Button("Pair this device"){Task{await model.pairDevice()}}.disabled(model.pairingCode.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || model.busy);Text("On a computer connected to your home network, open the server address followed by /api/v1/admin/pair. Enter the displayed code here; it expires after five minutes.").font(.caption).foregroundStyle(.secondary)}else{Button("Unlock with Face ID or passcode"){Task{await model.unlock()}};Button("Remove administrator access",role:.destructive){Task{await model.removeAccess()}};Text("This iPhone is paired. Its private credential is stored in the Keychain.").font(.caption).foregroundStyle(.secondary)}}
    @ViewBuilder private var progressOverlay:some View {if model.busy{ProgressView().controlSize(.large)}}
}
