import Foundation

// MARK: - MetaSolar-13 Calendar Engine (per blueprint §8.2)
//
// Thirteen 28-day months + Year Bridge (+ Leap Bridge in leap years).
// Common year = 365 days, Leap year = 366 days.
// Bridge days advance all uninterrupted cycles (ADR-009).
// Development profile: metasolar13.g400.dev-v1 (97/400 leap pattern)

/// MetaSolar day coordinate — never represented as month 13 day 29/30
enum MetaSolarDayCoordinate: Codable, Sendable, Equatable, Hashable {
    case monthDay(year: Int, month: Int, day: Int)  // month 1...13, day 1...28
    case yearBridge(year: Int)
    case leapBridge(year: Int)
}

/// MetaSolar profile configuration
struct MetaSolarProfile: Codable, Sendable, Equatable {
    let id: String
    let epochFixedDay: Int64
    let epochYear: Int
    let monthNames: [String]
    let status: ProjectionStatus
}

/// MetaSolar-13 Engine — pure arithmetic calendar
enum MetaSolarEngine {
    
    // Development profile epoch: Jan 1, 2000 CE = fixed day 730120
    // (FixedDay.fromGregorian(year: 2000, month: 1, day: 1))
    static let devEpochFixedDay: Int64 = FixedDay.fromGregorian(year: 2000, month: 1, day: 1)
    static let devEpochYear: Int = 2000
    
    // User-friendly month names: each aligns ~1:1 with a Gregorian month
    // Month 1 starts Jan 1, each month = 28 days, so month N ≈ Gregorian month N
    // Names use a dual format: "Prima (Jan)" so users always know where they are
    static let monthNames = [
        "Prima (Jan)",      // 1  ≈ January
        "Secunda (Feb)",    // 2  ≈ February (starts ~Jan 29)
        "Tertia (Mar)",     // 3  ≈ February/March
        "Quarta (Apr)",     // 4  ≈ March/April
        "Quinta (May)",     // 5  ≈ April/May
        "Sexta (Jun)",      // 6  ≈ May/Jun
        "Septima (Jul)",    // 7  ≈ June/July
        "Octava (Aug)",     // 8  ≈ July/August
        "Nona (Sep)",       // 9  ≈ August/September
        "Decima (Oct)",     // 10 ≈ September/October
        "Undecima (Nov)",   // 11 ≈ October/November
        "Duodecima (Dec)",  // 12 ≈ November/December
        "Finale (Year-End)" // 13 ≈ December (last 28 days)
    ]
    
    static let profile = MetaSolarProfile(
        id: "metasolar13.g400.dev-v1",
        epochFixedDay: devEpochFixedDay,
        epochYear: devEpochYear,
        monthNames: monthNames,
        status: .experimental
    )
    
    // MARK: - Current Date Helpers
    
    /// Current MetaSolar year
    static func currentYear() -> Int {
        let cal = Calendar(identifier: .gregorian)
        let todayFD = FixedDay.fromGregorian(
            year: cal.component(.year, from: Date()),
            month: cal.component(.month, from: Date()),
            day: cal.component(.day, from: Date())
        )
        let coord = coordinate(forFixedDay: todayFD)
        switch coord {
        case .monthDay(let y, _, _): return y
        case .yearBridge(let y): return y
        case .leapBridge(let y): return y
        }
    }
    
    /// Current MetaSolar month (1-13)
    static func currentMonth() -> Int {
        let cal = Calendar(identifier: .gregorian)
        let todayFD = FixedDay.fromGregorian(
            year: cal.component(.year, from: Date()),
            month: cal.component(.month, from: Date()),
            day: cal.component(.day, from: Date())
        )
        let coord = coordinate(forFixedDay: todayFD)
        switch coord {
        case .monthDay(_, let m, _): return m
        case .yearBridge: return 13  // bridge after month 13
        case .leapBridge: return 13
        }
    }
    
    // MARK: - Leap Year (97/400 arithmetic pattern — Gregorian-compatible)
    
