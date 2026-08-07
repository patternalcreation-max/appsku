import Foundation

// MARK: - Alignment Finder Engine
// The killer feature: search for moments when multiple cycle conditions occur simultaneously.
//
// Usage: build a list of CycleCondition, then AlignmentFinder.search() scans day-by-day
// to find the next N dates where ALL conditions match.

// MARK: - Condition Types

enum CycleCondition: Identifiable, Hashable {
    case weekday(Int)              // 0=Sunday ... 6=Saturday
    case pasaran(Int)              // 0=Legi ... 4=Kliwon
    case moonPhase(Double, tolerance: Double)  // 0=new, 180=full (±tolerance degrees)
    case metaSolarMonth(Int)       // 1-13
    case metaSolarDay(Int)         // 1-28
    case hijriMonth(Int)           // 1-12
    case hijriDay(Int)             // 1-30
    case chineseLunarMonth(Int)    // 1-12
    case chineseLunarDay(Int)      // 1-30
    case seasonalEvent(String)     // "solstice", "equinox"
    case metaSolarBridge           // bridge day
    case wetonDay(Int)             // 1-35 (combined pasaran+saptawara)

    var id: String { description }

    var description: String {
        switch self {
        case .weekday(let d): return ["Ahad","Senin","Selasa","Rabu","Kamis","Jumat","Sabtu"][d]
        case .pasaran(let p): return ["Legi","Pahing","Pon","Wage","Kliwon"][p]
        case .moonPhase(let deg, let tol): return deg < 90 ? "Bulan Baru (±\(Int(tol))°)" : deg < 270 ? "Bulan Separuh" : "Bulan Purnama (±\(Int(tol))°)"
        case .metaSolarMonth(let m): return "MetaSolar Bulan \(m)"
        case .metaSolarDay(let d): return "MetaSolar Hari \(d)"
        case .hijriMonth(let m): return "Hijri Bulan \(m)"
        case .hijriDay(let d): return "Hijri Hari \(d)"
        case .chineseLunarMonth(let m): return "China Bulan \(m)"
        case .chineseLunarDay(let d): return "China Hari \(d)"
        case .seasonalEvent(let s): return s == "solstice" ? "Solstis" : "Equinox"
        case .metaSolarBridge: return "Hari Jembatan"
        case .wetonDay(let w): return "Weton Hari \(w)"
        }
    }

    var emoji: String {
        switch self {
        case .weekday: return "📅"
        case .pasaran: return "🟢"
        case .moonPhase(let deg, _): return deg < 45 || deg > 315 ? "🌑" : deg < 135 ? "🌓" : deg < 225 ? "🌕" : "🌗"
        case .metaSolarMonth: return "🔆"
        case .metaSolarDay: return "⭐"
        case .hijriMonth: return "🕌"
        case .hijriDay: return "🕌"
        case .chineseLunarMonth: return "🀄"
        case .chineseLunarDay: return "🀄"
        case .seasonalEvent: return "🌍"
        case .metaSolarBridge: return "✨"
        case .wetonDay: return "🟣"
        }
    }

    /// Check if this condition matches on a given fixed day
    func matches(fixedDay: Int64, timeZone: TimeZone, ruleset: RulesetSelection) -> Bool {
        switch self {
        case .weekday(let target):
            return FixedDay.weekday(fixedDay) == target

        case .pasaran(let target):
            return JavaneseAdapter.pasaranIndex(fixedDay: fixedDay) == target

        case .moonPhase(let targetDeg, let tolerance):
            let phase = AstronomyEngine.moonPhaseAngle(forFixedDay: fixedDay)
            let diff = min(abs(phase - targetDeg), 360 - abs(phase - targetDeg))
            return diff <= tolerance

        case .metaSolarMonth(let target):
            let coord = MetaSolarEngine.coordinate(forFixedDay: fixedDay)
            if case .monthDay(_, let m, _) = coord { return m == target }
            return false

        case .metaSolarDay(let target):
            let coord = MetaSolarEngine.coordinate(forFixedDay: fixedDay)
            if case .monthDay(_, _, let d) = coord { return d == target }
            return false

        case .hijriMonth(let target):
            let (hMonth, _) = HijriAdapter.hijriFromFixedDay(fixedDay)
            return hMonth == target

        case .hijriDay(let target):
            let (_, hDay) = HijriAdapter.hijriFromFixedDay(fixedDay)
            return hDay == target

        case .chineseLunarMonth(let target):
            let chineseMonth = ChineseAdapter.lunarMonth(forFixedDay: fixedDay)
            return chineseMonth == target

        case .chineseLunarDay(let target):
            let chineseDay = ChineseAdapter.lunarDay(forFixedDay: fixedDay)
            return chineseDay == target

        case .seasonalEvent(let type):
            // Check if within ±2 days of nearest solstice/equinox
            let yearEvents = AstroEvents.generate(forGregorianYear: FixedDay.toGregorian(fixedDay).year)
            let seasonal = yearEvents.filter {
                $0.name.contains("Solstis") || $0.name.contains("Equinox")
            }
            for event in seasonal {
                if abs(event.fixedDay - fixedDay) <= 2 {
                    if type == "solstice" && event.name.contains("Solstis") { return true }
                    if type == "equinox" && event.name.contains("Equinox") { return true }
                }
            }
            return false

        case .metaSolarBridge:
            let coord = MetaSolarEngine.coordinate(forFixedDay: fixedDay)
            if case .yearBridge = coord { return true }
            if case .leapBridge = coord { return true }
            return false

        case .wetonDay(let target):
            let w = JavaneseAdapter.wetonDay(fixedDay: fixedDay)
            return (w + 1) == target
        }
    }
}

