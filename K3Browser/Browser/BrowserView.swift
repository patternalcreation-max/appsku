import SwiftUI
import WebKit
import Combine
import UIKit
import Security

struct PageSnapshot: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let text: String
    let links: [String]
    let forms: [String]

    var summaryText: String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let clippedText = String(cleanText.prefix(9000))
        let clippedLinks = links.prefix(40).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let clippedForms = forms.prefix(40).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return """
        K3 Browser Page Snapshot

        Title: \(title.isEmpty ? "(none)" : title)
        URL: \(url)

        TEXT
        \(clippedText.isEmpty ? "(no readable text)" : clippedText)

        LINKS
        \(clippedLinks.isEmpty ? "(none)" : clippedLinks)

        FORMS / INPUTS
        \(clippedForms.isEmpty ? "(none)" : clippedForms)
        """
    }
}

enum KeychainStore {
    static let service = "com.patternalcreation.k3browser"

    static func save(_ value: String, account: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8) else { return "" }
        return string
    }
}

final class AgentSettings: ObservableObject {
    @Published var apiKey: String = ""
    @Published var baseURL: String = UserDefaults.standard.string(forKey: "agent.baseURL") ?? "https://api.openai.com/v1/chat/completions"
    @Published var model: String = UserDefaults.standard.string(forKey: "agent.model") ?? "gpt-4o-mini"
    @Published var systemPrompt: String = UserDefaults.standard.string(forKey: "agent.systemPrompt") ?? "You are K3 Browser Agent. Be concise. Use the provided page snapshot. If user asks for page actions, output clear selectors and steps."

    init() {
        apiKey = KeychainStore.load(account: "agent.apiKey")
    }

    func save() {
        _ = KeychainStore.save(apiKey, account: "agent.apiKey")
        UserDefaults.standard.set(baseURL, forKey: "agent.baseURL")
        UserDefaults.standard.set(model, forKey: "agent.model")
        UserDefaults.standard.set(systemPrompt, forKey: "agent.systemPrompt")
    }
}

final class BrowserState: ObservableObject {
    @Published var urlText: String = "https://duckduckgo.com"
    @Published var currentURL: URL? = URL(string: "https://duckduckgo.com")
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var snapshot: PageSnapshot?
    @Published var snapshotStatus: String = "Ready"
    @Published var agentAnswer: String = ""
    @Published var isAsking = false
    @Published var toolStatus: String = "Tools ready"

    let webView: WKWebView

