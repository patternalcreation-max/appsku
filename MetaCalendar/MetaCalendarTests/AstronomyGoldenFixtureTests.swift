import XCTest
@testable import MetaCalendar

/// Golden fixture tests for astronomy calculations.
/// Each test compares computed values against authoritative external sources.
/// Sources are cited per-fixture with retrieval date and tolerance.
final class AstronomyGoldenFixtureTests: XCTestCase {

    // MARK: - Solar Longitude: USNO Equinox/Solstice Values
    //
    // At the exact moment of equinox/solstice, solar longitude should be
    // 0° (vernal), 90° (summer), 180° (autumnal), 270° (winter).
    //
    // Source: USNO Season Dates
    // URL: https://aa.usno.navy.mil/data/Seasons
    // Retrieved: 2026-08-07
    // Tolerance: ±0.5° (allows for timing offset from exact minute of event)

    func test_solarLongitude_vernalEquinox_2024() {
        // 2024 Vernal Equinox: March 20, 2024, 03:06 UTC
        // JD at that moment
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2024, month: 3, day: 20, hour: 3, minute: 6)
        guard let date = cal.date(from: comps) else {
            XCTFail("Could not construct date")
            return
        }
        let jd = AstronomyEngine.julianDay(from: date)
        let longitude = AstronomyEngine.solarLongitude(julianDay: jd)
        XCTAssertEqual(longitude, 0.0, accuracy: 0.5,
                       "Vernal equinox solar longitude should be ~0° (got \(longitude)°)")
    }

    func test_solarLongitude_summerSolstice_2024() {
        // 2024 Summer Solstice: June 20, 2024, 20:51 UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2024, month: 6, day: 20, hour: 20, minute: 51)
        guard let date = cal.date(from: comps) else {
            XCTFail("Could not construct date")
            return
        }
        let jd = AstronomyEngine.julianDay(from: date)
        let longitude = AstronomyEngine.solarLongitude(julianDay: jd)
        XCTAssertEqual(longitude, 90.0, accuracy: 0.5,
                       "Summer solstice solar longitude should be ~90° (got \(longitude)°)")
    }

    func test_solarLongitude_autumnalEquinox_2024() {
        // 2024 Autumnal Equinox: September 22, 2024, 12:44 UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2024, month: 9, day: 22, hour: 12, minute: 44)
        guard let date = cal.date(from: comps) else {
            XCTFail("Could not construct date")
            return
        }
        let jd = AstronomyEngine.julianDay(from: date)
        let longitude = AstronomyEngine.solarLongitude(julianDay: jd)
        XCTAssertEqual(longitude, 180.0, accuracy: 0.5,
                       "Autumnal equinox solar longitude should be ~180° (got \(longitude)°)")
    }

    func test_solarLongitude_winterSolstice_2024() {
        // 2024 Winter Solstice: December 21, 2024, 09:21 UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2024, month: 12, day: 21, hour: 9, minute: 21)
        guard let date = cal.date(from: comps) else {
            XCTFail("Could not construct date")
            return
        }
        let jd = AstronomyEngine.julianDay(from: date)
        let longitude = AstronomyEngine.solarLongitude(julianDay: jd)
        XCTAssertEqual(longitude, 270.0, accuracy: 0.5,
                       "Winter solstice solar longitude should be ~270° (got \(longitude)°)")
    }

    // MARK: - Lunar Phase: USNO New Moon Dates
    //
    // Source: USNO Phases of the Moon
    // URL: https://aa.usno.navy.mil/data/MoonPhases
    // Retrieved: 2026-08-07
    // At new moon, lunarPhase should be ~0.0 (or ~1.0 wrapping)
    // Tolerance: ±0.03 (≈ ±0.9 days from mean phase)

    func test_lunarPhase_newMoon_2024_01_11() {
        // New Moon: January 11, 2024, 11:57 UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2024, month: 1, day: 11, hour: 11, minute: 57)
        guard let date = cal.date(from: comps) else {
            XCTFail("Could not construct date")
            return
        }
        let jd = AstronomyEngine.julianDay(from: date)
        let phase = AstronomyEngine.lunarPhase(julianDay: jd)
        XCTAssertTrue(phase < 0.03 || phase > 0.97,
                       "New Moon Jan 11, 2024 phase should be ~0 (got \(phase))")
    }

    func test_lunarPhase_fullMoon_2024_01_25() {
        // Full Moon: January 25, 2024, 17:54 UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2024, month: 1, day: 25, hour: 17, minute: 54)
        guard let date = cal.date(from: comps) else {
            XCTFail("Could not construct date")
            return
        }
        let jd = AstronomyEngine.julianDay(from: date)
        let phase = AstronomyEngine.lunarPhase(julianDay: jd)
        XCTAssertEqual(phase, 0.5, accuracy: 0.03,
                       "Full Moon Jan 25, 2024 phase should be ~0.5 (got \(phase))")
    }

    // MARK: - Julian Day: Known JDN Values
    //
    // Source: USNO Julian Date Converter
    // URL: https://aa.usno.navy.mil/data/JulianDate
    // Tolerance: exact

    func test_julianDay_J2000_epoch() {
        // J2000 epoch: January 1, 2000, 12:00 UTC = JD 2451545.0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = DateComponents(year: 2000, month: 1, day: 1, hour: 12, minute: 0)
        guard let date = cal.date(from: comps) else {
            XCTFail("Could not construct date")
            return
        }
        let jd = AstronomyEngine.julianDay(from: date)
        XCTAssertEqual(jd, 2451545.0, accuracy: 0.001,
                       "J2000 epoch JD should be 2451545.0 (got \(jd))")
    }

    // MARK: - Provenance Metadata Tests

    func test_solarLongitudeProvenance_isCalculated() {
        let result = EmbeddedAstronomyProvider().solarLongitudeWithProvenance(julianDay: 2460336.5)
        XCTAssertEqual(result.provenance.epistemicClass, .calculated)
        XCTAssertEqual(result.provenance.methodID, "solarLongitude.meeus-ch25-simplified")
        XCTAssertNotNil(result.provenance.supportedRange)
    }

    func test_lunarPhaseProvenance_isApproximate() {
        let result = EmbeddedAstronomyProvider().lunarPhaseWithProvenance(julianDay: 2460336.5)
        XCTAssertEqual(result.provenance.availability, .approximate,
                       "Lunar phase should be marked approximate")
        XCTAssertTrue(result.provenance.accuracyDescription.contains("0.3"),
                      "Accuracy should mention ±0.3 days")
    }

    func test_eclipseProvenance_isObserved() {
        let prov = AstronomyProvenanceCatalog.tabulatedEclipses
        XCTAssertEqual(prov.epistemicClass, .observed)
        XCTAssertEqual(prov.supportedRange?.startYear, 2020)
        XCTAssertEqual(prov.supportedRange?.endYear, 2035)
        XCTAssertNotNil(prov.retrievalDate)
    }

    func test_meteorShowerProvenance_isTraditional() {
        let prov = AstronomyProvenanceCatalog.meteorShowers
        XCTAssertEqual(prov.epistemicClass, .traditional)
        XCTAssertEqual(prov.availability, .approximate)
    }

    func test_supermoonProvenance_hasDateRange() {
        let prov = AstronomyProvenanceCatalog.supermoons
        XCTAssertEqual(prov.supportedRange?.startYear, 2025)
        XCTAssertEqual(prov.supportedRange?.endYear, 2028)
    }

    func test_riseSetResult_availabilityMapping() {
        XCTAssertEqual(RiseSetResult.rises(sunrise: Date(), sunset: Date()).availability, .available)
        XCTAssertEqual(RiseSetResult.midnightSun.availability, .available)
        XCTAssertEqual(RiseSetResult.polarNight.availability, .available)
        XCTAssertEqual(RiseSetResult.unknown.availability, .unavailable)
    }

    // MARK: - Polar Edge Case

    func test_polarNight_returnsNilNil() {
        // Tromsø, Norway in January (polar night)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Oslo")!
        let comps = DateComponents(year: 2024, month: 1, day: 15)
        guard let date = cal.date(from: comps) else {
            XCTFail("Could not construct date")
            return
        }
        let result = AstronomyEngine.sunRiseSet(
            date: date,
            latitude: 69.6,
            longitude: 18.9,
            timeZone: TimeZone(identifier: "Europe/Oslo")!
        )
        XCTAssertNil(result.sunrise, "Polar night should have no sunrise")
        XCTAssertNil(result.sunset, "Polar night should have no sunset")
    }

    // MARK: - Non-blocking: Exhaustive Gregorian Round-Trip (146,097 days)

    func test_exhaustiveRoundTrip_400_year_cycle() {
        // Test ALL 146,097 days in the first 400-year Gregorian cycle
        // This is the recommended permanent regression shield
        var failures = 0
        var firstFailure = ""
        for fd in 1...146097 {
            let (y, m, d) = FixedDay.toGregorian(Int64(fd))
            let back = FixedDay.fromGregorian(year: y, month: m, day: d)
            if back != Int64(fd) {
                failures += 1
                if firstFailure.isEmpty {
                    firstFailure = "FD \(fd) → (\(y),\(m),\(d)) → FD \(back)"
                }
                if failures > 5 { break }  // Report first few only
            }
        }
        XCTAssertTrue(failures == 0,
                      "Round-trip failed for \(failures) of 146,097 days. First: \(firstFailure)")
    }
}
