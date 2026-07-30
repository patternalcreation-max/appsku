import Foundation

// PEAK 4 Endgame — Workflow recipes.
// Saved browsing workflows as JSON in app sandbox. User can create, run, edit, export.

struct Workflow: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var steps: [WorkflowStep]
    var createdAt: Date
    var isBuiltIn: Bool

    init(name: String, description: String, steps: [WorkflowStep], isBuiltIn: Bool = false) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.steps = steps
        self.createdAt = Date()
        self.isBuiltIn = isBuiltIn
    }
}

struct WorkflowStep: Codable, Equatable {
    enum Kind: String, Codable {
        case snapshot          // capture page snapshot
        case extractLinks      // extract all links
        case extractTables     // extract tables
        case summarize         // ask agent to summarize
        case customPrompt      // run custom agent prompt
        case saveNote          // save result as note
    }

    var kind: Kind
    var prompt: String        // used for customPrompt and summarize
    var label: String         // display label
}

enum WorkflowStore {
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("K3Browser", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("workflows.json")
    }

    static func load() -> [Workflow] {
        let userWorkflows: [Workflow] = {
            guard let data = try? Data(contentsOf: fileURL) else { return [] }
            return (try? JSONDecoder().decode([Workflow].self, from: data)) ?? []
        }()
        return BuiltInWorkflows.all + userWorkflows
    }

    static func save(_ workflows: [Workflow]) {
        let userOnly = workflows.filter { !$0.isBuiltIn }
        let encoded = (try? JSONEncoder().encode(userOnly)) ?? Data()
        try? encoded.write(to: fileURL, options: .atomic)
    }

    static func add(name: String, description: String, steps: [WorkflowStep]) {
        var existing = load().filter { !$0.isBuiltIn }
        existing.append(Workflow(name: name, description: description, steps: steps))
        save(existing)
    }

    static func remove(id: UUID) {
        var existing = load().filter { !$0.isBuiltIn }
        existing.removeAll { $0.id == id }
        save(existing)
    }
}

enum BuiltInWorkflows {
    static let all: [Workflow] = [summarizeAndNote, extractLinksMarkdown, extractTableCSV]

    static let summarizeAndNote = Workflow(
        name: "Summarize + Save Note",
        description: "Summarize the current page and save the result as a note.",
        steps: [
            WorkflowStep(kind: .summarize, prompt: "Summarize this page in 3 key points.", label: "Summarize"),
            WorkflowStep(kind: .saveNote, prompt: "", label: "Save as note")
        ],
        isBuiltIn: true
    )

    static let extractLinksMarkdown = Workflow(
        name: "Extract Links as Markdown",
        description: "Capture snapshot and extract all links as a Markdown list.",
        steps: [
            WorkflowStep(kind: .snapshot, prompt: "", label: "Capture snapshot"),
            WorkflowStep(kind: .extractLinks, prompt: "", label: "Extract links")
        ],
        isBuiltIn: true
    )

    static let extractTableCSV = Workflow(
        name: "Extract Table to CSV",
        description: "Extract tables from the current page for CSV export.",
        steps: [
            WorkflowStep(kind: .snapshot, prompt: "", label: "Capture snapshot"),
            WorkflowStep(kind: .extractTables, prompt: "", label: "Extract tables")
        ],
        isBuiltIn: true
    )
}
