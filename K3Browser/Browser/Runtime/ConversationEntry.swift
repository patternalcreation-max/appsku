import Foundation

// ConversationEntry — chat-style history for agent interactions.
// Stores user commands and agent responses with markdown preserved.

struct ConversationEntry: Identifiable, Codable, Equatable {
    enum Role: String, Codable {
        case user
        case agent
    }

    let id: UUID
    let role: Role
    let content: String        // raw markdown text
    let timestamp: Date
    var isError: Bool

    init(role: Role, content: String, isError: Bool = false) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.isError = isError
    }
}
