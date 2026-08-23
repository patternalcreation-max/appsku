import Foundation
import SwiftUI

enum ReplyKind: String, Codable, Equatable {
    case chat
    case story
}

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
    /// Non-empty / story image = show IG-style reply chrome above this bubble.
    var replyText: String? = nil
    var replyFromMe: Bool = false
    var replyKind: ReplyKind = .chat
    /// JPEG for story / media being replied to.
    var replyImageJPEG: Data? = nil
    /// JPEG for a photo message (text may be empty).
    var imageJPEG: Data? = nil
    /// For `.date` rows: underlying instant used by smart IG formatting / presets.
    var stampAt: Date? = nil

    var hasReply: Bool {
        let t = (replyText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty || replyImageJPEG != nil || replyKind == .story
    }

    var hasImage: Bool { imageJPEG != nil }

    enum CodingKeys: String, CodingKey {
        case id, style, text, heartHint, replyText, replyFromMe, replyKind, replyImageJPEG, imageJPEG, stampAt
    }

    init(id: UUID = UUID(), style: Style, text: String, heartHint: Bool = false,
         replyText: String? = nil, replyFromMe: Bool = false, replyKind: ReplyKind = .chat,
         replyImageJPEG: Data? = nil, imageJPEG: Data? = nil, stampAt: Date? = nil) {
        self.id = id; self.style = style; self.text = text; self.heartHint = heartHint
        self.replyText = replyText; self.replyFromMe = replyFromMe; self.replyKind = replyKind
        self.replyImageJPEG = replyImageJPEG; self.imageJPEG = imageJPEG
        self.stampAt = stampAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        style = try c.decode(Style.self, forKey: .style)
        text = try c.decode(String.self, forKey: .text)
        heartHint = try c.decodeIfPresent(Bool.self, forKey: .heartHint) ?? false
        replyText = try c.decodeIfPresent(String.self, forKey: .replyText)
        replyFromMe = try c.decodeIfPresent(Bool.self, forKey: .replyFromMe) ?? false
        replyKind = try c.decodeIfPresent(ReplyKind.self, forKey: .replyKind) ?? .chat
        replyImageJPEG = try c.decodeIfPresent(Data.self, forKey: .replyImageJPEG)
        imageJPEG = try c.decodeIfPresent(Data.self, forKey: .imageJPEG)
        stampAt = try c.decodeIfPresent(Date.self, forKey: .stampAt)
    }
}

struct IGProfile: Codable, Equatable {
    var username: String = "gentlewomanstore"
    var isVerified: Bool = false
    var followers: String = "482K"
    var posts: String = "11K"
    var statusLine: String = "You don't follow each other on Instagram"
    var subtitle: String = "Business chat"
    var barPlaceholder: String = "Message…"
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
    /// Patricia / Kimchi Pump.fun script (Us = Me, Patricia = Them)
    static func patriciaKimchiElements() -> [ChatElement] {
        var out: [ChatElement] = [IGStamp.makeSeparator(.hours2)]
        func me(_ s: String) { out.append(ChatElement(style: .sent, text: s)) }
        func them(_ s: String) { out.append(ChatElement(style: .received, text: s)) }

        me("Hey Patricia,\nI saw the reel.\nThe mama of Kimchi one.")
        me("You played it as a joke, but the timing is actually perfect. He’s all over the internet right now and barely says anything himself.")
        me("You already have an angle that doesn’t look forced.")
        me("If you want this set up properly, send me your Solana wallet and make a Pump.fun account.\n100% of the creator fees go to you. No split.")

        them("Wait you actually watched that?? 😭\nI was being messy for content. I even said “his dad is Asian” like I was filing a birth certificate.")
        them("I’m not gonna lie though… I’ve been in a Kimchi rabbit hole for days. I keep refreshing like a crazy person.")
        them("If I do that, can I actually interact with him through this?\nIf yes I’ll make the account right now.")

        me("Yes.")
        me("And you’re not even the only one who saw that reel.\nOrangie already posted your video. The mama of Kimchi one.")
        me("He’s been close with Kimchi since they were kids playing Fortnite.\nSo the people around him have already seen you claiming him as your son.")
        me("Send the wallet when the account is ready.")

        them("STOP.\nOrangie posted it?? The Fortnite friend??\nI need a second. I made that reel in my kitchen like it was nothing.")
        them("Okay. I’ll do whatever I have to if it actually gets me in front of him.\nDo I just… make the account and that’s it? I’m not trying to look like I wandered into the wrong app.")

        me("Yeah. Make the Pump.fun account, send the Solana wallet, that’s it.")
        me("You don’t have to start talking like a trader. Keep being you. The reel already did the work.")
        me("We’re not putting you in a situation where you look lost.")

        them("Fine. I’m doing it.\n\nIf this gets me ignored I’m deleting the reel.")
        them("Here :\nWallet\n\nJust made the Pump.fun account too.")
        them("Please don’t make me look crazy.\nI already look crazy enough calling myself his mom.")

        me("Got it.\nBefore we launch, look at this.\nThis is the banner and the token logo.\nWhat do you think?")

        them("WAIT.\nThat’s actually funny. Like stupid funny.\nAnd it looks sexy. Hot. I look good in that, I’m not even gonna pretend I don’t.")
        them("I like it. A lot.\nIf Kimchi sees this and still ignores me I’m going to take it personally.")

        me("Then we’re using it.\nWe’ll launch it first, then post the screen record on X.\nYou’ll see it before it goes public.")
        me("Thank you, Patricia.")
        return out
    }

