import Foundation

// MARK: - Fundamental Types (per blueprint §7.1)

/// Physical moment — canonical computational anchor (ADR-001)
struct Instant: Codable, Sendable, Comparable, Hashable {
    let date: Date
    
    init(_ date: Date = Date()) { self.date = date }
    
    static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.date < rhs.date }
    static func == (lhs: Instant, rhs: Instant) -> Bool { lhs.date == rhs.date }
}

/// Half-open interval [start, end)
struct InstantInterval: Codable, Sendable, Equatable, Hashable {
    let start: Instant
    let end: Instant
}

struct GeoPoint: Codable, Sendable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    let elevationMeters: Double?
    let horizontalAccuracyMeters: Double?
}

/// Explicit calculation context — never reads OS globals (ADR-007)
struct CalculationContext: Codable, Sendable, Equatable {
    let instant: Instant
    let timeZoneIdentifier: String
    let location: GeoPoint?
    let localeIdentifier: String
    let rulesetSelection: RulesetSelection
}

struct RulesetSelection: Codable, Sendable, Equatable {
    var hijriProfile: HijriProfile
    var javaneseProfile: JavaneseProfile
    var displayOrder: [CalendarSystemID]
}

// MARK: - Calendar System IDs

enum CalendarSystemID: String, Codable, Sendable, CaseIterable, Identifiable {
    case metaSolar = "metasolar13"
    case gregorian = "gregorian"
    case chinese = "chinese"
    case hijri = "hijri"
    case javanese = "javanese"
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .metaSolar: return "MetaSolar-13"
        case .gregorian: return "Gregorian"
        case .chinese: return "Chinese"
        case .hijri: return "Hijri"
        case .javanese: return "Javanese"
        }
    }
    
    var iconName: String {
        switch self {
        case .metaSolar: return "sun.max.fill"
        case .gregorian: return "calendar"
        case .chinese: return "moon.stars.fill"
        case .hijri: return "moon.fill"
        case .javanese: return "circle.grid.cross.fill"
        }
    }
}

// MARK: - Calendar Coordinate

/// A calendar-specific date coordinate
struct CalendarCoordinate: Codable, Sendable, Equatable, Hashable {
    let calendarSystemID: CalendarSystemID
    let year: Int
    let month: Int
    let day: Int
    let isLeapMonth: Bool
    let extraFields: [String: String]  // cycle info, era, etc.
}

// MARK: - Calendar Projection (per blueprint §7.4)

enum ProjectionStatus: String, Codable, Sendable {
    case computed
    case predicted
    case observed
    case officiallyDeclared
    case historicalReconstruction
    case experimental
}

struct CalendarProjection: Codable, Sendable, Equatable, Hashable, Identifiable {
    let id: UUID
    let calendarSystemID: CalendarSystemID
    let rulesetID: String
    let coordinate: CalendarCoordinate
    let displayString: String
    let subtitle: String
    let status: ProjectionStatus
    let provenance: String
    let warnings: [String]
    
    init(calendarSystemID: CalendarSystemID, rulesetID: String, coordinate: CalendarCoordinate,
         displayString: String, subtitle: String, status: ProjectionStatus,
         provenance: String, warnings: [String] = []) {
        self.id = UUID()
        self.calendarSystemID = calendarSystemID
        self.rulesetID = rulesetID
        self.coordinate = coordinate
        self.displayString = displayString
        self.subtitle = subtitle
        self.status = status
        self.provenance = provenance
        self.warnings = warnings
    }
}

// MARK: - Profiles

enum HijriProfile: String, Codable, Sendable, CaseIterable, Identifiable {
    case tabular = "hijri.tabular"
    case civil = "hijri.civil"
    case ummAlQura = "hijri.umm-al-qura"
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .tabular: return "Tabular (Type II)"
        case .civil: return "Civil (Type I)"
        case .ummAlQura: return "Umm al-Qura (approx)"
        }
    }
}

enum JavaneseProfile: String, Codable, Sendable, CaseIterable, Identifiable {
    case cycles = "javanese.cycles"
    case sultanAgungan = "javanese.sultan-agungan"
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cycles: return "Cycles (Dino, Wuku, Neptu)"
        case .sultanAgungan: return "Sultan Agungan (Lunar)"
        }
    }
}

// MARK: - Timezone Modes (per blueprint §3.2)

enum TimeZoneMode: Codable, Sendable, Equatable, Hashable {
    case followSystem
    case locked(identifier: String)
    
    var displayName: String {
        switch self {
        case .followSystem: return "Follow System"
        case .locked(let id): return "Locked: \(id)"
        }
    }
}

// MARK: - Day Count Helper

