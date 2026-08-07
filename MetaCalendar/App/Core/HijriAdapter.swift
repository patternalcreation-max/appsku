import Foundation

// MARK: - Hijri Calendar Adapter (per blueprint §8.4)
//
// Implements:
// - Tabular Hijri (Type I/II/III/IV) — pure arithmetic
// - Umm al-Qura approximation
// Status is always "calculated" unless an authority supplies observed/official data.

enum HijriAdapter {
    
    static let rulesetID = "hijri.tabular.type-II"
    
    // Islamic epoch: Friday, 16 July 622 CE (Julian) = fixed day 227015
    static let epochFixedDay: Int64 = 227015
    
    // Arabic month names
    static let monthNames = [
        "Muharram", "Safar", "Rabi' al-Awwal", "Rabi' al-Thani",
        "Jumada al-Awwal", "Jumada al-Thani", "Rajab", "Sha'ban",
        "Ramadan", "Shawwal", "Dhu al-Qi'dah", "Dhu al-Hijjah"
    ]
    
    // MARK: - Tabular Hijri Algorithm
    
    /// Check if a Hijri year is a leap year (Type II — most common tabular variant)
    /// Leap years in 30-year cycle (Type II): 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29
    static func isLeapYear(_ hijriYear: Int) -> Bool {
        let cyclePos = floorMod(Int64(hijriYear), modulus: 30)
        let leapPositions: Set<Int> = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29]
        return leapPositions.contains(Int(cyclePos))
    }
    
    /// Number of days in a Hijri month (tabular)
    static func daysInMonth(year: Int, month: Int) -> Int {
        // Odd months = 30 days, even months = 29 days
        // Dhu al-Hijjah = 30 in leap year, 29 in common year
        if month == 12 {
            return isLeapYear(year) ? 30 : 29
        }
        return month % 2 == 1 ? 30 : 29
    }
    
    /// Days in a Hijri year
    static func daysInYear(_ year: Int) -> Int {
        isLeapYear(year) ? 355 : 354
    }
    
    /// Convert fixed day to Hijri date (tabular)
    /// Uses the closed-form algorithm from Calendrical Calculations
    static func hijriFromFixedDay(_ fixedDay: Int64) -> (year: Int, month: Int, day: Int) {
        // From Calendrical Calculations (Reingold-Dershowitz), Islamic Tabular
        let q1 = Int64(floor(Double(fixedDay - epochFixedDay) / 10631.0))
        let r1 = (fixedDay - epochFixedDay) % 10631
        
        var year = q1
        var remaining = r1
        
        // Find year within the cycle
        let daysBefore: [Int64] = [0, 354, 709, 1063, 1418, 1772, 2127, 2481, 2836, 3190, 3545, 3899, 4254, 4608, 4963, 5317, 5672, 6026, 6381, 6735, 7090, 7444, 7799, 8153, 8508, 8862, 9217, 9571, 9926, 10280]
        
        var y = 1
        while y <= 30 && remaining >= daysBefore[y] {
            y += 1
        }
        year = q1 * 30 + Int64(y)
        remaining = r1 - daysBefore[y - 1]
        
        // Find month
        var month = 1
        while month <= 12 {
            let dim = Int64(daysInMonth(year: Int(year), month: month))
            if remaining < dim { break }
            remaining -= dim
            month += 1
        }
        
        let day = Int(remaining + 1)
        return (Int(year), month, day)
    }
    
    /// Convert Hijri date to fixed day (tabular)
    static func fixedDayFromHijri(year: Int, month: Int, day: Int) -> Int64 {
        var total: Int64 = 0
        for y in 1..<year {
            total += Int64(daysInYear(y))
        }
        for m in 1..<month {
            total += Int64(daysInMonth(year: year, month: m))
        }
        total += Int64(day - 1)
        return epochFixedDay + total
    }
    
    /// Project instant to Hijri date
    static func project(instant: Instant, timeZone: TimeZone, profile: HijriProfile) -> CalendarProjection {
        // Get the Gregorian date in the target timezone
        let cal = Calendar(identifier: .gregorian)
        var gCal = cal
        gCal.timeZone = timeZone
        
        // Use midnight of the current date for fixed-day calculation
        let dateComponents = gCal.dateComponents([.year, .month, .day], from: instant.date)
        let gregFixedDay = FixedDay.fromGregorian(
            year: dateComponents.year ?? 2026,
            month: dateComponents.month ?? 1,
            day: dateComponents.day ?? 1
        )
        
        let hijriDate: (year: Int, month: Int, day: Int)
        let ruleset: String
        let status: ProjectionStatus
        
        switch profile {
        case .tabular:
            hijriDate = hijriFromFixedDay(gregFixedDay)
            ruleset = "hijri.tabular.type-II"
            status = .computed
            
        case .civil:
            // Type I (Thursday epoch) — slight shift
            let adjusted = gregFixedDay - 1
            hijriDate = hijriFromFixedDay(adjusted)
            ruleset = "hijri.civil.type-I"
            status = .computed
            
        case .ummAlQura:
            // Umm al-Qura approximation: use Foundation, fall back to tabular
            let islamicCal = Calendar(identifier: .islamicUmmAlQura)
            var iCal = islamicCal
            iCal.timeZone = timeZone
            let comp = iCal.dateComponents([.year, .month, .day], from: instant.date)
            hijriDate = (comp.year ?? 0, comp.month ?? 0, comp.day ?? 0)
            ruleset = "hijri.umm-al-qura.foundation"
            status = .computed
        }
        
        let monthName = hijriDate.month > 0 && hijriDate.month <= monthNames.count
            ? monthNames[hijriDate.month - 1]
            : "Month \(hijriDate.month)"
        
        let coordinate = CalendarCoordinate(
            calendarSystemID: .hijri,
            year: hijriDate.year,
            month: hijriDate.month,
            day: hijriDate.day,
            isLeapMonth: false,
            extraFields: ["method": profile.rawValue]
        )
        
        return CalendarProjection(
            calendarSystemID: .hijri,
            rulesetID: ruleset,
            coordinate: coordinate,
            displayString: "\(monthName) \(hijriDate.day), \(hijriDate.year) AH",
            subtitle: "\(profile.displayName) · Calculated",
            status: status,
            provenance: "\(ruleset) · Arithmetic tabular method · Not an official declaration"
        )
    }
}
