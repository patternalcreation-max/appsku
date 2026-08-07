import XCTest
@testable import MetaCalendar

/// Evidence that all expansion feature flags default to OFF.
/// Required by M1.4: "feature flags default OFF until each milestone gate passes."
final class FeatureFlagTests: XCTestCase {

    func test_all_flags_off_by_default() {
        let flags = FeatureFlags.allOff

        // M3
        XCTAssertFalse(flags.universalEventsV2, "universalEventsV2 must default OFF")
        // M4
        XCTAssertFalse(flags.alignmentDSL, "alignmentDSL must default OFF")
        // M5
        XCTAssertFalse(flags.goodDay, "goodDay must default OFF")
        XCTAssertFalse(flags.symbolicLenses, "symbolicLenses must default OFF")
        // M6
        XCTAssertFalse(flags.chronicle, "chronicle must default OFF")
        XCTAssertFalse(flags.auraPortrait, "auraPortrait must default OFF")
        XCTAssertFalse(flags.patternLab, "patternLab must default OFF")
        // M7
        XCTAssertFalse(flags.locationProvider, "locationProvider must default OFF")
        XCTAssertFalse(flags.notifications, "notifications must default OFF")
        XCTAssertFalse(flags.eventKitExport, "eventKitExport must default OFF")
        XCTAssertFalse(flags.spaceWeather, "spaceWeather must default OFF")
    }

    func test_default_initializer_matches_allOff() {
        let defaultFlags = FeatureFlags()
        let explicitOff = FeatureFlags.allOff
        XCTAssertEqual(defaultFlags, explicitOff,
                       "FeatureFlags() must equal FeatureFlags.allOff")
    }

    func test_all_eleven_flags_exist() {
        // Ensure no flag was accidentally removed during refactoring.
        // Count all Bool properties via Mirror.
        let flags = FeatureFlags.allOff
        let mirror = Mirror(reflecting: flags)
        let boolChildren = mirror.children.filter { 
            $0.value as? Bool != nil 
        }
        XCTAssertEqual(boolChildren.count, 11,
                       "FeatureFlags must have exactly 11 flag properties")
    }
}
