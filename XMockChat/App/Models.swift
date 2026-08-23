import Foundation
import SwiftUI

// MARK: - Domain models (Codable, persisted as JSON)

enum ChatStyle: String, Codable {
    case timestamp
    case notice
    case sent
    case received
}

struct ChatElement: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var style: ChatStyle
    var text: String
}

struct ChatSession: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var displayName: String = "lauren"
    var isVerified: Bool = true
    var avatarPNG: Data? = nil
    var inputPlaceholder: String = "Message"
    var badgeNotifications: Int = 4
    var badgeMessages: Int = 7
    var elements: [ChatElement] = ChatSeed.defaultElements()

    var title: String {
        let first = elements.first { !$0.text.isEmpty }?.text ?? ""
        return first.isEmpty ? displayName : String(first.prefix(32))
    }
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

    static func blankElements() -> [ChatElement] {
        [
            ChatElement(style: .timestamp, text: "Today"),
            ChatElement(style: .sent, text: "New message")
        ]
    }
}

// MARK: - Icon override slots

struct IconSlot: Codable, Equatable {
    var path: String
    var viewBoxWidth: Double
    var viewBoxHeight: Double
}

enum IconSlotKey: String, CaseIterable, Identifiable {
    case verified
    case voice
    case audioCall
    case videoCall
    case backArrow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .verified: return "Verified badge"
        case .voice: return "Voice note (mic)"
        case .audioCall: return "Audio call"
        case .videoCall: return "Video call"
        case .backArrow: return "Back arrow"
        }
    }
}

struct IconOverrides: Codable, Equatable {
    var verified: IconSlot? = nil
    var voice: IconSlot? = nil
    var audioCall: IconSlot? = nil
    var videoCall: IconSlot? = nil
    var backArrow: IconSlot? = nil

    subscript(key: IconSlotKey) -> IconSlot? {
        get {
            switch key {
            case .verified: return verified
            case .voice: return voice
            case .audioCall: return audioCall
            case .videoCall: return videoCall
            case .backArrow: return backArrow
            }
        }
        set {
            switch key {
            case .verified: verified = newValue
            case .voice: voice = newValue
            case .audioCall: audioCall = newValue
            case .videoCall: videoCall = newValue
            case .backArrow: backArrow = newValue
            }
        }
    }
}

// MARK: - Store (persistence)

final class ChatStore: ObservableObject {
    @Published var sessions: [ChatSession] {
        didSet { persistSessions() }
    }
    @Published var icons: IconOverrides {
        didSet { persistIcons() }
    }

    init() {
        sessions = Self.loadSessions()
        icons = Self.loadIcons()
        if sessions.isEmpty {
            sessions = [ChatSession()]
        }
    }

    private static var docs: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var sessionsURL: URL { docs.appendingPathComponent("chats.json") }
    private static var iconsURL: URL { docs.appendingPathComponent("icons.json") }

    private static func loadSessions() -> [ChatSession] {
        guard let data = try? Data(contentsOf: sessionsURL),
              let list = try? JSONDecoder().decode([ChatSession].self, from: data) else { return [] }
        return list
    }

    private static func loadIcons() -> IconOverrides {
        guard let data = try? Data(contentsOf: iconsURL),
              let o = try? JSONDecoder().decode(IconOverrides.self, from: data) else { return IconOverrides() }
        return o
    }

    private func persistSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            try? data.write(to: Self.sessionsURL, options: .atomic)
        }
    }

    private func persistIcons() {
        if let data = try? JSONEncoder().encode(icons) {
            try? data.write(to: Self.iconsURL, options: .atomic)
        }
    }
}
