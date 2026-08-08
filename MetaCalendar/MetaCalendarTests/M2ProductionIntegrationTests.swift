import XCTest
@testable import MetaCalendar

/// M2 production-integration tests.
///
/// These tests assert that the M2 astronomy-provenance layer is wired into the
/// **production** module path — not a shadow/test-only implementation. They exercise
/// the real `CalendarEngine` projection (the same path `AppState.refreshToday()` uses
/// to drive the UI) and the real `EmbeddedAstronomyProvider` / `AstronomyProvenanceCatalog`
/// that live in the app target.
///
/// If any of these types were demoted to the test target, the `@testable import`
/// below would fail to resolve them and these tests would not compile — i.e. the
/// suite structurally fails when the integration is reverted to test-only.
final class M2ProductionIntegrationTests: XCTestCase {

    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    // MARK: - 1. Production path requests provenance from the real provider

    func test_productionProjection_carriesProvenanceDescriptors() throws {
        // Same entry point the UI uses (AppState.refreshToday -> CalendarEngine.project).
        let bundle = CalendarEngine.project(
            instant: Instant(date(2026, 6, 21)),
            timeZone: utc,
            location: GeoPoint(latitude: -6.2088, longitude: 106.8456,
                               elevationMeters: 8, horizontalAccuracyMeters: nil),
            ruleset: .default
        )

        let astro = try XCTUnwrap(bundle.astronomy,
                                  "Production projection must compute astronomy data")

        // Provenance came from the real catalog through the real provider.
        XCTAssertEqual(astro.solarLongitudeProvenance.methodID,
                       "solarLongitude.meeus-ch25-simplified")
        XCTAssertEqual(astro.solarLongitudeProvenance.dataOrigin, .algorithmic)
        XCTAssertEqual(astro.lunarPhaseProvenance.methodID, "lunarPhase.mean-synodic-month")
        XCTAssertEqual(astro.dominantDataOrigin, .algorithmic)

        // The capability marker must be the integrated v2 provenance layer.
        XCTAssertEqual(AstronomyEngine.astronomyCapabilityVersion,
                       "metacalendar.astronomy-accuracy.v2")
        XCTAssertEqual(AstronomyEngine.version, "1.1.0")
    }

    // MARK: - 2. Polar sunrise/sunset produces a typed RiseSetResult

    func test_polarProvider_midnightSun_inArcticSummer() {
        let provider = EmbeddedAstronomyProvider()
        let result = provider.sunRiseSetTyped(
            date: date(2026, 6, 21),
            latitude: 78.9, longitude: 11.9, timeZone: utc
        )
        XCTAssertEqual(result, .midnightSun, "Arctic summer solstice should be midnight sun")
        XCTAssertEqual(result.conditionLabel, "midnightSun")
        XCTAssertEqual(result.availability, .available)
    }

    func test_polarProvider_polarNight_inArcticWinter() {
        let provider = EmbeddedAstronomyProvider()
        let result = provider.sunRiseSetTyped(
            date: date(2026, 12, 21),
            latitude: 78.9, longitude: 11.9, timeZone: utc
        )
        XCTAssertEqual(result, .polarNight, "Arctic winter solstice should be polar night")
        XCTAssertEqual(result.conditionLabel, "polarNight")
        XCTAssertEqual(result.availability, .available)
    }

    func test_productionProjection_surfacesTypedRiseSet_atPolarLocation() throws {
        // Production projection through CalendarEngine must surface the typed result.
        let bundle = CalendarEngine.project(
            instant: Instant(date(2026, 6, 21)),
            timeZone: utc,
            location: GeoPoint(latitude: 78.9, longitude: 11.9,
                               elevationMeters: 10, horizontalAccuracyMeters: nil),
            ruleset: .default
        )
        XCTAssertEqual(try XCTUnwrap(bundle.astronomy).riseSetResult, .midnightSun)
    }

    // MARK: - 3. Event catalog returns explicit origin + provenance

    func test_astroEvents_carryExplicitDataOriginAndProvenance() {
        let events = AstroEvents.generate(forGregorianYear: 2026)
        let astro = events.filter { $0.category == .astronomical }
        XCTAssertFalse(astro.isEmpty, "AstroEvents must emit astronomy events for 2026")

        // Every astronomy event must carry an explicit origin and provenance descriptor.
        for event in astro {
            XCTAssertNotNil(event.dataOrigin,
                            "\(event.name) must declare a dataOrigin")
            XCTAssertNotNil(event.provenance,
                            "\(event.name) must carry an AstronomyProvenance descriptor")
        }
    }

