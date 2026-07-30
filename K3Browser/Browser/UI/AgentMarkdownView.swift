import SwiftUI
import UIKit

// AgentMarkdownView — Rich markdown renderer for agent responses.
// Parses markdown into blocks, renders with SwiftUI native views.
// Supports: headers, code blocks, inline code, bold, italic, links,
// bullet lists, numbered lists, blockquotes, horizontal rules, paragraphs.
// No external deps. Pure SwiftUI.

// MARK: - Block Model

enum MarkdownBlock: Identifiable {
    case header(level: Int, text: String, runs: [MarkdownInlineRun])
    case paragraph(runs: [MarkdownInlineRun])
    case codeBlock(language: String?, code: String)
    case bulletList(items: [[MarkdownInlineRun]])
    case numberList(items: [[MarkdownInlineRun]])
    case blockquote(runs: [MarkdownInlineRun])
    case rule

    var id: String {
        switch self {
        case .header(_, let text, _): return "h-\(text)"
        case .paragraph(let runs): return "p-\(runs.map(\.text).joined())"
        case .codeBlock(_, let code): return "code-\(code.prefix(40))"
        case .bulletList(let items): return "ul-\(items.count)"
        case .numberList(let items): return "ol-\(items.count)"
        case .blockquote(let runs): return "bq-\(runs.map(\.text).joined().prefix(30))"
        case .rule: return "hr"
        }
    }
}

// MARK: - Inline Runs

struct MarkdownInlineRun: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let style: InlineStyle

    enum InlineStyle: Equatable {
        case plain
        case bold
        case italic
        case code
        case link(url: String)
        case strikethrough
        case boldItalic
    }
}

// MARK: - Parser

enum MarkdownParser {
    static func parse(_ raw: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = raw.components(separatedBy: "\n")
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty
            guard !trimmed.isEmpty else { i += 1; continue }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.rule)
                i += 1
                continue
            }

            // Code block (fenced)
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count {
                    let cl = lines[i]
                    if cl.trimmingCharacters(in: .whitespaces).hasPrefix("```") { i += 1; break }
                    codeLines.append(cl)
                    i += 1
                }
                if !codeLines.isEmpty {
                    blocks.append(.codeBlock(language: lang.isEmpty ? nil : lang, code: codeLines.joined(separator: "\n")))
                }
                continue
            }

            // Header
            if let level = headerLevel(trimmed) {
                let text = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                blocks.append(.header(level: level, text: text, runs: parseInline(text)))
                i += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix(">") {
                    quoteLines.append(lines[i].trimmingCharacters(in: .whitespaces).dropFirst().trimmingCharacters(in: .whitespaces))
                    i += 1
                }
                blocks.append(.blockquote(runs: parseInline(quoteLines.joined(separator: " "))))
                continue
            }

            // Bullet list (- or * or +)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var items: [[MarkdownInlineRun]] = []
                while i < lines.count {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    guard lt.hasPrefix("- ") || lt.hasPrefix("* ") || lt.hasPrefix("+ ") else { break }
                    let content = lt.dropFirst(2).trimmingCharacters(in: .whitespaces)
                    items.append(parseInline(content))
                    i += 1
                }
                if !items.isEmpty {
                    blocks.append(.bulletList(items: items))
                }
                continue
            }

            // Numbered list (1. 2. etc)
            if isNumberedItem(trimmed) {
                var items: [[MarkdownInlineRun]] = []
                while i < lines.count {
                    let lt = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isNumberedItem(lt) else { break }
                    let content = lt.drop(while: { $0.isNumber }).dropFirst().trimmingCharacters(in: .whitespaces)
                    items.append(parseInline(content))
                    i += 1
                }
                if !items.isEmpty {
                    blocks.append(.numberList(items: items))
                }
                continue
            }

            // Paragraph (collect consecutive non-empty, non-special lines)
            var paraLines: [String] = []
            while i < lines.count {
                let lt = lines[i].trimmingCharacters(in: .whitespaces)
                if lt.isEmpty || lt.hasPrefix("#") || lt.hasPrefix("```") || lt.hasPrefix(">") ||
                   lt.hasPrefix("- ") || lt.hasPrefix("* ") || lt.hasPrefix("+ ") ||
                   lt == "---" || lt == "***" || isNumberedItem(lt) { break }
                paraLines.append(lt)
                i += 1
            }
            if !paraLines.isEmpty {
                blocks.append(.paragraph(runs: parseInline(paraLines.joined(separator: " "))))
            }
        }

        return blocks
    }

    private static func headerLevel(_ trimmed: String) -> Int? {
        var count = 0
        for ch in trimmed {
            if ch == "#" { count += 1 } else { break }
        }
        return count > 0 && count <= 6 && trimmed.count > count && trimmed[trimmed.index(trimmed.startIndex, offsetBy: count)] == " " ? count : nil
    }

    private static func isNumberedItem(_ s: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: "^\\d+\\.\\s")
        return regex?.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    // MARK: - Inline parser

    static func parseInline(_ text: String) -> [MarkdownInlineRun] {
        var runs: [MarkdownInlineRun] = []
        var current = ""
        var i = text.startIndex

        func flushCurrent(_ style: MarkdownInlineRun.InlineStyle = .plain) {
            if !current.isEmpty {
                runs.append(MarkdownInlineRun(text: current, style: style))
                current = ""
            }
        }

        while i < text.endIndex {
            // Inline code `code`
            if text[i] == "`" {
                let start = text.index(after: i)
                if let end = text[start...].firstIndex(of: "`") {
                    flushCurrent()
                    let code = String(text[start..<end])
                    if !code.isEmpty {
                        runs.append(MarkdownInlineRun(text: code, style: .code))
                    }
                    i = text.index(after: end)
                    continue
                }
            }

            // Bold ** or __
            if (text[i] == "*" || text[i] == "_") &&
               text.index(after: i) < text.endIndex &&
               text[text.index(after: i)] == text[i] {
                let marker = String(text[i]) + String(text[i])
                let start = text.index(i, offsetBy: 2)
                if let endRange = text.range(of: marker, range: start..<text.endIndex) {
                    flushCurrent()
                    let inner = String(text[start..<endRange.lowerBound])
                    if !inner.isEmpty {
                        // Check for italic inside bold
                        runs.append(MarkdownInlineRun(text: inner, style: .bold))
                    }
                    i = endRange.upperBound
                    continue
                }
            }

            // Italic * or _
            if text[i] == "*" || text[i] == "_" {
                let marker = String(text[i])
                let start = text.index(after: i)
                if let end = text[start...].firstIndex(of: text[i]) {
                    flushCurrent()
                    let inner = String(text[start..<end])
                    if !inner.isEmpty {
                        runs.append(MarkdownInlineRun(text: inner, style: .italic))
                    }
                    i = text.index(after: end)
                    continue
                }
            }

            // Link [text](url)
            if text[i] == "[" {
                if let textEnd = text[i...].firstIndex(of: "]"),
                   text.index(after: textEnd) < text.endIndex,
                   text[text.index(after: textEnd)] == "(" {
                    let urlStart = text.index(textEnd, offsetBy: 2)
                    if let urlEnd = text[urlStart...].firstIndex(of: ")") {
                        flushCurrent()
                        let linkText = String(text[text.index(after: i)..<textEnd])
                        let url = String(text[urlStart..<urlEnd])
                        runs.append(MarkdownInlineRun(text: linkText, style: .link(url: url)))
                        i = text.index(after: urlEnd)
                        continue
                    }
                }
            }

            // Strikethrough ~~
            if text[i] == "~" && text.index(after: i) < text.endIndex && text[text.index(after: i)] == "~" {
                let start = text.index(i, offsetBy: 2)
                if let endRange = text.range(of: "~~", range: start..<text.endIndex) {
                    flushCurrent()
                    let inner = String(text[start..<endRange.lowerBound])
                    runs.append(MarkdownInlineRun(text: inner, style: .strikethrough))
                    i = endRange.upperBound
                    continue
                }
            }

            current.append(text[i])
            i = text.index(after: i)
        }

        flushCurrent()
        return runs.isEmpty ? [MarkdownInlineRun(text: text, style: .plain)] : runs
    }
}

