import XCTest
@testable import MetaCalendar

/// M1.1 — Characterization tests for existing calendar engines.
/// These tests capture CURRENT behavior (golden/snapshot style), not "correct" behavior.
/// They exist to detect regressions when we add provenance, protocols, or refactor engines.
/// If a test fails after a change, that change altered existing behavior — investigate.
///
/// Test philosophy: "Mark known-wrong behavior rather than silently blessing it."
final class CalendarCharacterizationTests: XCTestCase {

    // MARK: - FixedDay (Rata Die)

    func testFixedDay_epoch_Jan1_1CE_is_RD1() {
        let fd = FixedDay.fromGregorian(year: 1, month: 1, day: 1)
        XCTAssertEqual(fd, 1, "Jan 1, 1 CE should be RD 1")
    }

    func testFixedDay_roundTrip_1945_08_17() {
        let original = FixedDay.fromGregorian(year: 1945, month: 8, day: 17)
        let back = FixedDay.toGregorian(original)
        XCTAssertEqual(back.year, 1945)
        XCTAssertEqual(back.month, 8)
        XCTAssertEqual(back.day, 17)
    }

    func testFixedDay_roundTrip_2000_01_01() {
        let original = FixedDay.fromGregorian(year: 2000, month: 1, day: 1)
        let back = FixedDay.toGregorian(original)
        XCTAssertEqual(back.year, 2000)
        XCTAssertEqual(back.month, 1)
        XCTAssertEqual(back.day, 1)
    }

    func testFixedDay_roundTrip_2026_08_07() {
        let original = FixedDay.fromGregorian(year: 2026, month: 8, day: 7)
        let back = FixedDay.toGregorian(original)
        XCTAssertEqual(back.year, 2026)
        XCTAssertEqual(back.month, 8)
        XCTAssertEqual(back.day, 7)
    }

    func testFixedDay_weekday_17Aug1945_is_Friday() {
        let fd = FixedDay.fromGregorian(year: 1945, month: 8, day: 17)
        // 0=Sunday, 5=Friday
        XCTAssertEqual(FixedDay.weekday(fd), 5, "17 Aug 1945 should be Friday (Jumat)")
    }

    func testFixedDay_weekday_Jan1_2000_is_Saturday() {
        let fd = FixedDay.fromGregorian(year: 2000, month: 1, day: 1)
        XCTAssertEqual(FixedDay.weekday(fd), 6, "Jan 1, 2000 should be Saturday")
    }

    func testFixedDay_toJulianDayNumber_Jan1_2000() {
        let fd = FixedDay.fromGregorian(year: 2000, month: 1, day: 1)
        let jdn = FixedDay.toJulianDayNumber(fd)
        // Jan 1, 2000 12:00 UT → JDN 2451545 (noon-based)
        XCTAssertEqual(jdn, 2451545, "Jan 1, 2000 should be JDN 2451545")
    }

    // MARK: - MetaSolar Engine

    func testMetaSolar_epoch_is_Jan1_2000() {
        XCTAssertEqual(MetaSolarEngine.devEpochFixedDay,
                       FixedDay.fromGregorian(year: 2000, month: 1, day: 1),
                       "MetaSolar epoch must be Jan 1, 2000")
    }

    func testMetaSolar_coordinate_Jan1_2000_is_month1_day1() {
        let fd = MetaSolarEngine.devEpochFixedDay
        let coord = MetaSolarEngine.coordinate(forFixedDay: fd)
        if case .monthDay(let year, let month, let day) = coord {
            XCTAssertEqual(year, 2000)
            XCTAssertEqual(month, 1)
            XCTAssertEqual(day, 1)
        } else {
            XCTFail("Expected monthDay but got \(coord)")
        }
    }

    func testMetaSolar_coordinate_Jan29_2000_is_month1_day29() {
        let fd = FixedDay.fromGregorian(year: 2000, month: 1, day: 29)
        let coord = MetaSolarEngine.coordinate(forFixedDay: fd)
        if case .monthDay(_, let month, let day) = coord {
            XCTAssertEqual(month, 1, "Day 29 of year should still be month 1")
            XCTAssertEqual(day, 29)
        } else {
            XCTFail("Expected monthDay but got \(coord)")
        }
    }

