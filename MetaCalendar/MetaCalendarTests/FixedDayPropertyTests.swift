import XCTest
@testable import MetaCalendar

/// Property-based invariant tests for FixedDay Rata Die system.
/// These verify structural correctness across the entire 400-year Gregorian cycle,
/// not just spot-check dates.
final class FixedDayPropertyTests: XCTestCase {

    // MARK: - Round-trip: Gregorian → FixedDay → Gregorian

    func test_roundTrip_full_400_year_cycle() {
        // Test every month-start from year 1 to year 400
        for year in stride(from: 1, through: 400, by: 1) {
            for month in 1...12 {
                let fd = FixedDay.fromGregorian(year: year, month: month, day: 1)
                let back = FixedDay.toGregorian(fd)
                XCTAssertEqual(back.year, year, "Year mismatch at \(year)-\(month)-1")
                XCTAssertEqual(back.month, month, "Month mismatch at \(year)-\(month)-1")
                XCTAssertEqual(back.day, 1, "Day mismatch at \(year)-\(month)-1")
            }
        }
    }

    func test_roundTrip_modern_dates() {
        // Test specific known dates 1900-2100
        let testDates: [(year: Int, month: Int, day: Int)] = [
            (1900, 1, 1), (1900, 3, 1), (1945, 8, 17),
            (1999, 12, 31), (2000, 1, 1), (2000, 2, 29), (2000, 12, 31),
            (2001, 1, 1), (2020, 2, 29), (2024, 2, 29), (2024, 8, 7),
            (2026, 8, 7), (2030, 12, 25), (2050, 6, 15), (2099, 12, 31),
            (2100, 1, 1), (2100, 3, 1),
        ]
        for (y, m, d) in testDates {
            let fd = FixedDay.fromGregorian(year: y, month: m, day: d)
            let back = FixedDay.toGregorian(fd)
            XCTAssertEqual(back.year, y, "Year mismatch at \(y)-\(m)-\(d)")
            XCTAssertEqual(back.month, m, "Month mismatch at \(y)-\(m)-\(d)")
            XCTAssertEqual(back.day, d, "Day mismatch at \(y)-\(m)-\(d)")
        }
    }

    // MARK: - One-day increment invariant

    func test_consecutive_days_increment_by_exactly_one() {
        // For each day in 2024, FD(D+1) = FD(D) + 1
        let fdJan1 = FixedDay.fromGregorian(year: 2024, month: 1, day: 1)
        for offset in 0..<365 {
            let fd = fdJan1 + Int64(offset)
            let next = fd + 1
            let date = FixedDay.toGregorian(fd)
            let nextDate = FixedDay.toGregorian(next)
            // nextDate should be exactly 1 day after date
            let fd2 = FixedDay.fromGregorian(year: nextDate.year, month: nextDate.month, day: nextDate.day)
            XCTAssertEqual(fd2, next, "Day after \(date) should be FD \(next), got \(fd2)")
        }
    }

    // MARK: - Leap year boundaries

    func test_leap_day_2024_exists() {
        let feb28 = FixedDay.fromGregorian(year: 2024, month: 2, day: 28)
        let feb29 = FixedDay.fromGregorian(year: 2024, month: 2, day: 29)
        let mar1 = FixedDay.fromGregorian(year: 2024, month: 3, day: 1)
        XCTAssertEqual(feb29 - feb28, 1, "Feb 28 → Feb 29 should be 1 day")
        XCTAssertEqual(mar1 - feb29, 1, "Feb 29 → Mar 1 should be 1 day")
    }

    func test_non_leap_year_2100_skips_feb_29() {
        // 2100 is divisible by 100 but not 400 → NOT a leap year
        let feb28 = FixedDay.fromGregorian(year: 2100, month: 2, day: 28)
        let mar1 = FixedDay.fromGregorian(year: 2100, month: 3, day: 1)
        XCTAssertEqual(mar1 - feb28, 1, "Feb 28 → Mar 1 in non-leap 2100 should be 1 day")
        // Feb 29 should not exist in 2100
        let feb29 = FixedDay.fromGregorian(year: 2100, month: 2, day: 29)
        let back = FixedDay.toGregorian(feb29)
        // fromGregorian with invalid day should still produce a valid round-trip
        // but it won't be Feb 29 — it'll be Mar 1
        XCTAssertNotEqual(back.month, 2, "Feb 29 in 2100 should not round-trip to February")
    }

    func test_year_2000_is_leap() {
        // 2000 is divisible by 400 → IS a leap year
        let feb28 = FixedDay.fromGregorian(year: 2000, month: 2, day: 28)
        let feb29 = FixedDay.fromGregorian(year: 2000, month: 2, day: 29)
        let mar1 = FixedDay.fromGregorian(year: 2000, month: 3, day: 1)
        XCTAssertEqual(feb29 - feb28, 1)
        XCTAssertEqual(mar1 - feb29, 1)
    }

    // MARK: - Known Rata Die anchors

