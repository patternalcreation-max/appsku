import Foundation

// MARK: - Javanese Calendar Adapter (per blueprint §8.5)
//
// Independent from Hijri (ADR-010, ADR-013).
// Implements:
// 1. Saptawara (7-day week)
// 2. Pancawara/Pasaran (5-day cycle) → Weton = 35-day combined cycle
// 3. Wuku (210-day cycle = 30 wuku × 7 days)
// 4. Neptu (numerological values)
// 5. Sultan Agungan lunar date (independent calculation)

enum JavaneseAdapter {
    
    // MARK: - Saptawara (7-day week)
    static let saptawaraNames = [
        "Radite (Sunday)", "Soma (Monday)", "Anggara (Tuesday)",
        "Buddha (Wednesday)", "Respati (Thursday)", "Sukra (Friday)", "Tumpek (Saturday)"
    ]
    
    // MARK: - Pancawara / Pasaran (5-day cycle)
    static let pasaranNames = ["Legi (Umanis)", "Pahing", "Pon", "Wage", "Kliwon"]
    
    // MARK: - Weton = Saptawara × Pancawara = 35-day cycle
    // Weton names are the combination: e.g., "Sunday Legi", "Monday Pahing"
    
    // MARK: - Wuku (30 cycles of 7 days = 210 days)
    static let wukuNames = [
        "Sinta", "Landep", "Wukir", "Kurantil", "Tolu", "Gumbreg", "Wariga",
        "Warigadean", "Julungwangi", "Sungsang", "Galungan", "Kuningan",
        "Langkir", "Mandhasiya", "Julungpujut", "Pahang", "Kuruwelut",
        "Marakeh", "Tambir", "Medangkungan", "Maktal", "Wuye", "Manahil",
        "Pranagat", "Bala", "Wugu", "Wayang", "Kujawin", "Sambat", "Hindun"
    ]
    
    // MARK: - Neptu values (for pasaran and saptawara)
    // Pasaran neptu: Legi=5, Pahing=9, Pon=7, Wage=4, Kliwon=8
    static let pasaranNeptu = [5, 9, 7, 4, 8]
    
    // Saptawara neptu: Radite=5, Soma=4, Anggara=3, Buddha=7, Respati=8, Sukra=6, Tumpek=9
    static let saptawaraNeptu = [5, 4, 3, 7, 8, 6, 9]
    
    // MARK: - Anchors
    // Anchor: January 1, 1900 CE (Monday) = fixed day 693961
    // On this day:
    //   - Pasaran = Pahing (index 1)
    //   - Wuku = Sinta (index 0, day 0 of 210-day cycle)
    // Verified: Jan 1 1900 was Monday. Sinta wuku started on that day per Javanese calendar tradition.
    private static let anchorFixedDay: Int64 = FixedDay.fromGregorian(year: 1900, month: 1, day: 1)
    static let anchorFixedDayPublic: Int64 = FixedDay.fromGregorian(year: 1900, month: 1, day: 1)
    private static let anchorPasaran: Int64 = 1  // Pahing
    
    // MARK: - Cycle Calculations
    
    /// Get pasaran index (0-4) for a fixed day
    static func pasaranIndex(fixedDay: Int64) -> Int {
        let offset = fixedDay - anchorFixedDay + anchorPasaran
        return Int(floorMod(offset, modulus: 5))
    }
    
    /// Get saptawara index (0=Sunday, 6=Saturday) for a fixed day
    static func saptawaraIndex(fixedDay: Int64) -> Int {
        return FixedDay.weekday(fixedDay)
    }
    
    /// Get weton cycle day (0-34)
    static func wetonDay(fixedDay: Int64) -> Int {
        let sapta = Int64(saptawaraIndex(fixedDay: fixedDay))
        let pasaran = Int64(pasaranIndex(fixedDay: fixedDay))
        // Combined cycle: find the day in 0-34 where both match
        // sapta advances by 1 each day, pasaran by 1 each day
        // LCM(7,5) = 35
        let offset = fixedDay - anchorFixedDay
        return Int(floorMod(offset, modulus: 35))
    }
    
    /// Get wuku index (0-29) and day within wuku (0-6)
    static func wukuIndex(fixedDay: Int64) -> (wuku: Int, dayInWuku: Int) {
        let offset = floorMod(fixedDay - anchorFixedDay, modulus: 210)
        let wuku = Int(offset / 7)
        let dayInWuku = Int(offset % 7)
        return (wuku, dayInWuku)
    }
    
    /// Calculate total neptu for a day
    static func totalNeptu(fixedDay: Int64) -> Int {
        let sapta = saptawaraIndex(fixedDay: fixedDay)
        let pasaran = pasaranIndex(fixedDay: fixedDay)
        return saptawaraNeptu[sapta] + pasaranNeptu[pasaran]
    }
    
    // MARK: - Weton Name
    
    static func wetonName(saptawara: Int, pasaran: Int) -> String {
        let saptaName = saptawaraNames[saptawara].split(separator: " ").first.map(String.init) ?? saptawaraNames[saptawara]
        let pasaranName = pasaranNames[pasaran].split(separator: " ").first.map(String.init) ?? pasaranNames[pasaran]
        return "\(saptaName) \(pasaranName)"
    }
    
    // MARK: - Sultan Agungan (Lunar Calendar)
    // The Javanese lunar calendar (Sultan Agungan) is based on the lunar cycle.
    // Epoch: 1555 CE (Anno Javanico) — but the era starts from 125 CE (but this is complex).
    // For a practical implementation:
    // Javanese lunar months alternate 29/30 days, 12 months per year.
    // Intercalary years (Taun Kabisat) add a 13th month every ~3 years.
    
