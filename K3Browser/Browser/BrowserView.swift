import SwiftUI
import WebKit
import Combine
import UIKit

struct PageSnapshot: Identifiable {
    let id = UUID()
    let title: String
    let url: String
    let text: String
    let links: [String]

    var summaryText: String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let clippedText = String(cleanText.prefix(6000))
        let clippedLinks = links.prefix(30).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return """
        K3 Browser Page Snapshot

        Title: \(title.isEmpty ? "(none)" : title)
        URL: \(url)

        TEXT
        \(clippedText.isEmpty ? "(no readable text)" : clippedText)

        LINKS
        \(clippedLinks.isEmpty ? "(none)" : clippedLinks)
        """
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

    func captureSnapshot() {
        snapshotStatus = "Extracting page..."
        let js = """
        (() => {
          const clean = (s) => (s || '').replace(/\\s+/g, ' ').trim();
          const links = Array.from(document.links || [])
            .slice(0, 80)
            .map(a => clean(a.innerText || a.href) + ' — ' + a.href)
            .filter(Boolean);
          return JSON.stringify({
            title: document.title || '',
            url: location.href,
            text: clean(document.body ? document.body.innerText : ''),
            links
          });
        })();
        """
        webView.evaluateJavaScript(js) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.snapshotStatus = "Snapshot failed: \(error.localizedDescription)"
                    return
                }
                guard let json = result as? String,
                      let data = json.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.snapshotStatus = "Snapshot failed: empty result"
                    return
                }
                let title = object["title"] as? String ?? ""
                let url = object["url"] as? String ?? self.currentURL?.absoluteString ?? self.urlText
                let text = object["text"] as? String ?? ""
                let links = object["links"] as? [String] ?? []
                self.snapshot = PageSnapshot(title: title, url: url, text: text, links: links)
                self.snapshotStatus = "Captured \(text.count) chars / \(links.count) links"
            }
        }
    }

    func copySnapshot() {
        guard let snapshot else { return }
        UIPasteboard.general.string = snapshot.summaryText
        snapshotStatus = "Copied snapshot"
    }
}

struct BrowserView: View {
    @StateObject private var state = BrowserState()
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
            AgentPanel(state: state, showShareSnapshot: $showShareSnapshot)
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
    @Binding var showShareSnapshot: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Agent Snapshot", systemImage: "bolt.fill")
                        .font(.headline)
                    Spacer()
                    Button("Close") { dismiss() }
                }

                Text(state.currentURL?.absoluteString ?? state.urlText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Button(action: state.captureSnapshot) {
                        Label("Extract", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: state.copySnapshot) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .disabled(state.snapshot == nil)

                    Button(action: { showShareSnapshot = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(state.snapshot == nil)
                }
                .labelStyle(.iconOnly)

                Text(state.snapshotStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                if let snapshot = state.snapshot {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(snapshot.title.isEmpty ? "(No title)" : snapshot.title)
                                .font(.title3.bold())
                            Text(snapshot.url)
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(String(snapshot.text.prefix(3000)).isEmpty ? "No readable body text." : String(snapshot.text.prefix(3000)))
                                .font(.body)
                                .textSelection(.enabled)
                            if !snapshot.links.isEmpty {
                                Text("Links")
                                    .font(.headline)
                                ForEach(Array(snapshot.links.prefix(20).enumerated()), id: \.offset) { index, link in
                                    Text("\(index + 1). \(link)")
                                        .font(.caption)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "bolt")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundColor(.orange)
                        Text("No snapshot yet")
                            .font(.headline)
                        Text("Tap Extract to read page title, URL, visible text, and links.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .padding()
            .navigationBarHidden(true)
        }
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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state?.estimatedProgress = 1
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            state?.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            state?.isLoading = false
        }

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
