import Foundation

// MARK: - Calendar Events & Holidays (per blueprint §7.5)
//
// Computes major cultural, religious, national, and seasonal observances across all
// five calendar systems supported by Meta Calendar. Every event resolves to a `fixedDay`
// (Rata Die ordinal), so it can be projected into any system by the existing adapters.
//
// Computation model:
//  - Gregorian / Chinese / Seasonal events are keyed by the Gregorian year.
//  - Islamic events are keyed by the Hijri year (a Gregorian year overlaps ~2 Hijri years).
//  - Javanese court observances (Sekaten, Grebeg, Satu Suro) follow the Sultan Agungan
//    lunar months, which parallel the Hijri months — so they are resolved via the Hijri
//    fixed-day arithmetic and tagged with the Javanese system.
//
// All dates are tabular/arithmetic (`.computed` status). Real-world observance may shift
// ±1–2 days from lunar-sighting or local authority declarations.

// MARK: - Event Category

/// Coarse classification used for filtering and theming in the UI.
enum EventCategory: String, Codable, Sendable, CaseIterable, Identifiable {
    case religious
    case cultural
    case national
    case seasonal
    case observance
    case astronomical
    case sport

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .religious:    return "Religious"
        case .cultural:     return "Cultural"
        case .national:     return "National"
        case .seasonal:     return "Seasonal"
        case .observance:   return "Observance"
        case .astronomical: return "Astronomy"
        case .sport:        return "Sport"
        }
    }

    /// SF Symbol used when no emoji is available.
    var systemImage: String {
        switch self {
        case .religious:     return "moon.fill"
        case .cultural:      return "theatermasks.fill"
        case .national:      return "flag.fill"
        case .seasonal:      return "leaf.fill"
        case .observance:    return "sparkles"
        case .astronomical:  return "moon.stars.fill"
        case .sport:         return "trophy.fill"
        }
    }
}

// MARK: - Calendar Event

/// A single resolved holiday / observance pinned to one day.
struct CalendarEvent: Identifiable, Sendable, Equatable, Hashable {
    /// Stable identifier: "<system>.<key>.<fixedDay>" — unique per occurrence.
    let id: String
    let name: String
    let emoji: String
    let category: EventCategory
    let calendarSystem: CalendarSystemID
    let fixedDay: Int64
    let description: String

    /// M2: explicit origin of the underlying astronomical data. nil for non-astronomy events.
    let dataOrigin: AstronomyDataOrigin?
    /// M2: full provenance descriptor (method/source/accuracy). nil for non-astronomy events.
    let provenance: AstronomyProvenance?

    /// Convenience: Gregorian (year, month, day) of the event.
    var gregorianDate: (year: Int, month: Int, day: Int) {
        FixedDay.toGregorian(fixedDay)
    }

    /// Weekday index (0 = Sunday … 6 = Saturday), per `FixedDay.weekday`.
    var weekdayIndex: Int { FixedDay.weekday(fixedDay) }

    /// Human-readable Gregorian date label.
    var gregorianLabel: String {
        let (y, m, d) = gregorianDate
        let names = Calendar(identifier: .gregorian).monthSymbols
        let monthName = (1...12).contains(m) ? names[m - 1] : "M\(m)"
        return "\(monthName) \(d), \(y)"
    }

    /// UI convenience: formatted date string (short)
    var dateString: String {
        let (m, d) = (gregorianDate.month, gregorianDate.day)
        let names = Calendar(identifier: .gregorian).shortMonthSymbols
        let monthName = (1...12).contains(m) ? names[m - 1] : "M\(m)"
        return "\(monthName) \(d)"
    }

    /// UI convenience: days from today (positive = future, 0 = today, negative = past)
    var daysFromToday: Int {
        let todayFD = FixedDay.fromGregorian(year: Calendar(identifier: .gregorian).component(.year, from: Date()),
                                             month: Calendar(identifier: .gregorian).component(.month, from: Date()),
                                             day: Calendar(identifier: .gregorian).component(.day, from: Date()))
        return Int(fixedDay - todayFD)
    }
}

// MARK: - Calendar Events Generator

enum CalendarEvents {

    /// GMT timezone used for all internal calendar resolution (ADR-007: no OS-global reads).
    private static let gmt: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current

    // --------------------------------------------------------------------------------------------
    // MARK: Public entry points
    // --------------------------------------------------------------------------------------------