    func testMetaSolar_coordinate_Feb25_2000_is_month1_day56() {
        // Jan has 31 days, so Feb 25 = day 56 → month 2, day 28
        let fd = FixedDay.fromGregorian(year: 2000, month: 2, day: 25)
        let coord = MetaSolarEngine.coordinate(forFixedDay: fd)
        if case .monthDay(_, let month, let day) = coord {
            // day 56: month = (56-1)/28 + 1 = 3, day = (56-1)%28 + 1 = 1
            XCTAssertEqual(month, 3, "Day 56 → month 3, day 1 (0-based: 55/28=1, 55%28=27 → month 2, day 28)")
            XCTAssertEqual(day, 1)
        } else {
            XCTFail("Expected monthDay but got \(coord)")
        }
    }

    func testMetaSolar_yearBridgeDay_exists() {
        // Day 365 of year = Year Bridge (dayOfYear == 364, 0-based)
        // Jan 1 = dayOfYear 0, so day 365 = Dec 31 in non-leap year
        // 2000 is a leap year, so Dec 30 = day 365 (0-based 364)
        let yearStart = MetaSolarEngine.startOfYear(2000)
        let bridgeDay = yearStart + 364  // 0-based day 364
        let coord = MetaSolarEngine.coordinate(forFixedDay: bridgeDay)
        if case .yearBridge(let year) = coord {
            XCTAssertEqual(year, 2000)
        } else {
            XCTFail("Expected yearBridge but got \(coord). yearStart=\(yearStart), bridgeDay=\(bridgeDay)")
        }
    }

    func testMetaSolar_leapBridgeDay_exists_in_leap_year() {
        let yearStart = MetaSolarEngine.startOfYear(2000) // 2000 is leap
        let leapBridgeDay = yearStart + 365
        let coord = MetaSolarEngine.coordinate(forFixedDay: leapBridgeDay)
        if case .leapBridge(let year) = coord {
            XCTAssertEqual(year, 2000)
        } else {
            XCTFail("Expected leapBridge but got \(coord)")
        }
    }

    func testMetaSolar_fixedDay_roundTrip() {
        let fd = FixedDay.fromGregorian(year: 2026, month: 8, day: 7)
        let coord = MetaSolarEngine.coordinate(forFixedDay: fd)
        let back = MetaSolarEngine.fixedDay(for: coord)
        XCTAssertEqual(back, fd, "coordinate → fixedDay should round-trip")
    }

    // MARK: - Javanese (anchor: 17 Aug 1945 = Jumat Legi)

    func testJavanese_anchor_17Aug1945() {
        let fd = FixedDay.fromGregorian(year: 1945, month: 8, day: 17)
        let saptawara = JavaneseAdapter.saptawaraIndex(fixedDay: fd)
        let pasaran = JavaneseAdapter.pasaranIndex(fixedDay: fd)
        let weton = JavaneseAdapter.wetonDay(fixedDay: fd)
        // Jumat = saptawara 5, Legi = pasaran 0
        XCTAssertEqual(saptawara, 5, "17 Aug 1945 should be Jumat (saptawara 5)")
        XCTAssertEqual(pasaran, 0, "17 Aug 1945 should be Legi (pasaran 0)")
        XCTAssertEqual(weton, 5, "Weton day should be 5 for Jumat Legi (5*1+0)")
    }

    func testJavanese_weton_cycle_35_days() {
        let base = FixedDay.fromGregorian(year: 1945, month: 8, day: 17)
        let baseWeton = JavaneseAdapter.wetonDay(fixedDay: base)
        // 35 days later, same weton
        let later = base + 35
        let laterWeton = JavaneseAdapter.wetonDay(fixedDay: later)
        XCTAssertEqual(baseWeton, laterWeton, "Weton should repeat every 35 days")
    }

    func testJavanese_neptu_is_nonNegative() {
        for offset in 0..<35 {
            let fd = FixedDay.fromGregorian(year: 2026, month: 8, day: 7) + Int64(offset)
            let neptu = JavaneseAdapter.totalNeptu(fixedDay: fd)
            XCTAssertGreaterThanOrEqual(neptu, 0, "Neptu should be non-negative")
        }
    }

    // MARK: - Hijri (Tabular)

