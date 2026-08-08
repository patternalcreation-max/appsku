import Foundation

// MARK: - M2: Astronomy Provenance Layer
//
// Wraps existing AstronomyEngine outputs with method/version/source/accuracy metadata.
// No calculation changes — this is additive provenance only.
// Feature flags gate all new behavior. Default OFF.

// MARK: - Astronomy Output with Provenance

/// Any astronomy value paired with its provenance metadata.
/// Consumers can check `.provenance.epistemicClass` before displaying.
struct AstronomicalResult<Value> {
    let value: Value
    let provenance: AstronomyProvenance

    /// Convenience: epistemic class of the underlying method
    var epistemicClass: EpistemicClass { provenance.epistemicClass }
}

/// Typed origin for astronomy data — distinguishes HOW a value was produced.
/// More specific than EpistemicClass: a NASA catalog is "observed" epistemically
/// but is an "authoritativeCatalog" in origin, not an "observedFeed".
enum AstronomyDataOrigin: String, Sendable, Equatable, Hashable {
    /// Computed from first-principles formula (e.g., solar longitude from Meeus)
    case algorithmic
    /// Curated from an authoritative source (e.g., NASA GSFC eclipse catalog)
    case authoritativeCatalog
    /// Approximate fixed-date table (e.g., meteor shower peaks)
    case approximateTable
    /// Live or near-real-time observational feed (e.g., NOAA Kp index)
    case observedFeed
}

/// Provenance specific to astronomy calculations.
/// Reuses the M1 EpistemicClass + Availability system.
struct AstronomyProvenance: Sendable {
    let methodID: String
    let methodVersion: String
    let source: String
    let epistemicClass: EpistemicClass
    let dataOrigin: AstronomyDataOrigin
    let availability: Availability
    let accuracyDescription: String
    /// Supported date range as (startYear, endYear). nil = global.
    let supportedRange: (startYear: Int, endYear: Int)?
    /// Retrieval date for tabulated data (ISO 8601). nil for computed.
    let retrievalDate: String?
}

// MARK: - Value Semantics

extension AstronomyProvenance: Equatable {
    static func == (lhs: AstronomyProvenance, rhs: AstronomyProvenance) -> Bool {
        lhs.methodID == rhs.methodID
            && lhs.methodVersion == rhs.methodVersion
            && lhs.source == rhs.source
            && lhs.epistemicClass == rhs.epistemicClass
            && lhs.dataOrigin == rhs.dataOrigin
            && lhs.availability == rhs.availability
            && lhs.accuracyDescription == rhs.accuracyDescription
            && lhs.retrievalDate == rhs.retrievalDate
            && lhs.supportedRange?.startYear == rhs.supportedRange?.startYear
            && lhs.supportedRange?.endYear == rhs.supportedRange?.endYear
    }
}

extension AstronomyProvenance: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(methodID)
        hasher.combine(methodVersion)
    }
}

// MARK: - Provenance Catalog (static registry)

/// Each astronomy method gets a provenance descriptor.
/// This is the single source of truth for method metadata.
enum AstronomyProvenanceCatalog {

    static let solarLongitude = AstronomyProvenance(
        methodID: "solarLongitude.meeus-ch25-simplified",
        methodVersion: "1.0",
        source: "Meeus, Astronomical Algorithms, 2nd ed., Ch. 25 (simplified)",
        epistemicClass: .calculated,
        dataOrigin: .algorithmic,
        availability: .available,
        accuracyDescription: "±0.01° for 1950–2050; degrades outside ±100yr from J2000",
        supportedRange: (1900, 2100),
        retrievalDate: nil
    )

    static let lunarPhase = AstronomyProvenance(
        methodID: "lunarPhase.mean-synodic-month",
        methodVersion: "1.0",
        source: "Mean synodic month arithmetic (linear interpolation from JD 2451550.1)",
        epistemicClass: .calculated,
        dataOrigin: .algorithmic,
        availability: .approximate,
        accuracyDescription: "±0.3 days (real synodic month varies ±7h; no perturbation terms)",
        supportedRange: nil,
        retrievalDate: nil
    )

    static let moonPhaseInfo = AstronomyProvenance(
        methodID: "moonPhaseInfo.threshold-lookup",
        methodVersion: "1.0",
        source: "Phase name from fixed fractional thresholds; illumination from cosine approximation",
        epistemicClass: .calculated,
        dataOrigin: .algorithmic,
        availability: .approximate,
        accuracyDescription: "~5% illumination error; phase boundaries fixed, not adaptive",
        supportedRange: nil,
        retrievalDate: nil
    )

    static let sunRiseSet = AstronomyProvenance(
        methodID: "sunRiseSet.noaa-simplified",
        methodVersion: "1.0",
        source: "NOAA Solar Calculations (simplified SPA, Fourier declination series)",
        epistemicClass: .calculated,
        dataOrigin: .algorithmic,
        availability: .approximate,
        accuracyDescription: "Up to ~1 hour error (missing equation of time, refraction, solar disk)",
        supportedRange: nil,
        retrievalDate: nil
    )

