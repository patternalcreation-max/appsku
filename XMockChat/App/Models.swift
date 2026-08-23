import Foundation

// MARK: - v1.3.1 element model (unchanged)

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

    static func blankElements() -> [ChatElement] {
        [
            ChatElement(style: .timestamp, text: "Today"),
            ChatElement(style: .sent, text: "New message")
        ]
    }
}

// MARK: - Session wrapper (NEW in 2.x — enables chat list + persistence)

struct ChatSession: Identifiable, Equatable {
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

// MARK: - Persistence (JSON in Documents)

import SwiftUI

final class ChatStore: ObservableObject {
    @Published var sessions: [ChatSession] = [] {
        didSet { persist() }
    }

    init() {
        load()
        if sessions.isEmpty {
            sessions = [ChatSession()]
        }
    }

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("xmockchat_sessions.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let list = try? decoder.decode([ChatSession].self, from: data) else { return }
        sessions = list
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(sessions) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}

extension ChatSession {
    /// Manual Codable implementation (kept out of the struct to preserve v1.3.1 memberwise init)
    enum CodingKeys: String, CodingKey {
        case id, createdAt, displayName, isVerified, avatarPNG, inputPlaceholder
        case badgeNotifications, badgeMessages, elements
    }
}

extension ChatSession: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? "lauren"
        isVerified = try c.decodeIfPresent(Bool.self, forKey: .isVerified) ?? true
        avatarPNG = try c.decodeIfPresent(Data.self, forKey: .avatarPNG)
        inputPlaceholder = try c.decodeIfPresent(String.self, forKey: .inputPlaceholder) ?? "Message"
        badgeNotifications = try c.decodeIfPresent(Int.self, forKey: .badgeNotifications) ?? 4
        badgeMessages = try c.decodeIfPresent(Int.self, forKey: .badgeMessages) ?? 7
        elements = try c.decodeIfPresent([ChatElement].self, forKey: .elements) ?? ChatSeed.defaultElements()
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(isVerified, forKey: .isVerified)
        try c.encodeIfPresent(avatarPNG, forKey: .avatarPNG)
        try c.encode(inputPlaceholder, forKey: .inputPlaceholder)
        try c.encode(badgeNotifications, forKey: .badgeNotifications)
        try c.encode(badgeMessages, forKey: .badgeMessages)
        try c.encode(elements, forKey: .elements)
    }
}

extension ChatElement: Codable {}
