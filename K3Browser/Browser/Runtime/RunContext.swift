import Foundation

struct RunContext: Equatable {
    let runID: UUID
    let command: String
    let startedAt: Date

    init(runID: UUID = UUID(), command: String, startedAt: Date = Date()) {
        self.runID = runID
        self.command = command
        self.startedAt = startedAt
    }
}
