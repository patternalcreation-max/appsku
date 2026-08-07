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
/// Algorithm from "Calendrical Calculations" by Reingold & Dershowitz.
enum FixedDay {
    
    /// Convert Gregorian date to fixed day number
    static func fromGregorian(year: Int, month: Int, day: Int) -> Int64 {
        let y = Int64(year)
        let m = Int64(month)
        let d = Int64(day)
        
        // From Calendrical Calculations (Reingold-Dershowitz)
        let prevY = y - (m <= 2 ? 1 : 0)
        let leapDays = prevY / 4 - prevY / 100 + prevY / 400
        
        return 365 * (y - 1) + leapDays + Int64(floor(Double(367 * (m - 2 + 12 * ((14 - m) / 12))) / 12.0)) + d - 1 - 1721425 + 1
    }
    
    /// Convert fixed day number to Gregorian date
    static func toGregorian(_ fixedDay: Int64) -> (year: Int, month: Int, day: Int) {
        // From Calendrical Calculations
        let d0 = fixedDay + 1721425
        let d1 = d0 + 306  // shift to March-based year
        let y1 = Int64(floor(Double((10000 * d1 + 14780)) / 3652425.0))
        var day2 = d1 - Int64(365 * y1) - Int64(floor(Double(y1) / 4.0)) + Int64(floor(Double(y1) / 100.0)) - Int64(floor(Double(y1) / 400.0))
        
        var year = y1
        if day2 < 0 {
            year -= 1
            day2 = d1 - Int64(365 * year) - Int64(floor(Double(year) / 4.0)) + Int64(floor(Double(year) / 100.0)) - Int64(floor(Double(year) / 400.0))
        }
        
        let mp = Int64(floor(Double(100 * day2 + 52) / 3060.0))
        let month = mp < 10 ? mp + 3 : mp - 9
        let day = day2 - Int64(floor(Double(306 * (mp + 1)) / 10.0)) + 1
        let finalYear = month <= 2 ? year + 1 : year
        
        return (Int(finalYear), Int(month), Int(day))
    }
    
    /// Get the weekday (0=Sunday, 1=Monday, ..., 6=Saturday) for a fixed day
    /// RD 1 (Jan 1, 1 CE) was a Monday. So weekday = (fixedDay + 1) % 7 gives 0=Sunday
    static func weekday(_ fixedDay: Int64) -> Int {
        return Int(((fixedDay % 7) + 7) % 7)
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