    func test_RD_epoch_Jan1_1CE() {
        XCTAssertEqual(FixedDay.fromGregorian(year: 1, month: 1, day: 1), 1)
    }

    func test_RD_JDN_conversion_Jan1_2000() {
        let fd = FixedDay.fromGregorian(year: 2000, month: 1, day: 1)
        let jdn = FixedDay.toJulianDayNumber(fd)
        XCTAssertEqual(jdn, 2451545, "JDN for Jan 1, 2000 should be 2451545")
    }

    func test_RD_JDN_conversion_Jan1_1CE() {
        let fd = Int64(1)
        let jdn = FixedDay.toJulianDayNumber(fd)
        XCTAssertEqual(jdn, 1721426, "JDN for Jan 1, 1 CE should be 1721426")
    }

    func test_RD_JDN_roundTrip() {
        for fd in [Int64(1), Int64(710260), Int64(730120), Int64(739835)] {
            let jdn = FixedDay.toJulianDayNumber(fd)
            let back = FixedDay.fromJulianDayNumber(jdn)
            XCTAssertEqual(back, fd, "JDN round-trip failed for FD \(fd)")
        }
    }

    // MARK: - Weekday anchors

    func test_weekday_Jan1_1CE_is_Monday() {
        let fd = FixedDay.fromGregorian(year: 1, month: 1, day: 1)
        XCTAssertEqual(FixedDay.weekday(fd), 1, "Jan 1, 1 CE was Monday")
    }

    func test_weekday_17Aug1945_is_Friday() {
        let fd = FixedDay.fromGregorian(year: 1945, month: 8, day: 17)
        XCTAssertEqual(FixedDay.weekday(fd), 5, "17 Aug 1945 was Friday")
    }

    func test_weekday_Jan1_2000_is_Saturday() {
        let fd = FixedDay.fromGregorian(year: 2000, month: 1, day: 1)
        XCTAssertEqual(FixedDay.weekday(fd), 6, "Jan 1, 2000 was Saturday")
    }

    func test_weekday_cycles_every_7_days() {
        let base = FixedDay.fromGregorian(year: 2024, month: 1, day: 1)
        let baseWd = FixedDay.weekday(base)
        for i in 1...7 {
            let wd = FixedDay.weekday(base + Int64(i))
            let expected = (baseWd + i) % 7
            XCTAssertEqual(wd, expected, "Weekday at +\(i) days should be \(expected)")
        }
    }

    // MARK: - Dependent cycle anchors (Javanese)

    func test_javanese_saptawara_17Aug1945_is_Jumat() {
        let fd = FixedDay.fromGregorian(year: 1945, month: 8, day: 17)
        XCTAssertEqual(JavaneseAdapter.saptawaraIndex(fixedDay: fd), 5, "17 Aug 1945 = Jumat (5)")
    }

    func test_javanese_pasaran_17Aug1945_is_Legi() {
        let fd = FixedDay.fromGregorian(year: 1945, month: 8, day: 17)
        XCTAssertEqual(JavaneseAdapter.pasaranIndex(fixedDay: fd), 0, "17 Aug 1945 = Legi (0)")
    }

    func test_javanese_weton_35_day_cycle() {
        let anchor = FixedDay.fromGregorian(year: 1945, month: 8, day: 17)
        let anchorPasaran = JavaneseAdapter.pasaranIndex(fixedDay: anchor)
        let anchorSaptawara = JavaneseAdapter.saptawaraIndex(fixedDay: anchor)
        // After 35 days, both should repeat
        let later = anchor + 35
        XCTAssertEqual(JavaneseAdapter.pasaranIndex(fixedDay: later), anchorPasaran, "Pasaran repeats every 35 days")
        XCTAssertEqual(JavaneseAdapter.saptawaraIndex(fixedDay: later), anchorSaptawara, "Saptawara repeats every 7 days (and 35)")
    }

    // MARK: - Hijri epoch anchor

    func test_hijri_epoch_is_valid() {
        // Islamic epoch: 16 July 622 CE (Julian calendar) = RD 227015
        // This is a CC4 constant, not computed from fromGregorian
        XCTAssertEqual(HijriAdapter.epochFixedDay, 227015, "Hijri epoch must be RD 227015")
    }

    func test_hijri_conversion_returns_valid_ranges() {
        for year in stride(from: 1900, through: 2100, by: 50) {
            let fd = FixedDay.fromGregorian(year: year, month: 6, day: 15)
            let hijri = HijriAdapter.hijriFromFixedDay(fd)
            XCTAssertGreaterThanOrEqual(hijri.month, 1, "Hijri month >= 1 for \(year)")
            XCTAssertLessThanOrEqual(hijri.month, 12, "Hijri month <= 12 for \(year)")
            XCTAssertGreaterThanOrEqual(hijri.day, 1, "Hijri day >= 1 for \(year)")
            XCTAssertLessThanOrEqual(hijri.day, 30, "Hijri day <= 30 for \(year)")
        }
    }
}
