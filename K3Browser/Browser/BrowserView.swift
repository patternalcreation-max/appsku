import SwiftUI
import WebKit
import Combine

final class BrowserState: ObservableObject {
    @Published var urlText: String = "https://duckduckgo.com"
    @Published var currentURL: URL? = URL(string: "https://duckduckgo.com")
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false

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
}

struct BrowserView: View {
    @StateObject private var state = BrowserState()
    @State private var showShare = false

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
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [state.currentURL?.absoluteString ?? state.urlText])
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
                Button(action: { showShare = true }) { Image(systemName: "square.and.arrow.up") }
            }
            .font(.system(size: 17, weight: .semibold))
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
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
