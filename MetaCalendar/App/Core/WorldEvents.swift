import Foundation

// MARK: - World Events (Astronomical, Sports, Global Observances)
// Computes recurring and one-time world events, each resolved to a fixedDay.

enum WorldEvents {

    private static let gmt: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current

    // MARK: - Public Entry Points

    static func generate(forGregorianYear year: Int) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        events.append(contentsOf: globalObservances(forGregorianYear: year))
        events.append(contentsOf: meteorShowers(forGregorianYear: year))
        events.append(contentsOf: sportsEvents(forGregorianYear: year))
        events.append(contentsOf: notableEclipses(forGregorianYear: year))
        return events.sorted { $0.fixedDay < $1.fixedDay }
    }

    static func upcoming(days: Int) -> [CalendarEvent] {
        let cal = Calendar(identifier: .gregorian)
        let todayFD = FixedDay.fromGregorian(
            year: cal.component(.year, from: Date()),
            month: cal.component(.month, from: Date()),
            day: cal.component(.day, from: Date())
        )
        let now = cal.component(.year, from: Date())
        var all = generate(forGregorianYear: now)
        all.append(contentsOf: generate(forGregorianYear: now + 1))
        let ceiling = todayFD + Int64(days)
        return all.filter { $0.fixedDay >= todayFD && $0.fixedDay <= ceiling }
            .sorted { $0.fixedDay < $1.fixedDay }
    }

    static func notable(from fixedDay: Int64) -> [CalendarEvent] {
        let (y, _, _) = FixedDay.toGregorian(fixedDay)
        return generate(forGregorianYear: y).filter { $0.fixedDay >= fixedDay }
    }

    // MARK: - Global Observances

    private static func globalObservances(forGregorianYear year: Int) -> [CalendarEvent] {
        let observances: [(month: Int, day: Int, name: String, emoji: String, desc: String)] = [
            (1, 1, "Tahun Baru Masehi", "🎉", "Awal tahun Gregorian"),
            (2, 14, "Hari Valentine", "💝", "Hari kasih sayang internasional"),
            (3, 8, "Hari Wanita Sedunia", "♀️", "Peringatan hak wanita"),
            (4, 1, "April Mop", "🤡", "Hari lelucon internasional"),
            (4, 22, "Hari Bumi", "🌍", "Kesadaran lingkungan global"),
            (5, 1, "Hari Buruh Internasional", "🔨", "Hak pekerja dunia"),
            (6, 5, "Hari Lingkungan Hidup", "🌱", "Deklarasi Stockholm 1972"),
            (8, 12, "Hari Pemuda Internasional", "💪", "Peran pemuda dunia"),
            (10, 31, "Halloween", "🎃", "Festival musim gugur"),
            (12, 10, "Hari Hak Asasi Manusia", "🕊️", "Deklarasi HAM PBB 1948"),
            (12, 31, "Malam Tahun Baru", "🎆", "Penutup tahun Gregorian"),
        ]

        return observances.map { item in
            let fd = FixedDay.fromGregorian(year: year, month: item.month, day: item.day)
            return makeEvent(key: "global.\(item.name).\(year)", name: item.name, emoji: item.emoji,
                             category: .observance, fixedDay: fd, description: item.desc)
        }
    }

    // MARK: - Meteor Showers

    private static func meteorShowers(forGregorianYear year: Int) -> [CalendarEvent] {
        let showers: [(month: Int, day: Int, name: String, desc: String)] = [
            (1, 3, "Quadrantids", "Hujan meteor awal tahun, radiante di Boötes"),
            (4, 22, "Lyrids", "Hujan meteor kuno dari rasi Lyra"),
            (5, 5, "Eta Aquariids", "Sisa komet Halley, terlihat di belahan selatan"),
            (7, 28, "Delta Aquariids", "Hujan meteor pertengahan musim panas"),
            (8, 12, "Perseids", "Hujan meteor terbesar tahun ini, sangat terlihat"),
            (10, 8, "Draconids", "Hujan meteor variatif dari Draco"),
            (10, 21, "Orionids", "Sisa komet Halley, cepat dan terang"),
            (11, 17, "Leonids", "Hujan meteor badai periodik dari Leo"),
            (12, 14, "Geminids", "Hujan meteor terbaik tahun ini, dari asteroid 3200 Phaethon"),
            (12, 22, "Ursids", "Hujan meteor akhir tahun dari Ursa Minor"),
        ]

        return showers.map { item in
            let fd = FixedDay.fromGregorian(year: year, month: item.month, day: item.day)
            return makeEvent(key: "meteor.\(item.name).\(year)", name: "Hujan Meteor \(item.name)",
                             emoji: "☄️", category: .astronomical, fixedDay: fd, description: item.desc)
        }
    }

    // MARK: - Sports Events

    private static func sportsEvents(forGregorianYear year: Int) -> [CalendarEvent] {
        var events: [CalendarEvent] = []

        // Olympics 2028 LA (Jul 14-30)
        if year == 2028 {
            let fd = FixedDay.fromGregorian(year: 2028, month: 7, day: 14)
            events.append(makeEvent(key: "sport.olympics2028", name: "Olimpiade Los Angeles 2028",
                                     emoji: "🏅", category: .sport, fixedDay: fd,
                                     description: "Olimpiade Musim Panas XXXIV di Los Angeles, AS"))
        }

        // World Cup 2026 (Jun 11 - Jul 19)
        if year == 2026 {
            let fd = FixedDay.fromGregorian(year: 2026, month: 6, day: 11)
            events.append(makeEvent(key: "sport.worldcup2026", name: "Piala Dunia FIFA 2026",
                                     emoji: "⚽", category: .sport, fixedDay: fd,
                                     description: "Piala Dunia FIFA bersama AS, Kanada, Meksiko"))
        }

        // Super Bowl (2nd Sunday February)
        if let sbDate = nthWeekday(year: year, month: 2, weekday: 1, occurrence: 2) {
            let fd = FixedDay.fromGregorian(year: year, month: 2, day: sbDate)
            events.append(makeEvent(key: "sport.superbowl.\(year)", name: "Super Bowl \(romanNumeral(year - 1965))",
                                     emoji: "🏈", category: .sport, fixedDay: fd,
                                     description: "Final liga sepak bola Amerika (NFL)"))
        }

        // UEFA Champions League Final (typically late May/early June)
        // Approximate: last Saturday of May
        if let clDate = lastWeekday(year: year, month: 5, weekday: 7) {
            let fd = FixedDay.fromGregorian(year: year, month: 5, day: clDate)
            events.append(makeEvent(key: "sport.uefa.\(year)", name: "Final Liga Champions UEFA",
                                     emoji: "🏆", category: .sport, fixedDay: fd,
                                     description: "Pertandingan final klub sepak bola Eropa"))
        }

        // F1 Monaco GP (typically last Sunday of May)
        if let monacoDate = lastWeekday(year: year, month: 5, weekday: 1) {
            let fd = FixedDay.fromGregorian(year: year, month: 5, day: monacoDate)
            events.append(makeEvent(key: "sport.f1monaco.\(year)", name: "F1 Grand Prix Monaco",
                                     emoji: "🏎️", category: .sport, fixedDay: fd,
                                     description: "Balapan Formula 1 paling bergengsi"))
        }

        // Tour de France (typically starts late June/early July)
        // Approximate: July 1
        let tdfFD = FixedDay.fromGregorian(year: year, month: 7, day: 1)
        events.append(makeEvent(key: "sport.tdf.\(year)", name: "Tour de France",
                                 emoji: "🚴", category: .sport, fixedDay: tdfFD,
                                 description: "Balapan sepeda panggung terbesar dunia"))

        return events
    }

    // MARK: - Notable Eclipses (known upcoming through 2030)

    private static func notableEclipses(forGregorianYear year: Int) -> [CalendarEvent] {
        let knownEclipses: [(year: Int, month: Int, day: Int, name: String, type: String, desc: String)] = [
            (2026, 2, 17, "Gerhana Matahari Cincin", "Annular", "Gerhana matahari cincin, terlihat di Antartika"),
            (2026, 8, 12, "Gerhana Matahari Total", "Total", "Gerhana total, terlihat di Greenland, Islandia, Spanyol"),
            (2027, 2, 6, "Gerhana Matahari Cincin", "Annular", "Gerhana cincin melintasi Amerika Selatan"),
            (2027, 8, 2, "Gerhana Matahari Total Abad Ini", "Total", "Gerhana total terpanjang abad 21 (6 menit 23 detik), lintas Mesir"),
            (2028, 1, 26, "Gerhana Matahari Cincin", "Annular", "Terlihat di Amerika Selatan dan Atlantik"),
            (2028, 7, 22, "Gerhana Matahari Total", "Total", "Gerhana total lintas Australia dan Selandia Baru"),
        ]

        return knownEclipses.compactMap { e in
            guard e.year == year else { return nil }
            let fd = FixedDay.fromGregorian(year: e.year, month: e.month, day: e.day)
            return makeEvent(key: "eclipse.\(e.name).\(e.year)", name: e.name,
                             emoji: "🌑", category: .astronomical, fixedDay: fd,
                             description: e.desc)
        }
    }

    // MARK: - Helpers

    private static func makeEvent(key: String, name: String, emoji: String,
                                  category: EventCategory, fixedDay: Int64, description: String) -> CalendarEvent {
        return CalendarEvent(
            id: key,
            name: name,
            emoji: emoji,
            category: category,
            calendarSystem: .gregorian,
            fixedDay: fixedDay,
            description: description
        )
    }

    /// Find the Nth occurrence of a weekday in a month.
    /// weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
    private static func nthWeekday(year: Int, month: Int, weekday: Int, occurrence: Int) -> Int? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = gmt

        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = occurrence

        guard let date = cal.date(from: components) else { return nil }
        let day = cal.component(.day, from: date)
        let resultMonth = cal.component(.month, from: date)
        return resultMonth == month ? day : nil
    }

    /// Find the last occurrence of a weekday in a month.
    private static func lastWeekday(year: Int, month: Int, weekday: Int) -> Int? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = gmt

        var components = DateComponents()
        components.year = year
        components.month = month
        components.weekday = weekday
        components.weekdayOrdinal = -1

        guard let date = cal.date(from: components) else { return nil }
        let day = cal.component(.day, from: date)
        let resultMonth = cal.component(.month, from: date)
        return resultMonth == month ? day : nil
    }

    private static func romanNumeral(_ n: Int) -> String {
        let values: [(Int, String)] = [
            (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"),
            (5, "V"), (4, "IV"), (1, "I")
        ]
        var result = ""
        var remaining = n
        for (value, numeral) in values {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }
}