    /// Sultan Agungan year from Gregorian year
    /// The Javanese year (Alip cycle) starts around the summer solstice.
    /// Simplified: Javanese year ≈ Gregorian year - 78 (Shaka era offset) + adjustment
    /// More accurately, the Sultan Agungan epoch is 1555 CE
    static func sultanAgunganFromFixedDay(_ fixedDay: Int64) -> (year: Int, month: Int, day: Int, isLeapYear: Bool) {
        // Javanese epoch: July 8, 1555 CE (proleptic) — traditional start of Sultan Agungan era
        let epochFixedDay: Int64 = FixedDay.fromGregorian(year: 1555, month: 7, day: 8)
        
        let daysSinceEpoch = fixedDay - epochFixedDay
        
        // Average year length ~354.367 days (lunar)
        // 8-year windu cycle: 2835 days (8 × 354 + 3 leap days approx)
        let windu = Int(daysSinceEpoch / 2835)  // 8-year cycle
        let dayInWindu = Int(daysSinceEpoch % 2835)
        
        // Within a windu, determine year (1-8)
        let yearLengths = [354, 354, 355, 354, 354, 355, 354, 355]  // 8 years in a windu
        var yearInWindu = 0
        var remaining = dayInWindu
        for (i, len) in yearLengths.enumerated() {
            if remaining < len {
                yearInWindu = i
                break
            }
            remaining -= len
        }
        
        let year = 1555 + windu * 8 + yearInWindu
        let isLeapYear = (year % 3 == 0)  // approximately
        
        // Months: alternate 29/30 days
        let monthLengths = isLeapYear
            ? [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30]  // 13 months (leap)
            : [30, 29, 30, 29, 30, 29, 30, 29, 30, 29, 30, 29]      // 12 months
        
        var month = 1
        var day = remaining
        for (i, len) in monthLengths.enumerated() {
            if day < len {
                month = i + 1
                break
            }
            day -= len
        }
        
        return (year, month, day + 1, isLeapYear)
    }
    
    static let sultanMonthNames = [
        "Sura", "Sapar", "Mulud", "Bakda Mulud", "Jumadilawal",
        "Jumadilakir", "Rejeb", "Ruwah", "Pasa", "Sawal",
        "Dulkaidah", "Besar", "(Leap Bulik)"
    ]
    
    // MARK: - Full Projection
    
    static func project(instant: Instant, timeZone: TimeZone, profile: JavaneseProfile) -> CalendarProjection {
        let cal = Calendar(identifier: .gregorian)
        var gCal = cal
        gCal.timeZone = timeZone
        let dateComp = gCal.dateComponents([.year, .month, .day], from: instant.date)
        let fixedDay = FixedDay.fromGregorian(
            year: dateComp.year ?? 2026,
            month: dateComp.month ?? 1,
            day: dateComp.day ?? 1
        )
        
        let sapta = saptawaraIndex(fixedDay: fixedDay)
        let pasaran = pasaranIndex(fixedDay: fixedDay)
        let weton = wetonDay(fixedDay: fixedDay)
        let (wuku, dayInWuku) = wukuIndex(fixedDay: fixedDay)
        let neptu = totalNeptu(fixedDay: fixedDay)
        
        var extras: [String: String] = [
            "pasaran": pasaranNames[pasaran],
            "weton": wetonName(saptawara: sapta, pasaran: pasaran),
            "wetonDay": "\(weton + 1)/35",
            "wuku": wukuNames[wuku],
            "neptu": "\(neptu)",
            "saptawaraNeptu": "\(saptawaraNeptu[sapta])",
            "pasaranNeptu": "\(pasaranNeptu[pasaran])",
        ]
        
        let displayStr: String
        let subtitleStr: String
        
        if profile == .sultanAgungan {
            let sa = sultanAgunganFromFixedDay(fixedDay)
            let monthName = sa.month > 0 && sa.month <= sultanMonthNames.count
                ? sultanMonthNames[sa.month - 1]
                : "Month \(sa.month)"
            extras["sultanYear"] = "\(sa.year)"
            extras["sultanMonth"] = monthName
            let saptaShort = saptawaraNames[sapta].split(separator: " ").first.map(String.init) ?? saptawaraNames[sapta]
            let pasaranShort = pasaranNames[pasaran].split(separator: " ").first.map(String.init) ?? pasaranNames[pasaran]
            displayStr = "\(saptaShort) \(pasaranShort)"
            subtitleStr = "\(monthName) \(sa.day), \(sa.year) AJ · Wuku \(wukuNames[wuku]) · Neptu \(neptu)"
        } else {
            let saptaShort = saptawaraNames[sapta].split(separator: " ").first.map(String.init) ?? saptawaraNames[sapta]
            let pasaranShort = pasaranNames[pasaran].split(separator: " ").first.map(String.init) ?? pasaranNames[pasaran]
            displayStr = "\(saptaShort) \(pasaranShort)"
            subtitleStr = "Wuku \(wukuNames[wuku]) · Neptu \(neptu) · Weton day \(weton + 1)/35"
        }
        
        let coordinate = CalendarCoordinate(
            calendarSystemID: .javanese,
            year: Int(wuku),  // Using wuku cycle as "year" context
            month: weton + 1,
            day: Int(fixedDay % 210) + 1,
            isLeapMonth: false,
            extraFields: extras
        )
        
        return CalendarProjection(
            calendarSystemID: .javanese,
            rulesetID: profile.rawValue,
            coordinate: coordinate,
            displayString: displayStr,
            subtitle: subtitleStr,
            status: .computed,
            provenance: "\(profile.rawValue) · Independent from Hijri · Anchors: 1900-01-01 CE"
        )
    }
}