/// Fixed day number (ordinal day count) — the backbone of all calendar conversions.
/// Uses RD (Rata Die / Fixed Day) system: Jan 1, 1 CE (Gregorian proleptic) = RD 1.
/// Algorithm from "Calendrical Calculations" by Reingold & Dershowitz (CC4).
enum FixedDay {
    /// Algorithm version. Bumped when the conversion formula changes.
    /// v1.0: Original CC4 adaptation (had 367-day offset bug)
    /// v2.0: Fixed with explicit cumulative-days lookup table
    static let methodVersion = "2.0"

    
    /// Convert Gregorian date to fixed day number (Rata Die).
    /// RD 1 = Jan 1, 1 CE (Gregorian proleptic).
    /// Uses cumulative-days-before-month lookup + standard leap-day formula.
    static func fromGregorian(year: Int, month: Int, day: Int) -> Int64 {
        let y = Int64(year)
        let m = Int64(month)
        let d = Int64(day)
        
        // Cumulative days before start of each month (non-leap year)
        // Jan=0, Feb=31, Mar=59, ..., Dec=334
        let priorDays: [Int64] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        
        // Leap year adjustment: add 1 if past Feb in a leap year
        let isLeap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)
        let leapAdjust: Int64 = (m > 2 && isLeap) ? 1 : 0
        
        // Days before this year
        let prevY = y - 1
        let yearDays = 365 * prevY + prevY / 4 - prevY / 100 + prevY / 400
        
        // Total RD = days-before-year + days-before-month + day-of-month
        return yearDays + priorDays[Int(m - 1)] + leapAdjust + d
    }
    
    /// Convert fixed day number to Gregorian date.
    /// Inverse of fromGregorian.
    static func toGregorian(_ fixedDay: Int64) -> (year: Int, month: Int, day: Int) {
        // Compute year using 400-year cycle
        let d0 = fixedDay - 1  // zero-based from RD 1
        
        var n400 = d0 / 146097
        var d1 = d0 % 146097
        var n100 = d1 / 36524
        if n100 == 4 { n100 = 3 }
        var d2 = d1 - n100 * 36524
        var n4 = d2 / 1461
        if n4 == 4 { n4 = 3 }
        let d3 = d2 - n4 * 1461
        var n1 = d3 / 365
        if n1 == 4 { n1 = 3 }
        
        let year = 400 * n400 + 100 * n100 + 4 * n4 + n1 + 1
        
        // Day of year (0-based)
        let yearStart = 365 * (year - 1) + (year - 1) / 4 - (year - 1) / 100 + (year - 1) / 400
        let dayOfYear = fixedDay - yearStart - 1  // 0-based
        
        // Find month using cumulative days
        let priorDays: [Int64] = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        let leapDays: [Int64] = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]
        let isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
        let days = isLeap ? leapDays : priorDays
        
        var month: Int = 12
        for m in stride(from: 11, through: 0, by: -1) {
            if dayOfYear >= days[m] {
                month = m + 1
                break
            }
        }
        
        let day = Int(dayOfYear - days[month - 1]) + 1
        
        return (Int(year), Int(month), day)
    }
    
    /// Get the weekday (0=Sunday, 1=Monday, ..., 6=Saturday) for a fixed day
    /// RD 1 (Jan 1, 1 CE) was a Monday, so RD % 7 gives: 1=Mon, 2=Tue, ..., 0=Sun
    static func weekday(_ fixedDay: Int64) -> Int {
        let wd = fixedDay % 7
        // Map: 0=Sunday, 1=Monday, ..., 6=Saturday
        // RD 7 = Saturday → 7%7=0, but should be 6
        // RD 1 = Monday → 1%7=1 ✓
        // So we need: if wd==0 return 6 (Saturday), else return wd-1 for 0-indexed?
        // Actually: RD 1=Monday(1), RD 2=Tuesday(2), ... RD 6=Saturday(6), RD 7=Sunday(0)
        // RD%7: 1→1(Mon), 2→2(Tue), 3→3(Wed), 4→4(Thu), 5→5(Fri), 6→6(Sat), 7→0(Sun)
        // This gives 0=Sun, 1=Mon, ..., 6=Sat ✓
        return Int(((wd % 7) + 7) % 7)
    }
    
    /// Julian Day Number from fixed day
    static func toJulianDayNumber(_ fixedDay: Int64) -> Int64 {
        return fixedDay + 1721425
    }
    
    /// Fixed day from Julian Day Number
    static func fromJulianDayNumber(_ jdn: Int64) -> Int64 {
        return jdn - 1721425
    }
}

/// Positive floor-mod for continuous cycle calculations
@inlinable
func floorMod(_ value: Int64, modulus: Int64) -> Int64 {
    let r = value % modulus
    return r >= 0 ? r : r + modulus
}
