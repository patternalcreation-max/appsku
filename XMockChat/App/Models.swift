import Foundation

struct ChatElement: Identifiable, Equatable {
    enum Style: Equatable {
        case timestamp
        case notice
        case sent
        case received
    }

    var id: UUID = UUID()
    var style: Style
    var text: String
}

enum ChatSeed {
    static func defaultElements() -> [ChatElement] {
        [
            ChatElement(style: .timestamp, text: "Wed, 19 Aug"),
            ChatElement(style: .sent, text: "brother why i don't eligible to upgrade ?"),
            ChatElement(style: .timestamp, text: "Yesterday"),
            ChatElement(style: .received, text: "Thanks for your interest in the free Pro+ plan for Grok Bot! Please use this form anysphere.typeform.com/grokbot to apply, and note that your application is not guaranteed to be selected."),
            ChatElement(style: .notice, text: "🔒 This conversation is now end-to-end encrypted"),
            ChatElement(style: .sent, text: "but i have it already , what i ask is grok superheavy plan annual")
        ]
    }
}