    init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.allowsBackForwardNavigationGestures = true
    }

    func load(_ raw: String? = nil) {
        let text = (raw ?? urlText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let url: URL
        if let parsed = URL(string: text), parsed.scheme != nil {
            url = parsed
        } else if text.contains(".") && !text.contains(" "), let parsed = URL(string: "https://" + text) {
            url = parsed
        } else {
            let q = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
            url = URL(string: "https://duckduckgo.com/?q=\(q)")!
        }
        urlText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func reload() { webView.reload() }
    func goBack() { if webView.canGoBack { webView.goBack() } }
    func goForward() { if webView.canGoForward { webView.goForward() } }
    func stop() { webView.stopLoading() }

    func captureSnapshot(completion: ((PageSnapshot?) -> Void)? = nil) {
        snapshotStatus = "Extracting page..."
        let js = """
        (() => {
          const clean = (s) => (s || '').replace(/\\s+/g, ' ').trim();
          const selectorFor = (el) => {
            if (!el) return '';
            if (el.id) return '#' + CSS.escape(el.id);
            const name = el.getAttribute('name');
            if (name) return el.tagName.toLowerCase() + '[name="' + name.replace(/"/g, '\\\"') + '"]';
            const type = el.getAttribute('type');
            const ph = el.getAttribute('placeholder');
            if (ph) return el.tagName.toLowerCase() + '[placeholder="' + ph.replace(/"/g, '\\\"') + '"]';
            return el.tagName.toLowerCase() + (type ? '[type="' + type + '"]' : '');
          };
          const links = Array.from(document.links || [])
            .slice(0, 100)
            .map(a => clean(a.innerText || a.href) + ' — ' + a.href)
            .filter(Boolean);
          const forms = Array.from(document.querySelectorAll('input, textarea, select, button'))
            .slice(0, 100)
            .map(el => selectorFor(el) + ' — ' + clean(el.innerText || el.value || el.placeholder || el.getAttribute('aria-label') || el.type || el.name || ''))
            .filter(Boolean);
          return JSON.stringify({
            title: document.title || '',
            url: location.href,
            text: clean(document.body ? document.body.innerText : ''),
            links,
            forms
          });
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { completion?(nil); return }
                if let error {
                    self.snapshotStatus = "Snapshot failed: \(error.localizedDescription)"
                    completion?(nil)
                    return
                }
                guard let json = result as? String,
                      let data = json.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.snapshotStatus = "Snapshot failed: empty result"
                    completion?(nil)
                    return
                }
                let title = object["title"] as? String ?? ""
                let url = object["url"] as? String ?? self.currentURL?.absoluteString ?? self.urlText
                let text = object["text"] as? String ?? ""
                let links = object["links"] as? [String] ?? []
                let forms = object["forms"] as? [String] ?? []
                let snap = PageSnapshot(title: title, url: url, text: text, links: links, forms: forms)
                self.snapshot = snap
                self.snapshotStatus = "Captured \(text.count) chars / \(links.count) links / \(forms.count) controls"
                completion?(snap)
            }
        }
    }

    func copySnapshot() {
        guard let snapshot else { return }
        UIPasteboard.general.string = snapshot.summaryText
        snapshotStatus = "Copied snapshot"
    }

    func askPage(question: String, settings: AgentSettings) {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        guard !settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            agentAnswer = "Set API key dulu di Settings."
            return
        }
        isAsking = true
        agentAnswer = "Thinking..."
        captureSnapshot { [weak self] snap in
            guard let self else { return }
            guard let snap else {
                self.isAsking = false
                self.agentAnswer = "Failed to capture page snapshot."
                return
            }
            self.callAI(question: q, snapshot: snap, settings: settings)
        }
    }

    private func callAI(question: String, snapshot: PageSnapshot, settings: AgentSettings) {
        guard let url = URL(string: settings.baseURL) else {
            isAsking = false
            agentAnswer = "Bad API URL."
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        let prompt = """
        USER QUESTION:
        \(question)

        PAGE SNAPSHOT:
        \(snapshot.summaryText)
        """
        let body: [String: Any] = [
            "model": settings.model,
            "messages": [
                ["role": "system", "content": settings.systemPrompt],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.2
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isAsking = false
                if let error {
                    self.agentAnswer = "API error: \(error.localizedDescription)"
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode >= 300 {
                    let raw = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    self.agentAnswer = "API HTTP \(http.statusCode): \(raw.prefix(800))"
                    return
                }
                guard let data,
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.agentAnswer = "API returned invalid JSON."
                    return
                }
                if let choices = obj["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    self.agentAnswer = content
                } else if let output = obj["output_text"] as? String {
                    self.agentAnswer = output
                } else {
                    self.agentAnswer = "No answer field found."
                }
            }
        }.resume()
    }

    func fill(selector: String, value: String) {
        let js = """
        (() => {
          const el = document.querySelector(\(Self.jsLiteral(selector)));
          if (!el) return 'not found';
          el.focus();
          el.value = \(Self.jsLiteral(value));
          el.dispatchEvent(new Event('input', {bubbles:true}));
          el.dispatchEvent(new Event('change', {bubbles:true}));
          return 'filled ' + \(Self.jsLiteral(selector));
        })();
        """
        runToolJS(js)
    }

    func click(selector: String) {
        let js = """
        (() => {
          const el = document.querySelector(\(Self.jsLiteral(selector)));
          if (!el) return 'not found';
          el.scrollIntoView({block:'center'});
          el.click();
          return 'clicked ' + \(Self.jsLiteral(selector));
        })();
        """
        runToolJS(js)
    }

    func runCustomJS(_ source: String) {
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        runToolJS(source)
    }

    private func runToolJS(_ js: String) {
        toolStatus = "Running..."
        webView.evaluateJavaScript(js) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error { self?.toolStatus = "Tool failed: \(error.localizedDescription)" }
                else { self?.toolStatus = "Result: \(String(describing: result ?? "ok"))" }
            }
        }
    }

    static func jsLiteral(_ string: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [string])
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
        return String(json.dropFirst().dropLast())
    }
}

struct BrowserView: View {
    @StateObject private var state = BrowserState()
    @StateObject private var settings = AgentSettings()
    @State private var showShareURL = false
    @State private var showAgent = false
    @State private var showShareSnapshot = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
            if state.estimatedProgress > 0 && state.estimatedProgress < 1 {
                ProgressView(value: state.estimatedProgress)
                    .progressViewStyle(.linear)
                    .tint(.orange)
            }
            WebViewContainer(state: state)
                .ignoresSafeArea(edges: .bottom)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showShareURL) {
            ShareSheet(items: [state.currentURL?.absoluteString ?? state.urlText])
        }
        .sheet(isPresented: $showAgent) {
            AgentPanel(state: state, settings: settings, showShareSnapshot: $showShareSnapshot)
        }
        .sheet(isPresented: $showShareSnapshot) {
            ShareSheet(items: [state.snapshot?.summaryText ?? "No snapshot"])
        }
        .onAppear { state.load("https://duckduckgo.com") }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: state.goBack) { Image(systemName: "chevron.left") }
                    .disabled(!state.canGoBack)
                Button(action: state.goForward) { Image(systemName: "chevron.right") }
                    .disabled(!state.canGoForward)
                TextField("Search or URL", text: $state.urlText)
                    .keyboardType(.webSearch)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit { state.load() }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button(action: { state.isLoading ? state.stop() : state.reload() }) {
                    Image(systemName: state.isLoading ? "xmark" : "arrow.clockwise")
                }
                Button(action: { showShareURL = true }) { Image(systemName: "square.and.arrow.up") }
                Button(action: { showAgent = true }) {
                    Text("⚡")
                        .font(.system(size: 18, weight: .bold))
                }
            }
            .font(.system(size: 17, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
}

struct AgentPanel: View {
    @ObservedObject var state: BrowserState
    @ObservedObject var settings: AgentSettings
    @Binding var showShareSnapshot: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var question = "Summarize this page and list useful actions."
    @State private var selector = ""
    @State private var value = ""
    @State private var customJS = "document.title"

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("K3 Agent", systemImage: "bolt.fill").font(.headline)
                    Spacer()
                    Button("Close") { dismiss() }
                }
                Picker("Mode", selection: $tab) {
                    Text("Ask").tag(0)
                    Text("Snapshot").tag(1)
                    Text("Tools").tag(2)
                    Text("Settings").tag(3)
                }
                .pickerStyle(.segmented)

                if tab == 0 { askView }
                else if tab == 1 { snapshotView }
                else if tab == 2 { toolsView }
                else { settingsView }
            }
            .padding()
            .navigationBarHidden(true)
        }
    }

    private var askView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.currentURL?.absoluteString ?? state.urlText)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            TextEditor(text: $question)
                .frame(height: 90)
                .padding(6)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            HStack {
                Button(action: { state.askPage(question: question, settings: settings) }) {
                    Label(state.isAsking ? "Thinking" : "Ask Page", systemImage: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.isAsking)
                Button("Summarize") {
                    question = "Summarize this page in bullets, extract key claims, and list next actions."
                    state.askPage(question: question, settings: settings)
                }
                .buttonStyle(.bordered)
                .disabled(state.isAsking)
            }
            Divider()
            ScrollView {
                Text(state.agentAnswer.isEmpty ? "AI answer will appear here. Set API key in Settings first." : state.agentAnswer)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private var snapshotView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: { state.captureSnapshot() }) { Label("Extract", systemImage: "doc.text.magnifyingglass") }
                    .buttonStyle(.borderedProminent)
                Button(action: state.copySnapshot) { Label("Copy", systemImage: "doc.on.doc") }
                    .buttonStyle(.bordered)
                    .disabled(state.snapshot == nil)
                Button(action: { showShareSnapshot = true }) { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.bordered)
                    .disabled(state.snapshot == nil)
            }
            .labelStyle(.iconOnly)
            Text(state.snapshotStatus).font(.caption).foregroundColor(.secondary)
            Divider()
            if let snapshot = state.snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(snapshot.title.isEmpty ? "(No title)" : snapshot.title).font(.title3.bold())
                        Text(snapshot.url).font(.caption).foregroundColor(.blue).textSelection(.enabled)
                        Text(String(snapshot.text.prefix(4000)).isEmpty ? "No readable body text." : String(snapshot.text.prefix(4000)))
                            .font(.body).textSelection(.enabled)
                        if !snapshot.links.isEmpty {
                            Text("Links").font(.headline)
                            ForEach(Array(snapshot.links.prefix(25).enumerated()), id: \.offset) { index, link in
                                Text("\(index + 1). \(link)").font(.caption).textSelection(.enabled)
                            }
                        }
                        if !snapshot.forms.isEmpty {
                            Text("Forms / Controls").font(.headline)
                            ForEach(Array(snapshot.forms.prefix(25).enumerated()), id: \.offset) { index, item in
                                Text("\(index + 1). \(item)").font(.caption).textSelection(.enabled)
                            }
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                emptyState("No snapshot yet", "Tap Extract to read title, URL, text, links, and controls.")
            }
        }
    }

    private var toolsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Page actions run in the current WKWebView. Use simple CSS selectors like #email, input[name=q], button[type=submit].")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("CSS selector", text: $selector)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .padding(8).background(Color(.secondarySystemBackground)).cornerRadius(8)
            TextField("Value for Fill", text: $value)
                .padding(8).background(Color(.secondarySystemBackground)).cornerRadius(8)
            HStack {
                Button("Fill") { state.fill(selector: selector, value: value) }.buttonStyle(.borderedProminent)
                Button("Click") { state.click(selector: selector) }.buttonStyle(.bordered)
            }
            Divider()
            Text("Custom JS probe")
                .font(.caption.bold())
            TextEditor(text: $customJS)
                .frame(height: 100)
                .padding(6).background(Color(.secondarySystemBackground)).cornerRadius(8)
            Button("Run JS") { state.runCustomJS(customJS) }
                .buttonStyle(.bordered)
            Text(state.toolStatus).font(.caption).foregroundColor(.secondary).textSelection(.enabled)
            Spacer()
        }
    }

    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("OpenAI-compatible API")
                    .font(.headline)
                SecureField("API key", text: $settings.apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(8).background(Color(.secondarySystemBackground)).cornerRadius(8)
                TextField("Chat completions URL", text: $settings.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(8).background(Color(.secondarySystemBackground)).cornerRadius(8)
                TextField("Model", text: $settings.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding(8).background(Color(.secondarySystemBackground)).cornerRadius(8)
                Text("System prompt")
                    .font(.caption.bold())
                TextEditor(text: $settings.systemPrompt)
                    .frame(height: 120)
                    .padding(6).background(Color(.secondarySystemBackground)).cornerRadius(8)
                Button(action: settings.save) {
                    Label("Save Settings", systemImage: "key.fill")
                }
                .buttonStyle(.borderedProminent)
                Text("Default URL expects OpenAI /v1/chat/completions shape. OpenRouter also works if you set its chat completions URL + model.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func emptyState(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt").font(.system(size: 44, weight: .bold)).foregroundColor(.orange)
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var state: BrowserState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    func makeUIView(context: Context) -> WKWebView {
        state.webView.navigationDelegate = context.coordinator
        state.webView.uiDelegate = context.coordinator
        context.coordinator.observe(webView: state.webView)
        return state.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private weak var state: BrowserState?
        private var observations: [NSKeyValueObservation] = []

        init(state: BrowserState) { self.state = state }

        func observe(webView: WKWebView) {
            observations = [
                webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                    DispatchQueue.main.async { self?.state?.estimatedProgress = webView.estimatedProgress }
                },
                webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                    DispatchQueue.main.async {
                        self?.state?.currentURL = webView.url
                        if let url = webView.url { self?.state?.urlText = url.absoluteString }
                    }
                },
                webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                    DispatchQueue.main.async { self?.state?.canGoBack = webView.canGoBack }
                },
                webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                    DispatchQueue.main.async { self?.state?.canGoForward = webView.canGoForward }
                },
                webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                    DispatchQueue.main.async { self?.state?.isLoading = webView.isLoading }
                }
            ]
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { state?.estimatedProgress = 1 }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { state?.isLoading = false }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { state?.isLoading = false }

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