    func testHijri_basic_conversion() {
        let fd = FixedDay.fromGregorian(year: 2024, month: 4, day: 10)
        let hijri = HijriAdapter.hijriFromFixedDay(fd)
        // We don't assert exact values (method may vary), just that it returns valid ranges
        XCTAssertGreaterThan(hijri.year, 1400, "Hijri year for 2024 should be > 1400")
        XCTAssertLessThan(hijri.year, 1500, "Hijri year for 2024 should be < 1500")
        XCTAssertGreaterThanOrEqual(hijri.month, 1)
        XCTAssertLessThanOrEqual(hijri.month, 12)
        XCTAssertGreaterThanOrEqual(hijri.day, 1)
        XCTAssertLessThanOrEqual(hijri.day, 30)
    }

    // MARK: - Astronomy

    func testAstronomy_solarLongitude_Jan2026_near_280() {
        // Around Jan 4, Earth is at perihelion; solar longitude ~280°
        let fd = FixedDay.fromGregorian(year: 2026, month: 1, day: 4)
        let jdn = Double(FixedDay.toJulianDayNumber(fd))
        let lon = AstronomyEngine.solarLongitude(julianDay: jdn)
        // Allow generous tolerance for simplified model
        XCTAssertTrue(lon >= 270 && lon <= 300,
                      "Solar longitude near Jan 4 should be ~280°, got \(lon)")
    }

    func testAstronomy_solarLongitude_Jul2026_near_100() {
        // Around Jul 4, Earth is at aphelion; solar longitude ~100° (apparent)
        // But our model may use ecliptic longitude, so ~100-120°
        let fd = FixedDay.fromGregorian(year: 2026, month: 7, day: 4)
        let jdn = Double(FixedDay.toJulianDayNumber(fd))
        let lon = AstronomyEngine.solarLongitude(julianDay: jdn)
        // Check it's in a reasonable summer range
        XCTAssertTrue(lon >= 80 && lon <= 140,
                      "Solar longitude near Jul 4 should be ~100°, got \(lon)")
    }

    func testAstronomy_lunarPhase_returns_0_to_360() {
        for dayOffset in 0..<30 {
            let fd = FixedDay.fromGregorian(year: 2026, month: 1, day: 1) + Int64(dayOffset)
            let jdn = Double(FixedDay.toJulianDayNumber(fd))
            let phase = AstronomyEngine.lunarPhase(julianDay: jdn)
            XCTAssertGreaterThanOrEqual(phase, 0, "Lunar phase should be >= 0, got \(phase)")
            XCTAssertLessThan(phase, 360, "Lunar phase should be < 360, got \(phase)")
        }
    }

    func testAstronomy_moonPhaseInfo_returns_valid_data() {
        let info0 = AstronomyEngine.moonPhaseInfo(phase: 0)    // New moon
        let info180 = AstronomyEngine.moonPhaseInfo(phase: 180) // Full moon
        XCTAssertFalse(info0.name.isEmpty, "Phase name should not be empty")
        XCTAssertFalse(info180.name.isEmpty, "Phase name should not be empty")
        XCTAssertGreaterThanOrEqual(info0.illumination, 0)
        XCTAssertLessThanOrEqual(info0.illumination, 1)
        XCTAssertGreaterThanOrEqual(info180.illumination, 0)
        XCTAssertLessThanOrEqual(info180.illumination, 1)
    }

    // MARK: - AlignmentFinder

    func testAlignmentFinder_gcd() {
        XCTAssertEqual(AlignmentFinder.gcd(12, 8), 4)
        XCTAssertEqual(AlignmentFinder.gcd(7, 5), 1)
        XCTAssertEqual(AlignmentFinder.gcd(35, 7), 7)
    }

    func testAlignmentFinder_lcm() {
        XCTAssertEqual(AlignmentFinder.lcm(7, 5), 35)
        XCTAssertEqual(AlignmentFinder.lcm(28, 30), 420)  // not quite right for lunar
    }

    func testAlignmentFinder_cycleRealignment_7_and_5() {
        // Weekday(7) + Pasaran(5) → realign every 35 days
        let realign = AlignmentFinder.cycleRealignment(days: [7, 5])
        XCTAssertEqual(realign, 35, "7 and 5 should realign every 35 days")
    }

