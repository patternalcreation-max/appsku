import SwiftUI
import WebKit
import UIKit
import Security

// MARK: - Agent models

enum ToolRisk: String, Codable, Equatable {
    case auto
    case approval
    case blocked
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

@MainActor
final class BrowserState: NSObject, ObservableObject {
    private final class PendingNavigationAction {
        let actionID = UUID()
        let runID: UUID
        let action: String
        let completion: (String) -> Void
        let bindsFirstNavigation: Bool
        let expectedTarget: CanonicalPageTarget?
        var navigation: WKNavigation?
        var didStart = false
        var noNavigationWorkItem: DispatchWorkItem?
        var timeoutWorkItem: DispatchWorkItem?

        // Action-owned atomic invocation candidate state (private). Never exposed
        // in UI/log/result. The epoch identifies the exact invocation; the
        // in-flight flag is the only window a candidate may be captured; the
        // candidate fields hold at most one WKNavigation and/or one same-document
        // transition; the terminal receipt stores a closed bounded result if the
        // candidate finishes before authorization.
        let atomicInvocationEpoch = UUID()
        var atomicInvocationInFlight = false
        var atomicCandidateNavigation: WKNavigation?
        var atomicCandidateSameDocument = false
        var atomicCandidateTerminalReceipt: String?

