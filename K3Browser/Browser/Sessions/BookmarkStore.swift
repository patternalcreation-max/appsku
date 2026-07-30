import Foundation

// PEAK 2 Sessions — Bookmarks persistence.
// Atomic JSON store. User-curated, no auto-population.

struct Bookmark: Codable, Identifiable, Equatable {
    let id: UUID
    let url: String
    let title: String
    let createdAt: Date

    init(url: String, title: String) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.createdAt = Date()
    }
}

enum BookmarkStore {
    private static let filename = "bookmarks.json"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("K3Browser", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(filename)
    }

    static func load() -> [Bookmark] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Bookmark].self, from: data)) ?? []
    }

    static func add(url: String, title: String) {
        var bookmarks = load()
        guard !bookmarks.contains(where: { $0.url == url }) else { return }
        bookmarks.append(Bookmark(url: url, title: title))
        save(bookmarks)
    }

    static func remove(id: UUID) {
        var bookmarks = load()
        bookmarks.removeAll { $0.id == id }
        save(bookmarks)
    }

    static func isBookmarked(url: String) -> Bool {
        load().contains(where: { $0.url == url })
    }

    private static func save(_ bookmarks: [Bookmark]) {
        let encoded = (try? JSONEncoder().encode(bookmarks)) ?? Data()
        try? encoded.write(to: fileURL, options: .atomic)
    }
}