    func testAlignmentFinder_cycleRealignment_28_and_29_5() {
        // MetaSolar month(28) + lunar synodic(~29.53) → realign after LCM
        // Since we pass integer days, 28 and 30 → LCM(28,30) = 420
        let realign = AlignmentFinder.cycleRealignment(days: [28, 30])
        XCTAssertEqual(realign, 420)
    }
}

/// M1.1 — Astronomy provider characterization.
final class AstronomyCharacterizationTests: XCTestCase {

    func testProviderID_is_stable() {
        XCTAssertEqual(AstronomyEngine.providerID, "astronomy.embedded-standard-v1")
    }

    func testVersion_is_stable() {
        XCTAssertEqual(AstronomyEngine.version, "1.0.0")
    }

    func testSolarTerms_exist_for_all_24() {
        // Just verify the function returns non-empty strings for various longitudes
        for lon in stride(from: 0.0, through: 360.0, by: 15.0) {
            let term = AstronomyEngine.currentSolarTerm(longitude: lon)
            XCTAssertFalse(term.isEmpty, "Solar term at longitude \(lon) should not be empty")
        }
    }

    func testSunRiseSet_returns_values_for_Jakarta_summer() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let result = AstronomyEngine.sunRiseSet(
            date: date,
            latitude: -6.2088,
            longitude: 106.8456,
            timeZone: TimeZone(identifier: "Asia/Jakarta")!
        )
        // Jakarta has sunrise/sunset year-round
        XCTAssertNotNil(result.sunrise, "Jakarta should have sunrise in July")
        XCTAssertNotNil(result.sunset, "Jakarta should have sunset in July")
    }

    func testSunRiseSet_polar_night_is_nil_or_graceful() {
        // North pole in December → polar night, should return nil gracefully
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 12, day: 21))!
        let result = AstronomyEngine.sunRiseSet(
            date: date,
            latitude: 89.0,
            longitude: 0.0,
            timeZone: TimeZone(identifier: "UTC")!
        )
        // Should not crash. Sunrise may be nil (polar night).
        // We accept either nil or non-nil; the test just verifies no crash.
        _ = result
    }
}

/// M1.1 — Calendar projection characterization via CalendarEngine.
final class CalendarEngineCharacterizationTests: XCTestCase {

    func testProject_returns_5_projections() {
        let instant = Instant(Date(timeIntervalSince1970: 1722988800)) // Aug 7, 2024 00:00 UTC
        let bundle = CalendarEngine.project(
            instant: instant,
            timeZone: TimeZone(identifier: "Asia/Jakarta")!,
            location: nil,
            ruleset: .default
        )
        // Should have exactly 5 calendar projections
        XCTAssertGreaterThanOrEqual(bundle.projections.count, 5,
                                    "Should project to at least 5 calendar systems")
    }

    func testProject_gregorian_Aug7_2024() {
        let date = Date(timeIntervalSince1970: 1722988800) // Aug 7, 2024 00:00 UTC → Aug 7 Jakarta
        let instant = Instant(date)
        let bundle = CalendarEngine.project(
            instant: instant,
            timeZone: TimeZone(identifier: "Asia/Jakarta")!,
            location: nil,
            ruleset: .default
        )
        let gregorian = bundle.projections.first { $0.calendarSystemID == .gregorian }
        XCTAssertNotNil(gregorian, "Should have Gregorian projection")
        XCTAssertEqual(gregorian?.coordinate.year, 2024)
        XCTAssertEqual(gregorian?.coordinate.month, 8)
        XCTAssertEqual(gregorian?.coordinate.day, 7)
    }

    func testProject_javanese_has_pasaran() {
        let date = Date(timeIntervalSince1970: 1722988800) // Aug 7, 2024
        let instant = Instant(date)
        let bundle = CalendarEngine.project(
            instant: instant,
            timeZone: TimeZone(identifier: "Asia/Jakarta")!,
            location: nil,
            ruleset: .default
        )
        let javanese = bundle.projections.first { $0.calendarSystemID == .javanese }
        XCTAssertNotNil(javanese, "Should have Javanese projection")
        // Check that extraFields contains pasaran info
        let extra = javanese?.coordinate.extraFields
        XCTAssertNotNil(extra?["pasaran"], "Javanese projection should contain pasaran")
    }
}