    static func patriciaProfile() -> IGProfile {
        var p = IGProfile()
        p.username = "patricia"
        p.subtitle = "Business chat"
        p.isVerified = false
        p.followers = "128K"
        p.posts = "642"
        p.statusLine = "You don't follow each other on Instagram"
        p.infoLines = []
        return p
    }

}


// MARK: - Smart IG-style date stamps

enum IGStamp {
    /// Format like native IG separators: "2:34 PM" / "SAT 6:05PM" / "AUG 9 AT 2:34 PM"
    static func label(for date: Date, now: Date = Date()) -> String {
        var cal = Calendar.current
        cal.timeZone = .current
        let timeLoose: (Date) -> String = { d in
            let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: d).uppercased()
        }
        let timeTight: (Date) -> String = { d in
            let f = DateFormatter(); f.dateFormat = "h:mma"; return f.string(from: d).uppercased()
        }
        if cal.isDate(date, inSameDayAs: now) {
            return timeLoose(date)
        }
        let startNow = cal.startOfDay(for: now)
        let startDate = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startDate, to: startNow).day ?? 0
        if days >= 1 && days <= 6 {
            let f = DateFormatter(); f.dateFormat = "EEE"
            return f.string(from: date).uppercased() + " " + timeTight(date)
        }
        let mf = DateFormatter(); mf.dateFormat = "MMM d"
        return mf.string(from: date).uppercased() + " AT " + timeLoose(date)
    }

    enum Preset: String, CaseIterable, Identifiable {
        case justNow = "Just now"
        case hours2 = "2h ago"
        case hours6 = "6h ago"
        case yesterdayMorning = "Yesterday morning"
        case yesterdayEvening = "Yesterday evening"
        case threeDays = "3 days ago"
        case lastWeek = "Last week"
        var id: String { rawValue }

        func date(from now: Date = Date()) -> Date {
            var cal = Calendar.current
            cal.timeZone = .current
            switch self {
            case .justNow: return now
            case .hours2: return cal.date(byAdding: .hour, value: -2, to: now) ?? now
            case .hours6: return cal.date(byAdding: .hour, value: -6, to: now) ?? now
            case .yesterdayMorning:
                let y = cal.date(byAdding: .day, value: -1, to: now) ?? now
                return cal.date(bySettingHour: 9, minute: 12, second: 0, of: y) ?? y
            case .yesterdayEvening:
                let y = cal.date(byAdding: .day, value: -1, to: now) ?? now
                return cal.date(bySettingHour: 20, minute: 47, second: 0, of: y) ?? y
            case .threeDays:
                let d = cal.date(byAdding: .day, value: -3, to: now) ?? now
                return cal.date(bySettingHour: 14, minute: 5, second: 0, of: d) ?? d
            case .lastWeek:
                let d = cal.date(byAdding: .day, value: -7, to: now) ?? now
                return cal.date(bySettingHour: 16, minute: 30, second: 0, of: d) ?? d
            }
        }
    }

    static func makeSeparator(_ preset: Preset = .justNow, now: Date = Date()) -> ChatElement {
        let d = preset.date(from: now)
        return ChatElement(style: .date, text: label(for: d, now: now), stampAt: d)
    }

    static func apply(_ preset: Preset, to element: inout ChatElement, now: Date = Date()) {
        let d = preset.date(from: now)
        element.stampAt = d
        element.text = label(for: d, now: now)
    }

    static func nudge(_ element: inout ChatElement, minutes: Int, now: Date = Date()) {
        let base = element.stampAt ?? now
        let d = Calendar.current.date(byAdding: .minute, value: minutes, to: base) ?? base
        element.stampAt = d
        element.text = label(for: d, now: now)
    }
}

// MARK: - Date separator buckets (HTML tool parity)

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

        var today: [DateOption] = []
        for h in [0, 2, 4, 6, 9] {
            var d = now
            d = cal.date(byAdding: .hour, value: -h, to: d) ?? d
            if !cal.isDate(d, inSameDayAs: now) {
                d = cal.date(bySettingHour: 0, minute: 8, second: 0, of: now) ?? now
            }
            today.append(DateOption(label: fmtTime(d)))
        }

        let times: [(Int, Int)] = [(9, 12), (13, 29), (18, 5), (21, 47)]
        var dayOpts: [DateOption] = []
        for g in 1...6 {
            guard let day = cal.date(byAdding: .day, value: -g, to: now) else { continue }
            for t in times {
                let dd = cal.date(bySettingHour: t.0, minute: t.1, second: 0, of: day) ?? day
                dayOpts.append(DateOption(label: wdShort(dd) + " " + time(dd, tight: true)))
            }
        }

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

    func createChat(title: String? = nil, elements: [ChatElement]? = nil) -> ChatSession {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        let chat = ChatSession(
            title: title ?? "Chat \(chats.count + 1)",
            elements: elements ?? [ChatElement(style: .date, text: f.string(from: Date()).uppercased())]
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
        var subtitleFontSize: Double = 10
        var headerBlurOnly: Bool = true
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
