import Foundation
import SwiftUI

// PEAK 4 Endgame — Export services.
// CSV and Markdown exporters for extracted data. Sandbox-safe via ShareSheet.

enum ExportService {
    static func exportCSV(tables: [PageTable]) -> String {
        guard let first = tables.first else { return "" }
        var lines: [String] = []
        lines.append(first.headers.map(escapeCSV).joined(separator: ","))
        for row in first.rows {
            lines.append(row.map(escapeCSV).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func exportLinksMarkdown(links: [PageLink]) -> String {
        var lines: [String] = ["# Extracted Links\n"]
        for link in links {
            let text = link.text.isEmpty ? link.url : link.text
            lines.append("- [\(text)](\(link.url))")
        }
        return lines.joined(separator: "\n")
    }

    static func exportMarkdown(title: String, body: String, url: String) -> String {
        return """
        # \(title)

        Source: \(url)
        Date: \(Date())

        \(body)
        """
    }

    static func saveToFile(content: String, filename: String) -> URL? {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("K3Browser/Exports", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(filename)
        try? content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    private static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}

// Convenience: export extracted data from current snapshot
extension BrowserState {
    func exportSnapshotAsCSV() -> URL? {
        guard let snapshot = snapshot, !snapshot.tables.isEmpty else { return nil }
        let csv = ExportService.exportCSV(tables: snapshot.tables)
        let filename = "\(pageTitle.isEmpty ? "export" : pageTitle.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression).prefix(40)).csv"
        return ExportService.saveToFile(content: csv, filename: String(filename))
    }

    func exportLinksAsMarkdown() -> URL? {
        guard let snapshot = snapshot, !snapshot.links.isEmpty else { return nil }
        let md = ExportService.exportLinksMarkdown(links: snapshot.links)
        let filename = "\(pageTitle.isEmpty ? "links" : pageTitle.replacingOccurrences(of: "[^A-Za-z0-9_-]+", with: "-", options: .regularExpression).prefix(40)).md"
        return ExportService.saveToFile(content: md, filename: String(filename))
    }
}