        init(runID: UUID, action: String, bindsFirstNavigation: Bool, expectedTarget: CanonicalPageTarget?, completion: @escaping (String) -> Void) {
            self.runID = runID
            self.action = action
            self.bindsFirstNavigation = bindsFirstNavigation
            self.expectedTarget = expectedTarget
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
    @Published var history: [HistoryEntry] = []
    @Published var bookmarks: [Bookmark] = []

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private(set) var activeRun: RunContext?
    private var llmTask: URLSessionDataTask?
    private var pendingNavigationAction: PendingNavigationAction?
    private var pageIdentity = PageIdentityReducer()
    private var navigationBindings: [ObjectIdentifier: (navigation: WKNavigation, id: UUID)] = [:]
    private var startedNavigationIDs: Set<UUID> = []
    private var lastObservedURLString: String?
    private let privateTargetMap = PrivateElementReferenceMap()
    private let approvalAuthority = ApprovalAuthority()
    private var activeModelBinding: SnapshotIdentity?
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
            webView.observe(\.title, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async {
                let newTitle = view.title ?? ""
                self?.pageTitle = newTitle
                if let url = view.url, !newTitle.isEmpty, !url.absoluteString.isEmpty {
                    HistoryStore.record(url: url.absoluteString, title: newTitle)
                    self?.history = HistoryStore.load()
                }
            } },
            webView.observe(\.url, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.handleObservedURL(view.url) } },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.canGoBack = view.canGoBack } },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.canGoForward = view.canGoForward } },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in DispatchQueue.main.async { self?.isLoading = view.isLoading } }
        ]
        history = HistoryStore.load()
        bookmarks = BookmarkStore.load()
        loadAddress()
    }

    func addStep(_ icon: String, _ title: String, _ detail: String = "") {
        steps.append(AgentStep(icon: icon, title: title, detail: Redactor.text(detail)))
    }

    private func invalidatePageDerivedAuthority() {
        snapshot = nil
        privateTargetMap.invalidate()
        pendingApproval = nil
        activeModelBinding = nil
        approvalAuthority.invalidateAll()
    }

    private func navigationID(for navigation: WKNavigation) -> UUID {
        let key = ObjectIdentifier(navigation)
        if let existing = navigationBindings[key], existing.navigation === navigation { return existing.id }
        let created = UUID()
        navigationBindings[key] = (navigation, created)
        return created
    }

    private func retireNavigation(_ navigation: WKNavigation) {
        let key = ObjectIdentifier(navigation)
        guard let binding = navigationBindings[key], binding.navigation === navigation else { return }
        navigationBindings.removeValue(forKey: key)
        startedNavigationIDs.remove(binding.id)
    }

    private func cancelRunForPageTransition(_ message: String, asError: Bool = false) {
        let hadRunAuthority = activeRun != nil || pendingNavigationAction != nil || pendingApproval != nil
        llmTask?.cancel()
        llmTask = nil
        clearPendingNavigationAction()
        activeRun = nil
        pendingApproval = nil
        isAsking = false
        guard hadRunAuthority else { return }
        let safe = Redactor.text(message)
        phase = asError ? .error(safe) : .stopped
        addStep(asError ? "⚠️" : "⏹", asError ? "Page transition failed" : "Run stopped", safe)
    }

    private func handleObservedURL(_ url: URL?) {
        let observedURLString = url?.absoluteString
        currentURL = observedURLString ?? ""
        address = observedURLString ?? address
        guard observedURLString != lastObservedURLString else { return }
        lastObservedURLString = observedURLString
        guard let url, let target = try? CanonicalPageTarget(validating: url) else {
            if !pageIdentity.inFlightTopLevelNavigation {
                _ = pageIdentity.webContentProcessTerminated()
                cancelRunForPageTransition("The page URL became invalid")
                invalidatePageDerivedAuthority()
            }
            return
        }
        if pageIdentity.observeTopLevelURL(target) {
            if let pending = pendingNavigationAction,
               isActive(runID: pending.runID),
               pending.atomicInvocationInFlight,
               pending.atomicCandidateNavigation == nil,
               !pending.atomicCandidateSameDocument {
                pending.atomicCandidateSameDocument = true
                invalidatePageDerivedAuthority()
            } else {
                cancelRunForPageTransition("The page changed outside the active action")
                invalidatePageDerivedAuthority()
            }
        }
    }

    private func currentSnapshotIdentity() -> SnapshotIdentity? {
        guard let snapshot, pageIdentity.accepts(snapshot.identity) else { return nil }
        return snapshot.identity
    }

    private func isCurrent(_ identity: SnapshotIdentity?) -> Bool {
        guard let identity else { return false }
        return pageIdentity.accepts(identity) && currentSnapshotIdentity() == identity
    }

    private func isActive(runID: UUID) -> Bool { activeRun?.runID == runID }

    private func beginRun(command: String) -> RunContext {
        llmTask?.cancel()
        clearPendingNavigationAction()
        pendingApproval = nil
        approvalAuthority.invalidateAll()
        activeModelBinding = nil
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

    // MARK: - Bookmarks

    func toggleBookmark() {
        let url = currentURL.isEmpty ? address : currentURL
        guard !url.isEmpty else { return }
        if let existing = bookmarks.first(where: { $0.url == url }) {
            BookmarkStore.remove(id: existing.id)
        } else {
            BookmarkStore.add(url: url, title: pageTitle.isEmpty ? url : pageTitle)
        }
        bookmarks = BookmarkStore.load()
    }

    var isCurrentPageBookmarked: Bool {
        let url = currentURL.isEmpty ? address : currentURL
        return !url.isEmpty && bookmarks.contains(where: { $0.url == url })
    }

    func clearHistory() {
        HistoryStore.clear()
        history = []
    }

    func navigate(to url: String) {
        address = url
        loadAddress()
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
        if runID == nil, activeRun != nil { completion?(nil); return }
        guard !webView.isLoading, let capturedIdentity = pageIdentity.captureSnapshotIdentity() else {
            settleSnapshotFailure(runID: runID, message: "Committed page is not ready for a snapshot")
            completion?(nil)
            return
        }
        phase = .observing
        let snapshotBinding = capturedIdentity.snapshotID.uuidString.lowercased()
        webView.callAsyncJavaScript(
            SnapshotSanitizer.javascript,
            arguments: ["snapshotBinding": snapshotBinding],
            in: nil,
            contentWorld: WKContentWorld.defaultClient
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                if let runID, !self.isActive(runID: runID) { return }
                guard self.pageIdentity.accepts(capturedIdentity) else { completion?(nil); return }
                switch result {
                case .success(let value):
                    let raw = value as? String ?? "{}"
                    guard let data = raw.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        self.settleSnapshotFailure(runID: runID, message: "Bad JS payload")
                        completion?(nil); return
                    }
                    let decoded = BrowserState.decodeSnapshot(object, identity: capturedIdentity, snapshotBinding: snapshotBinding)
                    guard self.pageIdentity.accepts(capturedIdentity) else { completion?(nil); return }
                    self.privateTargetMap.replace(with: decoded.references, identity: capturedIdentity)
                    self.snapshot = decoded.snapshot
                    self.addStep("👁", "Observed page", "\(decoded.snapshot.text.count) chars, \(decoded.snapshot.links.count) links, \(decoded.snapshot.inputs.count) inputs, \(decoded.snapshot.tables.count) tables")
                    if runID == nil, self.activeRun == nil { self.phase = .idle }
                    completion?(decoded.snapshot)
                case .failure(let error):
                    self.settleSnapshotFailure(runID: runID, message: error.localizedDescription)
                    completion?(nil)
                }
            }
        }
    }

    static func decodeSnapshot(_ object: [String: Any], identity: SnapshotIdentity, snapshotBinding: String) -> (snapshot: PageSnapshot, references: [StableElementReference]) {
        func raw(_ dictionary: [String: Any], _ key: String) -> String { dictionary[key] as? String ?? "" }
        func string(_ dictionary: [String: Any], _ key: String) -> String { SnapshotSanitizer.sanitizedMetadata(raw(dictionary, key)) }
        func canonicalAction(_ value: String) -> String { (try? CanonicalPageTarget(validating: value).serializedURL) ?? "__invalid__" }
        func metadata(_ dictionary: [String: Any], formMethod: String = "", formAction: String = "") -> StableElementMetadata {
            let method = formMethod.isEmpty ? raw(dictionary, "formMethod") : formMethod
            let candidateAction = formAction.isEmpty ? raw(dictionary, "formAction") : formAction
            let action = candidateAction.isEmpty ? "" : canonicalAction(candidateAction)
            let ariaLabel = raw(dictionary, "ariaLabel")
            return StableElementMetadata.classify(
                tag: raw(dictionary, "tag"), type: raw(dictionary, "type"), role: raw(dictionary, "role"), name: raw(dictionary, "name"),
                label: ariaLabel.isEmpty ? raw(dictionary, "label") : ariaLabel, text: raw(dictionary, "text"),
                placeholder: raw(dictionary, "placeholder"), autocomplete: raw(dictionary, "autocomplete"), visible: dictionary["isVisible"] as? Bool ?? false,
                formMethod: method, formAction: action
            )
        }
        var references: [StableElementReference] = []
        let snapshotPageURL = object["url"] as? String ?? ""
        func actionable(_ dictionary: [String: Any], formMethod: String = "", formAction: String = "") -> StableElementReference? {
            let binding = StableElementReference(
                privateSelector: raw(dictionary, "selector"),
                snapshotMarker: snapshotBinding,
                pageURL: snapshotPageURL,
                identity: identity,
                metadata: metadata(dictionary, formMethod: formMethod, formAction: formAction)
            )
            guard binding.isExecutableBinding else { return nil }
            references.append(binding)
            return binding
        }
        func element(_ dictionary: [String: Any], isActionable: Bool) -> DOMElement? {
            let binding = isActionable ? actionable(dictionary) : nil
            if isActionable && binding == nil { return nil }
            return DOMElement(ref: binding?.ref, tag: string(dictionary, "tag"), text: string(dictionary, "text"), ariaLabel: string(dictionary, "ariaLabel"), role: string(dictionary, "role"), type: string(dictionary, "type"), name: string(dictionary, "name"), placeholder: string(dictionary, "placeholder"), isVisible: dictionary["isVisible"] as? Bool ?? false)
        }
        let headings = (object["headings"] as? [[String: Any]] ?? []).compactMap { element($0, isActionable: false) }
        let buttons = (object["buttons"] as? [[String: Any]] ?? []).compactMap { element($0, isActionable: true) }
        let inputs = (object["inputs"] as? [[String: Any]] ?? []).compactMap { element($0, isActionable: true) }
        let links = (object["links"] as? [[String: Any]] ?? []).compactMap { dictionary -> PageLink? in
            guard let binding = actionable(dictionary) else { return nil }
            return PageLink(ref: binding.ref, text: string(dictionary, "text"), href: SnapshotSanitizer.sanitizedURL(raw(dictionary, "href")))
        }
        let forms = (object["forms"] as? [[String: Any]] ?? []).compactMap { form -> PageForm? in
            let method = raw(form, "method")
            let action = canonicalAction(raw(form, "action"))
            guard let formBinding = actionable(form, formMethod: method, formAction: action) else { return nil }
            let fields = (form["fields"] as? [[String: Any]] ?? []).compactMap { field -> PageFormField? in
                guard let fieldBinding = actionable(field, formMethod: method, formAction: action) else { return nil }
                return PageFormField(ref: fieldBinding.ref, tag: string(field, "tag"), type: string(field, "type"), name: string(field, "name"), label: string(field, "label"), placeholder: string(field, "placeholder"), required: field["required"] as? Bool ?? false)
            }
            return PageForm(ref: formBinding.ref, action: SnapshotSanitizer.sanitizedURL(action), method: SnapshotSanitizer.sanitizedMetadata(method), fields: fields)
        }
        let tables = (object["tables"] as? [[String: Any]] ?? []).map { table in
            PageTable(headers: (table["headers"] as? [String] ?? []).map(SnapshotSanitizer.sanitizedMetadata), rows: (table["rows"] as? [[String]] ?? []).map { $0.map(SnapshotSanitizer.sanitizedMetadata) })
        }
        let snapshot = PageSnapshot(identity: identity, title: SnapshotSanitizer.sanitizedMetadata(object["title"] as? String ?? ""), url: SnapshotSanitizer.sanitizedURL(object["url"] as? String ?? ""), text: SnapshotSanitizer.sanitizedMetadata(object["text"] as? String ?? ""), headings: headings, buttons: buttons, inputs: inputs, links: links, forms: forms, tables: tables)
        return (snapshot, references)
    }

    // MARK: AI + Agent loop

    func askPage(question: String, settings: AgentSettings) {
        let context = beginRun(command: question)
        extractSnapshot(runID: context.runID) { [weak self] snap in
            guard let self = self, self.isActive(runID: context.runID), let snap = snap else { return }
            self.isAsking = true
            self.activeModelBinding = snap.identity
            self.agentAnswer = "Thinking..."
            let messages = [["role": "system", "content": settings.composedSystemPrompt], ["role": "user", "content": "Question: \(question)\n\n\(snap.summaryText)"]]
            self.callLLM(messages: messages, settings: settings, runID: context.runID) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self, self.isActive(runID: context.runID), self.isCurrent(self.activeModelBinding) else { return }
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
        approvalAuthority.invalidateAll()
        activeModelBinding = nil
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
            self.activeModelBinding = snap.identity
            let prompt = self.agentPrompt(command: context.command, snapshot: snap, previousResult: previousResult)
            self.addStep("💭", "Thinking", "Step \(self.stepIndex)/\(self.maxSteps)")
            let messages = [["role": "system", "content": settings.composedSystemPrompt], ["role": "user", "content": prompt]]
            self.callLLM(messages: messages, settings: settings, runID: context.runID) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self, self.isActive(runID: context.runID), self.isCurrent(self.activeModelBinding) else { return }
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
        guard isActive(runID: context.runID), isCurrent(activeModelBinding) else { return }
        switch parseAgentResponse(content) {
        case .failure(let error):
            phase = .error(error); addStep("⚠️", "Parser error", error); activeRun = nil
        case .success(let response):
            switch response.kind {
            case .final(let message):
                guard isCurrent(activeModelBinding) else { return }
                agentAnswer = Redactor.text(message); phase = .done; addStep("✅", "Final", message); activeRun = nil
            case .tool(let rawCall):
                let resolved = resolvedExecutionCall(rawCall)
                guard case .success(let call) = validate(resolved) else {
                    phase = .error("Tool schema validation failed"); addStep("⚠️", "Dispatch error", "Tool schema validation failed"); activeRun = nil; return
                }
                let risk = classify(call.transportCall)
                if risk == .blocked { phase = .done; addStep("⛔️", "Blocked", "\(call.tool): \(blockReason(call.transportCall))"); activeRun = nil; return }
                if risk == .approval {
                    let request = proposal(call: call, context: context, risk: risk)
                    pendingApproval = request
                    phase = .awaitingApproval
                    addStep("⏸", "Needs approval", request.preview)
                } else {
                    dispatch(call: call, context: context, authority: .automatic) { [weak self] result in
                        guard let self = self, self.isActive(runID: context.runID) else { return }
                        self.continueAgent(context: context, settings: settings, previousResult: result)
                    }
                }
            }
        }
    }

    func approvePending(settings: AgentSettings) {
        guard let request = pendingApproval, let context = activeRun, request.runID == context.runID else { pendingApproval = nil; return }
        pendingApproval = nil
        let token = approvalAuthority.issue(for: request)
        addStep("✅", "Approved", request.preview)
        dispatch(call: request.call, context: context, authority: .approved(token: token, proposal: request)) { [weak self] result in
            guard let self = self, self.isActive(runID: context.runID) else { return }
            self.continueAgent(context: context, settings: settings, previousResult: result)
        }
    }

    func denyPending() {
        guard let request = pendingApproval, request.runID == activeRun?.runID else { pendingApproval = nil; return }
        addStep("🚫", "Denied", request.preview)
        pendingApproval = nil
        approvalAuthority.invalidateAll()
        activeRun = nil
        phase = .stopped
    }

    func stageManualApproval(call: ToolCall) {
        let context = beginRun(command: "Manual \(call.tool)")
        guard case .success(let validated) = validate(resolvedExecutionCall(call)) else {
            phase = .error("Tool schema validation failed"); activeRun = nil; return
        }
        let risk = classify(validated.transportCall)
        guard risk != .blocked else {
            phase = .done; addStep("⛔️", "Blocked", "\(call.tool): \(blockReason(validated.transportCall))"); activeRun = nil; return
        }
        pendingApproval = proposal(call: validated, context: context, risk: .approval)
        phase = .awaitingApproval
    }

    func parseAgentResponse(_ text: String) -> AgentParseResult { AgentProtocol.parse(text) }

    private func validate(_ call: ToolCall) -> Result<ValidatedToolCall, ToolDispatchError> {
        ToolDispatchPolicy.validate(call, pageIdentity: currentSnapshotIdentity()) { [privateTargetMap] ref, identity in
            privateTargetMap.resolve(ref: ref, identity: identity)?.reference
        }
    }

    private func proposal(call: ValidatedToolCall, context: RunContext, risk: ToolRisk, id: UUID = UUID()) -> ApprovalRequest {
        ApprovalRequest(id: id, runID: context.runID, call: call, risk: risk, preview: ToolDispatchPolicy.safePreview(call), reason: ToolRegistry.approvalReason(for: call.tool))
    }

    func classify(_ call: ToolCall) -> ToolRisk {
        let descriptor = ToolRegistry.descriptor(for: call.tool)
        if SensitiveToolPolicy.blockReason(for: call.arguments) != nil { return .blocked }
        switch descriptor.defaultApprovalPolicy {
        case .automatic: return .auto
        case .requireApproval, .alwaysRequireApproval: return .approval
        }
    }

    func blockReason(_ call: ToolCall) -> String {
        SensitiveToolPolicy.blockReason(for: call.arguments) ?? "Blocked by tool policy."
    }

    func resolvedExecutionCall(_ call: ToolCall) -> ToolCall {
        guard call.tool.isExport else { return call }
        var arguments = call.arguments.objectValue ?? [:]
        let contentKey: String
        switch call.tool {
        case .exportMarkdown: contentKey = "body"
        case .exportJSON: contentKey = "json"
        case .exportCSV: contentKey = "rows"
        default: return call
        }
        if arguments[contentKey] == nil { arguments[contentKey] = .string(Redactor.exportBody(agentAnswer)) }
        return ToolCall(id: call.id, tool: call.tool, arguments: .object(arguments))
    }

    private func clearPendingNavigationAction() {
        pendingNavigationAction?.cancelTimers()
        pendingNavigationAction = nil
    }

    private func prepareNavigationAction(context: RunContext, action: String, bindsFirstNavigation: Bool, expectedTarget: CanonicalPageTarget? = nil, completion: @escaping (String) -> Void) {
        clearPendingNavigationAction()
        pendingNavigationAction = PendingNavigationAction(runID: context.runID, action: action, bindsFirstNavigation: bindsFirstNavigation, expectedTarget: expectedTarget, completion: completion)
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

    private func performNavigation(context: RunContext, action: String, expectedTarget: CanonicalPageTarget? = nil, completion: @escaping (String) -> Void, start: () -> WKNavigation?) {
        guard isActive(runID: context.runID) else { return }
        prepareNavigationAction(context: context, action: action, bindsFirstNavigation: false, expectedTarget: expectedTarget, completion: completion)
        guard let pending = pendingNavigationAction, pending.runID == context.runID else { return }
        guard let navigation = start() else {
            settleNavigationAction(actionID: pending.actionID, runID: context.runID, result: "\(action) did not start")
            return
        }
        pending.navigation = navigation
        pending.didStart = true
        scheduleNavigationTimeout(for: pending)
    }

    private func failDispatch(context: RunContext, message: String) {
        guard activeRun == context else { return }
        let safe = boundedResult(message, maximumBytes: 1_024)
        llmTask?.cancel()
        llmTask = nil
        clearPendingNavigationAction()
        pendingApproval = nil
        approvalAuthority.invalidateAll()
        activeModelBinding = nil
        activeRun = nil
        isAsking = false
        phase = .error(safe)
        addStep("⚠️", "Dispatch failed", safe)
    }

    private func boundedResult(_ raw: String, maximumBytes: Int) -> String {
        let safe = Redactor.text(raw)
        let limit = max(0, maximumBytes)
        guard safe.utf8.count > limit else { return safe }
        var result = ""
        for character in safe {
            let next = String(character)
            guard result.utf8.count + next.utf8.count <= limit else { break }
            result.append(character)
        }
        return result
    }

    /// Dispatch Gate + Commit Gate. No other method accepts an executable tool call.
    private func dispatch(call: ValidatedToolCall, context: RunContext, authority: CommitAuthority, completion: @escaping (String) -> Void) {
        guard activeRun == context else { return }

        switch authority {
        case .approved(let token, let proposal):
            guard case .success = approvalAuthority.consume(token, expected: proposal) else {
                failDispatch(context: context, message: "Approval authority was missing, expired, or mismatched")
                return
            }
            let trustedProposal = self.proposal(call: call, context: context, risk: .approval, id: proposal.id)
            guard proposal == trustedProposal,
                  proposal.runID == context.runID,
                  proposal.call == call,
                  proposal.risk == .approval,
                  classify(call.transportCall) == .approval else {
                failDispatch(context: context, message: "Approval proposal did not match the current action")
                return
            }
        case .automatic:
            let descriptor = ToolRegistry.descriptor(for: call.tool)
            guard descriptor.defaultApprovalPolicy == .automatic,
                  classify(call.transportCall) == .auto else {
                failDispatch(context: context, message: "Automatic authority cannot execute this action")
                return
            }
        }

        guard case .success(let liveCall) = validate(call.transportCall), liveCall == call else {
            failDispatch(context: context, message: "The validated action became stale before execution")
            return
        }

        let descriptor = ToolRegistry.descriptor(for: liveCall.tool)
        if descriptor.isPageBound {
            guard let identity = liveCall.pageIdentity,
                  pageIdentity.accepts(identity),
                  currentSnapshotIdentity() == identity else {
                failDispatch(context: context, message: "The page or snapshot changed before execution")
                return
            }
        }
        if let originalTarget = call.target {
            guard let liveTarget = liveCall.target,
                  liveTarget.ref == originalTarget.ref,
                  liveTarget.fingerprint == originalTarget.fingerprint,
                  liveTarget == originalTarget else {
                failDispatch(context: context, message: "The element target changed before execution")
                return
            }
        }

        executeValidated(call: liveCall, context: context, completion: completion)
    }

    private func executeValidated(call: ValidatedToolCall, context: RunContext, completion: @escaping (String) -> Void) {
        guard activeRun == context else { return }
        let descriptor = ToolRegistry.descriptor(for: call.tool)
        let finish: (String) -> Void = { [weak self] result in
            guard let self, self.activeRun == context else { return }
            completion(self.boundedResult(result, maximumBytes: descriptor.budget.maximumResultBytes))
        }
        phase = .acting(call.tool.rawValue)
        addStep("⚙️", "Running \(call.tool)", ToolDispatchPolicy.safePreview(call))

        switch call.tool {
        case .snapshotPage, .extractText, .extractLinks, .extractForms, .extractTables:
            extractSnapshot(runID: context.runID) { snapshot in
                finish(snapshot?.summaryText ?? "Snapshot unavailable")
            }
        case .saveMemoryNote:
            do {
                _ = try MemoryStore.save(
                    title: call.arguments["title"]?.stringValue ?? "K3 Note",
                    body: call.arguments["body"]?.stringValue ?? "",
                    url: currentURL
                )
                addStep("💾", "Saved note", "Local note saved")
                finish("Memory note saved")
            } catch {
                addStep("⚠️", "Note save failed", "Local note write failed")
                finish("Memory note rejected: localWriteFailure")
            }
        case .readMemoryNotes:
            finish(MemoryStore.recent())
        case .scroll:
            guard let direction = call.arguments["direction"]?.stringValue,
                  let amount = call.arguments["amount"]?.integerValue else {
                failDispatch(context: context, message: "Validated scroll arguments were unavailable")
                return
            }
            // Scroll is page-bound. The validated call must carry a page identity
            // that is still current, otherwise a same-document or full navigation
            // could land the approved scroll on a different page. Bind the isolated
            // snapshot marker, canonical page URL, and origin through WebKit
            // arguments; the scroll JS re-verifies all three synchronously before
            // scrollBy, rejecting with {status:"rejected",code:"pageMismatch"} on
            // any mismatch. No string interpolation of direction/amount.
            guard let pageIdentity = call.pageIdentity,
                  let snapshot = self.snapshot,
                  snapshot.identity.snapshotID == pageIdentity.snapshotID else {
                failDispatch(context: context, message: "Scroll requires a current page identity and snapshot")
                return
            }
            let snapshotMarker = snapshot.identity.snapshotID.uuidString.lowercased()
            guard let canonicalTarget = try? CanonicalPageTarget(validating: snapshot.url),
                  canonicalTarget.serializedURL == snapshot.url || canonicalTarget.origin == pageIdentity.origin,
                  canonicalTarget.origin == pageIdentity.origin else {
                failDispatch(context: context, message: "Scroll target origin does not match the validated page")
                return
            }
            let boundPageURL = canonicalTarget.serializedURL
            let boundOrigin = pageIdentity.origin
            let script = #"""
            "use strict";
            if (typeof snapshotMarker !== "string" || typeof boundPageURL !== "string" || typeof boundOrigin !== "string" ||
                typeof direction !== "string" || typeof amount !== "number") {
              return {status: "rejected", code: "pageMismatch"};
            }
            const encoder = new TextEncoder();
            function asciiLowercase(value) { return String(value).replace(/[A-Z]/g, function (c) { return String.fromCharCode(c.charCodeAt(0) + 32); }); }
            function canonicalPageURL(value) {
              if (typeof value !== "string" || value.length === 0 || encoder.encode(value).length > 4096 || /[\s\\\u0000-\u001f\u007f]/u.test(value)) return null;
              const schemeMatch = /^(https?):\/\//iu.exec(value);
              if (!schemeMatch) return null;
              const authority = value.slice(schemeMatch[0].length).split(/[/?#]/u, 1)[0];
              if (!authority || /[@%]/u.test(authority) || !/^[\x00-\x7f]+$/u.test(authority)) return null;
              let rawHost;
              let rawPort = "";
              if (authority.startsWith("[")) {
                const close = authority.indexOf("]");
                if (close <= 1) return null;
                rawHost = authority.slice(0, close + 1);
                const suffix = authority.slice(close + 1);
                if (suffix) {
                  if (!/^:[0-9]+$/u.test(suffix)) return null;
                  rawPort = suffix.slice(1);
                }
              } else {
                const pieces = authority.split(":");
                if (pieces.length > 2 || !pieces[0]) return null;
                rawHost = pieces[0];
                if (pieces.length === 2) {
                  if (!/^[0-9]+$/u.test(pieces[1])) return null;
                  rawPort = pieces[1];
                }
                if (rawHost.length > 253 || rawHost.startsWith(".") || rawHost.endsWith(".")) return null;
                const labels = rawHost.split(".");
                if (labels.some(function (label) { return !label || label.length > 63 || label.startsWith("-") || label.endsWith("-") || !/^[A-Za-z0-9-]+$/u.test(label); })) return null;
              }
              let parsed;
              try { parsed = new URL(value); } catch (_) { return null; }
              if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return null;
              if (parsed.username || parsed.password || !parsed.hostname || !/^[\x00-\x7f]+$/u.test(parsed.hostname)) return null;
              if (asciiLowercase(parsed.hostname) !== asciiLowercase(rawHost)) return null;
              const defaultPort = parsed.protocol === "https:" ? "443" : "80";
              if (rawPort && String(Number(rawPort)) !== defaultPort) return null;
              if (rawPort && (!/^(80|443)$/u.test(rawPort) || rawPort !== defaultPort)) return null;
              parsed.protocol = asciiLowercase(parsed.protocol);
              parsed.hostname = asciiLowercase(parsed.hostname);
              parsed.port = "";
              const canonical = parsed.href;
              if (!canonical || encoder.encode(canonical).length > 4096 || /[\s\\\u0000-\u001f\u007f]/u.test(canonical)) return null;
              return canonical;
            }
            if (globalThis.__K3BrowserPrivateSnapshotDocumentBinding_8f6d2a41 !== snapshotMarker) {
              return {status: "rejected", code: "pageMismatch"};
            }
            const expectedPageURL = canonicalPageURL(boundPageURL);
            const livePageURL = canonicalPageURL(location.href);
            if (expectedPageURL === null || expectedPageURL !== boundPageURL || livePageURL !== expectedPageURL) {
              return {status: "rejected", code: "pageMismatch"};
            }
            if (location.origin !== boundOrigin) {
              return {status: "rejected", code: "pageMismatch"};
            }
            const delta = direction === "up" ? -amount : amount;
            window.scrollBy({top: delta, left: 0, behavior: "smooth"});
            return {status: "executed", code: "scrolled"};
            """#
            webView.callAsyncJavaScript(
                script,
                arguments: [
                    "direction": direction,
                    "amount": amount,
                    "snapshotMarker": snapshotMarker,
                    "boundPageURL": boundPageURL,
                    "boundOrigin": boundOrigin,
                ],
                in: nil,
                contentWorld: WKContentWorld.defaultClient
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let value):
                        if let object = value as? [String: Any],
                           let status = object["status"] as? String,
                           let code = object["code"] as? String,
                           status == "executed", code == "scrolled" {
                            finish("executed:scrolled")
                        } else {
                            finish("rejected:pageMismatch")
                        }
                    case .failure: finish("rejected:webKitFailure")
                    }
                }
            }
        case .openURL:
            guard let target = call.effectiveTarget else {
                failDispatch(context: context, message: "Validated navigation target was unavailable")
                return
            }
            performNavigation(context: context, action: "Open URL", expectedTarget: target, completion: finish) {
                self.webView.load(URLRequest(url: target.url))
            }
        case .back:
            performNavigation(context: context, action: "Back", completion: finish) { self.webView.goBack() }
        case .forward:
            performNavigation(context: context, action: "Forward", completion: finish) { self.webView.goForward() }
        case .reload:
            performNavigation(context: context, action: "Reload", completion: finish) { self.webView.reload() }
        case .fillSelector, .clickSelector, .selectOption, .submitForm:
            executeAtomicElement(call: call, context: context, completion: finish)
        case .exportMarkdown, .exportJSON, .exportCSV:
            let title = call.arguments["title"]?.stringValue ?? "k3-export"
            let body: String
            let ext: String
            switch call.tool {
            case .exportMarkdown:
                body = call.arguments["body"]?.stringValue ?? ""
                ext = "md"
            case .exportJSON:
                body = call.arguments["json"]?.stringValue ?? ""
                ext = "json"
            case .exportCSV:
                body = call.arguments["rows"]?.stringValue ?? ""
                ext = "csv"
            default:
                return
            }
            finish(exportText(title: title, body: body, ext: ext) ? "Export ready" : "Export failed")
        }
    }

    private func executeAtomicElement(call: ValidatedToolCall, context: RunContext, completion: @escaping (String) -> Void) {
        guard activeRun == context,
              let reference = call.target,
              let operation = AtomicElementOperation(tool: call.tool) else {
            failDispatch(context: context, message: "Validated element operation was unavailable")
            return
        }
        let value: String?
        switch operation {
        case .fill, .select:
            guard let validatedValue = call.arguments["value"]?.stringValue else {
                failDispatch(context: context, message: "Validated element value was unavailable")
                return
            }
            value = validatedValue
        case .click, .submit:
            value = nil
        }

        let waitsForPossibleNavigation = operation == .click || operation == .submit
        var preparedActionID: UUID?
        var invocationEpoch: UUID?
        if waitsForPossibleNavigation {
            let action = operation == .click ? "Click" : "Submit"
            prepareNavigationAction(context: context, action: action, bindsFirstNavigation: true, completion: completion)
            guard let pending = pendingNavigationAction, pending.runID == context.runID else {
                failDispatch(context: context, message: "Navigation settlement could not be prepared")
                return
            }
            preparedActionID = pending.actionID
            invocationEpoch = pending.atomicInvocationEpoch
            // Arm the exact atomic invocation window immediately before the sole
            // AtomicElementExecutor call. This is the only window a WKNavigation
            // or same-document transition may be captured as this action's
            // candidate. No synthetic timeout starts before the atomic receipt:
            // timing out first could report failure and then allow a delayed
            // effect. A real navigation starts its timeout only after the
            // candidate is bound post-receipt; a no-navigation effect settles
            // only after the atomic receipt.
            pending.atomicInvocationInFlight = true
        }

        Task { @MainActor [weak self] in
            guard let self, self.activeRun == context else { return }
            let receipt = await AtomicElementExecutor.execute(
                in: self.webView,
                reference: reference,
                operation: operation,
                value: value
            )
            let closedReceipt = "\(receipt.status.rawValue):\(receipt.code.rawValue)"

            guard waitsForPossibleNavigation else {
                completion(closedReceipt)
                return
            }
            guard let actionID = preparedActionID,
                  let epoch = invocationEpoch,
                  let pending = self.pendingNavigationAction,
                  pending.actionID == actionID,
                  pending.runID == context.runID,
                  pending.atomicInvocationEpoch == epoch else { return }

            // Clear the atomic invocation window immediately after the await
            // returns. Any transition observed after this point is unrelated.
            pending.atomicInvocationInFlight = false

            switch receipt.status {
            case .rejected:
                // Rejected + any candidate: the candidate is untrusted/unrelated.
                // Stop/fail the run; never claim the candidate.
                self.clearPendingNavigationAction()
                self.failDispatch(context: context, message: closedReceipt)
            case .executed:
                if let navigation = pending.atomicCandidateNavigation {
                    // Executed + exact WKNavigation candidate: bind and authorize.
                    pending.navigation = navigation
                    pending.atomicCandidateNavigation = nil
                    pending.didStart = true
                    pending.noNavigationWorkItem?.cancel()
                    if let terminalReceipt = pending.atomicCandidateTerminalReceipt {
                        // Candidate already terminal: settle with stored receipt.
                        self.settleNavigationAction(actionID: actionID, runID: context.runID, result: terminalReceipt)
                    } else {
                        // Candidate still in-flight: start normal navigation timeout.
                        self.scheduleNavigationTimeout(for: pending)
                    }
                } else if pending.atomicCandidateSameDocument {
                    // Executed + same-document candidate: settle once with closed receipt.
                    self.settleNavigationAction(actionID: actionID, runID: context.runID, result: closedReceipt)
                } else {
                    // Executed + no candidate: 0.8s no-navigation grace. Any
                    // transition after the invocation window is unrelated and
                    // must cancel, not be claimed.
                    if pending.didStart { return }
                    let work = DispatchWorkItem { [weak self, weak pending] in
                        guard let self,
                              let pending,
                              let current = self.pendingNavigationAction,
                              current.actionID == pending.actionID,
                              current.runID == context.runID,
                              !current.didStart else { return }
                        self.settleNavigationAction(actionID: current.actionID, runID: context.runID, result: closedReceipt)
                    }
                    pending.noNavigationWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
                }
            }
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

    func exportLog() {
        // Mission Control export must go through the same schema validation,
        // approval, and commit gate as model-generated exports. Never call
        // exportText directly from Mission Control; exportText remains the write
        // sink used by executeValidated only.
        let body = Redactor.exportBody(steps.map { "- \($0.icon) **\($0.title)**: \($0.detail)" }.joined(separator: "\n"))
        stageManualApproval(call: ToolCall(id: UUID().uuidString, tool: .exportMarkdown, arguments: .object(["title": .string("k3-agent-run"), "body": .string(body)])))
    }

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
        \(ToolRegistry.promptToolList).

        Return ONLY JSON.
        Final: {"type":"final","message":"..."}
        Tool: {"type":"tool_call","tool":"fill_selector","arguments":{"ref":"COPY_EXACT_CURRENT_SNAPSHOT_REF","value":"query"},"reason":"..."}
        Opaque element refs come only from the current snapshot and expire whenever the page changes. fill_selector, click_selector, select_option, and submit_form must use a current snapshot ref; never invent or substitute a raw selector.
        Use one tool per response. For click/fill/select/submit/navigation, propose the tool and wait for approval.
        """
    }

}

extension BrowserState: WKNavigationDelegate, WKUIDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard let navigation else { return }
        let runtimeID = navigationID(for: navigation)
        guard startedNavigationIDs.insert(runtimeID).inserted else { return }

        // Exact bound direct navigation (open/back/forward/reload): the pending
        // action already holds this WKNavigation from performNavigation.
        if let pending = pendingNavigationAction,
           isActive(runID: pending.runID),
           let boundNavigation = pending.navigation,
           boundNavigation === navigation {
            _ = pageIdentity.mainFrameProvisionalStart(navigationID: runtimeID, expectedTarget: pending.expectedTarget)
            invalidatePageDerivedAuthority()
            pending.didStart = true
            pending.noNavigationWorkItem?.cancel()
            scheduleNavigationTimeout(for: pending)
            return
        }

        // Candidate capture: a possible-navigation action may preserve the exact
        // WKNavigation as a candidate ONLY while that same action's atomic
        // invocation is in flight. Do not report/schedule action settlement yet.
        // Still advance page identity and invalidate old page authority.
        if let pending = pendingNavigationAction,
           isActive(runID: pending.runID),
           pending.atomicInvocationInFlight,
           pending.atomicCandidateNavigation == nil {
            pending.atomicCandidateNavigation = navigation
            _ = pageIdentity.mainFrameProvisionalStart(navigationID: runtimeID, expectedTarget: nil)
            invalidatePageDerivedAuthority()
            return
        }

        // Unrelated navigation outside any authorized window: fail-closed.
        _ = pageIdentity.mainFrameProvisionalStart(navigationID: runtimeID, expectedTarget: nil)
        cancelRunForPageTransition("Navigation was not initiated by the active agent action")
        invalidatePageDerivedAuthority()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard let navigation else { return }
        let runtimeID = navigationID(for: navigation)
        guard pageIdentity.inFlightNavigationID == runtimeID else { return }
        guard let url = webView.url, let target = try? CanonicalPageTarget(validating: url) else {
            cancelRunForPageTransition("Committed page target is invalid", asError: true)
            invalidatePageDerivedAuthority()
            return
        }
        _ = pageIdentity.mainFrameCommit(target, navigationID: runtimeID)
        // open_url authority: the approved expectedTarget is authoritative, not
        // page metadata. If the exact bound pending action expected a different
        // committed target, the approved action must not succeed. Consume is
        // already done: cancel/fail the run, invalidate all page-derived
        // authority/token, and prevent didFinish from reporting success.
        // back/forward/reload/click/submit have nil expectedTarget here.
        if let pending = pendingNavigationAction,
           pending.navigation === navigation,
           let expected = pending.expectedTarget,
           expected != target {
            cancelRunForPageTransition("The committed page did not match the approved target", asError: true)
            invalidatePageDerivedAuthority()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let navigation else { return }
        defer { retireNavigation(navigation) }
        guard let pending = pendingNavigationAction,
              isActive(runID: pending.runID) else { return }
        // When the exact navigation is only a not-yet-authorized candidate, store
        // a closed bounded terminal receipt and do not settle. The atomic receipt
        // will bind or reject the candidate; only then may this receipt be used.
        if pending.atomicCandidateNavigation === navigation {
            pending.atomicCandidateTerminalReceipt = "\(pending.action) completed"
            return
        }
        // Bound navigation after executed receipt: normal exact settlement.
        guard let boundNavigation = pending.navigation,
              boundNavigation === navigation,
              pending.didStart else { return }
        let url = Redactor.sanitizeURLString(webView.url?.absoluteString ?? "")
        settleNavigationAction(actionID: pending.actionID, runID: pending.runID, result: "\(pending.action) completed: \(url)")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let navigation else { return }
        defer { retireNavigation(navigation) }
        guard let pending = pendingNavigationAction,
              isActive(runID: pending.runID) else { return }
        if pending.atomicCandidateNavigation === navigation {
            pending.atomicCandidateTerminalReceipt = "\(pending.action) failed"
            return
        }
        guard let boundNavigation = pending.navigation,
              boundNavigation === navigation,
              pending.didStart else { return }
        settleNavigationAction(actionID: pending.actionID, runID: pending.runID, result: "\(pending.action) failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard let navigation else { return }
        defer { retireNavigation(navigation) }
        guard let pending = pendingNavigationAction,
              isActive(runID: pending.runID) else { return }
        if pending.atomicCandidateNavigation === navigation {
            pending.atomicCandidateTerminalReceipt = "\(pending.action) failed"
            return
        }
        guard let boundNavigation = pending.navigation,
              boundNavigation === navigation,
              pending.didStart else { return }
        settleNavigationAction(actionID: pending.actionID, runID: pending.runID, result: "\(pending.action) failed: \(error.localizedDescription)")
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        _ = pageIdentity.webContentProcessTerminated()
        navigationBindings.removeAll(keepingCapacity: false)
        startedNavigationIDs.removeAll(keepingCapacity: false)
        lastObservedURLString = nil
        cancelRunForPageTransition("The web content process terminated", asError: true)
        invalidatePageDerivedAuthority()
    }
}

// MARK: - UI

private enum BrowserPresentation: Int, Identifiable {
    case missionControl
    case share

    var id: Int { rawValue }
}

struct BrowserView: View {
    @StateObject private var state = BrowserState()
    @StateObject private var settings = AgentSettings()
    @StateObject private var dockPreferences = DockPreferences()
    @State private var showApprovalReview = false
    @State private var focusApprovalDeny = false
    @State private var activePresentation: BrowserPresentation?
    @State private var queuedPresentation: BrowserPresentation?
    @State private var revealApprovalAfterDismiss = false

    var body: some View {
        ZStack {
            browserWorkspace
                // The keyboard repositions the Capsule, never the WKWebView workspace.
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .disabled(state.pendingApproval != nil)
                .accessibilityHidden(state.pendingApproval != nil)

            agentOverlay
                .disabled(state.pendingApproval != nil)
                .accessibilityHidden(state.pendingApproval != nil)

            if showApprovalReview, let pending = state.pendingApproval {
                ApprovalReviewOverlay(
                    request: pending,
                    focusDeny: focusApprovalDeny,
                    onApprove: {
                        showApprovalReview = false
                        state.approvePending(settings: settings)
                    },
                    onDeny: {
                        showApprovalReview = false
                        state.denyPending()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(100)
            }
        }
        .onChange(of: state.pendingApproval?.id) { approvalID in
            if approvalID != nil {
                focusApprovalDeny = false
                queuedPresentation = nil
                state.showMissionControl = false
                state.showShare = false
                if activePresentation != nil {
                    revealApprovalAfterDismiss = true
                    activePresentation = nil
                } else {
                    showApprovalReview = true
                }
            } else {
                revealApprovalAfterDismiss = false
                showApprovalReview = false
            }
        }
        .onChange(of: state.showMissionControl) { requested in
            if requested { requestPresentation(.missionControl) }
        }
        .onChange(of: state.showShare) { requested in
            if requested { requestPresentation(.share) }
        }
        .sheet(item: $activePresentation, onDismiss: presentationDidDismiss) { route in
            switch route {
            case .missionControl:
                MissionControlView(state: state, settings: settings)
                    .disabled(state.pendingApproval != nil)
                    .accessibilityHidden(state.pendingApproval != nil)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .share:
                ShareSheet(items: state.shareItems)
            }
        }
    }

    private var browserWorkspace: some View {
        VStack(spacing: 0) {
            BrowserChromeView(
                address: $state.address,
                canGoBack: state.canGoBack,
                canGoForward: state.canGoForward,
                isLoading: state.isLoading,
                estimatedProgress: state.estimatedProgress,
                isBookmarked: state.isCurrentPageBookmarked,
                onBack: state.back,
                onForward: state.forward,
                onReload: state.reload,
                onStop: state.stopLoading,
                onSubmitAddress: state.loadAddress,
                onToggleBookmark: state.toggleBookmark
            )
            WebViewContainer(webView: state.webView)
        }
    }

    private var agentResultText: String {
        // A current terminal error must outrank any answer left by an older run.
        if case .error(let message) = state.phase {
            let errorMessage = Redactor.text(message).trimmingCharacters(in: .whitespacesAndNewlines)
            if !errorMessage.isEmpty { return errorMessage }
        }

        let answer = Redactor.text(state.agentAnswer).trimmingCharacters(in: .whitespacesAndNewlines)
        if !answer.isEmpty { return answer }

        switch state.phase {
        case .done, .error:
            if let finalStep = state.steps.last {
                let title = Redactor.text(finalStep.title).trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = Redactor.text(finalStep.detail).trimmingCharacters(in: .whitespacesAndNewlines)
                let stepResult = [title, detail].filter { !$0.isEmpty }.joined(separator: ": ")
                if !stepResult.isEmpty { return stepResult }
            }
            return Redactor.text(state.phase.label)
        default:
            return answer
        }
    }

    private var agentOverlay: some View {
        AdaptiveAgentOverlay(
            dockPreferences: dockPreferences,
            commandText: $state.commandText,
            phase: state.phase,
            resultText: agentResultText,
            isConfigured: !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            pendingApprovalCount: state.pendingApproval == nil ? 0 : 1,
            statusText: settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Agent Not Configured" : nil,
            hasPresentationConflict: activePresentation != nil || showApprovalReview,
            onRun: runCommand,
            onStop: state.stopAgent,
            onOpenMissionControl: { requestPresentation(.missionControl) },
            onExpandApproval: {
                guard state.pendingApproval != nil else { return }
                focusApprovalDeny = true
                showApprovalReview = true
            }
        )
    }

    private func requestPresentation(_ route: BrowserPresentation) {
        state.showMissionControl = false
        state.showShare = false
        guard state.pendingApproval == nil else { return }
        guard activePresentation != route else { return }
        if activePresentation == nil {
            activePresentation = route
        } else {
            queuedPresentation = route
            activePresentation = nil
        }
    }

    private func presentationDidDismiss() {
        if revealApprovalAfterDismiss, state.pendingApproval != nil {
            revealApprovalAfterDismiss = false
            showApprovalReview = true
            return
        }
        guard state.pendingApproval == nil, let next = queuedPresentation else {
            queuedPresentation = nil
            return
        }
        queuedPresentation = nil
        DispatchQueue.main.async {
            guard state.pendingApproval == nil else { return }
            activePresentation = next
        }
    }

    private func runCommand() {
        let command = state.commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        state.startAgent(command: command, settings: settings)
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
