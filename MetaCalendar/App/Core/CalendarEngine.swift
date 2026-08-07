import Foundation

// MARK: - Calendar Engine Orchestrator
//
// Coordinates all calendar adapters, projection, and relation.
// The engine is pure — no OS-global state reads (ADR-007).

struct AstronomyData: Sendable, Equatable {
    let solarLongitude: Double
    let solarTerm: String
    let moonPhase: Double
    let moonPhaseName: String
    let moonPhaseEmoji: String
    let moonIllumination: Double
    let sunrise: Date?
    let sunset: Date?
    let provenance: String
}

struct ProjectionBundle: Sendable {
    let context: CalculationContext
    let projections: [CalendarProjection]
    let astronomy: AstronomyData?
    let warnings: [String]
}

enum CalendarEngine {
    
    /// Project a single instant into all enabled calendar systems
    static func project(
        instant: Instant,
        timeZone: TimeZone,
        location: GeoPoint?,
        ruleset: RulesetSelection
    ) -> ProjectionBundle {
        var projections: [CalendarProjection] = []
        var warnings: [String] = []
        
        // 1. MetaSolar-13
        let gregCal = Calendar(identifier: .gregorian)
        var gCal = gregCal
        gCal.timeZone = timeZone
        let dateComp = gCal.dateComponents([.year, .month, .day], from: instant.date)
        let fixedDay = FixedDay.fromGregorian(
            year: dateComp.year ?? 2026,
            month: dateComp.month ?? 1,
            day: dateComp.day ?? 1
        )
        
        let msCoord = MetaSolarEngine.coordinate(forFixedDay: fixedDay)
        let msDisplay = MetaSolarEngine.displayString(for: msCoord)
        let msSubtitle = MetaSolarEngine.subtitle(for: msCoord)
        
        let msCoordinate = CalendarCoordinate(
            calendarSystemID: .metaSolar,
            year: MetaSolarEngine.devEpochYear + Int((fixedDay - MetaSolarEngine.devEpochFixedDay) / 365),
            month: 1, day: 1, isLeapMonth: false,
            extraFields: ["coordinate": String(describing: msCoord)]
        )
        
        projections.append(CalendarProjection(
            calendarSystemID: .metaSolar,
            rulesetID: MetaSolarEngine.profile.id,
            coordinate: msCoordinate,
            displayString: msDisplay,
            subtitle: msSubtitle,
            status: MetaSolarEngine.profile.status,
            provenance: "\(MetaSolarEngine.profile.id) · Arithmetic 13×28 · Epoch: Jan 1, 2000 CE"
        ))
        
        // 2. Gregorian
        projections.append(GregorianAdapter.project(instant: instant, timeZone: timeZone))
        
        // 3. Chinese
        projections.append(ChineseAdapter.project(instant: instant, timeZone: timeZone))
        
        // 4. Hijri
        projections.append(HijriAdapter.project(instant: instant, timeZone: timeZone, profile: ruleset.hijriProfile))
        
        // 5. Javanese
        projections.append(JavaneseAdapter.project(instant: instant, timeZone: timeZone, profile: ruleset.javaneseProfile))
        
        // Sort by display order
        let ordered = ruleset.displayOrder.compactMap { id in
            projections.first { $0.calendarSystemID == id }
        } + projections.filter { proj in
            !ruleset.displayOrder.contains { $0 == proj.calendarSystemID }
        }
        
        // Astronomy
        let astronomy = computeAstronomy(instant: instant, timeZone: timeZone, location: location)
        
        return ProjectionBundle(
            context: CalculationContext(
                instant: instant,
                timeZoneIdentifier: timeZone.identifier,
                location: location,
                localeIdentifier: "en_US",
                rulesetSelection: ruleset
            ),
            projections: ordered,
            astronomy: astronomy,
            warnings: warnings
        )
    }
    
    /// Compute astronomy data if location is available
    private static func computeAstronomy(instant: Instant, timeZone: TimeZone, location: GeoPoint?) -> AstronomyData? {
        let jd = AstronomyEngine.julianDay(from: instant.date)
        let solarLong = AstronomyEngine.solarLongitude(julianDay: jd)
        let solarTerm = AstronomyEngine.currentSolarTerm(longitude: solarLong)
        let moonPhase = AstronomyEngine.lunarPhase(julianDay: jd)
        let moonInfo = AstronomyEngine.moonPhaseInfo(phase: moonPhase)
        
        var sunrise: Date? = nil
        var sunset: Date? = nil
        
        if let loc = location {
            let (sr, ss) = AstronomyEngine.sunRiseSet(
                date: instant.date,
                latitude: loc.latitude,
                longitude: loc.longitude,
                timeZone: timeZone
            )
            sunrise = sr
            sunset = ss
        }
        
        return AstronomyData(
            solarLongitude: solarLong,
            solarTerm: solarTerm,
            moonPhase: moonPhase,
            moonPhaseName: moonInfo.name,
            moonPhaseEmoji: moonInfo.emoji,
            moonIllumination: moonInfo.illumination,
            sunrise: sunrise,
            sunset: sunset,
            provenance: "\(AstronomyEngine.providerID) v\(AstronomyEngine.version) · Error: \(AstronomyEngine.expectedErrorEnvelope)"
        )
    }
    
    // MARK: - Resolution (source calendar coordinate → target projections)
    
    static func resolve(
        sourceSystem: CalendarSystemID,
        year: Int, month: Int, day: Int,
        timeZone: TimeZone,
        ruleset: RulesetSelection
    ) -> [CalendarProjection] {
        // Convert source coordinate to fixed day
        let fixedDay: Int64?
        
        switch sourceSystem {
        case .gregorian:
            fixedDay = FixedDay.fromGregorian(year: year, month: month, day: day)
        case .metaSolar:
            let coord = MetaSolarDayCoordinate.monthDay(year: year, month: month, day: day)
            fixedDay = MetaSolarEngine.fixedDay(for: coord)
        case .hijri:
            fixedDay = HijriAdapter.fixedDayFromHijri(year: year, month: month, day: day)
        case .chinese:
            // Use Foundation to resolve Chinese date
            var cal = Calendar(identifier: .chinese)
            cal.timeZone = timeZone
            let dateComp = DateComponents(year: year, month: month, day: day)
            if let date = cal.date(from: dateComp) {
                let gCal = Calendar(identifier: .gregorian)
                var g = gCal
                g.timeZone = timeZone
                let gc = g.dateComponents([.year, .month, .day], from: date)
                fixedDay = FixedDay.fromGregorian(year: gc.year ?? year, month: gc.month ?? month, day: gc.day ?? day)
            } else {
                fixedDay = nil
            }
        case .javanese:
            // For Javanese, we need to find the fixed day from wuku/weton
            // Simplified: use the wuku/weton as an offset from the anchor
            fixedDay = JavaneseAdapter.anchorFixedDayPublic + Int64(day)  // simplified
        }
        
        guard let fd = fixedDay else { return [] }
        
        // Re-project from fixed day
        let (gy, gm, gd) = FixedDay.toGregorian(fd)
        let instant = Instant()
        // Create a date at noon to avoid DST edge cases
        var gCal = Calendar(identifier: .gregorian)
        gCal.timeZone = timeZone
        let dateComponents = DateComponents(year: gy, month: gm, day: gd, hour: 12)
        let resolvedDate = gCal.date(from: dateComponents) ?? Date()
        
        return project(
            instant: Instant(resolvedDate),
            timeZone: timeZone,
            location: nil,
            ruleset: ruleset
        ).projections
    }
}