    static func isLeapYear(_ year: Int) -> Bool {
        let y = year - devEpochYear + 2000  // align with Gregorian
        return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)
    }
    
    /// Number of leap years from epochYear to (but not including) given year
    static func leapDaysBefore(year: Int) -> Int64 {
        let start = devEpochYear
        guard year > start else { return 0 }
        var count: Int64 = 0
        for y in start..<year {
            if isLeapYear(y) { count += 1 }
        }
        return count
    }
    
    /// Fixed day of the start of a MetaSolar year
    static func startOfYear(_ year: Int) -> Int64 {
        let yearsElapsed = Int64(year - devEpochYear)
        return devEpochFixedDay + yearsElapsed * 365 + leapDaysBefore(year: year)
    }
    
    /// Total days in a MetaSolar year
    static func daysInYear(_ year: Int) -> Int {
        isLeapYear(year) ? 366 : 365
    }
    
    // MARK: - Forward Projection: Fixed Day → MetaSolar Coordinate
    
    static func coordinate(forFixedDay fixedDay: Int64) -> MetaSolarDayCoordinate {
        let year = findYear(forFixedDay: fixedDay)
        let yearStart = startOfYear(year)
        let dayOfYear = fixedDay - yearStart  // 0-based
        
        if dayOfYear < 364 {
            let month = Int(dayOfYear / 28) + 1   // 1...13
            let day = Int(dayOfYear % 28) + 1     // 1...28
            return .monthDay(year: year, month: month, day: day)
        } else if dayOfYear == 364 {
            return .yearBridge(year: year)
        } else {
            // dayOfYear == 365 → leap bridge
            return .leapBridge(year: year)
        }
    }
    
    /// Binary search for the year containing this fixed day
    private static func findYear(forFixedDay fixedDay: Int64) -> Int {
        // Arithmetic estimate
        let approx = Int((fixedDay - devEpochFixedDay) / 365) + devEpochYear
        var year = max(devEpochYear, approx - 1)
        
        // Move forward to find the right year
        while startOfYear(year + 1) <= fixedDay {
            year += 1
        }
        while startOfYear(year) > fixedDay {
            year -= 1
        }
        return year
    }
    
    // MARK: - Reverse Resolution: MetaSolar Coordinate → Fixed Day
    
    static func fixedDay(for coordinate: MetaSolarDayCoordinate) -> Int64? {
        switch coordinate {
        case .monthDay(let year, let month, let day):
            guard month >= 1 && month <= 13, day >= 1 && day <= 28 else { return nil }
            let dayOfYear = Int64((month - 1) * 28 + (day - 1))
            return startOfYear(year) + dayOfYear
            
        case .yearBridge(let year):
            return startOfYear(year) + 364
            
        case .leapBridge(let year):
            guard isLeapYear(year) else { return nil }
            return startOfYear(year) + 365
        }
    }
    
    // MARK: - Display
    
    static func displayString(for coordinate: MetaSolarDayCoordinate) -> String {
        switch coordinate {
        case .monthDay(let year, let month, let day):
            let name = month <= monthNames.count ? monthNames[month - 1] : "M\(month)"
            return "\(name) \(day), \(year)"
        case .yearBridge(let year):
            return "Year Bridge, \(year)"
        case .leapBridge(let year):
            return "Leap Bridge, \(year)"
        }
    }
    
    static func subtitle(for coordinate: MetaSolarDayCoordinate) -> String {
        switch coordinate {
        case .monthDay(_, let month, _):
            return "Month \(month) of 13 · Day \(month * 4)% of year"
        case .yearBridge:
            return "Intercalary day · Common to all years"
        case .leapBridge:
            return "Intercalary day · Leap years only"
        }
    }
    
    /// Get all MetaSolar dates for a month for calendar grid
    static func monthGrid(year: Int, month: Int) -> [MetaSolarDayCoordinate?] {
        guard month >= 1 && month <= 13 else { return [] }
        var days: [MetaSolarDayCoordinate?] = []
        // 28 days = exactly 4 weeks, 7 columns
        for day in 1...28 {
            days.append(.monthDay(year: year, month: month, day: day))
        }
        // Pad to complete weeks (should already be complete: 28 = 4×7)
        return days
    }
    
    /// Year Bridge + Leap Bridge positions
    static func bridgeDays(year: Int) -> [MetaSolarDayCoordinate] {
        var bridges: [MetaSolarDayCoordinate] = [.yearBridge(year: year)]
        if isLeapYear(year) {
            bridges.append(.leapBridge(year: year))
        }
        return bridges
    }
}