// MARK: - Alignment Finder

enum AlignmentFinder {

    struct AlignmentResult: Identifiable {
        let id = UUID()
        let fixedDay: Int64
        let conditions: [CycleCondition]
        let gregorianDate: (year: Int, month: Int, day: Int)

        var dateString: String {
            let cal = Calendar(identifier: .gregorian)
            let date = cal.date(from: DateComponents(year: gregorianDate.year, month: gregorianDate.month, day: gregorianDate.day)) ?? Date()
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.locale = Locale(identifier: "id_ID")
            return fmt.string(from: date)
        }

        var daysFromToday: Int {
            let cal = Calendar(identifier: .gregorian)
            let todayFD = FixedDay.fromGregorian(
                year: cal.component(.year, from: Date()),
                month: cal.component(.month, from: Date()),
                day: cal.component(.day, from: Date())
            )
            return Int(fixedDay - todayFD)
        }

        var weekdayName: String {
            let names = ["Ahad","Senin","Selasa","Rabu","Kamis","Jumat","Sabtu"]
            return names[FixedDay.weekday(fixedDay)]
        }

        var pasaranName: String {
            let names = ["Legi","Pahing","Pon","Wage","Kliwon"]
            return names[JavaneseAdapter.pasaranIndex(fixedDay: fixedDay)]
        }

        var wetonName: String { "\(weekdayName) \(pasaranName)" }
    }

    /// Search for the next N alignments starting from a given fixed day.
    /// Scans forward day-by-day, checking all conditions.
    static func search(
        conditions: [CycleCondition],
        from startFixedDay: Int64,
        maxDays: Int = 36500,  // ~100 years
        maxResults: Int = 20,
        timeZone: TimeZone = .autoupdatingCurrent,
        ruleset: RulesetSelection = .default
    ) -> [AlignmentResult] {
        guard !conditions.isEmpty else { return [] }

        var results: [AlignmentResult] = []
        var current = startFixedDay
        let ceiling = startFixedDay + Int64(maxDays)

        while current <= ceiling && results.count < maxResults {
            let allMatch = conditions.allSatisfy { $0.matches(fixedDay: current, timeZone: timeZone, ruleset: ruleset) }
            if allMatch {
                let greg = FixedDay.toGregorian(current)
                results.append(AlignmentResult(fixedDay: current, conditions: conditions, gregorianDate: greg))
            }
            current += 1
        }

        return results
    }

    /// Calculate LCM of cycle lengths (for "when do these cycles realign?")
    static func cycleRealignment(days: [Int]) -> Int {
        guard !days.isEmpty else { return 0 }
        var result = days[0]
        for i in 1..<days.count {
            result = lcm(result, days[i])
        }
        return result
    }

    /// Least Common Multiple
    static func lcm(_ a: Int, _ b: Int) -> Int {
        guard a != 0 && b != 0 else { return 0 }
        return abs(a * b) / gcd(a, b)
    }

    /// Greatest Common Divisor
    static func gcd(_ a: Int, _ b: Int) -> Int {
        var x = abs(a)
        var y = abs(b)
        while y != 0 { let t = y; y = x % y; x = t }
        return x
    }

    /// Format a number of days into human readable
    static func formatDuration(_ days: Int) -> String {
        if days < 365 { return "\(days) hari" }
        let years = days / 365
        let remaining = days % 365
        if remaining == 0 { return "\(years) tahun" }
        return "\(years) tahun \(remaining) hari"
    }
}

// MARK: - Helpers needed by ChineseAdapter

extension ChineseAdapter {
    static func lunarMonth(forFixedDay fd: Int64) -> Int {
        var cal = Calendar(identifier: .chinese)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let (y, m, d) = FixedDay.toGregorian(fd)
        let date = cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()
        let comp = cal.dateComponents([.month, .day], from: date)
        return comp.month ?? 1
    }

    static func lunarDay(forFixedDay fd: Int64) -> Int {
        var cal = Calendar(identifier: .chinese)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let (y, m, d) = FixedDay.toGregorian(fd)
        let date = cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()
        let comp = cal.dateComponents([.month, .day], from: date)
        return comp.day ?? 1
    }
}

// MARK: - Helpers needed by AstronomyEngine

extension AstronomyEngine {
    static func moonPhaseAngle(forFixedDay fd: Int64) -> Double {
        let (y, m, d) = FixedDay.toGregorian(fd)
        let cal = Calendar(identifier: .gregorian)
        let date = cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()
        let (_, _, phase) = AstronomyEngine.lunarPhase(for: date)
        return phase
    }
}
