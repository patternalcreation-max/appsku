import Foundation

// MARK: - World Events (Astronomical / Observances / Sport)
//
// Companion generator to `CalendarEvents` that surfaces world/astronomical/sport
// happenings — solar & lunar eclipses, major meteor showers, global observances,
// and major one-off sporting events (Olympics, World Cup).
//
// All events resolve to a `fixedDay` (Rata Die), so they project into every
// calendar system via the existing adapters.
//
// Coverage model:
//  - Recurring annual events (meteor showers, observances) are generated per
//    Gregorian year.
//  - Eclipses and major sporting events are tabulated for known upcoming dates.
//  - Floating observances (Mother's Day, Father's Day) are resolved via weekday
//    arithmetic ("2nd Sunday of May", "3rd Sunday of June").

enum WorldEvents {

    /// GMT timezone for all internal resolution (ADR-007: no OS-global reads).
    private static let gmt: TimeZone = TimeZone(secondsFromGMT: 0) ?? .current

    // --------------------------------------------------------------------------------------------
    // MARK: Public entry points
    // --------------------------------------------------------------------------------------------

    /// All world/astronomical/sport events that fall within the given Gregorian year,
    /// sorted chronologically by `fixedDay`.
    static func generate(forGregorianYear year: Int) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        events.append(contentsOf: meteorShowers(forGregorianYear: year))
        events.append(contentsOf: annualObservances(forGregorianYear: year))
        events.append(contentsOf: eclipses(forGregorianYear: year))
        events.append(contentsOf: sportingEvents(forGregorianYear: year))
        return events.sorted { $0.fixedDay < $1.fixedDay }
    }

    /// World events within `dayCount` days after (and including) today.
    static func upcoming(days dayCount: Int) -> [CalendarEvent] {
        let cal = Calendar(identifier: .gregorian)
        let todayFD = FixedDay.fromGregorian(
            year:  cal.component(.year,  from: Date()),
            month: cal.component(.month, from: Date()),
            day:   cal.component(.day,   from: Date())
        )
        return upcoming(from: todayFD, days: dayCount)
    }

    /// World events within `dayCount` days after (and including) `anchorFixedDay`.
    static func upcoming(from anchorFixedDay: Int64, days dayCount: Int) -> [CalendarEvent] {
        let (y, _, _) = FixedDay.toGregorian(anchorFixedDay)
        let window = generate(forGregorianYearRange: y, through: y + 1)
        let ceiling = anchorFixedDay + Int64(dayCount)
        return window.filter { $0.fixedDay >= anchorFixedDay && $0.fixedDay <= ceiling }
                     .sorted { $0.fixedDay < $1.fixedDay }
    }

    /// Notable world events from a given fixed day onward (next 365 days).
    /// Curated to surface only eclipses, major showers, and tentpole sport events.
    static func notable(from anchorFixedDay: Int64) -> [CalendarEvent] {
        let (y, _, _) = FixedDay.toGregorian(anchorFixedDay)
        let window = generate(forGregorianYearRange: y, through: y + 1)
        return window.filter { $0.fixedDay >= anchorFixedDay }
                     .filter { $0.category == .astronomical || $0.category == .sport }
                     .sorted { $0.fixedDay < $1.fixedDay }
    }

    /// World events across an inclusive Gregorian year range.
    static func generate(forGregorianYearRange startYear: Int, through endYear: Int) -> [CalendarEvent] {
        let years = Swift.min(startYear, endYear)...Swift.max(startYear, endYear)
        return years.flatMap { generate(forGregorianYear: $0) }.sorted { $0.fixedDay < $1.fixedDay }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Annual meteor showers
    // --------------------------------------------------------------------------------------------

    /// Major annual meteor showers, keyed by their approximate Gregorian peak date.
    /// Peak times shift by ~1 day year to year; the entries use canonical peak dates.
    private static func meteorShowers(forGregorianYear year: Int) -> [CalendarEvent] {
        struct Def { let key: String; let name: String; let emoji: String;
                     let month: Int; let day: Int; let desc: String }
        let defs: [Def] = [
            Def(key: "quadrantids", name: "Quadrantids Peak", emoji: "☄️",
                month: 1, day: 3,
                desc: "Early-January meteor shower; radiant in northern Boötes. Sharp peak, up to 60–100/hr."),
            Def(key: "lyrids", name: "Lyrids Peak", emoji: "☄️",
                month: 4, day: 22,
                desc: "April meteor shower from Comet Thatcher; radiant near Vega. ~15–18/hr."),
            Def(key: "eta_aquariids", name: "Eta Aquariids Peak", emoji: "☄️",
                month: 5, day: 5,
                desc: "Southern-friendly shower from Comet Halley's debris. ~40–50/hr in the tropics."),
            Def(key: "perseids", name: "Perseids Peak", emoji: "☄️",
                month: 8, day: 12,
                desc: "August's famous shower from Comet Swift–Tuttle; radiant in Perseus. Up to ~100/hr."),
            Def(key: "orionids", name: "Orionids Peak", emoji: "☄️",
                month: 10, day: 21,
                desc: "October shower from Comet Halley; radiant near Orion. ~20/hr."),
            Def(key: "leonids", name: "Leonids Peak", emoji: "☄️",
                month: 11, day: 17,
                desc: "November shower from Comet Tempel–Tuttle; radiant in Leo. ~15/hr, storms ~33-yr cycle."),
            Def(key: "geminids", name: "Geminids Peak", emoji: "☄️",
                month: 12, day: 14,
                desc: "December's strongest shower from asteroid 3200 Phaethon; radiant in Gemini. Up to ~120/hr.")
        ]

        return defs.map { d in
            let fd = FixedDay.fromGregorian(year: year, month: d.month, day: d.day)
            return makeEvent(key: d.key, fixedDay: fd,
                             name: d.name, emoji: d.emoji,
                             category: .astronomical, desc: d.desc,
                             dataOrigin: AstronomyProvenanceCatalog.meteorShowers.dataOrigin,
                             provenance: AstronomyProvenanceCatalog.meteorShowers)
        }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Annual global observances
    // --------------------------------------------------------------------------------------------

    private static func annualObservances(forGregorianYear year: Int) -> [CalendarEvent] {
        struct Def { let key: String; let name: String; let emoji: String;
                     let category: EventCategory; let month: Int; let day: Int; let desc: String }
        let defs: [Def] = [
            // Fixed-date observances.
            Def(key: "valentines", name: "Valentine's Day", emoji: "💘",
                category: .observance, month: 2, day: 14,
                desc: "Traditional day of love and affection, celebrated in many countries."),
            Def(key: "april_fools", name: "April Fools' Day", emoji: "🤡",
                category: .observance, month: 4, day: 1,
                desc: "Day of pranks and hoaxes, observed across the world."),
            Def(key: "earth_day", name: "Earth Day", emoji: "🌍",
                category: .observance, month: 4, day: 22,
                desc: "Global day of environmental action and awareness, first held in 1970."),
            Def(key: "labour_global", name: "International Workers' Day", emoji: "✊",
                category: .observance, month: 5, day: 1,
                desc: "May Day; international labour and workers' solidarity observance."),
            Def(key: "world_env_day", name: "World Environment Day", emoji: "🌱",
                category: .observance, month: 6, day: 5,
                desc: "United Nations day for encouraging worldwide environmental awareness."),
            Def(key: "intl_youth", name: "International Youth Day", emoji: "🧑‍🤝‍🧑",
                category: .observance, month: 8, day: 12,
                desc: "UN observance drawing attention to youth issues worldwide."),
            Def(key: "un_day", name: "United Nations Day", emoji: "🕊️",
                category: .observance, month: 10, day: 24,
                desc: "Commemorates the 1945 entry into force of the UN Charter."),
            Def(key: "halloween", name: "Halloween", emoji: "🎃",
                category: .observance, month: 10, day: 31,
                desc: "Eve of All Hallows' Day; costumes, trick-or-treat, jack-o'-lanterns."),
            Def(key: "human_rights", name: "Human Rights Day", emoji: "⚖️",
                category: .observance, month: 12, day: 10,
                desc: "Anniversary of the 1948 Universal Declaration of Human Rights."),
            Def(key: "womens_day", name: "International Women's Day", emoji: "♀️",
                category: .observance, month: 3, day: 8,
                desc: "Global day celebrating women's achievements and advocating for gender equality."),
            Def(key: "new_years_eve_global", name: "New Year's Eve", emoji: "🎇",
                category: .observance, month: 12, day: 31,
                desc: "Final day of the Gregorian calendar year; celebrated with fireworks worldwide.")
        ]

        var events: [CalendarEvent] = defs.map { d in
            let fd = FixedDay.fromGregorian(year: year, month: d.month, day: d.day)
            return makeEvent(key: d.key, fixedDay: fd,
                             name: d.name, emoji: d.emoji,
                             category: d.category, desc: d.desc)
        }

        // Floating observances.
        if let mothers = nthWeekday(year: year, month: 5, weekday: 1, occurrence: 2) {
            events.append(makeEvent(key: "mothers_day", fixedDay: mothers,
                                    name: "Mother's Day", emoji: "💐",
                                    category: .observance,
                                    desc: "2nd Sunday of May; honoring mothers (US and many countries)."))
        }
        if let fathers = nthWeekday(year: year, month: 6, weekday: 1, occurrence: 3) {
            events.append(makeEvent(key: "fathers_day", fixedDay: fathers,
                                    name: "Father's Day", emoji: "👨‍👧‍👦",
                                    category: .observance,
                                    desc: "3rd Sunday of June; honoring fathers (US and many countries)."))
        }
        return events
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Eclipses (tabulated, known upcoming)
    // --------------------------------------------------------------------------------------------

    /// Known upcoming solar & lunar eclipses through 2030, sourced from NASA's
    /// eclipse canon. Only the calendar-day peak is captured; times and visibility
    /// regions are noted in the description.
    private static func eclipses(forGregorianYear year: Int) -> [CalendarEvent] {
        struct Def { let key: String; let name: String; let emoji: String;
                     let year: Int; let month: Int; let day: Int; let desc: String }
        let defs: [Def] = [
            // ---- 2025 ----
            Def(key: "lunar_2025_03", name: "Total Lunar Eclipse", emoji: "🌕",
                year: 2025, month: 3, day: 14,
                desc: "Total lunar eclipse — 'Blood Worm Moon'. Visible in the Americas, W. Europe, W. Africa."),
            Def(key: "solar_2025_03", name: "Partial Solar Eclipse", emoji: "🌑",
                year: 2025, month: 3, day: 29,
                desc: "Partial solar eclipse. Visible in Europe, northern Asia, NW Africa, N. Atlantic."),
            Def(key: "lunar_2025_09", name: "Total Lunar Eclipse", emoji: "🌕",
                year: 2025, month: 9, day: 7,
                desc: "Total lunar eclipse. Visible in Europe, Africa, Asia, Australia."),
            Def(key: "solar_2025_09", name: "Partial Solar Eclipse", emoji: "🌑",
                year: 2025, month: 9, day: 21,
                desc: "Partial solar eclipse. Visible in southern New Zealand, Antarctica."),

            // ---- 2026 ----
            Def(key: "lunar_2026_03", name: "Total Lunar Eclipse", emoji: "🌕",
                year: 2026, month: 3, day: 3,
                desc: "Total lunar eclipse. Visible in E. Asia, Australia, Pacific, Americas."),
            Def(key: "solar_2026_08", name: "Total Solar Eclipse", emoji: "🌑",
                year: 2026, month: 8, day: 12,
                desc: "Total solar eclipse across Greenland, Iceland, and northern Spain. Path of totality ~2m18s."),
            Def(key: "lunar_2026_08", name: "Partial Lunar Eclipse", emoji: "🌝",
                year: 2026, month: 8, day: 28,
                desc: "Partial lunar eclipse. Visible over the Americas, Europe, and Africa."),
            Def(key: "solar_2026_02", name: "Annular Solar Eclipse", emoji: "🌑",
                year: 2026, month: 2, day: 17,
                desc: "Annular solar eclipse. Visible in Antarctica."),

            // ---- 2027 ----
            Def(key: "solar_2027_02", name: "Annular Solar Eclipse", emoji: "🌑",
                year: 2027, month: 2, day: 6,
                desc: "Annular solar eclipse across Chile, Argentina, Atlantic. 'Ring of fire' ~7m51s."),
            Def(key: "solar_2027_08", name: "Total Solar Eclipse", emoji: "🌑",
                year: 2027, month: 8, day: 2,
                desc: "Total solar eclipse — longest of the 21st century (~6m23s). Path crosses Spain, N. Africa, the Horn of Africa."),
            Def(key: "lunar_2027_08", name: "Partial Lunar Eclipse", emoji: "🌝",
                year: 2027, month: 8, day: 17,
                desc: "Partial lunar eclipse. Visible in S. America, Europe, Africa, Asia, Australia."),
            Def(key: "solar_2027_08_a", name: "Partial Solar Eclipse", emoji: "🌑",
                year: 2027, month: 8, day: 17,
                desc: "Minor partial solar eclipse. Visible in the Pacific and Antarctica."),

            // ---- 2028 ----
            Def(key: "solar_2028_01", name: "Annular Solar Eclipse", emoji: "🌑",
                year: 2028, month: 1, day: 26,
                desc: "Annular solar eclipse across Ecuador, Peru, Brazil, Suriname, the Atlantic, Spain, Portugal."),
            Def(key: "lunar_2028_07", name: "Partial Lunar Eclipse", emoji: "🌝",
                year: 2028, month: 7, day: 6,
                desc: "Partial lunar eclipse. Visible in eastern Africa, Asia, Australia."),
            Def(key: "solar_2028_07", name: "Total Solar Eclipse", emoji: "🌑",
                year: 2028, month: 7, day: 22,
                desc: "Total solar eclipse across central Australia, Sydney, New Zealand. Totality ~5m10s."),

            // ---- 2029 ----
            Def(key: "solar_2029_06", name: "Total Solar Eclipse", emoji: "🌑",
                year: 2029, month: 6, day: 12,
                desc: "Total solar eclipse across Mexico, the central US, southeastern Canada — the 'Great North American' return."),
            Def(key: "lunar_2029_12", name: "Total Lunar Eclipse", emoji: "🌕",
                year: 2029, month: 12, day: 9,
                desc: "Total lunar eclipse. Visible in the Americas, Europe, Africa, Asia.")
        ]

        return defs
            .filter { $0.year == year }
            .map { d in
                let fd = FixedDay.fromGregorian(year: d.year, month: d.month, day: d.day)
                return makeEvent(key: d.key, fixedDay: fd,
                                 name: d.name, emoji: d.emoji,
                                 category: .astronomical, desc: d.desc,
                                 dataOrigin: AstronomyProvenanceCatalog.tabulatedEclipses.dataOrigin,
                                 provenance: AstronomyProvenanceCatalog.tabulatedEclipses)
            }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Major one-off sporting events (tabulated)
    // --------------------------------------------------------------------------------------------

    /// Major global sporting events (Olympics, FIFA World Cup) keyed to their known dates.
    private static func sportingEvents(forGregorianYear year: Int) -> [CalendarEvent] {
        struct Def { let key: String; let name: String; let emoji: String;
                     let startYear: Int; let startMonth: Int; let startDay: Int;
                     let endYear: Int; let endMonth: Int; let endDay: Int; let desc: String }
        let defs: [Def] = [
            // FIFA World Cup 2026 (USA / Canada / Mexico).
            Def(key: "wc2026_opening", name: "FIFA World Cup 2026 — Opening Match", emoji: "⚽",
                startYear: 2026, startMonth: 6, startDay: 11,
                endYear: 2026, endMonth: 7, endDay: 19,
                desc: "First match of the 48-team World Cup, co-hosted by the USA, Canada, and Mexico."),
            Def(key: "wc2026_final", name: "FIFA World Cup 2026 — Final", emoji: "🏆",
                startYear: 2026, startMonth: 7, startDay: 19,
                endYear: 2026, endMonth: 7, endDay: 19,
                desc: "Final of the 2026 FIFA World Cup, held at MetLife Stadium, New Jersey."),

            // Summer Olympics 2028 — Los Angeles (Jul 14–30, 2028 per LA28 plan).
            Def(key: "olympics2028_opening", name: "Los Angeles 2028 Olympics — Opening", emoji: "🥇",
                startYear: 2028, startMonth: 7, startDay: 14,
                endYear: 2028, endMonth: 7, endDay: 14,
                desc: "Opening ceremony of the Games of the XXXIV Olympiad, Los Angeles, USA."),
            Def(key: "olympics2028_closing", name: "Los Angeles 2028 Olympics — Closing", emoji: "🥇",
                startYear: 2028, startMonth: 7, startDay: 30,
                endYear: 2028, endMonth: 7, endDay: 30,
                desc: "Closing ceremony of the LA28 Summer Olympic Games.")
        ]

        // Each Def emits one event pinned to its start date. End-date info lives in the description.
        return defs
            .filter { $0.startYear == year }
            .map { d in
                let fd = FixedDay.fromGregorian(year: d.startYear, month: d.startMonth, day: d.startDay)
                return makeEvent(key: d.key, fixedDay: fd,
                                 name: d.name, emoji: d.emoji,
                                 category: .sport, desc: d.desc)
            }
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Weekday arithmetic — "Nth weekday of month"
    // --------------------------------------------------------------------------------------------

    /// Resolve the fixed day of the `occurrence`-th `weekday` (0=Sunday…6=Saturday)
    /// of a given Gregorian `month`/`year`. Returns nil if the day does not exist.
    ///
    /// Example: `nthWeekday(year: 2026, month: 5, weekday: 1, occurrence: 2)`
    /// → 2nd Sunday of May 2026 = Mother's Day.
    private static func nthWeekday(year: Int, month: Int, weekday: Int, occurrence: Int) -> Int64? {
        guard occurrence >= 1 else { return nil }
        let firstOfMonth = FixedDay.fromGregorian(year: year, month: month, day: 1)
        let firstWeekday = FixedDay.weekday(firstOfMonth)            // 0 = Sunday … 6 = Saturday
        // Forward distance from the 1st to the first matching weekday.
        let delta = ((weekday - firstWeekday + 7) % 7) + 7 * (occurrence - 1)
        let resolvedFD = firstOfMonth + Int64(delta)
        // Sanity check: the resolved date must still be in the same year/month.
        let (ry, rm, _) = FixedDay.toGregorian(resolvedFD)
        guard ry == year, rm == month else { return nil }
        return resolvedFD
    }

    // --------------------------------------------------------------------------------------------
    // MARK: Event builder
    // --------------------------------------------------------------------------------------------

    /// Build a `CalendarEvent` tagged with the `world` namespace and Gregorian system,
    /// matching the identifier convention used by `CalendarEvents.makeEvent`.
    private static func makeEvent(key: String, fixedDay: Int64,
                                  name: String, emoji: String,
                                  category: EventCategory, desc: String,
                                  dataOrigin: AstronomyDataOrigin? = nil,
                                  provenance: AstronomyProvenance? = nil) -> CalendarEvent {
        CalendarEvent(
            id: "world.\(key).\(fixedDay)",
            name: name,
            emoji: emoji,
            category: category,
            calendarSystem: .gregorian,
            fixedDay: fixedDay,
            description: desc,
            dataOrigin: dataOrigin,
            provenance: provenance
        )
    }
}
