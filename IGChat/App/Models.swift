import Foundation

struct ChatElement: Identifiable, Hashable {
    enum Style: Equatable {
        case date
        case sent
        case received
    }

    var id: UUID = UUID()
    var style: Style
    var text: String
    var heartHint: Bool = false
}

struct IGProfile {
    var username: String = "gentlewomanstore"
    var isVerified: Bool = false
    var followers: String = "482K"
    var posts: String = "11K"
    var statusLine: String = "You don't follow each other on Instagram"
    var subtitle: String = "Business chat"
    var barPlaceholder: String = "Message…"
    // extra info lines under username (fullname etc.) — rendered tight, same style as status
    var infoLines: [String] = []

    var initials: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(2)).uppercased()
    }
}

enum IGSeed {
    static func smartDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date()).uppercased()
    }

    static func defaultElements() -> [ChatElement] {
        [
            ChatElement(style: .date, text: smartDate()),
            ChatElement(style: .sent, text: "Hey"),
            ChatElement(style: .received, text: "Hi", heartHint: false)
        ]
    }
}
