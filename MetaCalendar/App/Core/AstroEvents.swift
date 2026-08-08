import Foundation

// MARK: - Comprehensive Astronomical Events Database
// Sources: NASA Eclipse Catalog (Five Millennium Canon), IMO meteor calendar,
//          ESA/NASA mission archives, historical astronomy records.
// All dates are UTC. fixedDay computed via CC4 Rata Die.

enum AstroEvents {

    // MARK: - Public

    /// All astronomical events for a given Gregorian year (recurring + tabulated + historical).
    static func generate(forGregorianYear year: Int) -> [CalendarEvent] {
        var events: [CalendarEvent] = []
        events.append(contentsOf: meteorShowers(forGregorianYear: year))
        events.append(contentsOf: solsticesEquinoxes(forGregorianYear: year))
        events.append(contentsOf: tabulatedEclipses(forGregorianYear: year))
        events.append(contentsOf: historicalAnniversaries(forGregorianYear: year))
        events.append(contentsOf: cometApparitions(forGregorianYear: year))
        events.append(contentsOf: supermoons(forGregorianYear: year))
        return events.sorted { $0.fixedDay < $1.fixedDay }
    }

    /// Events within N days of today.
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
        all.append(contentsOf: generate(forGregorianYear: now + 2))
        let ceiling = todayFD + Int64(days)
        return all.filter { $0.fixedDay >= todayFD && $0.fixedDay <= ceiling }
            .sorted { $0.fixedDay < $1.fixedDay }
    }

    /// Past events (for timeline history view).
    static func past(days: Int) -> [CalendarEvent] {
        let cal = Calendar(identifier: .gregorian)
        let todayFD = FixedDay.fromGregorian(
            year: cal.component(.year, from: Date()),
            month: cal.component(.month, from: Date()),
            day: cal.component(.day, from: Date())
        )
        let now = cal.component(.year, from: Date())
        var all = generate(forGregorianYear: now)
        all.append(contentsOf: generate(forGregorianYear: now - 1))
        let floor = todayFD - Int64(days)
        return all.filter { $0.fixedDay >= floor && $0.fixedDay < todayFD }
            .sorted { $0.fixedDay < $1.fixedDay }
    }

    // MARK: - Meteor Showers (annual, IMO calendar)

    private static func meteorShowers(forGregorianYear year: Int) -> [CalendarEvent] {
        // (month, peakDay, name, radiant, parent body, ZHR range, hemisphere)
        let showers: [(Int, Int, String, String, String, String, String)] = [
            (1, 3, "Quadrantids", "Boötes", "Asteroid 2003 EH1", "60-200", "N"),
            (4, 22, "Lyrids", "Lyra", "Komet C/1861 G1 Thatcher", "10-18", "Both"),
            (5, 5, "Eta Aquariids", "Aquarius", "Komet Halley (1P/Halley)", "30-50", "S"),
            (7, 30, "Delta Aquariids", "Aquarius", "Komet Marsden-Kracht", "15-20", "S"),
            (8, 12, "Perseids", "Perseus", "Komet Swift-Tuttle (109P)", "80-100", "N"),
            (10, 8, "Draconids", "Draco", "Komet Giacobini-Zinner (21P)", "Variable", "N"),
            (10, 21, "Orionids", "Orion", "Komet Halley (1P/Halley)", "10-20", "Both"),
            (11, 17, "Leonids", "Leo", "Komet Tempel-Tuttle (55P)", "10-15", "Both"),
            (11, 28, "Andromedids", "Andromeda", "Komet Biela (3D/Biela)", "Variable", "Both"),
            (12, 14, "Geminids", "Gemini", "Asteroid 3200 Phaethon", "120-160", "Both"),
            (12, 22, "Ursids", "Ursa Minor", "Komet Tuttle (8P/Tuttle)", "5-10", "N"),
        ]

        return showers.map { item in
            let fd = FixedDay.fromGregorian(year: year, month: item.0, day: item.1)
            return CalendarEvent(
                id: "astro.meteor.\(item.2).\(year)",
                name: "Hujan Meteor \(item.2)",
                emoji: "☄️",
                category: .astronomical,
                calendarSystem: .gregorian,
                fixedDay: fd,
                description: "Radiante: \(item.3) · Induk: \(item.4) · ZHR: \(item.5) · Belahan: \(item.6)",
                dataOrigin: AstronomyProvenanceCatalog.meteorShowers.dataOrigin,
                provenance: AstronomyProvenanceCatalog.meteorShowers
            )
        }
    }

    // MARK: - Solstices & Equinoxes (computed via solar longitude)

    private static func solsticesEquinoxes(forGregorianYear year: Int) -> [CalendarEvent] {
        // Approximate dates (within ±1 day of true astronomical event)
        let events: [(Int, Int, String, String)] = [
            (3, 20, "Equinox Maret", " Matahari di ekuator, awal musim semi (UTara) / musim gugur (Uselatan)"),
            (6, 21, "Solstis Juni", "Hari terpanjang di belahan utara, awal musim panas"),
            (9, 22, "Equinox September", "Matahari kembali ke ekuator, awal musim gugur (U) / musim semi (S)"),
            (12, 21, "Solstis Desember", "Hari terpendek di belahan utara, awal musim dingin"),
        ]

        return events.map { item in
            let fd = FixedDay.fromGregorian(year: year, month: item.0, day: item.1)
            return CalendarEvent(
                id: "astro.season.\(item.2).\(year)",
                name: item.2,
                emoji: "🌍",
                category: .astronomical,
                calendarSystem: .gregorian,
                fixedDay: fd,
                description: item.3,
                dataOrigin: AstronomyProvenanceCatalog.solsticesEquinoxes.dataOrigin,
                provenance: AstronomyProvenanceCatalog.solsticesEquinoxes
            )
        }
    }

    // MARK: - Tabulated Eclipses (NASA Five Millennium Canon, 2020–2035)

    private static func tabulatedEclipses(forGregorianYear year: Int) -> [CalendarEvent] {
        // Source: NASA GSFC Eclipse Web Site (eclipse.gsfc.nasa.gov)
        // Format: (year, month, day, type, subType, visibility, magnitude/note)
        let eclipses: [(Int, Int, Int, String, String, String)] = [
            // 2020
            (2020, 1, 10, "Penumbral Lunar", "Penumbral", "Eropa, Afrika, Asia, Australia"),
            (2020, 6, 5, "Penumbral Lunar", "Penumbral", "Eropa, Afrika, Asia, Australia"),
            (2020, 6, 21, "Annular Solar", "Annular", "Afrika, SE Asia, Pasifik"),
            (2020, 7, 5, "Penumbral Lunar", "Penumbral", "Amerika, Afrika barat"),
            (2020, 11, 30, "Penumbral Lunar", "Penumbral", "Asia, Australia, Pasifik, Amerika"),
            (2020, 12, 14, "Total Solar", "Total", "Amerika Selatan, totalitas di Chili & Argentina"),
            // 2021
            (2021, 5, 26, "Total Lunar", "Total", "Asia Timur, Australia, Pasifik, Amerika"),
            (2021, 6, 10, "Annular Solar", "Annular", "Kanada, Greenland, Rusia"),
            (2021, 11, 19, "Partial Lunar", "Partial (97%)", "Amerika, Australia, Asia Timur"),
            (2021, 12, 4, "Total Solar", "Total", "Antartika"),
            // 2022
            (2022, 4, 30, "Partial Solar", "Partial", "SE Pasifik, Amerika Selatan"),
            (2022, 5, 16, "Total Lunar", "Total", "Amerika, Eropa, Afrika"),
            (2022, 10, 25, "Partial Solar", "Partial", "Eropa, Timur Tengah, Asia"),
            (2022, 11, 8, "Total Lunar", "Total", "Asia, Australia, Pasifik, Amerika"),
            // 2023
            (2023, 4, 20, "Hybrid Solar", "Hybrid", "Indonesia, Australia, Papua Nugini"),
            (2023, 5, 5, "Penumbral Lunar", "Penumbral", "Afrika, Asia, Australia"),
            (2023, 10, 14, "Annular Solar", "Annular", "AS, Meksiko, Amerika Tengah, Brasil"),
            (2023, 10, 28, "Partial Lunar", "Partial", "Eropa, Asia, Australia, Afrika"),
            // 2024
            (2024, 3, 25, "Penumbral Lunar", "Penumbral", "Amerika"),
            (2024, 4, 8, "Total Solar", "Total", "Meksiko, AS, Kanada — Great American Eclipse"),
            (2024, 9, 18, "Partial Lunar", "Partial", "Amerika, Eropa, Afrika"),
            (2024, 10, 2, "Annular Solar", "Annular", "Pasifik, Amerika Selatan"),
            // 2025
            (2025, 3, 14, "Total Lunar", "Total", "Pasifik, Amerika, Eropa barat"),
            (2025, 3, 29, "Partial Solar", "Partial", "Eropa, Afrika utara, AS utara"),
            (2025, 9, 7, "Total Lunar", "Total", "Eropa, Afrika, Asia, Australia"),
            (2025, 9, 21, "Partial Solar", "Partial", "Pasifik selatan, Antartika"),
            // 2026
            (2026, 2, 17, "Annular Solar", "Annular", "Antartika"),
            (2026, 3, 3, "Total Lunar", "Total", "Asia timur, Australia, Amerika"),
            (2026, 8, 12, "Total Solar", "Total", "Greenland, Islandia, Spanyol"),
            (2026, 8, 28, "Partial Lunar", "Partial", "Afrika, Eropa, Asia"),
            // 2027
            (2027, 2, 6, "Annular Solar", "Annular", "Amerika Selatan, Atlantik, Afrika"),
            (2027, 2, 20, "Penumbral Lunar", "Penumbral", "Americas, Eropa, Afrika"),
            (2027, 7, 18, "Penumbral Lunar", "Penumbral", "Pasifik, Australia, Asia timur"),
            (2027, 8, 2, "Total Solar", "Total", "Spanyol, Afrika utara, Mesir — terpanjang abad 21 (6m23s)"),
            (2027, 8, 17, "Penumbral Lunar", "Penumbral", "Eropa, Afrika, Asia"),
            // 2028
            (2028, 1, 26, "Annular Solar", "Annular", "Amerika Selatan, Atlantik, Eropa"),
            (2028, 1, 12, "Partial Lunar", "Partial", "Amerika, Eropa, Afrika"),
            (2028, 7, 6, "Partial Solar", "Partial", "Australia, Selandia Baru"),
            (2028, 7, 22, "Total Solar", "Total", "Australia, Selandia Baru"),
            (2028, 12, 31, "Total Lunar", "Total", "Eropa, Afrika, Asia, Australia"),
            // 2029
            (2029, 1, 14, "Partial Solar", "Partial", "Amerika Utara, Pasifik"),
            (2029, 6, 12, "Partial Solar", "Partial", "Arktik, Skandinavia, Siberia"),
            (2029, 6, 26, "Total Lunar", "Total", "Amerika, Eropa barat, Afrika"),
            (2029, 7, 11, "Partial Solar", "Partial", "Pasifik selatan"),
            (2029, 12, 5, "Partial Solar", "Partial", "Antartika"),
            (2029, 12, 20, "Total Lunar", "Total", "Eropa, Afrika, Asia, Australia"),
            // 2030
            (2030, 6, 1, "Annular Solar", "Annular", "Aljazair, Tunisia, Yunani, Rusia, Kanada"),
            (2030, 6, 15, "Partial Lunar", "Partial", "Asia timur, Australia"),
            (2030, 6, 26, "Total Lunar", "Total", "Pasifik, Australia, Asia timur"),
            (2030, 11, 25, "Total Solar", "Total", "Afrika selatan, Australia"),
            (2030, 12, 9, "Penumbral Lunar", "Penumbral", "Amerika, Eropa, Afrika"),
            // 2031
            (2031, 5, 21, "Annular Solar", "Annular", "Australia, Papua Nugini, Pasifik"),
            (2031, 6, 5, "Partial Lunar", "Partial", "Amerika, Eropa, Afrika"),
            (2031, 10, 30, "Annular Solar", "Annular", "Pasifik, Amerika Selatan"),
            (2031, 11, 14, "Partial Lunar", "Partial", "Asia, Australia, Pasifik, Amerika"),
            // 2032
            (2032, 4, 30, "Total Solar", "Total", "Amerika Selatan, Atlantik, Afrika"),
            (2032, 5, 15, "Partial Lunar", "Partial", "Eropa, Afrika, Asia"),
            (2032, 10, 25, "Annular Solar", "Annular", "Asia, Pasifik"),
            (2032, 11, 8, "Partial Lunar", "Partial", "Eropa, Afrika, Asia"),
            // 2033
            (2033, 3, 30, "Total Solar", "Total", "Siberia, Arktik"),
            (2033, 4, 14, "Partial Lunar", "Partial", "Eropa, Afrika, Asia"),
            (2033, 9, 24, "Partial Lunar", "Partial", "Amerika, Eropa, Afrika"),
            (2033, 10, 14, "Annular Solar", "Annular", "Amerika Selatan, Atlantik"),
            // 2034
            (2034, 3, 20, "Total Solar", "Total", "Afrika, Arab, India, Asia Tenggara"),
            (2034, 4, 3, "Partial Lunar", "Partial", "Eropa, Afrika, Asia"),
            (2034, 9, 12, "Total Lunar", "Total", "Amerika, Eropa, Afrika"),
            (2034, 9, 28, "Annular Solar", "Annular", "Amerika Selatan, Atlantik, Afrika"),
            // 2035
            (2035, 2, 5, "Partial Solar", "Partial", "Antartika, Selandia Baru"),
            (2035, 2, 21, "Penumbral Lunar", "Penumbral", "Eropa, Afrika, Asia"),
            (2035, 7, 22, "Total Solar", "Total", "Cina, Korea, Jepang"),
            (2035, 8, 6, "Penumbral Lunar", "Penumbral", "Eropa, Afrika, Asia, Australia"),
        ]

        return eclipses.compactMap { e in
            guard e.0 == year else { return nil }
            let fd = FixedDay.fromGregorian(year: e.0, month: e.1, day: e.2)
            return CalendarEvent(
                id: "astro.eclipse.\(e.3).\(e.0).\(e.1).\(e.2)",
                name: e.3,
                emoji: eclipseEmoji(e.3),
                category: .astronomical,
                calendarSystem: .gregorian,
                fixedDay: fd,
                description: "Tipe: \(e.4) · Terlihat: \(e.5)",
                dataOrigin: AstronomyProvenanceCatalog.tabulatedEclipses.dataOrigin,
                provenance: AstronomyProvenanceCatalog.tabulatedEclipses
            )
        }
    }

    private static func eclipseEmoji(_ type: String) -> String {
        if type.contains("Total") && type.contains("Solar") { return "🌑" }
        if type.contains("Annular") { return "🌗" }
        if type.contains("Lunar") { return "🌕" }
        if type.contains("Hybrid") { return "🌘" }
        if type.contains("Penumbral") { return "🌖" }
        return "🌑"
    }

    // MARK: - Historical Astronomy Anniversaries

    private static func historicalAnniversaries(forGregorianYear year: Int) -> [CalendarEvent] {
        // (month, day, event, year-of-event, emoji, description)
        let history: [(Int, Int, String, Int, String, String)] = [
            // Space milestones
            (4, 12, "Hari Kosmonautika — Yuri Gagarin", 1961, "🚀", "Manusia pertama di luar angkasa, Vostok 1"),
            (5, 5, "Alan Shepard — Mercury 3", 1961, "🚀", "Orang Amerika pertama di luar angkasa"),
            (5, 25, "JFK Moon Speech", 1961, "🌙", "Kennedy berjanji mendarat di Bulan sebelum 1970"),
            (7, 20, "Apollo 11 — Pendaratan Bulan", 1969, "🌙", "Armstrong & Aldrin mendarat di Bulan, 'satu langkah kecil...'"),
            (7, 29, "NASA Didirikan", 1958, "🛰️", "Badan antariksa AS dibentuk"),
            (10, 4, "Sputnik 1 — Satelit Pertama", 1957, "🛰️", "Satelit buatan pertama, memulai Era Antariksa"),
            (10, 10, "Laika — Makhluk Hidup Pertama di Orbit", 1957, "🐕", "Anjing Soviet di Sputnik 2"),
            (11, 3, "Sputnik 2 — Laika", 1957, "🐕", "Makhluk hidup pertama mengorbit Bumi"),
            (12, 21, "Apollo 8 — Mengorbit Bulan", 1968, "🌙", "Manusia pertama meninggalkan orbit Bumi"),
            (1, 27, "Apollo 1 — Tragedi", 1967, "🕯️", "Kebakaran kapsul, Grissom, White, Chaffee gugur"),
            (1, 28, "Challenger — Tragedi", 1986, "🕯️", "Pesawat ulang-alig meledak 73 detik setelah peluncuran"),
            (2, 1, "Columbia — Tragedi", 2003, "🕯️", "Pesawat hancur saat masuk kembali, 7 astronot gugur"),
            (4, 24, "Hubble — Peluncuran", 1990, "🔭", "Teleskop antariksa Hubble diluncurkan"),
            (12, 25, "James Webb — Peluncuran", 2021, "🔭", "Teleskop JWST diluncurkan, penerus Hubble"),
            // Astronomy discoveries
            (1, 7, "Penemuan Galilean Moons", 1610, "🪐", "Galileo menemukan 4 bulan Yupiter: Io, Europa, Ganymede, Callisto"),
            (3, 13, "Penemuan Uranus", 1781, "🪐", "William Herschel menemukan planet Uranus"),
            (9, 23, "Penemuan Neptunus", 1846, "🪐", "Galle menemukan Neptunus berdasarkan prediksi Le Verrier"),
            (2, 18, "Penemuan Pluto", 1930, "🪐", "Clyde Tombaugh menemukan Pluto"),
            (2, 24, "Penemuan Supernova 1987A", 1987, "💥", "Supernova terdekat sejak 1604, di Awan Magellan Besar"),
            (10, 9, "Penemuan Ring Planet Saturn", 1655, "🪐", "Huygens menerangkan cincin Saturnus"),
            // Comets
            (3, 14, "Flyby Halley 1986", 1986, "☄️", "Sonde Giotto terbang dekat Komet Halley"),
            // Transits
            (6, 5, "Transit Venus 2012", 2012, "☀️", "Transit Venus terakhir abad ini"),
        ]

        return history.compactMap { item in
            let anniversaryYear = year - item.3
            guard anniversaryYear > 0 else { return nil }
            let fd = FixedDay.fromGregorian(year: year, month: item.0, day: item.1)
            return CalendarEvent(
                id: "astro.history.\(item.2).\(year)",
                name: "\(item.2) (\(anniversaryYear) tahun)",
                emoji: item.4,
                category: .astronomical,
                calendarSystem: .gregorian,
                fixedDay: fd,
                description: "\(item.5) · Peringatan ke-\(anniversaryYear) tahun (\(item.3))",
                dataOrigin: AstronomyProvenanceCatalog.historicalAnniversaries.dataOrigin,
                provenance: AstronomyProvenanceCatalog.historicalAnniversaries
            )
        }
    }

    // MARK: - Comet Apparitions

    private static func cometApparitions(forGregorianYear year: Int) -> [CalendarEvent] {
        // Known periodic comet perihelions
        let comets: [(year: Int, month: Int, day: Int, name: String, desc: String)] = [
            (2061, 7, 28, "Komet Halley Kembali", "Perihelion berikutnya Komet Halley (1P/Halley)"),
            (2134, 12, 16, "Komet Halley Berikutnya", "Perihelion setelah 2061"),
        ]

        return comets.compactMap { c in
            guard c.year == year else { return nil }
            let fd = FixedDay.fromGregorian(year: c.year, month: c.month, day: c.day)
            return CalendarEvent(
                id: "astro.comet.\(c.name).\(c.year)",
                name: c.name,
                emoji: "☄️",
                category: .astronomical,
                calendarSystem: .gregorian,
                fixedDay: fd,
                description: c.desc,
                dataOrigin: AstronomyProvenanceCatalog.cometApparitions.dataOrigin,
                provenance: AstronomyProvenanceCatalog.cometApparitions
            )
        }
    }

    // MARK: - Supermoons (approximate, based on perigee distance)

    private static func supermoons(forGregorianYear year: Int) -> [CalendarEvent] {
        // Known supermoon dates (full moon near perigee)
        let known: [(year: Int, month: Int, day: Int, note: String)] = [
            (2025, 10, 7, "Superbulan Pemburu"),
            (2025, 11, 5, "Superbulan Berang-berang"),
            (2025, 12, 4, "Superbulan Dingin"),
            (2026, 9, 26, "Superbulan Jagung"),
            (2026, 10, 26, "Superbulan Pemburu"),
            (2026, 11, 24, "Superbulan Berang-berang"),
            (2027, 10, 15, "Superbulan Pemburu"),
            (2027, 11, 14, "Superbulan Berang-berang"),
            (2028, 10, 4, "Superbulan Pemburu"),
            (2028, 11, 3, "Superbulan Berang-berang"),
        ]

        return known.compactMap { sm in
            guard sm.year == year else { return nil }
            let fd = FixedDay.fromGregorian(year: sm.year, month: sm.month, day: sm.day)
            return CalendarEvent(
                id: "astro.supermoon.\(sm.note).\(sm.year)",
                name: sm.note,
                emoji: "🌕",
                category: .astronomical,
                calendarSystem: .gregorian,
                fixedDay: fd,
                description: "Bulan purnama terdekat dengan perigee — tampak lebih besar dan terang",
                dataOrigin: AstronomyProvenanceCatalog.supermoons.dataOrigin,
                provenance: AstronomyProvenanceCatalog.supermoons
            )
        }
    }
}
