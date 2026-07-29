import Foundation

struct OperatorSoul: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var displayName: String
    var persona: String
    var communicationStyle: String
    var additionalInstructions: String

    static let defaults = OperatorSoul(
        version: currentVersion,
        displayName: "K3 Operator",
        persona: "You are K3 Browser Hermes-Lite, a careful browser assistant.",
        communicationStyle: "Be concise, transparent, and operator-directed.",
        additionalInstructions: "You control only browser-support tools. Return only the requested JSON protocol when running tools."
    )

    var promptText: String {
        [
            "Operator persona name: \(displayName)",
            persona,
            communicationStyle,
            additionalInstructions
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}

enum OperatorSoulStore {
    private static let directoryName = "K3Browser"
    private static let fileName = "operator-soul.json"

    private static func fileURL(fileManager: FileManager = .default) throws -> URL {
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = support.appendingPathComponent(directoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    static func load(fileManager: FileManager = .default) -> OperatorSoul? {
        guard let url = try? fileURL(fileManager: fileManager),
              let data = try? Data(contentsOf: url),
              let soul = try? JSONDecoder().decode(OperatorSoul.self, from: data),
              soul.version <= OperatorSoul.currentVersion else { return nil }
        return soul
    }

    @discardableResult
    static func save(_ soul: OperatorSoul, fileManager: FileManager = .default) -> Bool {
        do {
            let url = try fileURL(fileManager: fileManager)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(soul)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func reset(fileManager: FileManager = .default) -> OperatorSoul {
        if let url = try? fileURL(fileManager: fileManager) {
            try? fileManager.removeItem(at: url)
        }
        return .defaults
    }
}