// MARK: - SwiftUI Renderer

struct AgentMarkdownView: View {
    let text: String
    var fontSize: CGFloat = 15

    private var blocks: [MarkdownBlock] { MarkdownParser.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(blocks) { block in
                renderBlock(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .header(let level, _, let runs):
            renderInlineRuns(runs)
                .font(headerFont(level))
                .padding(.top, level <= 2 ? 6 : 4)

        case .paragraph(let runs):
            renderInlineRuns(runs)
                .font(.system(size: fontSize))

        case .codeBlock(_, let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: fontSize - 1, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = code
                } label: {
                    Label("Copy code", systemImage: "doc.on.doc")
                }
            }

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        renderInlineRuns(item)
                            .font(.system(size: fontSize))
                    }
                }
            }

        case .numberList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.system(size: fontSize).monospacedDigit())
                            .foregroundStyle(.secondary)
                        renderInlineRuns(item)
                            .font(.system(size: fontSize))
                    }
                }
            }

        case .blockquote(let runs):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(K3VisualSystem.Palette.interaction.opacity(0.4))
                    .frame(width: 3)
                renderInlineRuns(runs)
                    .font(.system(size: fontSize))
                    .foregroundStyle(.secondary)
            }

        case .rule:
            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(height: 0.5)
                .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func renderInlineRuns(_ runs: [MarkdownInlineRun]) -> some View {
        if runs.isEmpty {
            Text("").font(.system(size: fontSize))
        } else {
            // Build attributed string for proper inline mixing
            Text(buildAttributed(runs, size: fontSize))
                .environment(\.openURL, OpenURLAction { url in
                    UIPasteboard.general.string = url.absoluteString
                    return .handled
                })
        }
    }

    private func buildAttributed(_ runs: [MarkdownInlineRun], size: CGFloat) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            var attr = AttributedString(run.text)
            switch run.style {
            case .plain:
                attr.font = .system(size: size)
            case .bold:
                attr.font = .system(size: size, weight: .semibold)
            case .italic:
                attr.font = .system(size: size).italic()
            case .code:
                attr.font = .system(size: size - 1, design: .monospaced)
                attr.backgroundColor = UIColor.secondarySystemBackground
                attr.foregroundColor = K3VisualSystem.Palette.interaction
            case .boldItalic:
                attr.font = .system(size: size, weight: .semibold).italic()
            case .strikethrough:
                attr.strikethroughStyle = .single
                attr.font = .system(size: size)
            case .link(let url):
                attr.font = .system(size: size)
                attr.foregroundColor = K3VisualSystem.Palette.interaction
                if let urlObj = URL(string: url) {
                    attr.link = urlObj
                }
            }
            result += attr
        }
        return result
    }

    private func headerFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.weight(.bold)
        case 2: return .title3.weight(.semibold)
        case 3: return .headline
        case 4: return .subheadline.weight(.semibold)
        default: return .body.weight(.semibold)
        }
    }
}
