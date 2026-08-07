import Foundation

// MARK: - Chinese Calendar Adapter (per blueprint §8.3)
//
// Uses Foundation Calendar(identifier: .chinese) for lunar month/day.
// Enriches with 24 Solar Terms (Jieqi) based on approximate solar longitude.

enum ChineseAdapter {
    
    static let rulesetID = "chinese.foundation-v1"
    
    /// 24 Solar Terms with approximate dates (Gregorian month/day ranges)
    /// These are approximate; precise dates vary by year ±1-2 days.
    static let solarTerms: [(name: String, approxMonth: Int, approxDay: Int, longitude: Double)] = [
        ("小寒 Minor Cold", 1, 6, 285),
        ("大寒 Major Cold", 1, 20, 300),
        ("立春 Start of Spring", 2, 4, 315),
        ("雨水 Rain Water", 2, 19, 330),
        ("驚蟄 Awakening of Insects", 3, 6, 345),
        ("春分 Spring Equinox", 3, 21, 0),
        ("清明 Pure Brightness", 4, 5, 15),
        ("穀雨 Grain Rain", 4, 20, 30),
        ("立夏 Start of Summer", 5, 6, 45),
        ("小滿 Grain Buds", 5, 21, 60),
        ("芒種 Grain in Ear", 6, 6, 75),
        ("夏至 Summer Solstice", 6, 21, 90),
        ("小暑 Minor Heat", 7, 7, 105),
        ("大暑 Major Heat", 7, 23, 120),
        ("立秋 Start of Autumn", 8, 8, 135),
        ("處暑 End of Heat", 8, 23, 150),
        ("白露 White Dew", 9, 8, 165),
        ("秋分 Autumn Equinox", 9, 23, 180),
        ("寒露 Cold Dew", 10, 8, 195),
        ("霜降 Frost's Descent", 10, 23, 210),
        ("立冬 Start of Winter", 11, 7, 225),
        ("小雪 Minor Snow", 11, 22, 240),
        ("大雪 Major Snow", 12, 7, 255),
        ("冬至 Winter Solstice", 12, 22, 270),
    ]
    
    /// Sexagenary cycle (Gan-Zhi) — 10 Heavenly Stems × 12 Earthly Branches
    static let heavenlyStems = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
    static let earthlyBranches = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    static let branchAnimals = ["Rat 鼠", "Ox 牛", "Tiger 虎", "Rabbit 兔", "Dragon 龍", "Snake 蛇",
                                "Horse 馬", "Goat 羊", "Monkey 猴", "Rooster 雞", "Dog 狗", "Pig 豬"]
    
    /// Project instant to Chinese calendar date
    static func project(instant: Instant, timeZone: TimeZone) -> CalendarProjection {
        let chineseCal = Calendar(identifier: .chinese)
        var cal = chineseCal
        cal.timeZone = timeZone
        
        let components = cal.dateComponents([.year, .month, .day, .isLeapMonth], from: instant.date)
        
        let era = components.year ?? 1  // Chinese era cycle
        let month = components.month ?? 1
        let day = components.day ?? 1
        let isLeap = components.isLeapMonth ?? false
        
        // Sexagenary year: 60-year cycle
        // Year 1 of current cycle (1984 CE) = 甲子
        let gregorianCal = Calendar(identifier: .gregorian)
        var gCal = gregorianCal
        gCal.timeZone = timeZone
        let gregYear = gCal.component(.year, from: instant.date)
        let sexagenaryIndex = floorMod(Int64((gregYear - 4) % 60), modulus: 60)
        let stemIdx = Int(sexagenaryIndex % 10)
        let branchIdx = Int(sexagenaryIndex % 12)
        let stem = heavenlyStems[stemIdx]
        let branch = earthlyBranches[branchIdx]
        let animal = branchAnimals[branchIdx]
        
        // Find nearest solar term
        let gregMonth = gCal.component(.month, from: instant.date)
        let gregDay = gCal.component(.day, from: instant.date)
        let nearestTerm = findNearestSolarTerm(month: gregMonth, day: gregDay)
        
        let monthNames = cal.monthSymbols
        let monthName = month > 0 && month <= monthNames.count ? monthNames[month - 1] : "Month \(month)"
        
        let coordinate = CalendarCoordinate(
            calendarSystemID: .chinese,
            year: era,
            month: month,
            day: day,
            isLeapMonth: isLeap,
            extraFields: [
                "sexagenary": "\(stem)\(branch) Year",
                "zodiac": animal,
                "solarTerm": nearestTerm,
                "gregorianYear": "\(gregYear)"
            ]
        )
        
        let leapStr = isLeap ? " (Leap)" : ""
        
        return CalendarProjection(
            calendarSystemID: .chinese,
            rulesetID: rulesetID,
            coordinate: coordinate,
            displayString: "\(monthName) \(day)\(leapStr)",
            subtitle: "\(stem)\(branch) · \(animal) · \(nearestTerm)",
            status: .computed,
            provenance: "Foundation Calendar(identifier: .chinese) · New-moon based · Solar terms approximate"
        )
    }
    
    private static func findNearestSolarTerm(month: Int, day: Int) -> String {
        var best = solarTerms[0]
        var bestDiff = Int.max
        
        for term in solarTerms {
            // Approximate day-of-year for the term
            let termDOY = approximateDayOfYear(month: term.approxMonth, day: term.approxDay)
            let currentDOY = approximateDayOfYear(month: month, day: day)
            let diff = min(abs(termDOY - currentDOY), 365 - abs(termDOY - currentDOY))
            if diff < bestDiff {
                bestDiff = diff
                best = term
            }
        }
        return best.name
    }
    
    private static func approximateDayOfYear(month: Int, day: Int) -> Int {
        let cumulative = [0, 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        return cumulative[month] + day
    }
}