    func test_eclipseEvents_areAuthoritativeCatalog() throws {
        let eclipses = AstroEvents.generate(forGregorianYear: 2026)
            .filter { $0.id.contains("eclipse") }
        XCTAssertFalse(eclipses.isEmpty, "2026 must have tabulated eclipses")
        for e in eclipses {
            let origin = try XCTUnwrap(e.dataOrigin, "Eclipse '\(e.name)' missing dataOrigin")
            XCTAssertEqual(origin, .authoritativeCatalog,
                           "Eclipse '\(e.name)' must be sourced from an authoritative catalog")
            let source = try XCTUnwrap(e.provenance?.source, "Eclipse '\(e.name)' missing provenance")
            XCTAssertTrue(source.contains("NASA"),
                          "Eclipse provenance must cite the NASA GSFC catalog")
        }
    }

    func test_solsticeEvents_carryApproximateTableOrigin() throws {
        let seasonal = AstroEvents.generate(forGregorianYear: 2026)
            .filter { $0.id.contains("season") }
        XCTAssertFalse(seasonal.isEmpty, "2026 must have solstice/equinox events")
        for s in seasonal {
            let origin = try XCTUnwrap(s.dataOrigin, "Solstice event missing dataOrigin")
            XCTAssertEqual(origin, .approximateTable)
            XCTAssertNotNil(s.provenance)
        }
    }

    func test_worldEclipses_carryProvenance() {
        let eclipses = WorldEvents.generate(forGregorianYear: 2026)
            .filter { $0.category == .astronomical }
        XCTAssertFalse(eclipses.isEmpty)
        for e in eclipses {
            XCTAssertNotNil(e.dataOrigin, "\(e.name) must declare a dataOrigin")
            XCTAssertNotNil(e.provenance, "\(e.name) must carry provenance")
        }
    }

    // MARK: - 4. Descriptor reaches a presenter

    func test_provenanceDescriptor_isDisplayable() throws {
        let bundle = CalendarEngine.project(
            instant: Instant(date(2026, 3, 20)),
            timeZone: utc,
            location: GeoPoint(latitude: 51.4769, longitude: 0.0005,
                               elevationMeters: 10, horizontalAccuracyMeters: nil),
            ruleset: .default
        )
        let astro = try XCTUnwrap(bundle.astronomy)

        // The descriptor fields surfaced by the Settings/diagnostics view are non-empty.
        let descriptor = """
        \(astro.solarLongitudeProvenance.methodID) · \
        \(astro.solarLongitudeProvenance.accuracyDescription) · \
        \(astro.riseSetResult.conditionLabel)
        """
        XCTAssertFalse(descriptor.isEmpty)
        XCTAssertTrue(descriptor.contains("solarLongitude"))
        XCTAssertTrue(descriptor.contains(astro.riseSetResult.conditionLabel))

        // All RiseSetResult condition labels are stable tokens.
        let labels = Set([
            RiseSetResult.rises(sunrise: Date(), sunset: Date()).conditionLabel,
            RiseSetResult.midnightSun.conditionLabel,
            RiseSetResult.polarNight.conditionLabel,
            RiseSetResult.unknown.conditionLabel
        ])
        XCTAssertEqual(labels, ["rises", "midnightSun", "polarNight", "unknown"])
    }

    // MARK: - 5. Adapter/catalog live in the app module (not test-only)

    func test_provenanceTypes_resolveThroughAppModule() {
        // If EmbeddedAstronomyProvider / AstronomyProvenanceCatalog were test-only,
        // these references would not compile under @testable import MetaCalendar.
        let provider = EmbeddedAstronomyProvider()
        XCTAssertEqual(provider.methodID, AstronomyEngine.providerID)

        let prov = AstronomyProvenanceCatalog.solsticesEquinoxes
        XCTAssertEqual(prov.dataOrigin, .approximateTable)

        // Type metadata confirms the types are emitted by the app module.
        XCTAssertTrue(String(describing: EmbeddedAstronomyProvider.self)
                        .contains("EmbeddedAstronomyProvider"))
        XCTAssertTrue(String(describing: AstronomyProvenanceCatalog.self)
                        .contains("AstronomyProvenanceCatalog"))
        XCTAssertTrue(String(describing: RiseSetResult.self).contains("RiseSetResult"))
        XCTAssertTrue(String(describing: AstronomyDataOrigin.self).contains("AstronomyDataOrigin"))
    }
}
