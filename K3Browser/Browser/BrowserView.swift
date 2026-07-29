import SwiftUI
import WebKit
import UIKit
import Security

// MARK: - Page perception

struct PageLink: Identifiable, Codable {
    let id = UUID()
    let text: String
    let href: String
    let selector: String
}

struct PageFormField: Identifiable, Codable {
    let id = UUID()
    let selector: String
    let tag: String
    let type: String
    let name: String
    let label: String
    let placeholder: String
    let valuePreview: String
    let required: Bool
}

struct PageForm: Identifiable, Codable {
    let id = UUID()
    let selector: String
    let action: String
    let method: String
    let fields: [PageFormField]
}

struct PageTable: Identifiable, Codable {
    let id = UUID()
    let selector: String
    let headers: [String]
    let rows: [[String]]
}

struct DOMElement: Identifiable, Codable {
    let id = UUID()
    let selector: String
    let tag: String
    let text: String
    let ariaLabel: String
    let role: String
    let type: String
    let name: String
    let placeholder: String
    let isVisible: Bool
}

struct PageSnapshot: Identifiable, Codable {
    let id = UUID()
    let title: String
    let url: String
    let text: String
    let headings: [DOMElement]
    let buttons: [DOMElement]
    let inputs: [DOMElement]
    let links: [PageLink]
    let forms: [PageForm]
    let tables: [PageTable]
    let capturedAt: Date = Date()

    var summaryText: String {
        let clippedText = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(9000))
        let headingBlock = headings.prefix(25).map { "- \($0.text) [\($0.selector)]" }.joined(separator: "\n")
        let linkBlock = links.prefix(40).enumerated().map { "\($0.offset + 1). \($0.element.text) → \($0.element.href) [\($0.element.selector)]" }.joined(separator: "\n")
        let inputBlock = inputs.prefix(40).map { "- \($0.type) \($0.name) \($0.placeholder) [\($0.selector)]" }.joined(separator: "\n")
        let formBlock = forms.prefix(10).map { form in
            let fields = form.fields.map { "  - \($0.type) \($0.name) \($0.placeholder) [\($0.selector)]" }.joined(separator: "\n")
            return "FORM \(form.selector) \(form.method) \(form.action)\n\(fields)"
        }.joined(separator: "\n")
        let tableBlock = tables.prefix(8).map { table in
            let rows = table.rows.prefix(8).map { $0.joined(separator: " | ") }.joined(separator: "\n")
            return "TABLE \(table.selector)\nHeaders: \(table.headers.joined(separator: " | "))\n\(rows)"
        }.joined(separator: "\n")
        return """
        K3 Browser DOM Snapshot V2
        Title: \(title.isEmpty ? "(none)" : title)
        URL: \(url)

        TEXT
        \(clippedText.isEmpty ? "(no readable text)" : clippedText)

        HEADINGS
        \(headingBlock.isEmpty ? "(none)" : headingBlock)

        LINKS
        \(linkBlock.isEmpty ? "(none)" : linkBlock)

        INPUTS
        \(inputBlock.isEmpty ? "(none)" : inputBlock)

        FORMS
        \(formBlock.isEmpty ? "(none)" : formBlock)

        TABLES
        \(tableBlock.isEmpty ? "(none)" : tableBlock)
        """
    }
}

// MARK: - Agent models

enum AgentPhase: Equatable {
    case idle
    case observing
    case thinking
    case awaitingApproval
    case acting(String)
    case done
    case stopped
    case error(String)

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .observing: return "Observing…"
        case .thinking: return "Thinking…"
        case .awaitingApproval: return "Approval needed"
        case .acting(let tool): return "Acting: \(tool)"
        case .done: return "Done"
        case .stopped: return "Stopped"
        case .error: return "Error"
        }
    }
}

enum ToolRisk: String, Codable {
    case auto
    case approval
    case blocked
}

struct ToolCall: Identifiable, Codable {
    let id: String
    let tool: String
    let arguments: [String: String]
    let reason: String
}

struct AgentResponse {
    enum Kind { case final(String); case tool(ToolCall) }
    let kind: Kind
}

enum AgentParseResult {
    case success(AgentResponse)
    case failure(String)
}

struct AgentStep: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let date = Date()
}

struct ApprovalRequest: Identifiable {
    let id = UUID()
    let call: ToolCall
    let risk: ToolRisk
    let preview: String
    let reason: String
}

struct MemoryNote: Identifiable, Codable {
    let id = UUID()
    let title: String
    let body: String
    let url: String
    let createdAt: Date
}

// MARK: - Storage

