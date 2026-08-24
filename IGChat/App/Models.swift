import Foundation
import SwiftUI

enum ReplyKind: String, Codable, Equatable {
    case chat
    case story
}

/// Framing for a photo bubble (IG-like crop window + pan + zoom).
struct PhotoFrame: Codable, Equatable, Hashable {
    /// 0 = full height · 1 = shortest IG-style window
    var window: Double = 0.35
    /// 0 = left · 0.5 = center · 1 = right
    var focusX: Double = 0.5
    /// 0 = top · 0.5 = center · 1 = bottom
    var focusY: Double = 0.5
    /// 1 = normal fill · up to 2.5 = punch-in
    var zoom: Double = 1.0

    static let `default` = PhotoFrame()

    func clamped() -> PhotoFrame {
        PhotoFrame(
            window: min(max(window, 0), 1),
            focusX: min(max(focusX, 0), 1),
            focusY: min(max(focusY, 0), 1),
            zoom: min(max(zoom, 1), 2.5)
        )
    }
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
    /// Per-photo framing override. nil = use Settings defaults.
    var photoFrame: PhotoFrame? = nil
    /// For `.date` rows: underlying instant used by smart IG formatting / presets.
    var stampAt: Date? = nil

    var hasReply: Bool {
        let t = (replyText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty || replyImageJPEG != nil || replyKind == .story
    }

    var hasImage: Bool { imageJPEG != nil }

    enum CodingKeys: String, CodingKey {
        case id, style, text, heartHint, replyText, replyFromMe, replyKind, replyImageJPEG, imageJPEG, photoFrame, stampAt
    }

    init(id: UUID = UUID(), style: Style, text: String, heartHint: Bool = false,
         replyText: String? = nil, replyFromMe: Bool = false, replyKind: ReplyKind = .chat,
         replyImageJPEG: Data? = nil, imageJPEG: Data? = nil, photoFrame: PhotoFrame? = nil,
         stampAt: Date? = nil) {
        self.id = id; self.style = style; self.text = text; self.heartHint = heartHint
        self.replyText = replyText; self.replyFromMe = replyFromMe; self.replyKind = replyKind
        self.replyImageJPEG = replyImageJPEG; self.imageJPEG = imageJPEG
        self.photoFrame = photoFrame
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
        if let frame = try c.decodeIfPresent(PhotoFrame.self, forKey: .photoFrame) {
            photoFrame = frame
        } else {
            // migrate v1.27 landscapeCrop → photoFrame.window
            enum Legacy: String, CodingKey { case landscapeCrop }
            let legacy = try decoder.container(keyedBy: Legacy.self)
            if let crop = try legacy.decodeIfPresent(Double.self, forKey: .landscapeCrop) {
                photoFrame = PhotoFrame(window: crop)
            } else {
                photoFrame = nil
            }
        }
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
    /// Patricia / Kimchi Pump.fun script (Us = Me, Patricia = Them).
    /// Timestamps: from ~5:00 PM (local) through "now", with uneven gaps so it doesn't look instant.
    static func patriciaKimchiElements(now: Date = Date()) -> [ChatElement] {
        var cal = Calendar.current
        cal.timeZone = .current

        // "Jam 5 sore tadi" — 17:00 local; if that is still in the future, use yesterday.
        var start = cal.date(bySettingHour: 17, minute: Int.random(in: 0...18), second: Int.random(in: 0...50), of: now) ?? now
        if start >= now {
            start = cal.date(byAdding: .day, value: -1, to: start) ?? start
        }

        struct Line { let me: Bool; let text: String }
        // Short stranger→girl pitch. Patricia stays excited / hot-funny, not essay-length.
        let lines: [Line] = [
            .init(me: true,  text: "Hey Patricia — random but I saw your reel. The mama of Kimchi one."),
            .init(me: true,  text: "Timing’s actually perfect. He’s everywhere rn and barely says anything. Your angle already works."),
            .init(me: true,  text: "If you want it set up: Pump.fun account + Solana wallet.\n100% creator fees to you. No split."),

            .init(me: false, text: "wait you actually watched that 😭 I was being so unserious"),
            .init(me: false, text: "ok but like… can this actually get me near him or is this just crypto weirdness"),

            .init(me: true,  text: "Both. And Orangie already reshared your video btw."),
            .init(me: true,  text: "Wallet + account when you’re ready."),

            .init(me: false, text: "STOP orangie posted it?? 💀 I filmed that in my kitchen"),
            .init(me: false, text: "fine i’m doing it. if I look crazy that’s already on brand as his mom"),

            .init(me: false, text: "here\nWallet\nmade the pump account too"),

            .init(me: true,  text: "before we launch — banner + logo. what do you think?"),

            .init(me: false, text: "wait that’s actually hot 😭 stupid funny but I look good I’m not even gonna lie"),
            .init(me: false, text: "if he ignores this i’m taking it personal"),

            .init(me: true,  text: "we’re using it. launch first, then X screen record. you’ll see it before it goes public."),
        ]

        // Raw gaps: short inside a burst, slow between speaker turns (not "fast respond").
        var raw: [TimeInterval] = [0]
        for i in 1..<lines.count {
            let same = lines[i].me == lines[i - 1].me
            if same {
                raw.append(TimeInterval(Int.random(in: 20...150)))          // 20s…2.5m
            } else {
                // Mix of "thinking" replies — minutes, sometimes longer
                let roll = Int.random(in: 0...9)
                if roll <= 5 {
                    raw.append(TimeInterval(Int.random(in: 9 * 60...28 * 60)))   // 9–28m
                } else if roll <= 8 {
                    raw.append(TimeInterval(Int.random(in: 28 * 60...55 * 60)))  // 28–55m
                } else {
                    raw.append(TimeInterval(Int.random(in: 55 * 60...95 * 60)))  // 55–95m
                }
            }
        }

        let span = max(now.timeIntervalSince(start) - TimeInterval(Int.random(in: 90...420)), 60)
        let sum = raw.reduce(0, +)
        let scale = sum > 0 ? span / sum : 1

        var times: [Date] = []
        var cursor = start
        for (idx, gap) in raw.enumerated() {
            if idx == 0 {
                times.append(start)
            } else {
                cursor = cursor.addingTimeInterval(gap * scale)
                if cursor > now.addingTimeInterval(-45) {
                    cursor = now.addingTimeInterval(-45)
                }
                times.append(cursor)
            }
        }
        // Last bubble near "now" (a few minutes ago)
        if times.count > 1 {
            times[times.count - 1] = now.addingTimeInterval(-TimeInterval(Int.random(in: 45...360)))
        }

        var out: [ChatElement] = []
        var lastStampAt: Date?
        for (i, line) in lines.enumerated() {
            let d = times[i]
            let showStamp: Bool
            if let last = lastStampAt {
                let gap = d.timeIntervalSince(last)
                // New stamp when enough wall-clock passed, or IG label would change (day/hour style)
                showStamp = gap >= 22 * 60
                    || IGStamp.label(for: d, now: now) != IGStamp.label(for: last, now: now)
            } else {
                showStamp = true
            }
            if showStamp {
                out.append(ChatElement(style: .date, text: IGStamp.label(for: d, now: now), stampAt: d))
                lastStampAt = d
            }
            out.append(ChatElement(
                style: line.me ? .sent : .received,
                text: line.text,
                stampAt: d
            ))
        }
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
        var frostBlur: Double
        var gradTop: Double = 35
        var gradBottom: Double = 60
        var subtitleFontSize: Double = 10
        /// Default photo framing (overridden per bubble when set)
        var photoWindow: Double = 0.35
        var photoFocusX: Double = 0.5
        var photoFocusY: Double = 0.5
        var photoZoom: Double = 1.0
        var photoMaxWidth: Double = 280
        // legacy (ignored in UI; still decoded if present)
        var bandPct: Double = 15
        var headerBlurOnly: Bool = true
        var landscapeCrop: Double = 0.35
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
