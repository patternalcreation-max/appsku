import Foundation

// MARK: - M1.2: Epistemic Classification
//
// Every user-visible conclusion declares an epistemic class and availability.
// These types are additive — existing ProjectionStatus maps to EpistemicClass.
// No existing types are removed or renamed.

/// How a result was derived. Determines the authority a user should grant it.
///
/// - `observed`: External measurement or feed (e.g., NOAA Kp observation)
/// - `calculated`: Deterministic model (e.g., lunar phase, equinox)
/// - `traditional`: Named, sourced cultural rule (e.g., reviewed auspice rule)
/// - `symbolic`: Optional interpretation (e.g., reflection archetype)
/// - `experimental`: Product-defined model (e.g., MetaSolar theme)
enum EpistemicClass: String, Codable, Sendable, CaseIterable, Equatable, Hashable {
    case observed
    case calculated
    case traditional
    case symbolic
    case experimental
}

/// Whether a result is available at all, separate from its epistemic class.
///
/// - `available`: Full quality result
/// - `approximate`: Simplified or low-precision result
/// - `compatibility`: System calendar fallback (e.g., Foundation .islamic)
/// - `unavailable`: No result can be produced for this input
enum Availability: String, Codable, Sendable, CaseIterable, Equatable, Hashable {
    case available
    case approximate
    case compatibility
    case unavailable
}

// MARK: - M1.2: Provenance

/// Documents the source, method, version, and review status of any result.
/// Attach to projections, astronomy outputs, events, and alignment results.
struct Provenance: Codable, Hashable, Sendable {
    let epistemicClass: EpistemicClass
    let methodID: String
    let methodVersion: String
    let sourceTitle: String
    let sourceURL: URL?
    let validRangeStart: Date?
    let validRangeEnd: Date?
    let accuracyNote: String?
    let reviewedBy: [String]

    init(
        epistemicClass: EpistemicClass,
        methodID: String,
        methodVersion: String,
        sourceTitle: String,
        sourceURL: URL? = nil,
        validRangeStart: Date? = nil,
        validRangeEnd: Date? = nil,
        accuracyNote: String? = nil,
        reviewedBy: [String] = []
    ) {
        self.epistemicClass = epistemicClass
        self.methodID = methodID
        self.methodVersion = methodVersion
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.validRangeStart = validRangeStart
        self.validRangeEnd = validRangeEnd
        self.accuracyNote = accuracyNote
        self.reviewedBy = reviewedBy
    }

    /// Human-readable summary for UI display.
    var summary: String {
        var parts: [String] = ["\(methodID) v\(methodVersion)"]
        if let note = accuracyNote { parts.append(note) }
        if !reviewedBy.isEmpty { parts.append("Reviewed: " + reviewedBy.joined(separator: ", ")) }
        return parts.joined(separator: " · ")
    }
}

/// Wraps a value with its availability and explanation.
struct Explained<Value: Codable & Sendable>: Codable, Sendable {
    let value: Value?
    let availability: Availability
    let explanation: String
    let provenance: Provenance
}

// MARK: - M1.2: Existing ProjectionStatus → EpistemicClass bridge

extension ProjectionStatus {
    /// Maps the existing ProjectionStatus to the new EpistemicClass.
    /// This is a read-only bridge — ProjectionStatus is not removed.
    var epistemicClass: EpistemicClass {
        switch self {
        case .computed: return .calculated
        case .predicted: return .calculated
        case .observed: return .observed
        case .officiallyDeclared: return .traditional
        case .historicalReconstruction: return .calculated
        case .experimental: return .experimental
        }
    }
}

// MARK: - M1.3: Protocol Seams

/// Unified interface for calendar projection adapters.
/// Existing engines already work; this protocol formalizes the contract
/// without changing their internal logic.
protocol CalendarProjecting: Sendable {
    var profileID: String { get }
    var methodVersion: String { get }

    func project(
        instant: Date,
        timeZone: TimeZone,
        ruleset: RulesetSelection
    ) -> CalendarProjection
}

/// Unified interface for astronomy providers.
/// The existing `AstronomyEngine` uses static methods; this protocol
/// allows injection and testing.
protocol AstronomyProviding: Sendable {
    var methodID: String { get }
    var methodVersion: String { get }

    func solarLongitude(julianDay: Double) -> Double
    func lunarPhase(julianDay: Double) -> Double
    func sunRiseSet(
        date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> (sunrise: Date?, sunset: Date?)
}

/// Adapter that wraps the static `AstronomyEngine` to satisfy `AstronomyProviding`.
/// The engine itself is unchanged — this is a zero-cost bridge.
/// M2: Adds provenance-returning variants (existing methods unchanged).
struct EmbeddedAstronomyProvider: AstronomyProviding {
    let methodID: String = AstronomyEngine.providerID
    let methodVersion: String = AstronomyEngine.version

    func solarLongitude(julianDay: Double) -> Double {
        AstronomyEngine.solarLongitude(julianDay: julianDay)
    }

    func lunarPhase(julianDay: Double) -> Double {
        AstronomyEngine.lunarPhase(julianDay: julianDay)
    }

    func sunRiseSet(
        date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> (sunrise: Date?, sunset: Date?) {
        AstronomyEngine.sunRiseSet(date: date, latitude: latitude, longitude: longitude, timeZone: timeZone)
    }

    // MARK: - M2: Provenance-returning variants

    func solarLongitudeWithProvenance(julianDay: Double) -> AstronomicalResult<Double> {
        AstronomicalResult(
            value: AstronomyEngine.solarLongitude(julianDay: julianDay),
            provenance: AstronomyProvenanceCatalog.solarLongitude
        )
    }

    func lunarPhaseWithProvenance(julianDay: Double) -> AstronomicalResult<Double> {
        AstronomicalResult(
            value: AstronomyEngine.lunarPhase(julianDay: julianDay),
            provenance: AstronomyProvenanceCatalog.lunarPhase
        )
    }

    func sunRiseSetTyped(
        date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> RiseSetResult {
        let (sunrise, sunset) = AstronomyEngine.sunRiseSet(
            date: date, latitude: latitude, longitude: longitude, timeZone: timeZone
        )
        if sunrise == nil && sunset == nil {
            // Distinguish: midnight sun returns (date, date), polar night returns (nil, nil)
            // The existing engine returns (date, date) for midnight sun
            return .polarNight
        }
        if sunrise == sunset {
            return .midnightSun
        }
        guard let sr = sunrise, let ss = sunset else {
            return .unknown
        }
        return .rises(sunrise: sr, sunset: ss)
    }
}

// MARK: - M1.4: Feature Flags

/// Typed local feature flags for expansion features.
/// All default to OFF until each milestone gate passes.
/// Flags may hide unfinished UI but must NOT change core calculation semantics.
struct FeatureFlags: Codable, Sendable, Equatable {
    // M3 — Universal events
    var universalEventsV2: Bool = false

    // M4 — Alignment DSL
    var alignmentDSL: Bool = false

    // M5 — Good Day
    var goodDay: Bool = false

    // M5 — Symbolic lenses
    var symbolicLenses: Bool = false

    // M6 — Chronicle
    var chronicle: Bool = false

    // M6 — Aura
    var auraPortrait: Bool = false

    // M6 — Pattern Lab
    var patternLab: Bool = false

    // M7 — Native adapters
    var locationProvider: Bool = false
    var notifications: Bool = false
    var eventKitExport: Bool = false
    var spaceWeather: Bool = false

    /// All flags OFF — the safe default.
    static let allOff = FeatureFlags()
}