enum KeychainStore {
    static let service = "com.patternalcreation.k3browser"

    static func save(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data, let string = String(data: data, encoding: .utf8) else { return "" }
        return string
    }
}

final class AgentSettings: ObservableObject {
    @Published var apiKey: String = ""
    @Published var baseURL: String = UserDefaults.standard.string(forKey: "agent.baseURL") ?? "https://api.openai.com/v1/chat/completions"
    @Published var model: String = UserDefaults.standard.string(forKey: "agent.model") ?? "gpt-4o-mini"
    @Published var systemPrompt: String = UserDefaults.standard.string(forKey: "agent.systemPrompt") ?? "You are K3 Browser Hermes-Lite. You control only browser-support tools. Return ONLY JSON: {\"type\":\"final\",\"message\":\"...\"} or {\"type\":\"tool_call\",\"tool\":\"tool_name\",\"arguments\":{...},\"reason\":\"...\"}. Never ask for unsafe actions."
    @Published var status: String = "Not tested"
    @Published var isTesting = false

    init() { apiKey = KeychainStore.load(account: "agent.apiKey") }

    func save() {
        _ = KeychainStore.save(apiKey, account: "agent.apiKey")
        UserDefaults.standard.set(baseURL, forKey: "agent.baseURL")
        UserDefaults.standard.set(model, forKey: "agent.model")
        UserDefaults.standard.set(systemPrompt, forKey: "agent.systemPrompt")
        status = "Saved locally"
    }

    func testConnection() {
        save()
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { status = "Missing API key"; return }
        guard let url = URL(string: baseURL) else { status = "Bad API URL"; return }
        isTesting = true
        status = "Testing..."
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["model": model, "messages": [["role": "user", "content": "Reply with OK only."]], "temperature": 0]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isTesting = false
                if let error = error { self.status = "Failed: \(error.localizedDescription)"; return }
                if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                    let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    self.status = "HTTP \(http.statusCode): \(raw.prefix(120))"
                    return
                }
                self.status = "Connection OK"
            }
        }.resume()
    }
}

enum MemoryStore {
    static func dir() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("K3Browser/Notes", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func save(title: String, body: String, url: String) -> String {
        let safeTitle = title.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression).prefix(50)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let name = "\(formatter.string(from: Date()))-\(safeTitle).md"
        let file = dir().appendingPathComponent(name)
        let content = "# \(title)\n\nSource: \(url)\nDate: \(Date())\n\n\(body)\n"
        try? content.write(to: file, atomically: true, encoding: .utf8)
        return file.lastPathComponent
    }

    static func recent(limit: Int = 8) -> String {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir(), includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let sorted = files.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return da > db
        }.prefix(limit)
        return sorted.map { "- \($0.lastPathComponent)" }.joined(separator: "\n")
    }
}

// MARK: - Browser State

