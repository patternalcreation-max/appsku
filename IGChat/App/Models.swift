import Foundation
import SwiftUI

struct ChatElement: Identifiable, Hashable, Codable {
    enum Style: Equatable, Codable {
        case date
        case sent
        case received
    }

    var id: UUID = UUID()
    var style: Style
    var text: String
    var heartHint: Bool = false
}

struct IGProfile: Codable {
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

// MARK: - Date separator buckets (HTML tool parity)
// Rules: today -> "2:34 PM" | yesterday..6d -> "SAT 6:05PM" | older -> "AUG 9 AT 2:34 PM"
// All options constructed BACKWARD from now -> future impossible.

struct DateOption: Identifiable {
    let id = UUID()
    let label: String
}

enum DateBuckets {
    struct Bucket: Identifiable {
        let id = UUID()
        let name: String
        let options: [DateOption]
    }

    static func time(_ d: Date, tight: Bool = false) -> String {
        let f = DateFormatter()
        f.dateFormat = tight ? "h:mma" : "h:mm a"
        return f.string(from: d).uppercased()
    }

    static func buckets(now: Date = Date()) -> [Bucket] {
        var cal = Calendar.current
        cal.timeZone = .current

        let fmtTime = { (d: Date) in time(d) }
        let wdShort = { (d: Date) in
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f.string(from: d).uppercased()
        }

        // Today: 0,2,4,6,9h back; clipped to early-today if crossed midnight
        var today: [DateOption] = []
        for h in [0, 2, 4, 6, 9] {
            var d = now
            d = cal.date(byAdding: .hour, value: -h, to: d) ?? d
            if !cal.isDate(d, inSameDayAs: now) {
                d = cal.date(bySettingHour: 0, minute: 8, second: 0, of: now) ?? now
            }
            today.append(DateOption(label: fmtTime(d)))
        }

        // yesterday..6 days: "SAT 6:05PM" — 4 plausible times/day
        let times: [(Int, Int)] = [(9, 12), (13, 29), (18, 5), (21, 47)]
        var dayOpts: [DateOption] = []
        for g in 1...6 {
            guard let day = cal.date(byAdding: .day, value: -g, to: now) else { continue }
            for t in times {
                let dd = cal.date(bySettingHour: t.0, minute: t.1, second: 0, of: day) ?? day
                dayOpts.append(DateOption(label: wdShort(dd) + " " + time(dd, tight: true)))
            }
        }

        // older: "AUG 9 AT 2:34 PM"
        var old: [DateOption] = []
        for g in [10, 14, 21, 30] {
            guard let day = cal.date(byAdding: .day, value: -g, to: now) else { continue }
            let mf = DateFormatter()
            mf.dateFormat = "MMM d"
            let stamp = mf.string(from: day).uppercased()
            old.append(DateOption(label: stamp + " AT " + fmtTime(day)))
        }

        return [
            Bucket(name: "Today", options: today),
            Bucket(name: "Yesterday", options: Array(dayOpts.prefix(4))),
            Bucket(name: "This week", options: Array(dayOpts.dropFirst(4))),
            Bucket(name: "Older", options: old)
        ]
    }
}


// MARK: - Multi-chat store (v1.18)
struct ChatSession: Identifiable, Equatable, Codable {
    var id = UUID()
    var title: String
    var elements: [ChatElement]
}

@MainActor
final class ChatStore: ObservableObject {
    @Published var chats: [ChatSession] = [] {
        didSet { persist() }
    }
    @Published var currentId: UUID? {
        didSet { persistCurrent() }
    }

    private let storage = UserDefaults.standard
    private let key = "igchat.sessions.v1"
    private let currentKey = "igchat.sessions.current"

    init() { restore() }

    var current: ChatSession? {
        get { chats.first(where: { $0.id == currentId }) }
    }

    // MARK: persistence — chats survive app restarts

    private func persist() {
        if let data = try? JSONEncoder().encode(chats) {
            storage.set(data, forKey: key)
        }
    }
    private func persistCurrent() {
        storage.set(currentId?.uuidString, forKey: currentKey)
    }
    private func restore() {
        if let data = storage.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ChatSession].self, from: data) {
            chats = decoded
        }
        if let s = storage.string(forKey: currentKey), let id = UUID(uuidString: s),
           chats.contains(where: { $0.id == id }) {
            currentId = id
        }
    }

    func openDefault(elements: [ChatElement], title: String) {
        if let first = chats.first {
            if currentId == nil { currentId = first.id }
        } else {
            let d = ChatSession(title: title, elements: elements)
            chats.append(d)
            currentId = d.id
        }
    }

    func snapshotCurrent(_ elements: [ChatElement]) {
        if let idx = chats.firstIndex(where: { $0.id == currentId }) {
            chats[idx].elements = elements
        }
    }

    func createChat() -> ChatSession {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        let chat = ChatSession(
            title: "Chat \(chats.count + 1)",
            elements: [ChatElement(style: .date, text: f.string(from: Date()).uppercased())]
        )
        chats.append(chat)
        currentId = chat.id
        return chat
    }

    func deleteChat(_ id: UUID) {
        chats.removeAll { $0.id == id }
        if currentId == id { currentId = chats.first?.id }
    }
}

// MARK: - Profile + Look & feel persistence

enum IGPersistence {
    private static let profileKey = "igchat.profile.v1"
    private static let lookKey = "igchat.look.v1"

    static func saveProfile(_ p: IGProfile) {
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }
    static func loadProfile() -> IGProfile? {
        guard let data = UserDefaults.standard.data(forKey: profileKey) else { return nil }
        return try? JSONDecoder().decode(IGProfile.self, from: data)
    }

    struct Look: Codable {
        var gradAHex: String
        var gradBHex: String
        var bandPct: Double
        var frostBlur: Double
        var gradTop: Double = 15
        var gradBottom: Double = 30
    }
    static func saveLook(_ l: Look) {
        if let data = try? JSONEncoder().encode(l) {
            UserDefaults.standard.set(data, forKey: lookKey)
        }
    }
    static func loadLook() -> Look? {
        guard let data = UserDefaults.standard.data(forKey: lookKey) else { return nil }
        return try? JSONDecoder().decode(Look.self, from: data)
    }
}

extension Color {
    var igHex: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    init(igHex: String) {
        var s = igHex
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}
