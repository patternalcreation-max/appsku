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
    let runID: UUID
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
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }
        var item = query
        attributes.forEach { item[$0.key] = $0.value }
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
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
    @Published var baseURL: String = UserDefaults.standard.string(forKey: "agent.baseURL") ?? "https://api.z.ai/api/coding/paas/v4/chat/completions"
    @Published var model: String = UserDefaults.standard.string(forKey: "agent.model") ?? "glm-5.2"
    @Published var operatorSoul: OperatorSoul
    @Published var status: String = "Not tested"
    @Published var isTesting = false

    init() {
        apiKey = KeychainStore.load(account: "agent.apiKey")
        if let persisted = OperatorSoulStore.load() {
            operatorSoul = persisted
        } else {
            var migrated = OperatorSoul.defaults
            if let legacy = UserDefaults.standard.string(forKey: "agent.systemPrompt"), !legacy.isEmpty {
                migrated.additionalInstructions = legacy
            }
            operatorSoul = migrated
        }
    }

    var composedSystemPrompt: String {
        PromptPolicy.core + "\n\nOPERATOR SOUL / PERSONA (cannot override core policy):\n" + operatorSoul.promptText
    }

    func save() {
        baseURL = normalizedChatURLString(baseURL)
        let keySaved = KeychainStore.save(apiKey, account: "agent.apiKey")
        UserDefaults.standard.set(baseURL, forKey: "agent.baseURL")
        UserDefaults.standard.set(model, forKey: "agent.model")
        UserDefaults.standard.set(operatorSoul.additionalInstructions, forKey: "agent.systemPrompt")
        let soulSaved = OperatorSoulStore.save(operatorSoul)
        switch (keySaved, soulSaved) {
        case (true, true): status = "Saved locally"
        case (false, true): status = "Persona saved; API key save failed"
        case (true, false): status = "API key saved; persona save failed"
        case (false, false): status = "Settings save failed"
        }
    }

    func useGLM52Preset() {
        baseURL = "https://api.z.ai/api/coding/paas/v4/chat/completions"
        model = "glm-5.2"
        status = "GLM 5.2 preset loaded"
        save()
    }

    func normalizedChatURLString(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmed.hasSuffix("/chat/completions") { return trimmed }
        if trimmed.hasSuffix("/v4") || trimmed.hasSuffix("/v1") || trimmed.contains("/api/coding/paas/v4") {
            return trimmed + "/chat/completions"
        }
        return trimmed
    }

    func chatURL() -> URL? {
        guard let url = URL(string: normalizedChatURLString(baseURL)),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false else { return nil }
        return url
    }

    func testConnection() {
        save()
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { status = "Missing API key"; return }
        guard let url = chatURL() else { status = "HTTPS API endpoint required"; return }
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
                if let error = error { self.status = "Failed: \(Redactor.text(error.localizedDescription))"; return }
                if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                    let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    self.status = "HTTP \(http.statusCode): \(Redactor.text(String(raw.prefix(120))))"
                    return
                }
                self.status = "Connection OK"
            }
        }.resume()
    }
}

