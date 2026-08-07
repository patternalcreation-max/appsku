import Foundation

// MARK: - Gregorian/ISO Bridge Adapter (per blueprint §8.1)

enum GregorianAdapter {
    
    static let rulesetID = "gregorian.iso.proleptic"
    
    /// Project an instant into Gregorian date components
    static func project(instant: Instant, timeZone: TimeZone) -> CalendarProjection {
        let calendar = Calendar(identifier: .gregorian)
        var cal = calendar
        cal.timeZone = timeZone
        
        let components = cal.dateComponents([.year, .month, .day, .weekday, .weekOfYear], from: instant.date)
        
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        let weekday = components.weekday ?? 1
        
        let monthNames = calendar.monthSymbols
        let monthName = month > 0 && month <= monthNames.count ? monthNames[month - 1] : "M\(month)"
        let weekdayName = cal.weekdaySymbols[weekday - 1]
        
        let coordinate = CalendarCoordinate(
            calendarSystemID: .gregorian,
            year: year,
            month: month,
            day: day,
            isLeapMonth: false,
            extraFields: ["weekday": "\(weekdayName) (\(weekday))"]
        )
        
        return CalendarProjection(
            calendarSystemID: .gregorian,
            rulesetID: rulesetID,
            coordinate: coordinate,
            displayString: "\(monthName) \(day), \(year)",
            subtitle: "\(weekdayName) · ISO Week \(components.weekOfYear ?? 0)",
            status: .computed,
            provenance: "Foundation Calendar(identifier: .gregorian) · Proleptic Gregorian"
        )
    }
    
    /// Get fixed day for Gregorian date
    static func fixedDay(year: Int, month: Int, day: Int) -> Int64 {
        return FixedDay.fromGregorian(year: year, month: month, day: day)
    }
    
    /// Gregorian date from fixed day
    static func dateFromFixedDay(_ fixedDay: Int64) -> (year: Int, month: Int, day: Int) {
        return FixedDay.toGregorian(fixedDay)
    }
}
