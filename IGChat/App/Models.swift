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
