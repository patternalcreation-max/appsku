import Foundation

// PEAK 2 Sessions — Browsing history persistence.
// Atomic JSON store under Application Support. No external deps, no entitlements.

struct HistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let url: String
    let title: String
    let visitedAt: Date

    init(url: String, title: String, visitedAt: Date = Date()) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.visitedAt = visitedAt
    }
}

enum HistoryStore {
    private static let maxEntries = 500
    private static let filename = "history.json"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("K3Browser", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(filename)
    }

    static func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoded = (try? JSONDecoder().decode([HistoryEntry].self, from: data)) ?? []
        return decoded.sorted { $0.visitedAt > $1.visitedAt }
    }

    static func record(url: String, title: String) {
        var entries = load()
        entries.removeAll { $0.url == url }
        entries.insert(HistoryEntry(url: url, title: title), at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        save(entries)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func remove(id: UUID) {
        var entries = load()
        entries.removeAll { $0.id == id }
        save(entries)
    }

    private static func save(_ entries: [HistoryEntry]) {
        let encoded = (try? JSONEncoder().encode(entries)) ?? Data()
        try? encoded.write(to: fileURL, options: .atomic)
    }
}