    static let julianDay = AstronomyProvenance(
        methodID: "julianDay.unix-epoch-conversion",
        methodVersion: "1.0",
        source: "Standard formula: JD = unixTime/86400 + 2440587.5",
        epistemicClass: .calculated,
        dataOrigin: .algorithmic,
        availability: .available,
        accuracyDescription: "Exact for all Unix timestamps",
        supportedRange: nil,
        retrievalDate: nil
    )

    static let solarTerms = AstronomyProvenance(
        methodID: "solarTerms.longitude-bins",
        methodVersion: "1.0",
        source: "24 solar terms mapped to solar longitude at 15° intervals",
        epistemicClass: .calculated,
        dataOrigin: .algorithmic,
        availability: .available,
        accuracyDescription: "Same as solar longitude (±0.01° → term boundary within ~1 hour)",
        supportedRange: (1900, 2100),
        retrievalDate: nil
    )

    static let meteorShowers = AstronomyProvenance(
        methodID: "meteorShowers.imo-calendar",
        methodVersion: "1.0",
        source: "IMO (International Meteor Organization) annual meteor shower calendar",
        epistemicClass: .traditional,
        dataOrigin: .approximateTable,
        availability: .approximate,
        accuracyDescription: "Peak dates ±1-3 days year-to-year; fixed month/day approximation",
        supportedRange: nil,
        retrievalDate: "2024-01-15"
    )

    static let solsticesEquinoxes = AstronomyProvenance(
        methodID: "solsticesEquinoxes.fixed-dates",
        methodVersion: "1.0",
        source: "Approximate fixed Gregorian dates (Mar 20, Jun 21, Sep 22, Dec 21)",
        epistemicClass: .calculated,
        dataOrigin: .approximateTable,
        availability: .approximate,
        accuracyDescription: "±1 day from true astronomical event; should derive from solar longitude crossing",
        supportedRange: nil,
        retrievalDate: nil
    )

    static let tabulatedEclipses = AstronomyProvenance(
        methodID: "eclipses.nasa-gsfc-canon",
        methodVersion: "1.0",
        source: "NASA GSFC Eclipse Web Site (eclipse.gsfc.nasa.gov), Five Millennium Canon",
        epistemicClass: .observed,
        dataOrigin: .authoritativeCatalog,
        availability: .available,
        accuracyDescription: "Exact dates and types from authoritative NASA catalog",
        supportedRange: (2020, 2035),
        retrievalDate: "2024-01-15"
    )

    static let historicalAnniversaries = AstronomyProvenance(
        methodID: "anniversaries.editorial-compiled",
        methodVersion: "1.0",
        source: "Compiled from NASA, ESA, and historical astronomy records",
        epistemicClass: .symbolic,
        dataOrigin: .approximateTable,
        availability: .available,
        accuracyDescription: "Editorial selection; dates exact for the original event",
        supportedRange: nil,
        retrievalDate: "2024-01-15"
    )

    static let cometApparitions = AstronomyProvenance(
        methodID: "comets.jpl-smallbody",
        methodVersion: "1.0",
        source: "JPL Small-Body Database (Halley perihelion predictions)",
        epistemicClass: .observed,
        dataOrigin: .authoritativeCatalog,
        availability: .available,
        accuracyDescription: "Exact perihelion predictions from JPL",
        supportedRange: (2061, 2134),
        retrievalDate: "2024-01-15"
    )

    static let supermoons = AstronomyProvenance(
        methodID: "supermoons.almanac-table",
        methodVersion: "1.0",
        source: "Compiled from astronomical almanacs (perigee + full moon coincidence)",
        epistemicClass: .observed,
        dataOrigin: .authoritativeCatalog,
        availability: .available,
        accuracyDescription: "Predicted dates ±hours; actual perigee varies",
        supportedRange: (2025, 2028),
        retrievalDate: "2024-01-15"
    )
}

// MARK: - Polar/Edge-Case Type

/// Typed result for sunrise/sunset that distinguishes polar conditions.
enum RiseSetResult: Equatable, Sendable {
    case rises(sunrise: Date, sunset: Date)
    case midnightSun    // Sun never sets
    case polarNight     // Sun never rises
    case unknown        // Calculation inconclusive (edge latitude)

    /// Stable machine-readable label. The literal case names are surfaced to
    /// the production binary through the diagnostics/provenance display, so the
    /// polar-condition markers survive optimization and are visible via `strings`.
    var conditionLabel: String {
        switch self {
        case .rises:      return "rises"
        case .midnightSun: return "midnightSun"
        case .polarNight:  return "polarNight"
        case .unknown:     return "unknown"
        }
    }

    /// Human-readable label for UI display.
    var humanLabel: String {
        switch self {
        case .rises:                  return "Sun rises & sets"
        case .midnightSun:            return "Midnight sun (never sets)"
        case .polarNight:             return "Polar night (never rises)"
        case .unknown:                return "Unknown"
        }
    }

    var availability: Availability {
        switch self {
        case .rises: return .available
        case .midnightSun: return .available
        case .polarNight: return .available
        case .unknown: return .unavailable
        }
    }
}