final class BrowserState: NSObject, ObservableObject {
    @Published var address = "https://duckduckgo.com"
    @Published var pageTitle = ""
    @Published var currentURL = ""
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var snapshot: PageSnapshot?
    @Published var agentAnswer = ""
    @Published var isAsking = false
    @Published var commandText = ""
    @Published var phase: AgentPhase = .idle
    @Published var steps: [AgentStep] = []
    @Published var pendingApproval: ApprovalRequest?
    @Published var showCockpit = false
    @Published var showShare = false
    @Published var shareItems: [Any] = []

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private var cancelled = false
    private var stepIndex = 0
    private let maxSteps = 6

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.estimatedProgress = view.estimatedProgress } },
            webView.observe(\.title, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.pageTitle = view.title ?? "" } },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.currentURL = view.url?.absoluteString ?? ""; self?.address = view.url?.absoluteString ?? self?.address ?? "" } },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.canGoBack = view.canGoBack } },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.canGoForward = view.canGoForward } },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.isLoading = view.isLoading } }
        ]
        loadAddress()
    }

    func addStep(_ icon: String, _ title: String, _ detail: String = "") {
        steps.append(AgentStep(icon: icon, title: title, detail: detail))
    }

    func normalizedURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return URL(string: "https://duckduckgo.com") }
        if trimmed.contains(" ") || !trimmed.contains(".") {
            let q = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            return URL(string: "https://duckduckgo.com/?q=\(q)")
        }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") { return URL(string: trimmed) }
        return URL(string: "https://\(trimmed)")
    }

    func loadAddress() { if let url = normalizedURL(address) { webView.load(URLRequest(url: url)) } }
    func back() { if webView.canGoBack { webView.goBack() } }
    func forward() { if webView.canGoForward { webView.goForward() } }
    func reload() { webView.reload() }
    func stopLoading() { webView.stopLoading() }

    func jsLiteral(_ value: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [value])
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(json.dropFirst().dropLast())
    }

    func runJS(_ js: String, completion: @escaping (Result<Any, Error>) -> Void) {
        webView.evaluateJavaScript(js) { value, error in
            if let error = error { completion(.failure(error)) } else { completion(.success(value ?? "")) }
        }
    }

    func extractSnapshot(completion: ((PageSnapshot?) -> Void)? = nil) {
        phase = .observing
        let js = BrowserState.snapshotJS
        runJS(js) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let value):
                    let raw = value as? String ?? "{}"
                    guard let data = raw.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        self.addStep("⚠️", "Snapshot failed", "Bad JS payload")
                        completion?(nil); return
                    }
                    let snap = BrowserState.decodeSnapshot(obj)
                    self.snapshot = snap
                    self.addStep("👁", "Observed page", "\(snap.text.count) chars, \(snap.links.count) links, \(snap.inputs.count) inputs, \(snap.tables.count) tables")
                    completion?(snap)
                case .failure(let error):
                    self.addStep("⚠️", "Snapshot failed", error.localizedDescription)
                    completion?(nil)
                }
            }
        }
    }

    static func decodeSnapshot(_ obj: [String: Any]) -> PageSnapshot {
        func s(_ key: String) -> String { obj[key] as? String ?? "" }
        func element(_ d: [String: Any]) -> DOMElement {
            DOMElement(selector: d["selector"] as? String ?? "", tag: d["tag"] as? String ?? "", text: d["text"] as? String ?? "", ariaLabel: d["ariaLabel"] as? String ?? "", role: d["role"] as? String ?? "", type: d["type"] as? String ?? "", name: d["name"] as? String ?? "", placeholder: d["placeholder"] as? String ?? "", isVisible: d["isVisible"] as? Bool ?? true)
        }
        let headings = (obj["headings"] as? [[String: Any]] ?? []).map(element)
        let buttons = (obj["buttons"] as? [[String: Any]] ?? []).map(element)
        let inputs = (obj["inputs"] as? [[String: Any]] ?? []).map(element)
        let links = (obj["links"] as? [[String: Any]] ?? []).map { PageLink(text: $0["text"] as? String ?? "", href: $0["href"] as? String ?? "", selector: $0["selector"] as? String ?? "") }
        let forms = (obj["forms"] as? [[String: Any]] ?? []).map { f -> PageForm in
            let fields = (f["fields"] as? [[String: Any]] ?? []).map { PageFormField(selector: $0["selector"] as? String ?? "", tag: $0["tag"] as? String ?? "", type: $0["type"] as? String ?? "", name: $0["name"] as? String ?? "", label: $0["label"] as? String ?? "", placeholder: $0["placeholder"] as? String ?? "", valuePreview: $0["valuePreview"] as? String ?? "", required: $0["required"] as? Bool ?? false) }
            return PageForm(selector: f["selector"] as? String ?? "", action: f["action"] as? String ?? "", method: f["method"] as? String ?? "", fields: fields)
        }
        let tables = (obj["tables"] as? [[String: Any]] ?? []).map { t in PageTable(selector: t["selector"] as? String ?? "", headers: t["headers"] as? [String] ?? [], rows: t["rows"] as? [[String]] ?? []) }
        return PageSnapshot(title: s("title"), url: s("url"), text: s("text"), headings: headings, buttons: buttons, inputs: inputs, links: links, forms: forms, tables: tables)
    }

    // MARK: AI + Agent loop

    func askPage(question: String, settings: AgentSettings) {
        extractSnapshot { [weak self] snap in
            guard let self = self, let snap = snap else { return }
            self.isAsking = true
            self.agentAnswer = "Thinking..."
            self.callLLM(messages: [["role": "system", "content": settings.systemPrompt], ["role": "user", "content": "Question: \(question)\n\n\(snap.summaryText)"]], settings: settings) { result in
                DispatchQueue.main.async {
                    self.isAsking = false
                    switch result { case .success(let text): self.agentAnswer = text; case .failure(let e): self.agentAnswer = "Error: \(e.localizedDescription)" }
                }
            }
        }
    }

    func startAgent(command: String, settings: AgentSettings) {
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { phase = .error("Missing API key"); showCockpit = true; return }
        cancelled = false
        stepIndex = 0
        steps.removeAll()
        agentAnswer = ""
        showCockpit = true
        addStep("▶️", "Started", command)
        continueAgent(command: command, settings: settings, previousResult: "")
    }

    func stopAgent() {
        cancelled = true
        pendingApproval = nil
        phase = .stopped
        addStep("⏹", "Stopped by operator")
    }

    func continueAgent(command: String, settings: AgentSettings, previousResult: String) {
        if cancelled { return }
        if stepIndex >= maxSteps { phase = .done; addStep("✅", "Max steps reached"); return }
        stepIndex += 1
        extractSnapshot { [weak self] snap in
            guard let self = self, let snap = snap, !self.cancelled else { return }
            self.phase = .thinking
            let prompt = self.agentPrompt(command: command, snapshot: snap, previousResult: previousResult)
            self.addStep("💭", "Thinking", "Step \(self.stepIndex)/\(self.maxSteps)")
            self.callLLM(messages: [["role": "system", "content": settings.systemPrompt], ["role": "user", "content": prompt]], settings: settings) { result in
                DispatchQueue.main.async {
                    guard !self.cancelled else { return }
                    switch result {
                    case .failure(let error):
                        self.phase = .error(error.localizedDescription); self.addStep("⚠️", "LLM error", error.localizedDescription)
                    case .success(let content):
                        self.handleAgentResponse(content, command: command, settings: settings)
                    }
                }
            }
        }
    }

    func handleAgentResponse(_ content: String, command: String, settings: AgentSettings) {
        switch parseAgentResponse(content) {
        case .failure(let error):
            phase = .error(error); addStep("⚠️", "Parser error", error + "\nRaw: \(String(content.prefix(500)))")
        case .success(let response):
            switch response.kind {
            case .final(let message):
                agentAnswer = message; phase = .done; addStep("✅", "Final", message)
            case .tool(let call):
                let risk = classify(call)
                if risk == .blocked { phase = .done; addStep("⛔️", "Blocked", "\(call.tool): \(blockReason(call))"); return }
                if risk == .approval {
                    pendingApproval = ApprovalRequest(call: call, risk: risk, preview: preview(call), reason: call.reason)
                    phase = .awaitingApproval
                    addStep("⏸", "Needs approval", preview(call))
                } else {
                    execute(call: call) { [weak self] result in self?.continueAgent(command: command, settings: settings, previousResult: result) }
                }
            }
        }
    }

    func approvePending(settings: AgentSettings) {
        guard let req = pendingApproval else { return }
        pendingApproval = nil
        addStep("✅", "Approved", preview(req.call))
        execute(call: req.call) { [weak self] result in self?.continueAgent(command: self?.steps.first?.detail ?? "", settings: settings, previousResult: result) }
    }

    func denyPending() {
        if let req = pendingApproval { addStep("🚫", "Denied", preview(req.call)) }
        pendingApproval = nil
        phase = .stopped
    }

    func parseAgentResponse(_ text: String) -> AgentParseResult {
        var raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = raw.range(of: "```") {
            raw = String(raw[start.upperBound...])
            if raw.lowercased().hasPrefix("json") { raw = String(raw.dropFirst(4)) }
            if let end = raw.range(of: "```") { raw = String(raw[..<end.lowerBound]) }
        }
        guard raw.count < 65000, let data = raw.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return .failure("Model did not return valid JSON") }
        let type = obj["type"] as? String ?? ""
        if type == "final" { return .success(AgentResponse(kind: .final(obj["message"] as? String ?? "Done"))) }
        if type == "tool_call" {
            let tool = obj["tool"] as? String ?? ""
            guard Self.knownTools.contains(tool) else { return .failure("Unknown tool: \(tool)") }
            var args: [String: String] = [:]
            if let dict = obj["arguments"] as? [String: Any] { for (k, v) in dict { args[k] = "\(v)" } }
            return .success(AgentResponse(kind: .tool(ToolCall(id: UUID().uuidString, tool: tool, arguments: args, reason: obj["reason"] as? String ?? ""))))
        }
        return .failure("Unknown response type: \(type)")
    }

    static let knownTools: Set<String> = ["snapshot_page", "extract_text", "extract_links", "extract_forms", "extract_tables", "save_memory_note", "read_memory_notes", "scroll", "open_url", "back", "forward", "reload", "fill_selector", "click_selector", "select_option", "submit_form", "export_markdown", "export_json", "export_csv"]

    func classify(_ call: ToolCall) -> ToolRisk {
        let joined = (call.tool + " " + call.arguments.values.joined(separator: " ")).lowercased()
        let blocked = ["password", "passcode", "otp", "2fa", "credit card", "cvv", "payment", "purchase", "checkout", "delete", "remove", "send money", "transfer", "swap", "wallet", "connect wallet", "sign transaction", "approve token", "confirm order"]
        if blocked.contains(where: { joined.contains($0) }) { return .blocked }
        let approval: Set<String> = ["scroll", "open_url", "back", "forward", "reload", "fill_selector", "click_selector", "select_option", "submit_form", "export_markdown", "export_json", "export_csv"]
        return approval.contains(call.tool) ? .approval : .auto
    }

    func blockReason(_ call: ToolCall) -> String { "Blocked by safety policy for sensitive/payment/login/crypto/delete pattern." }
    func preview(_ call: ToolCall) -> String { "\(call.tool) \(call.arguments.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))" }

    func execute(call: ToolCall, completion: @escaping (String) -> Void) {
        phase = .acting(call.tool)
        addStep("⚙️", "Running \(call.tool)", preview(call))
        switch call.tool {
        case "snapshot_page", "extract_text", "extract_links", "extract_forms", "extract_tables":
            extractSnapshot { snap in completion(snap?.summaryText ?? "No snapshot") }
        case "save_memory_note":
            let name = MemoryStore.save(title: call.arguments["title"] ?? "K3 Note", body: call.arguments["body"] ?? agentAnswer, url: currentURL)
            addStep("💾", "Saved note", name); completion("Saved note: \(name)")
        case "read_memory_notes":
            completion(MemoryStore.recent())
        case "scroll":
            let dir = call.arguments["direction"] ?? "down"
            let amount = Int(call.arguments["amount"] ?? "650") ?? 650
            let y = dir == "up" ? -amount : amount
            runJS("window.scrollBy({top:\(y),left:0,behavior:'smooth'}); 'scrolled';") { _ in completion("Scrolled \(dir)") }
        case "open_url":
            if let urlString = call.arguments["url"], let url = normalizedURL(urlString) { webView.load(URLRequest(url: url)); completion("Opened \(url.absoluteString)") } else { completion("Bad URL") }
        case "back": back(); completion("Back")
        case "forward": forward(); completion("Forward")
        case "reload": reload(); completion("Reload")
        case "fill_selector":
            let selector = call.arguments["selector"] ?? ""
            let value = call.arguments["value"] ?? ""
            let js = """
            (function(){ var el=document.querySelector(\(jsLiteral(selector))); if(!el){return 'selector not found';} el.focus(); el.value=\(jsLiteral(value)); el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); return 'filled '+\(jsLiteral(selector)); })();
            """
            runJS(js) { result in completion((try? result.get()) as? String ?? "Filled") }
        case "click_selector":
            let selector = call.arguments["selector"] ?? ""
            let js = """
            (function(){ var el=document.querySelector(\(jsLiteral(selector))); if(!el){return 'selector not found';} el.scrollIntoView({block:'center'}); el.click(); return 'clicked '+\(jsLiteral(selector)); })();
            """
            runJS(js) { result in completion((try? result.get()) as? String ?? "Clicked") }
        case "select_option":
            let selector = call.arguments["selector"] ?? ""; let value = call.arguments["value"] ?? ""
            let js = """
            (function(){ var el=document.querySelector(\(jsLiteral(selector))); if(!el){return 'selector not found';} el.value=\(jsLiteral(value)); el.dispatchEvent(new Event('change',{bubbles:true})); return 'selected'; })();
            """
            runJS(js) { result in completion((try? result.get()) as? String ?? "Selected") }
        case "submit_form":
            let selector = call.arguments["selector"] ?? "form"
            let js = """
            (function(){ var el=document.querySelector(\(jsLiteral(selector))); if(!el){return 'selector not found';} if(el.tagName.toLowerCase()!=='form'){el=el.closest('form');} if(!el){return 'form not found';} el.requestSubmit ? el.requestSubmit() : el.submit(); return 'submitted'; })();
            """
            runJS(js) { result in completion((try? result.get()) as? String ?? "Submitted") }
        case "export_markdown", "export_json", "export_csv":
            let title = call.arguments["title"] ?? "k3-export"
            let body = call.arguments["body"] ?? call.arguments["json"] ?? call.arguments["rows"] ?? agentAnswer
            exportText(title: title, body: body, ext: call.tool == "export_csv" ? "csv" : (call.tool == "export_json" ? "json" : "md"))
            completion("Export ready")
        default: completion("Unknown tool")
        }
    }

    func exportText(title: String, body: String, ext: String) {
        let safe = title.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression).prefix(50)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).\(ext)")
        try? body.write(to: url, atomically: true, encoding: .utf8)
        shareItems = [url]
        showShare = true
        addStep("📤", "Export ready", url.lastPathComponent)
    }

    func copyLog() {
        UIPasteboard.general.string = steps.map { "\($0.icon) \($0.title) — \($0.detail)" }.joined(separator: "\n")
    }

    func exportLog() { exportText(title: "k3-agent-run", body: steps.map { "- \($0.icon) **\($0.title)**: \($0.detail)" }.joined(separator: "\n"), ext: "md") }

    func callLLM(messages: [[String: String]], settings: AgentSettings, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: settings.baseURL) else { completion(.failure(NSError(domain: "K3", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bad API URL"]))); return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 90
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["model": settings.model, "messages": messages, "temperature": 0.2]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { data, response, error in
            if let error = error { completion(.failure(error)); return }
            if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                completion(.failure(NSError(domain: "K3", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(raw.prefix(200))"])))
                return
            }
            guard let data = data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let choices = obj["choices"] as? [[String: Any]], let msg = choices.first?["message"] as? [String: Any], let content = msg["content"] as? String else {
                completion(.failure(NSError(domain: "K3", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bad LLM response"])))
                return
            }
            completion(.success(content))
        }.resume()
    }

    func agentPrompt(command: String, snapshot: PageSnapshot, previousResult: String) -> String {
        return """
        USER GOAL: \(command)

        PREVIOUS TOOL RESULT:
        \(previousResult.isEmpty ? "(none)" : previousResult)

        PAGE CONTEXT:
        \(snapshot.summaryText.prefix(12000))

        AVAILABLE TOOLS:
        snapshot_page, extract_text, extract_links, extract_forms, extract_tables, save_memory_note, read_memory_notes, scroll, open_url, back, forward, reload, fill_selector, click_selector, select_option, submit_form, export_markdown, export_json, export_csv.

        Return ONLY JSON.
        Final: {"type":"final","message":"..."}
        Tool: {"type":"tool_call","tool":"fill_selector","arguments":{"selector":"input[name=q]","value":"query"},"reason":"..."}
        Use one tool per response. For click/fill/submit/navigation, propose the tool and wait for approval.
        """
    }

    static let snapshotJS = """
    (function(){
      function clean(s){return (s||'').replace(/\\s+/g,' ').trim();}
      function cssPath(el){
        if(!el || !el.tagName) return '';
        if(el.id && /^[A-Za-z][A-Za-z0-9_-]*$/.test(el.id)) return '#'+el.id;
        if(el.name) return el.tagName.toLowerCase()+'[name="'+CSS.escape(el.name)+'"]';
        var path=[];
        while(el && el.nodeType===1 && el!==document.body){
          var name=el.tagName.toLowerCase();
          var parent=el.parentElement;
          if(parent){ var same=Array.prototype.filter.call(parent.children,function(x){return x.tagName===el.tagName;}); if(same.length>1){ name+=':nth-of-type('+(same.indexOf(el)+1)+')'; } }
          path.unshift(name); el=parent;
        }
        return path.join(' > ');
      }
      function visible(el){ var r=el.getBoundingClientRect(); var st=getComputedStyle(el); return r.width>0 && r.height>0 && st.visibility!=='hidden' && st.display!=='none'; }
      function elem(el){ return {selector:cssPath(el), tag:(el.tagName||'').toLowerCase(), text:clean(el.innerText||el.value||'' ).slice(0,160), ariaLabel:clean(el.getAttribute('aria-label')||''), role:clean(el.getAttribute('role')||''), type:clean(el.getAttribute('type')||''), name:clean(el.getAttribute('name')||''), placeholder:clean(el.getAttribute('placeholder')||''), isVisible:visible(el)}; }
      var headings=Array.from(document.querySelectorAll('h1,h2,h3')).filter(visible).slice(0,40).map(elem);
      var buttons=Array.from(document.querySelectorAll('button,[role=button],input[type=button],input[type=submit],a')).filter(visible).slice(0,80).map(elem);
      var inputs=Array.from(document.querySelectorAll('input,textarea,select')).filter(visible).slice(0,80).map(elem);
      var links=Array.from(document.querySelectorAll('a[href]')).filter(visible).slice(0,100).map(function(a){return {text:clean(a.innerText||a.getAttribute('aria-label')||a.href).slice(0,160), href:a.href, selector:cssPath(a)};});
      var forms=Array.from(document.querySelectorAll('form')).slice(0,20).map(function(f){return {selector:cssPath(f), action:f.action||'', method:f.method||'', fields:Array.from(f.querySelectorAll('input,textarea,select')).slice(0,60).map(function(x){var typ=(x.getAttribute('type')||x.tagName||'').toLowerCase(); var val=(typ.indexOf('password')>=0||typ.indexOf('card')>=0)?'[masked]':clean(x.value||'').slice(0,80); return {selector:cssPath(x), tag:(x.tagName||'').toLowerCase(), type:typ, name:clean(x.name||''), label:clean((x.labels&&x.labels[0]&&x.labels[0].innerText)||''), placeholder:clean(x.placeholder||''), valuePreview:val, required:!!x.required};})};});
      var tables=Array.from(document.querySelectorAll('table')).slice(0,12).map(function(t){var rows=Array.from(t.querySelectorAll('tr')).slice(0,30).map(function(r){return Array.from(r.querySelectorAll('th,td')).slice(0,12).map(function(c){return clean(c.innerText).slice(0,120);});}); var headers=rows.length?rows[0]:[]; return {selector:cssPath(t), headers:headers, rows:rows.slice(1)};});
      return JSON.stringify({title:document.title||'', url:location.href, text:clean(document.body?document.body.innerText:'').slice(0,18000), headings:headings, buttons:buttons, inputs:inputs, links:links, forms:forms, tables:tables});
    })();
    """
}

extension BrowserState: WKNavigationDelegate, WKUIDelegate {}

// MARK: - UI

struct BrowserView: View {
    @StateObject private var state = BrowserState()
    @StateObject private var settings = AgentSettings()
    @State private var showShareURL = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                if state.estimatedProgress < 1.0 { ProgressView(value: state.estimatedProgress).progressViewStyle(.linear) }
                WebViewContainer(webView: state.webView)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            VStack(spacing: 8) {
                if let pending = state.pendingApproval { ApprovalTray(request: pending, onApprove: { state.approvePending(settings: settings) }, onDeny: { state.denyPending() }) }
                bottomCommandBar
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .sheet(isPresented: $state.showCockpit) { AgentCockpitView(state: state, settings: settings) }
        .sheet(isPresented: $state.showShare) { ShareSheet(items: state.shareItems) }
    }

    var topBar: some View {
        HStack(spacing: 8) {
            Button(action: state.back) { Image(systemName: "chevron.left") }.disabled(!state.canGoBack)
            Button(action: state.forward) { Image(systemName: "chevron.right") }.disabled(!state.canGoForward)
            TextField("Search / URL", text: $state.address, onCommit: state.loadAddress)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button(action: state.isLoading ? state.stopLoading : state.reload) { Image(systemName: state.isLoading ? "xmark" : "arrow.clockwise") }
            Button(action: { state.showCockpit = true }) { Image(systemName: "bolt.fill") }
        }.padding(8).background(Color(.systemBackground))
    }

    var bottomCommandBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                statusPill
                TextField(settings.apiKey.isEmpty ? "Set API key to run K3 Agent" : "Tell K3 what to do…", text: $state.commandText, onCommit: runCommand)
                    .textFieldStyle(.roundedBorder)
                    .disabled(settings.apiKey.isEmpty || state.phase == .thinking || state.phase == .observing)
                if state.phase == .thinking || state.phase == .observing || state.phase == .acting("") || state.pendingApproval != nil {
                    Button("Stop", action: state.stopAgent).buttonStyle(.bordered)
                } else {
                    Button("Run", action: runCommand).buttonStyle(.borderedProminent).disabled(settings.apiKey.isEmpty || state.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Button(action: { state.showCockpit = true }) { Image(systemName: "list.bullet.rectangle") }.buttonStyle(.bordered)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    chip("Summarize") { state.commandText = "Summarize this page and list next actions."; runCommand() }
                    chip("Find forms") { state.commandText = "Find forms and explain what fields are needed."; runCommand() }
                    chip("Extract links") { state.commandText = "Extract the most important links from this page."; runCommand() }
                    chip("Save note") { state.commandText = "Summarize this page and save a memory note."; runCommand() }
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(radius: 8)
    }

    var statusPill: some View {
        Text("● \(state.phase.label)")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(Color(.secondarySystemBackground)).cornerRadius(999)
    }

    func chip(_ text: String, action: @escaping () -> Void) -> some View { Button(text, action: action).font(.caption).buttonStyle(.bordered) }
    func runCommand() { let cmd = state.commandText.trimmingCharacters(in: .whitespacesAndNewlines); guard !cmd.isEmpty else { return }; state.startAgent(command: cmd, settings: settings) }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ApprovalTray: View {
    let request: ApprovalRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("Approve action?").font(.headline); Spacer(); Text(request.call.tool).font(.caption).padding(5).background(Color.orange.opacity(0.2)).cornerRadius(6) }
            Text(request.preview).font(.caption).textSelection(.enabled)
            if !request.reason.isEmpty { Text(request.reason).font(.caption).foregroundColor(.secondary) }
            HStack { Button("Deny", action: onDeny).buttonStyle(.bordered); Spacer(); Button("Run once", action: onApprove).buttonStyle(.borderedProminent) }
        }
        .padding(12).background(Color(.systemBackground)).cornerRadius(16).shadow(radius: 10)
    }
}

struct AgentCockpitView: View {
    @ObservedObject var state: BrowserState
    @ObservedObject var settings: AgentSettings
    @State private var tab = 0
    @State private var askText = ""
    @State private var selector = ""
    @State private var value = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Mode", selection: $tab) { Text("Cockpit").tag(0); Text("Snapshot").tag(1); Text("Tools").tag(2); Text("Settings").tag(3) }.pickerStyle(.segmented).padding()
                if tab == 0 { cockpit }
                if tab == 1 { snapshotView }
                if tab == 2 { toolsView }
                if tab == 3 { settingsView }
            }.navigationTitle("K3 Agent").navigationBarTitleDisplayMode(.inline)
        }
    }

    var cockpit: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.phase.label).font(.headline)
            HStack { TextField("Tell K3 what to do…", text: $state.commandText).textFieldStyle(.roundedBorder); Button("Run") { state.startAgent(command: state.commandText, settings: settings) }.buttonStyle(.borderedProminent); Button("Stop", action: state.stopAgent).buttonStyle(.bordered) }
            HStack { Button("Copy log", action: state.copyLog).buttonStyle(.bordered); Button("Export MD", action: state.exportLog).buttonStyle(.bordered); Button("Clear") { state.steps.removeAll() }.buttonStyle(.bordered) }
            Divider()
            ScrollView { VStack(alignment: .leading, spacing: 10) { if state.steps.isEmpty { Text("No actions yet. Run a command to start.").foregroundColor(.secondary) }; ForEach(state.steps) { step in VStack(alignment: .leading) { Text("\(step.icon) \(step.title)").font(.subheadline.weight(.semibold)); if !step.detail.isEmpty { Text(step.detail).font(.caption).foregroundColor(.secondary).textSelection(.enabled) } }.padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Color(.secondarySystemBackground)).cornerRadius(10) } } }
        }.padding()
    }

    var snapshotView: some View {
        VStack(alignment: .leading) { Button("Snapshot page") { state.extractSnapshot() }.buttonStyle(.borderedProminent); if let snap = state.snapshot { ScrollView { Text(snap.summaryText).font(.caption).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) } } else { Text("No snapshot yet") } }.padding()
    }

    var toolsView: some View {
        Form {
            Section("Manual selector tools") {
                TextField("CSS selector", text: $selector).autocapitalization(.none).disableAutocorrection(true)
                TextField("Value", text: $value)
                Button("Fill once") { state.pendingApproval = ApprovalRequest(call: ToolCall(id: UUID().uuidString, tool: "fill_selector", arguments: ["selector": selector, "value": value], reason: "Manual tool"), risk: .approval, preview: "fill_selector selector=\(selector)", reason: "Manual tool") }
                Button("Click once") { state.pendingApproval = ApprovalRequest(call: ToolCall(id: UUID().uuidString, tool: "click_selector", arguments: ["selector": selector], reason: "Manual tool"), risk: .approval, preview: "click_selector selector=\(selector)", reason: "Manual tool") }
            }
            Section("Memory") { Button("Read recent notes") { state.addStep("📚", "Recent notes", MemoryStore.recent()) }; Button("Save answer as note") { let name = MemoryStore.save(title: state.pageTitle.isEmpty ? "K3 Note" : state.pageTitle, body: state.agentAnswer, url: state.currentURL); state.addStep("💾", "Saved note", name) } }
        }
    }

    var settingsView: some View {
        Form {
            Section("API") {
                SecureField("API Key", text: $settings.apiKey)
                TextField("Base URL", text: $settings.baseURL).autocapitalization(.none).disableAutocorrection(true)
                TextField("Model", text: $settings.model).autocapitalization(.none).disableAutocorrection(true)
                TextEditor(text: $settings.systemPrompt).frame(height: 120)
                HStack { Button("Save", action: settings.save).buttonStyle(.borderedProminent); Button(settings.isTesting ? "Testing" : "Test", action: settings.testConnection).buttonStyle(.bordered).disabled(settings.isTesting) }
                Text(settings.status).font(.caption).textSelection(.enabled)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