    /// All events that begin on a day within the given Gregorian year, sorted chronologically.
    static func generate(forGregorianYear year: Int) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        events.append(contentsOf: gregorianEvents(forGregorianYear: year))
        events.append(contentsOf: islamicEvents(forGregorianYear: year))
        events.append(contentsOf: chineseEvents(forGregorianYear: year))
        events.append(contentsOf: javaneseEvents(forGregorianYear: year))
        events.append(contentsOf: seasonalEvents(forGregorianYear: year))
        return events.sorted { $0.fixedDay < $1.fixedDay }
    }

    /// Events across an inclusive Gregorian year range.
    static func generate(forGregorianYearRange startYear: Int, through endYear: Int) -> [CalendarEvent] {
        let years = Swift.min(startYear, endYear)...Swift.max(startYear, endYear)
        return years.flatMap { generate(forGregorianYear: $0) }.sorted { $0.fixedDay < $1.fixedDay }
    }

    /// Events occurring within `dayCount` days after (and including) `anchorFixedDay`.
    static func upcoming(from anchorFixedDay: Int64, dayCount: Int) -> [CalendarEvent] {
        let (y, _, _) = FixedDay.toGregorian(anchorFixedDay)
        let window = generate(forGregorianYearRange: y, through: y + 1)
        let ceiling = anchorFixedDay + Int64(dayCount)
        return window.filter { $0.fixedDay >= anchorFixedDay && $0.fixedDay <= ceiling }
                     .sorted { $0.fixedDay < $1.fixedDay }
    }

    /// Events that fall on a specific fixed day (typically 0 or 1).
    static func events(on fixedDay: Int64) -> [CalendarEvent] {
        let (y, _, _) = FixedDay.toGregorian(fixedDay)
        return generate(forGregorianYear: y).filter { $0.fixedDay == fixedDay }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: UI convenience wrappers
    // --------------------------------------------------------------------------------------------

    /// Upcoming events within `days` from today.
    static func upcoming(days: Int, hijriProfile: HijriProfile = .tabular) -> [CalendarEvent] {
        let cal = Calendar(identifier: .gregorian)
        let todayFD = FixedDay.fromGregorian(
            year: cal.component(.year, from: Date()),
            month: cal.component(.month, from: Date()),
            day: cal.component(.day, from: Date())
        )
        return upcoming(from: todayFD, dayCount: days)
    }

    /// Events on a specific fixed day (alias for UI code).
    static func eventsOnFixedDay(_ fd: Int64) -> [CalendarEvent] {
        return events(on: fd)
    }

    /// Events for a MetaSolar month (maps to Gregorian range).
    static func eventsForMonth(year: Int, month: Int, calendar: CalendarSystemID) -> [Int64: [CalendarEvent]] {
        // For MetaSolar: month is 1-13, each has 28 days starting from year start
        if calendar == .metaSolar {
            let yearStart = MetaSolarEngine.startOfYear(year)
            let monthStart = yearStart + Int64((month - 1) * 28)
            let monthEnd = monthStart + 28
            
            let gregStartYear = FixedDay.toGregorian(monthStart).year
            let gregEndYear = FixedDay.toGregorian(monthEnd).year
            let allEvents = generate(forGregorianYearRange: gregStartYear, through: gregEndYear)
            
            var result: [Int64: [CalendarEvent]] = [:]
            for event in allEvents where event.fixedDay >= monthStart && event.fixedDay < monthEnd {
                result[event.fixedDay, default: []].append(event)
            }
            return result
        }
        return [:]
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Gregorian events
    // --------------------------------------------------------------------------------------------

    private static func gregorianEvents(forGregorianYear year: Int) -> [CalendarEvent] {
        struct Def { let key: String; let name: String; let emoji: String;
                     let category: EventCategory; let month: Int; let day: Int; let desc: String }
        let defs: [Def] = [
            Def(key: "new_year", name: "New Year's Day", emoji: "🎆", category: .national,
                month: 1, day: 1, desc: "First day of the Gregorian calendar year."),
            Def(key: "labour_day", name: "Labour Day", emoji: "✊", category: .national,
                month: 5, day: 1, desc: "International Workers' Day; a public holiday in Indonesia."),
            Def(key: "vesak", name: "Vesak / Waisak", emoji: "🪷", category: .religious,
                month: 5, day: 0, desc: "Buddha's birthday (date set annually by lunar reckoning — placeholder)."),
            Def(key: "pancasila_day", name: "Pancasila Day", emoji: "🇮🇩", category: .national,
                month: 6, day: 1, desc: "Commemorates the birth of Indonesia's state ideology, Pancasila (1945)."),
            Def(key: "independence_day", name: "Indonesian Independence Day", emoji: "🇮🇩", category: .national,
                month: 8, day: 17, desc: "Proclamation of Indonesian independence (1945)."),
            Def(key: "christmas_eve", name: "Christmas Eve", emoji: "🕯️", category: .observance,
                month: 12, day: 24, desc: "The evening before Christmas Day."),
            Def(key: "christmas", name: "Christmas Day", emoji: "🎄", category: .religious,
                month: 12, day: 25, desc: "Christian celebration of the birth of Jesus Christ."),
            Def(key: "new_years_eve", name: "New Year's Eve", emoji: "🎇", category: .observance,
                month: 12, day: 31, desc: "The final day of the Gregorian calendar year.")
        ]

        var events: [CalendarEvent] = []
        for d in defs {
            // day == 0 flags an annually-variable date not resolvable arithmetically (e.g. Vesak);
            // skip — those are surfaced by their native calendar generators.
            guard d.day > 0 else { continue }
            let fd = FixedDay.fromGregorian(year: year, month: d.month, day: d.day)
            events.append(makeEvent(system: .gregorian, key: d.key, fixedDay: fd,
                                    name: d.name, emoji: d.emoji, category: d.category, desc: d.desc))
        }
        return events
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Islamic (Hijri) events
    // --------------------------------------------------------------------------------------------

    private static func islamicEvents(forGregorianYear year: Int) -> [CalendarEvent] {
        struct Def { let key: String; let name: String; let emoji: String;
                     let month: Int; let day: Int; let desc: String }
        let defs: [Def] = [
            Def(key: "islamic_new_year", name: "Islamic New Year (1 Muharram)", emoji: "🌙",
                month: 1, day: 1, desc: "Start of the Hijri year; commemorates the Hijra of 622 CE."),
            Def(key: "ashura", name: "Ashura (10 Muharram)", emoji: "🕌",
                month: 1, day: 10, desc: "Day of fasting; mourned by Shia Muslims for Imam Husayn."),
            Def(key: "isra_miraj", name: "Isra Mi'raj (27 Rajab)", emoji: "🌟",
                month: 7, day: 27, desc: "The Prophet's night journey and ascension to the heavens."),
            Def(key: "start_of_ramadan", name: "Start of Ramadan (1 Ramadan)", emoji: "🌙",
                month: 9, day: 1, desc: "First day of the month of fasting."),
            Def(key: "nuzul_quran", name: "Nuzul al-Qur'an (17 Ramadan)", emoji: "📖",
                month: 9, day: 17, desc: "Commemorates the first revelation of the Qur'an."),
            Def(key: "lailatul_qadr", name: "Lailatul Qadr (27 Ramadan, approx.)", emoji: "✨",
                month: 9, day: 27, desc: "Night of Power — believed to fall in the last ten nights of Ramadan."),
            Def(key: "eid_al_fitr", name: "Eid al-Fitr (1 Shawwal)", emoji: "🎉",
                month: 10, day: 1, desc: "Festival marking the end of Ramadan fasting."),
            Def(key: "eid_al_adha", name: "Eid al-Adha (10 Dhu al-Hijjah)", emoji: "🐑",
                month: 12, day: 10, desc: "Festival of Sacrifice, concluding the Hajj pilgrimage.")
        ]

        // A Gregorian year overlaps roughly two Hijri years. Enumerate both and keep those
        // whose fixed day lands inside the Gregorian year window.
        let jan1 = FixedDay.fromGregorian(year: year, month: 1, day: 1)
        let dec31 = FixedDay.fromGregorian(year: year, month: 12, day: 31)
        let hijriStart = HijriAdapter.hijriFromFixedDay(jan1).year
        let hijriEnd = HijriAdapter.hijriFromFixedDay(dec31).year

        var events: [CalendarEvent] = []
        for hy in hijriStart...hijriEnd {
            for d in defs {
                let fd = HijriAdapter.fixedDayFromHijri(year: hy, month: d.month, day: d.day)
                guard fd >= jan1, fd <= dec31 else { continue }
                let monthName = (1...12).contains(d.month) ? HijriAdapter.monthNames[d.month - 1] : "M\(d.month)"
                events.append(makeEvent(system: .hijri, key: d.key, fixedDay: fd,
                                        name: d.name, emoji: d.emoji, category: .religious,
                                        desc: "\(d.desc) (Tabular Hijri \(d.day) \(monthName) \(hy) AH)."))
            }
        }
        return events
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Chinese lunar events
    // --------------------------------------------------------------------------------------------

    private static func chineseEvents(forGregorianYear year: Int) -> [CalendarEvent] {
        struct Def { let key: String; let name: String; let emoji: String;
                     let lunarMonth: Int; let lunarDay: Int; let desc: String }
        let defs: [Def] = [
            Def(key: "chinese_new_year", name: "Chinese New Year (Spring Festival)", emoji: "🧧",
                lunarMonth: 1, lunarDay: 1, desc: "First day of the Chinese lunisolar year."),
            Def(key: "lantern_festival", name: "Lantern Festival", emoji: "🏮",
                lunarMonth: 1, lunarDay: 15, desc: "15th day of the first lunar month; ends the New Year festivities."),
            Def(key: "dragon_boat", name: "Dragon Boat Festival", emoji: "🐲",
                lunarMonth: 5, lunarDay: 5, desc: "Commemorates poet Qu Yuan; racing dragon boats and eating zongzi."),
            Def(key: "mid_autumn", name: "Mid-Autumn Festival", emoji: "🥮",
                lunarMonth: 8, lunarDay: 15, desc: "Harvest moon festival; sharing mooncakes under the full moon."),
            Def(key: "double_ninth", name: "Double Ninth Festival", emoji: "🍂",
                lunarMonth: 9, lunarDay: 9, desc: "Chongyang — a day to honour elders and climb mountains.")
        ]

        let lunarMap = chineseLunarMap(forGregorianYear: year)
        var events: [CalendarEvent] = []

        for d in defs {
            guard let fd = lunarMap[d.lunarMonth]?[d.lunarDay] else { continue }
            events.append(makeEvent(system: .chinese, key: d.key, fixedDay: fd,
                                    name: d.name, emoji: d.emoji, category: .cultural, desc: d.desc))
        }

        // Qingming is a solar term (~April 5) — resolve by the Foundation Chinese calendar's
        // solar-term alignment via a fixed Gregorian anchor, nudged by the equinox scan.
        if let qingming = nearestQingming(forGregorianYear: year) {
            events.append(makeEvent(system: .chinese, key: "qingming", fixedDay: qingming,
                                    name: "Qingming Festival", emoji: "🌿", category: .cultural,
                                    desc: "Tomb-sweeping day; falls on the 'Pure Brightness' solar term (~April 5).",
                                    dataOrigin: AstronomyProvenanceCatalog.solarTerms.dataOrigin,
                                    provenance: AstronomyProvenanceCatalog.solarTerms))
        }

        return events
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Javanese events (Sultan Agungan lunar months, parallel to Hijri)
    // --------------------------------------------------------------------------------------------

    private static func javaneseEvents(forGregorianYear year: Int) -> [CalendarEvent] {
        struct Def { let key: String; let name: String; let emoji: String;
                     let hijriMonth: Int; let hijriDay: Int; let offset: Int; let desc: String }
        // Offset is days before (+after) the referenced Hijri date; 0 = same day.
        let defs: [Def] = [
            Def(key: "satu_suro", name: "Satu Suro (Javanese New Year)", emoji: "🌑",
                hijriMonth: 1, hijriDay: 1, offset: 0,
                desc: "First day of Sura in the Javanese Sultan Agungan calendar; a solemn, reflective day."),
            Def(key: "sekaten_start", name: "Sekaten (begins)", emoji: "🥁",
                hijriMonth: 3, hijriDay: 12, offset: -5,
                desc: "Week-long court festival in Yogyakarta/Surakarta leading up to Maulid Nabi."),
            Def(key: "grebeg_maulud", name: "Grebeg Maulud", emoji: "🏛️",
                hijriMonth: 3, hijriDay: 12, offset: 0,
                desc: "Royal ceremony at the Keraton; mountains of food are given to the people on Maulid."),
            Def(key: "sekaten_peak", name: "Sekaten (peak / Maulid night)", emoji: "🎶",
                hijriMonth: 3, hijriDay: 12, offset: -1,
                desc: "Culminating night of Sekaten with gamelan at the Grand Mosque."),
            Def(key: "grebeg_puasa", name: "Grebeg Puasa (Eve of Eid)", emoji: "🍚",
                hijriMonth: 9, hijriDay: 30, offset: 0,
                desc: "Keraton Gunungan procession on the last day of Ramadan."),
            Def(key: "grebeg_besar", name: "Grebeg Besar (Eid al-Adha)", emoji: "🐏",
                hijriMonth: 12, hijriDay: 10, offset: 0,
                desc: "Keraton Gunungan ceremony marking Eid al-Adha.")
        ]

        let jan1 = FixedDay.fromGregorian(year: year, month: 1, day: 1)
        let dec31 = FixedDay.fromGregorian(year: year, month: 12, day: 31)
        let hijriStart = HijriAdapter.hijriFromFixedDay(jan1).year
        let hijriEnd = HijriAdapter.hijriFromFixedDay(dec31).year

        var events: [CalendarEvent] = []
        for hy in hijriStart...hijriEnd {
            for d in defs {
                let base = HijriAdapter.fixedDayFromHijri(year: hy, month: d.hijriMonth, day: d.hijriDay)
                let fd = base + Int64(d.offset)
                guard fd >= jan1, fd <= dec31 else { continue }
                events.append(makeEvent(system: .javanese, key: d.key, fixedDay: fd,
                                        name: d.name, emoji: d.emoji, category: .cultural, desc: d.desc))
            }
        }
        return events
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Seasonal events — solstices & equinoxes via solar longitude
    // --------------------------------------------------------------------------------------------

    private static func seasonalEvents(forGregorianYear year: Int) -> [CalendarEvent] {
        struct Def { let key: String; let name: String; let emoji: String;
                     let targetLongitude: Double; let desc: String }
        let defs: [Def] = [
            Def(key: "vernal_equinox", name: "Vernal (Spring) Equinox", emoji: "🌱",
                targetLongitude: 0, desc: "Day and night are nearly equal; the Sun crosses the celestial equator northward."),
            Def(key: "summer_solstice", name: "Summer Solstice", emoji: "☀️",
                targetLongitude: 90, desc: "Longest day of the year in the Northern Hemisphere."),
            Def(key: "autumnal_equinox", name: "Autumnal Equinox", emoji: "🍂",
                targetLongitude: 180, desc: "Day and night are nearly equal; the Sun crosses the celestial equator southward."),
            Def(key: "winter_solstice", name: "Winter Solstice", emoji: "❄️",
                targetLongitude: 270, desc: "Shortest day of the year in the Northern Hemisphere.")
        ]

        let longitudes = solarLongitudes(forGregorianYear: year)
        var events: [CalendarEvent] = []
        for d in defs {
            guard let fd = longitudeCrossing(longitudes: longitudes, target: d.targetLongitude) else { continue }
            events.append(makeEvent(system: .gregorian, key: d.key, fixedDay: fd,
                                    name: d.name, emoji: d.emoji, category: .seasonal, desc: d.desc,
                                    dataOrigin: AstronomyProvenanceCatalog.solsticesEquinoxes.dataOrigin,
                                    provenance: AstronomyProvenanceCatalog.solsticesEquinoxes))
        }
        return events
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Chinese lunar resolution helpers
    // --------------------------------------------------------------------------------------------

    /// Map of non-leap lunar (month → day → fixedDay) occurrences within a Gregorian year.
    /// Built by scanning every day of the Gregorian year through Foundation's Chinese calendar.
    private static func chineseLunarMap(forGregorianYear year: Int) -> [Int: [Int: Int64]] {
        var chineseCal = Calendar(identifier: .chinese)
        chineseCal.timeZone = gmt
        var gCal = Calendar(identifier: .gregorian)
        gCal.timeZone = gmt

        var map: [Int: [Int: Int64]] = [:]
        let jan1 = FixedDay.fromGregorian(year: year, month: 1, day: 1)
        var offset = 0
        while offset < 370 {
            let fd = jan1 + Int64(offset)
            let g = FixedDay.toGregorian(fd)
            if g.year != year { break }
            guard let date = gCal.date(from: DateComponents(year: g.year, month: g.month, day: g.day)) else {
                offset += 1; continue
            }
            let cc = chineseCal.dateComponents([.month, .day, .isLeapMonth], from: date)
            if let lm = cc.month, let ld = cc.day, !(cc.isLeapMonth ?? false) {
                if map[lm]?[ld] == nil {
                    map[lm, default: [:]][ld] = fd
                }
            }
            offset += 1
        }
        return map
    }

    /// Resolve Qingming (~April 5) to the nearest day whose solar longitude is closest to 15°
    /// (Pure Brightness solar term). Falls back to a fixed April 5 anchor.
    private static func nearestQingming(forGregorianYear year: Int) -> Int64? {
        // Window: late March through mid-April.
        let start = FixedDay.fromGregorian(year: year, month: 3, day: 25)
        let end = FixedDay.fromGregorian(year: year, month: 4, day: 12)
        var gCal = Calendar(identifier: .gregorian)
        gCal.timeZone = gmt

        var best: Int64? = nil
        var bestDelta = Double.infinity
        var fd = start
        while fd <= end {
            let g = FixedDay.toGregorian(fd)
            if let date = gCal.date(from: DateComponents(year: g.year, month: g.month, day: g.day, hour: 12)) {
                let jd = AstronomyEngine.julianDay(from: date)
                let lon = AstronomyEngine.solarLongitude(julianDay: jd)
                let delta = abs(forwardAngle(lon, 15.0))
                // Prefer the day where longitude has just crossed 15°.
                if delta < bestDelta { bestDelta = delta; best = fd }
            }
            fd += 1
        }
        return best ?? FixedDay.fromGregorian(year: year, month: 4, day: 5)
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Solar-longitude helpers (seasonal events)
    // --------------------------------------------------------------------------------------------

    /// Noon solar longitude for every day of a Gregorian year.
    private static func solarLongitudes(forGregorianYear year: Int) -> [(fixedDay: Int64, longitude: Double)] {
        var gCal = Calendar(identifier: .gregorian)
        gCal.timeZone = gmt
        var result: [(fixedDay: Int64, longitude: Double)] = []
        let jan1 = FixedDay.fromGregorian(year: year, month: 1, day: 1)
        var offset = 0
        while offset < 370 {
            let fd = jan1 + Int64(offset)
            let g = FixedDay.toGregorian(fd)
            if g.year != year { break }
            if let date = gCal.date(from: DateComponents(year: g.year, month: g.month, day: g.day, hour: 12)) {
                let jd = AstronomyEngine.julianDay(from: date)
                result.append((fd, AstronomyEngine.solarLongitude(julianDay: jd)))
            }
            offset += 1
        }
        return result
    }

    /// First day on which the solar longitude crosses `target` (moving in the direction of increase).
    private static func longitudeCrossing(longitudes: [(fixedDay: Int64, longitude: Double)],
                                          target: Double) -> Int64? {
        guard longitudes.count > 1 else { return nil }
        for i in 1..<longitudes.count {
            let prev = longitudes[i - 1].longitude
            let curr = longitudes[i].longitude
            let span = forwardAngle(prev, curr)            // ~0.986°/day, always positive
            let distToTarget = forwardAngle(prev, target)   // forward arc from prev to target
            if distToTarget >= 0 && distToTarget <= span {
                return longitudes[i].fixedDay
            }
        }
        return nil
    }

    /// Forward (clockwise) angular distance from `a` to `b`, result in [0, 360).
    private static func forwardAngle(_ a: Double, _ b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360.0)
        if d < 0 { d += 360 }
        return d
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Event builder
    // --------------------------------------------------------------------------------------------

    private static func makeEvent(system: CalendarSystemID, key: String, fixedDay: Int64,
                                  name: String, emoji: String, category: EventCategory,
                                  desc: String,
                                  dataOrigin: AstronomyDataOrigin? = nil,
                                  provenance: AstronomyProvenance? = nil) -> CalendarEvent {
        CalendarEvent(
            id: "\(system.rawValue).\(key).\(fixedDay)",
            name: name,
            emoji: emoji,
            category: category,
            calendarSystem: system,
            fixedDay: fixedDay,
            description: desc,
            dataOrigin: dataOrigin,
            provenance: provenance
        )
    }
}