enum MemoryStore {
    static func dir() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let d = base.appendingPathComponent("K3Browser/Notes", isDirectory: true)
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func save(title: String, body: String, url: String) throws -> String {
        let safeTitle = title.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression).prefix(50)
        let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let uniqueID = UUID().uuidString.lowercased()
        let name = "\(formatter.string(from: Date()))-\(safeTitle)-\(uniqueID).md"
        let file = try dir().appendingPathComponent(name)
        let content = "# \(Redactor.text(title))\n\nSource: \(Redactor.sanitizeURLString(url))\nDate: \(Date())\n\n\(Redactor.text(body))\n"
        try content.write(to: file, atomically: true, encoding: .utf8)
        return file.lastPathComponent
    }

    static func recent(limit: Int = 8) -> String {
        guard let directory = try? dir() else { return "Memory unavailable" }
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
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
    private final class PendingNavigationAction {
        let actionID = UUID()
        let runID: UUID
        let action: String
        let completion: (String) -> Void
        let bindsFirstNavigation: Bool
        var navigation: WKNavigation?
        var didStart = false
        var noNavigationWorkItem: DispatchWorkItem?
        var timeoutWorkItem: DispatchWorkItem?

        init(runID: UUID, action: String, bindsFirstNavigation: Bool, completion: @escaping (String) -> Void) {
            self.runID = runID
            self.action = action
            self.bindsFirstNavigation = bindsFirstNavigation
            self.completion = completion
        }

        func cancelTimers() {
            noNavigationWorkItem?.cancel()
            timeoutWorkItem?.cancel()
        }
    }

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
    @Published var showMissionControl = false
    @Published var showShare = false
    @Published var shareItems: [Any] = []

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private(set) var activeRun: RunContext?
    private var llmTask: URLSessionDataTask?
    private var pendingNavigationAction: PendingNavigationAction?
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
        steps.append(AgentStep(icon: icon, title: title, detail: Redactor.text(detail)))
    }

    private func isActive(runID: UUID) -> Bool { activeRun?.runID == runID }

    private func beginRun(command: String) -> RunContext {
        llmTask?.cancel()
        clearPendingNavigationAction()
        pendingApproval = nil
        let context = RunContext(command: command)
        activeRun = context
        return context
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

    private func settleSnapshotFailure(runID: UUID?, message: String) {
        let safeMessage = Redactor.text(message)
        if let runID = runID {
            guard isActive(runID: runID) else { return }
            activeRun = nil
            pendingApproval = nil
            isAsking = false
        }
        phase = .error(safeMessage)
        addStep("⚠️", "Snapshot failed", safeMessage)
    }

    func extractSnapshot(runID: UUID? = nil, completion: ((PageSnapshot?) -> Void)? = nil) {
        if runID == nil, activeRun != nil {
            completion?(nil)
            return
        }
        phase = .observing
        let js = SnapshotSanitizer.javascript
        runJS(js) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let runID = runID, !self.isActive(runID: runID) { return }
                switch result {
                case .success(let value):
                    let raw = value as? String ?? "{}"
                    guard let data = raw.data(using: .utf8), let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        self.settleSnapshotFailure(runID: runID, message: "Bad JS payload")
                        completion?(nil); return
                    }
                    let snap = BrowserState.decodeSnapshot(obj)
                    self.snapshot = snap
                    self.addStep("👁", "Observed page", "\(snap.text.count) chars, \(snap.links.count) links, \(snap.inputs.count) inputs, \(snap.tables.count) tables")
                    if runID == nil, self.activeRun == nil { self.phase = .idle }
                    completion?(snap)
                case .failure(let error):
                    self.settleSnapshotFailure(runID: runID, message: error.localizedDescription)
                    completion?(nil)
                }
            }
        }
    }

    static func decodeSnapshot(_ obj: [String: Any]) -> PageSnapshot {
        func s(_ key: String) -> String { obj[key] as? String ?? "" }
        func m(_ value: Any?) -> String { SnapshotSanitizer.sanitizedMetadata(value as? String ?? "") }
        func element(_ d: [String: Any]) -> DOMElement {
            DOMElement(
                selector: m(d["selector"]),
                tag: m(d["tag"]),
                text: m(d["text"]),
                ariaLabel: m(d["ariaLabel"]),
                role: m(d["role"]),
                type: m(d["type"]),
                name: m(d["name"]),
                placeholder: m(d["placeholder"]),
                isVisible: d["isVisible"] as? Bool ?? true
            )
        }
        let headings = (obj["headings"] as? [[String: Any]] ?? []).map(element)
        let buttons = (obj["buttons"] as? [[String: Any]] ?? []).map(element)
        let inputs = (obj["inputs"] as? [[String: Any]] ?? []).map(element)
        let links = (obj["links"] as? [[String: Any]] ?? []).map {
            PageLink(text: m($0["text"]), href: SnapshotSanitizer.sanitizedURL($0["href"] as? String ?? ""), selector: m($0["selector"]))
        }
        let forms = (obj["forms"] as? [[String: Any]] ?? []).map { f -> PageForm in
            let fields = (f["fields"] as? [[String: Any]] ?? []).map {
                PageFormField(
                    selector: m($0["selector"]),
                    tag: m($0["tag"]),
                    type: m($0["type"]),
                    name: m($0["name"]),
                    label: m($0["label"]),
                    placeholder: m($0["placeholder"]),
                    valuePreview: m($0["valuePreview"]),
                    required: $0["required"] as? Bool ?? false
                )
            }
            return PageForm(
                selector: m(f["selector"]),
                action: SnapshotSanitizer.sanitizedURL(f["action"] as? String ?? ""),
                method: m(f["method"]),
                fields: fields
            )
        }
        let tables = (obj["tables"] as? [[String: Any]] ?? []).map { t in
            PageTable(
                selector: m(t["selector"]),
                headers: (t["headers"] as? [String] ?? []).map(SnapshotSanitizer.sanitizedMetadata),
                rows: (t["rows"] as? [[String]] ?? []).map { $0.map(SnapshotSanitizer.sanitizedMetadata) }
            )
        }
        return PageSnapshot(
            title: m(s("title")),
            url: SnapshotSanitizer.sanitizedURL(s("url")),
            text: m(s("text")),
            headings: headings,
            buttons: buttons,
            inputs: inputs,
            links: links,
            forms: forms,
            tables: tables
        )
    }

    // MARK: AI + Agent loop

    func askPage(question: String, settings: AgentSettings) {
        let context = beginRun(command: question)
        extractSnapshot(runID: context.runID) { [weak self] snap in
            guard let self = self, self.isActive(runID: context.runID), let snap = snap else { return }
            self.isAsking = true
            self.agentAnswer = "Thinking..."
            let messages = [["role": "system", "content": settings.composedSystemPrompt], ["role": "user", "content": "Question: \(question)\n\n\(snap.summaryText)"]]
            self.callLLM(messages: messages, settings: settings, runID: context.runID) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self, self.isActive(runID: context.runID) else { return }
                    self.isAsking = false
                    switch result {
                    case .success(let text): self.agentAnswer = Redactor.text(text); self.phase = .done
                    case .failure(let error):
                        let message = Redactor.text(error.localizedDescription)
                        self.agentAnswer = "Error: \(message)"
                        self.phase = .error(message)
                    }
                    self.activeRun = nil
                }
            }
        }
    }

    func startAgent(command: String, settings: AgentSettings) {
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { phase = .error("Missing API key"); showMissionControl = true; return }
        let context = beginRun(command: command)
        stepIndex = 0
        steps.removeAll()
        agentAnswer = ""
        addStep("▶️", "Started", command)
        continueAgent(context: context, settings: settings, previousResult: "")
    }

    func stopAgent() {
        llmTask?.cancel()
        llmTask = nil
        clearPendingNavigationAction()
        activeRun = nil
        pendingApproval = nil
        isAsking = false
        phase = .stopped
        addStep("⏹", "Stopped by operator")
    }

    func continueAgent(context: RunContext, settings: AgentSettings, previousResult: String) {
        guard isActive(runID: context.runID) else { return }
        if stepIndex >= maxSteps { phase = .done; activeRun = nil; addStep("✅", "Max steps reached"); return }
        stepIndex += 1
        extractSnapshot(runID: context.runID) { [weak self] snap in
            guard let self = self, self.isActive(runID: context.runID), let snap = snap else { return }
            self.phase = .thinking
            let prompt = self.agentPrompt(command: context.command, snapshot: snap, previousResult: previousResult)
            self.addStep("💭", "Thinking", "Step \(self.stepIndex)/\(self.maxSteps)")
            let messages = [["role": "system", "content": settings.composedSystemPrompt], ["role": "user", "content": prompt]]
            self.callLLM(messages: messages, settings: settings, runID: context.runID) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self, self.isActive(runID: context.runID) else { return }
                    switch result {
                    case .failure(let error):
                        let message = Redactor.text(error.localizedDescription)
                        self.phase = .error(message); self.addStep("⚠️", "LLM error", message); self.activeRun = nil
                    case .success(let content):
                        self.handleAgentResponse(content, context: context, settings: settings)
                    }
                }
            }
        }
    }

    func handleAgentResponse(_ content: String, context: RunContext, settings: AgentSettings) {
        guard isActive(runID: context.runID) else { return }
        switch parseAgentResponse(content) {
        case .failure(let error):
            phase = .error(error); addStep("⚠️", "Parser error", error + "\nRaw: \(Redactor.text(String(content.prefix(500))))"); activeRun = nil
        case .success(let response):
            switch response.kind {
            case .final(let message):
                agentAnswer = Redactor.text(message); phase = .done; addStep("✅", "Final", message); activeRun = nil
            case .tool(let rawCall):
                let call = resolvedExecutionCall(rawCall)
                let risk = classify(call)
                if risk == .blocked { phase = .done; addStep("⛔️", "Blocked", "\(call.tool): \(blockReason(call))"); activeRun = nil; return }
                if risk == .approval {
                    pendingApproval = ApprovalRequest(runID: context.runID, call: call, risk: risk, preview: preview(call), reason: Redactor.text(call.reason))
                    phase = .awaitingApproval
                    addStep("⏸", "Needs approval", preview(call))
                } else {
                    execute(call: call, context: context) { [weak self] result in
                        guard let self = self, self.isActive(runID: context.runID) else { return }
                        self.continueAgent(context: context, settings: settings, previousResult: result)
                    }
                }
            }
        }
    }

    func approvePending(settings: AgentSettings) {
        guard let req = pendingApproval, let context = activeRun, req.runID == context.runID else { pendingApproval = nil; return }
        pendingApproval = nil
        addStep("✅", "Approved", preview(req.call))
        execute(call: req.call, context: context) { [weak self] result in
            guard let self = self, self.isActive(runID: context.runID) else { return }
            self.continueAgent(context: context, settings: settings, previousResult: result)
        }
    }

    func denyPending() {
        guard let req = pendingApproval, req.runID == activeRun?.runID else { pendingApproval = nil; return }
        addStep("🚫", "Denied", preview(req.call))
        pendingApproval = nil
        activeRun = nil
        phase = .stopped
    }

    func stageManualApproval(call: ToolCall) {
        let context = beginRun(command: "Manual \(call.tool)")
        pendingApproval = ApprovalRequest(runID: context.runID, call: call, risk: .approval, preview: preview(call), reason: "Manual tool")
        phase = .awaitingApproval
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
    func preview(_ call: ToolCall) -> String { Redactor.preview(tool: call.tool, arguments: call.arguments) }

    func resolvedExecutionCall(_ call: ToolCall) -> ToolCall {
        guard call.tool.hasPrefix("export_") else { return call }
        var arguments = call.arguments
        if arguments["body"] == nil, arguments["json"] == nil, arguments["rows"] == nil {
            arguments["body"] = Redactor.exportBody(agentAnswer)
        }
        return ToolCall(id: call.id, tool: call.tool, arguments: arguments, reason: call.reason)
    }

    private func clearPendingNavigationAction() {
        pendingNavigationAction?.cancelTimers()
        pendingNavigationAction = nil
    }

    private func prepareNavigationAction(context: RunContext, action: String, bindsFirstNavigation: Bool, completion: @escaping (String) -> Void) {
        clearPendingNavigationAction()
        pendingNavigationAction = PendingNavigationAction(runID: context.runID, action: action, bindsFirstNavigation: bindsFirstNavigation, completion: completion)
    }

    private func settleNavigationAction(actionID: UUID, runID: UUID, result: String) {
        guard let pending = pendingNavigationAction,
              pending.actionID == actionID,
              pending.runID == runID else { return }
        clearPendingNavigationAction()
        guard isActive(runID: runID) else { return }
        pending.completion(Redactor.text(result))
    }

    private func scheduleNavigationTimeout(for pending: PendingNavigationAction) {
        guard pendingNavigationAction === pending else { return }
        guard pending.timeoutWorkItem == nil else { return }
        let actionID = pending.actionID
        let runID = pending.runID
        let work = DispatchWorkItem { [weak self] in
            self?.settleNavigationAction(actionID: actionID, runID: runID, result: "Navigation timed out")
        }
        pending.timeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: work)
    }

    private func performNavigation(context: RunContext, action: String, completion: @escaping (String) -> Void, start: () -> WKNavigation?) {
        guard isActive(runID: context.runID) else { return }
        prepareNavigationAction(context: context, action: action, bindsFirstNavigation: false, completion: completion)
        guard let pending = pendingNavigationAction, pending.runID == context.runID else { return }
        guard let navigation = start() else {
            settleNavigationAction(actionID: pending.actionID, runID: context.runID, result: "\(action) did not start")
            return
        }
        pending.navigation = navigation
        pending.didStart = true
        scheduleNavigationTimeout(for: pending)
    }

    private func performPossibleNavigationJS(context: RunContext, action: String, javascript: String, completion: @escaping (String) -> Void) {
        guard isActive(runID: context.runID) else { return }
        guard !webView.isLoading else {
            completion("\(action) deferred: page is still loading")
            return
        }
        prepareNavigationAction(context: context, action: action, bindsFirstNavigation: true, completion: completion)
        guard let prepared = pendingNavigationAction, prepared.runID == context.runID else { return }
        scheduleNavigationTimeout(for: prepared)
        runJS(javascript) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self,
                      self.isActive(runID: context.runID),
                      let pending = self.pendingNavigationAction,
                      pending.actionID == prepared.actionID,
                      pending.runID == context.runID else { return }
                switch result {
                case .failure(let error):
                    if pending.didStart { return }
                    self.settleNavigationAction(actionID: pending.actionID, runID: context.runID, result: "\(action) failed: \(error.localizedDescription)")
                case .success(let value):
                    let message = value as? String ?? action
                    if message.lowercased().contains("not found") {
                        self.settleNavigationAction(actionID: pending.actionID, runID: context.runID, result: message)
                        return
                    }
                    if pending.didStart { return }
                    let work = DispatchWorkItem { [weak self, weak pending] in
                        guard let self = self,
                              let pending = pending,
                              let current = self.pendingNavigationAction,
                              current.actionID == pending.actionID,
                              current.runID == context.runID,
                              !current.didStart else { return }
                        self.settleNavigationAction(actionID: current.actionID, runID: context.runID, result: message)
                    }
                    pending.noNavigationWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
                }
            }
        }
    }

    func execute(call: ToolCall, context: RunContext, completion: @escaping (String) -> Void) {
        guard isActive(runID: context.runID) else { return }
        let finish: (String) -> Void = { [weak self] result in
            guard let self = self, self.isActive(runID: context.runID) else { return }
            completion(Redactor.text(result))
        }
        phase = .acting(call.tool)
        addStep("⚙️", "Running \(call.tool)", preview(call))
        switch call.tool {
        case "snapshot_page", "extract_text", "extract_links", "extract_forms", "extract_tables":
            extractSnapshot(runID: context.runID) { snap in finish(snap?.summaryText ?? "No snapshot") }
        case "save_memory_note":
            do {
                let name = try MemoryStore.save(title: call.arguments["title"] ?? "K3 Note", body: call.arguments["body"] ?? agentAnswer, url: currentURL)
                addStep("💾", "Saved note", name); finish("Saved note: \(name)")
            } catch {
                let message = Redactor.text(error.localizedDescription)
                addStep("⚠️", "Note save failed", message); finish("Note save failed: \(message)")
            }
        case "read_memory_notes":
            finish(MemoryStore.recent())
        case "scroll":
            let dir = call.arguments["direction"] ?? "down"
            let amount = Int(call.arguments["amount"] ?? "650") ?? 650
            let y = dir == "up" ? -amount : amount
            runJS("window.scrollBy({top:\(y),left:0,behavior:'smooth'}); 'scrolled';") { _ in finish("Scrolled \(dir)") }
        case "open_url":
            if let urlString = call.arguments["url"], let url = normalizedURL(urlString) {
                performNavigation(context: context, action: "Open URL", completion: finish) { self.webView.load(URLRequest(url: url)) }
            } else { finish("Bad URL") }
        case "back":
            performNavigation(context: context, action: "Back", completion: finish) { self.webView.goBack() }
        case "forward":
            performNavigation(context: context, action: "Forward", completion: finish) { self.webView.goForward() }
        case "reload":
            performNavigation(context: context, action: "Reload", completion: finish) { self.webView.reload() }
        case "fill_selector":
            let selector = call.arguments["selector"] ?? ""
            let value = call.arguments["value"] ?? ""
            let js = """
            (function(){ var el=document.querySelector(\(jsLiteral(selector))); if(!el){return 'selector not found';} el.focus(); el.value=\(jsLiteral(value)); el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); return 'filled '+\(jsLiteral(selector)); })();
            """
            runJS(js) { result in finish((try? result.get()) as? String ?? "Filled") }
        case "click_selector":
            let selector = call.arguments["selector"] ?? ""
            let js = """
            (function(){ var el=document.querySelector(\(jsLiteral(selector))); if(!el){return 'selector not found';} el.scrollIntoView({block:'center'}); el.click(); return 'clicked '+\(jsLiteral(selector)); })();
            """
            performPossibleNavigationJS(context: context, action: "Click", javascript: js, completion: finish)
        case "select_option":
            let selector = call.arguments["selector"] ?? ""; let value = call.arguments["value"] ?? ""
            let js = """
            (function(){ var el=document.querySelector(\(jsLiteral(selector))); if(!el){return 'selector not found';} el.value=\(jsLiteral(value)); el.dispatchEvent(new Event('change',{bubbles:true})); return 'selected'; })();
            """
            runJS(js) { result in finish((try? result.get()) as? String ?? "Selected") }
        case "submit_form":
            let selector = call.arguments["selector"] ?? "form"
            let js = """
            (function(){ var el=document.querySelector(\(jsLiteral(selector))); if(!el){return 'selector not found';} if(el.tagName.toLowerCase()!=='form'){el=el.closest('form');} if(!el){return 'form not found';} el.requestSubmit ? el.requestSubmit() : el.submit(); return 'submitted'; })();
            """
            performPossibleNavigationJS(context: context, action: "Submit", javascript: js, completion: finish)
        case "export_markdown", "export_json", "export_csv":
            let title = call.arguments["title"] ?? "k3-export"
            let body = call.arguments["body"] ?? call.arguments["json"] ?? call.arguments["rows"] ?? ""
            if exportText(title: title, body: body, ext: call.tool == "export_csv" ? "csv" : (call.tool == "export_json" ? "json" : "md")) {
                finish("Export ready")
            } else {
                finish("Export failed")
            }
        default: finish("Unknown tool")
        }
    }

    @discardableResult
    func exportText(title: String, body: String, ext: String) -> Bool {
        let safe = title.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression).prefix(50)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).\(ext)")
        let safeBody = Redactor.exportBody(body)
        do {
            try safeBody.write(to: url, atomically: true, encoding: .utf8)
            shareItems = [url]
            showShare = true
            addStep("📤", "Export ready", url.lastPathComponent)
            return true
        } catch {
            addStep("⚠️", "Export failed", Redactor.text(error.localizedDescription))
            return false
        }
    }

    func copyLog() {
        UIPasteboard.general.string = Redactor.text(steps.map { "\($0.icon) \($0.title) — \($0.detail)" }.joined(separator: "\n"))
    }

    func exportLog() { exportText(title: "k3-agent-run", body: Redactor.text(steps.map { "- \($0.icon) **\($0.title)**: \($0.detail)" }.joined(separator: "\n")), ext: "md") }

    func saveCurrentAnswerNote() {
        do {
            let name = try MemoryStore.save(title: pageTitle.isEmpty ? "K3 Note" : pageTitle, body: agentAnswer, url: currentURL)
            addStep("💾", "Saved note", name)
        } catch {
            addStep("⚠️", "Note save failed", Redactor.text(error.localizedDescription))
        }
    }

    func callLLM(messages: [[String: String]], settings: AgentSettings, runID: UUID, completion: @escaping (Result<String, Error>) -> Void) {
        guard isActive(runID: runID) else { return }
        guard let url = settings.chatURL() else { completion(.failure(NSError(domain: "K3", code: 1, userInfo: [NSLocalizedDescriptionKey: "Bad API URL"]))) ; return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"; req.timeoutInterval = 90
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = ["model": settings.model, "messages": messages, "temperature": 0.2]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        let task = URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self, self.isActive(runID: runID) else { return }
                if let error = error { completion(.failure(error)); return }
                if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                    let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    completion(.failure(NSError(domain: "K3", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(Redactor.text(String(raw.prefix(200))))"])))
                    return
                }
                guard let data = data, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let choices = obj["choices"] as? [[String: Any]], let msg = choices.first?["message"] as? [String: Any], let content = msg["content"] as? String else {
                    completion(.failure(NSError(domain: "K3", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bad LLM response"])))
                    return
                }
                completion(.success(content))
            }
        }
        llmTask = task
        task.resume()
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

}

extension BrowserState: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard let pending = pendingNavigationAction, isActive(runID: pending.runID) else { return }
        if let boundNavigation = pending.navigation {
            guard boundNavigation === navigation else { return }
        } else {
            guard pending.bindsFirstNavigation else { return }
            pending.navigation = navigation
        }
        pending.didStart = true
        pending.noNavigationWorkItem?.cancel()
        scheduleNavigationTimeout(for: pending)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let pending = pendingNavigationAction,
              let boundNavigation = pending.navigation,
              boundNavigation === navigation,
              pending.didStart else { return }
        let url = Redactor.sanitizeURLString(webView.url?.absoluteString ?? "")
        settleNavigationAction(actionID: pending.actionID, runID: pending.runID, result: "\(pending.action) completed: \(url)")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let pending = pendingNavigationAction,
              let boundNavigation = pending.navigation,
              boundNavigation === navigation else { return }
        settleNavigationAction(actionID: pending.actionID, runID: pending.runID, result: "\(pending.action) failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard let pending = pendingNavigationAction,
              let boundNavigation = pending.navigation,
              boundNavigation === navigation else { return }
        settleNavigationAction(actionID: pending.actionID, runID: pending.runID, result: "\(pending.action) failed: \(error.localizedDescription)")
    }
}

// MARK: - UI

struct BrowserView: View {
    @StateObject private var state = BrowserState()
    @StateObject private var settings = AgentSettings()
    @StateObject private var dockPreferences = DockPreferences()
    @State private var showApprovalTray = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topBar
                if state.estimatedProgress < 1.0 { ProgressView(value: state.estimatedProgress).progressViewStyle(.linear) }
                WebViewContainer(webView: state.webView)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            if showApprovalTray, let pending = state.pendingApproval {
                VStack {
                    ApprovalTray(
                        request: pending,
                        onApprove: {
                            showApprovalTray = false
                            state.approvePending(settings: settings)
                        },
                        onDeny: {
                            showApprovalTray = false
                            state.denyPending()
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 56)
                    Spacer(minLength: 0)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            AdaptiveAgentOverlay(
                dockPreferences: dockPreferences,
                commandText: $state.commandText,
                phase: state.phase,
                isConfigured: !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                pendingApprovalCount: state.pendingApproval == nil ? 0 : 1,
                engagementLabel: nil,
                statusText: nil,
                onRun: runCommand,
                onStop: state.stopAgent,
                onOpenMissionControl: { state.showMissionControl = true },
                onExpandApproval: { showApprovalTray = state.pendingApproval != nil }
            )
        }
        .onChange(of: state.pendingApproval?.id) { approvalID in
            withAnimation(.easeOut(duration: 0.20)) {
                showApprovalTray = approvalID != nil
            }
        }
        .sheet(isPresented: $state.showMissionControl) { MissionControlView(state: state, settings: settings) }
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
            Button(action: { state.showMissionControl = true }) { Image(systemName: "slider.horizontal.3") }
                .accessibilityLabel("Open Mission Control")
        }.padding(8).background(Color(.systemBackground))
    }

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

struct MissionControlView: View {
    @ObservedObject var state: BrowserState
    @ObservedObject var settings: AgentSettings
    @State private var tab = 0

    @State private var selector = ""
    @State private var value = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Workspace", selection: $tab) { Text("Run").tag(0); Text("Page").tag(1); Text("Tools").tag(2); Text("Settings").tag(3) }.pickerStyle(.segmented).padding()
                if tab == 0 { runOverview }
                if tab == 1 { snapshotView }
                if tab == 2 { toolsView }
                if tab == 3 { settingsView }
            }.navigationTitle("Mission Control").navigationBarTitleDisplayMode(.inline)
        }
    }

    var runOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.phase.label).font(.headline)
            Text("Commands run from the Agent Dock so the browser keeps one command boundary.")
                .font(.caption)
                .foregroundColor(.secondary)
            if state.phase.isBusy { Button("Stop active run", action: state.stopAgent).buttonStyle(.bordered) }
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
                Button("Fill once") { state.stageManualApproval(call: ToolCall(id: UUID().uuidString, tool: "fill_selector", arguments: ["selector": selector, "value": value], reason: "Manual tool")) }
                Button("Click once") { state.stageManualApproval(call: ToolCall(id: UUID().uuidString, tool: "click_selector", arguments: ["selector": selector], reason: "Manual tool")) }
            }
            Section("Memory") { Button("Read recent notes") { state.addStep("📚", "Recent notes", MemoryStore.recent()) }; Button("Save answer as note", action: state.saveCurrentAnswerNote) }
        }
    }

    var settingsView: some View {
        Form {
            Section("API") {
                Button("Use GLM 5.2 / Z.AI preset", action: settings.useGLM52Preset)
                SecureField("API Key", text: $settings.apiKey)
                TextField("Base URL", text: $settings.baseURL).autocapitalization(.none).disableAutocorrection(true)
                Text("GLM default: https://api.z.ai/api/coding/paas/v4/chat/completions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                TextField("Model", text: $settings.model).autocapitalization(.none).disableAutocorrection(true)
                TextField("Operator name", text: $settings.operatorSoul.displayName)
                TextField("Persona", text: $settings.operatorSoul.persona)
                TextField("Communication style", text: $settings.operatorSoul.communicationStyle)
                Text("Additional persona instructions (the immutable core safety policy is always applied separately).")
                    .font(.caption).foregroundColor(.secondary)
                TextEditor(text: $settings.operatorSoul.additionalInstructions).frame(height: 120)
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
