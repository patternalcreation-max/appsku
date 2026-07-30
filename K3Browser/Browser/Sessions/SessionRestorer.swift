import Foundation

// PEAK 2 Sessions — Tab session persistence.
// Saves the set of open tab URLs so they can be restored on next launch.
// Lightweight: stores URL strings only, not full page state.

struct SavedTab: Codable, Identifiable, Equatable {
    let id: UUID
    let url: String
    let title: String

    init(url: String, title: String) {
        self.id = UUID()
        self.url = url
        self.title = title
    }
}

enum SessionRestorer {
    private static let filename = "session.json"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("K3Browser", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(filename)
    }

    struct Snapshot: Codable, Equatable {
        let tabs: [SavedTab]
        let activeIndex: Int
    }

    static func save(tabs: [SavedTab], activeIndex: Int) {
        let snapshot = Snapshot(tabs: tabs, activeIndex: max(0, min(activeIndex, max(0, tabs.count - 1))))
        let encoded = (try? JSONEncoder().encode(snapshot)) ?? Data()
        try? encoded.write(to: fileURL, options: .atomic)
    }

    static func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
