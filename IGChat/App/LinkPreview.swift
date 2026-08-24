import SwiftUI
import UIKit

// MARK: - URL analysis

enum LinkURLAnalyzer {
    struct Result: Equatable {
        let url: URL
        let raw: String
        let isURLOnly: Bool
    }

    /// First http/https URL in text, if any.
    static func analyze(_ text: String) -> Result? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            let matches = detector.matches(in: trimmed, options: [], range: range)
            for match in matches {
                guard let urlRange = Range(match.range, in: trimmed) else { continue }
                let raw = String(trimmed[urlRange])
                guard let url = match.url ?? URL(string: raw) else { continue }
                let scheme = (url.scheme ?? "").lowercased()
                guard scheme == "http" || scheme == "https" else { continue }

                let isOnly = isURLOnlyMessage(trimmed: trimmed, urlRaw: raw)
                return Result(url: url, raw: raw, isURLOnly: isOnly)
            }
        }

        // Regex fallback
        let pattern = #"https?://[^\s<>"']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
              let urlRange = Range(match.range, in: trimmed) else {
            return nil
        }
        var raw = String(trimmed[urlRange])
        while let last = raw.last, ".,);:!?]'\"".contains(last) {
            raw.removeLast()
        }
        guard let url = URL(string: raw) else { return nil }
        return Result(url: url, raw: raw, isURLOnly: isURLOnlyMessage(trimmed: trimmed, urlRaw: raw))
    }

    /// Trimmed text equals the URL, optionally ignoring trailing punctuation on either side.
    private static func isURLOnlyMessage(trimmed: String, urlRaw: String) -> Bool {
        if trimmed == urlRaw { return true }
        var stripped = trimmed
        let trail = CharacterSet(charactersIn: ".,);:!?]'\"").union(.whitespacesAndNewlines)
        while let u = stripped.unicodeScalars.last, trail.contains(u) {
            stripped.removeLast()
        }
        if stripped == urlRaw { return true }
        var urlStripped = urlRaw
        while let u = urlStripped.unicodeScalars.last, trail.contains(u) {
            urlStripped.removeLast()
        }
        return stripped == urlStripped
    }

    static func domain(from url: URL) -> String {
        let host = (url.host ?? url.absoluteString).lowercased()
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }
}

// MARK: - Model + cache

struct LinkPreviewData: Codable, Equatable {
    var url: String
    var title: String
    var domain: String
    var imageJPEG: Data?
}

actor LinkPreviewCache {
    static let shared = LinkPreviewCache()

    private let memory = NSCache<NSString, NSData>()
    private let defaultsKey = "igchat.linkPreview.v1"

    private var diskIndex: [String: LinkPreviewData] = [:]
    private var loaded = false

    func get(_ urlString: String) -> LinkPreviewData? {
        loadIfNeeded()
        if let ns = memory.object(forKey: urlString as NSString) {
            let data = ns as Data
            if let decoded = try? JSONDecoder().decode(LinkPreviewData.self, from: data) {
                return decoded
            }
        }
        if let hit = diskIndex[urlString] {
            if let encoded = try? JSONEncoder().encode(hit) {
                memory.setObject(encoded as NSData, forKey: urlString as NSString)
            }
            return hit
        }
        return nil
    }

    func set(_ preview: LinkPreviewData) {
        loadIfNeeded()
        diskIndex[preview.url] = preview
        if let encoded = try? JSONEncoder().encode(preview) {
            memory.setObject(encoded as NSData, forKey: preview.url as NSString)
        }
        persist()
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let map = try? JSONDecoder().decode([String: LinkPreviewData].self, from: data) else {
            return
        }
        diskIndex = map
    }

    private func persist() {
        // Cap disk map to avoid unbounded growth
        if diskIndex.count > 80 {
            let keys = Array(diskIndex.keys)
            for key in keys.prefix(diskIndex.count - 60) {
                diskIndex.removeValue(forKey: key)
            }
        }
        if let data = try? JSONEncoder().encode(diskIndex) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

// MARK: - Fetcher

enum LinkPreviewFetcher {
    private static let ua =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    static func fetch(url: URL) async -> LinkPreviewData {
        let urlString = url.absoluteString
        if let cached = await LinkPreviewCache.shared.get(urlString) {
            return cached
        }

        let domain = LinkURLAnalyzer.domain(from: url)
        let fallbackTitle = fallbackTitle(for: url, domain: domain)
        var preview = LinkPreviewData(
            url: urlString,
            title: fallbackTitle,
            domain: domain,
            imageJPEG: nil
        )

        do {
            var request = URLRequest(url: url, timeoutInterval: 12)
            request.setValue(ua, forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1),
               (200..<400).contains(status) || !html.isEmpty {
                if let title = metaContent(html, property: "og:title")
                    ?? metaContent(html, name: "twitter:title")
                    ?? htmlTitle(html) {
                    let cleaned = decodeHTMLEntities(title).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty { preview.title = cleaned }
                }
                if let imageURLString = metaContent(html, property: "og:image")
                    ?? metaContent(html, name: "twitter:image")
                    ?? metaContent(html, property: "og:image:url"),
                   let imageURL = resolveURL(imageURLString, base: url) {
                    if let jpeg = await downloadJPEG(from: imageURL) {
                        preview.imageJPEG = jpeg
                    }
                }
            }
        } catch {
            // Keep fallback title/domain; no image.
        }

        await LinkPreviewCache.shared.set(preview)
        return preview
    }

    private static func fallbackTitle(for url: URL, domain: String) -> String {
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let last = path.split(separator: "/").last, !last.isEmpty {
            let decoded = last.removingPercentEncoding ?? String(last)
            if decoded.count >= 2 { return decoded }
        }
        return domain
    }

    private static func metaContent(_ html: String, property: String) -> String? {
        metaTag(html, key: "property", value: property)
            ?? metaTag(html, key: "name", value: property)
    }

    private static func metaContent(_ html: String, name: String) -> String? {
        metaTag(html, key: "name", value: name)
            ?? metaTag(html, key: "property", value: name)
    }

    private static func metaTag(_ html: String, key: String, value: String) -> String? {
        let patterns = [
            #"<meta[^>]*\#(key)\s*=\s*["']\#(value)["'][^>]*content\s*=\s*["']([^"']+)["'][^>]*/?>"#,
            #"<meta[^>]*content\s*=\s*["']([^"']+)["'][^>]*\#(key)\s*=\s*["']\#(value)["'][^>]*/?>"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, options: [], range: range),
               match.numberOfRanges >= 2,
               let contentRange = Range(match.range(at: 1), in: html) {
                return String(html[contentRange])
            }
        }
        return nil
    }

    private static func htmlTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: #"<title[^>]*>(.*?)</title>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[titleRange])
    }

    private static func resolveURL(_ string: String, base: URL) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let absolute = URL(string: trimmed), absolute.scheme != nil {
            return absolute
        }
        return URL(string: trimmed, relativeTo: base)?.absoluteURL
    }

    private static func downloadJPEG(from url: URL) async -> Data? {
        do {
            var request = URLRequest(url: url, timeoutInterval: 12)
            request.setValue(ua, forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<400).contains(status), let image = UIImage(data: data) else { return nil }
            return downscaleJPEG(image, maxWidth: 600)
        } catch {
            return nil
        }
    }

    private static func downscaleJPEG(_ image: UIImage, maxWidth: CGFloat) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return image.jpegData(compressionQuality: 0.72)
        }
        let scale = min(1, maxWidth / size.width)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.72)
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        var s = string
        let named: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&#x27;", "'"), ("&nbsp;", " ")
        ]
        for (a, b) in named { s = s.replacingOccurrences(of: a, with: b) }
        return s
    }
}

// MARK: - Side buttons (Them only) — SF Symbol info + existing share art

struct LinkPreviewSideButtons: View {
    var body: some View {
        VStack(spacing: 10) {
            sideCircle {
                Image(systemName: "info.circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
            }
            sideCircle {
                ScaledArtShape(base: MediaSideArt.sharePath, artSize: MediaSideArt.shareSize)
                    .fill(Color.white, style: FillStyle(eoFill: true, antialiased: true))
                    .frame(width: 18, height: 18)
            }
        }
    }

    private func sideCircle<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Circle().fill(Color(white: 0.18).opacity(0.92))
            content()
        }
        .frame(width: 36, height: 36)
    }
}

// MARK: - Card UI

struct LinkPreviewCard: View {
    let data: LinkPreviewData
    var width: CGFloat = 250

    private let cardFill = Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0)
    private let domainColor = Color(red: 0xA8 / 255.0, green: 0xA8 / 255.0, blue: 0xA8 / 255.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            imageBlock
            bottomBar
        }
        .frame(width: width)
        .background(cardFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var imageBlock: some View {
        let h = width * 0.75 // ~4:3
        if let jpeg = data.imageJPEG, let ui = UIImage(data: jpeg) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: h)
                .clipped()
        } else {
            ZStack {
                Color(white: 0.16)
                Image(systemName: "link")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(Color.white.opacity(0.35))
            }
            .frame(width: width, height: h)
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: data.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 10, weight: .regular))
                Text(verbatim: data.domain)
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .foregroundColor(domainColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill)
    }
}

struct LinkPreviewSkeleton: View {
    var width: CGFloat = 250

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(white: 0.16)
                .frame(width: width, height: width * 0.75)
                .overlay { ProgressView().tint(.white.opacity(0.6)) }
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: width * 0.45, height: 10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0))
        }
        .frame(width: width)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Loads preview for a URL and renders IG-style card. Them = side buttons left of card.
struct LinkPreviewBlock: View {
    let text: String
    let isSent: Bool
    var cardWidth: CGFloat = 250

    @State private var preview: LinkPreviewData?
    @State private var loadFailed = false

    private var analysis: LinkURLAnalyzer.Result? {
        LinkURLAnalyzer.analyze(text)
    }

    var body: some View {
        Group {
            if let analysis {
                content(for: analysis)
                    .task(id: analysis.url.absoluteString) {
                        await load(url: analysis.url)
                    }
            }
        }
    }

    @ViewBuilder
    private func content(for analysis: LinkURLAnalyzer.Result) -> some View {
        let card = cardView(for: analysis)
        if isSent {
            HStack {
                Spacer(minLength: 48)
                card
            }
        } else {
            HStack(alignment: .center, spacing: 8) {
                LinkPreviewSideButtons()
                card
            }
        }
    }

    @ViewBuilder
    private func cardView(for analysis: LinkURLAnalyzer.Result) -> some View {
        if let preview {
            LinkPreviewCard(data: preview, width: cardWidth)
        } else if loadFailed {
            LinkPreviewCard(
                data: LinkPreviewData(
                    url: analysis.url.absoluteString,
                    title: LinkURLAnalyzer.domain(from: analysis.url),
                    domain: LinkURLAnalyzer.domain(from: analysis.url),
                    imageJPEG: nil
                ),
                width: cardWidth
            )
        } else {
            LinkPreviewSkeleton(width: cardWidth)
        }
    }

    private func load(url: URL) async {
        preview = nil
        loadFailed = false
        let data = await LinkPreviewFetcher.fetch(url: url)
        await MainActor.run {
            preview = data
        }
    }
}
