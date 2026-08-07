import Foundation

// MARK: - Astronomy Engine (per blueprint §9)
//
// Implements:
// - Solar longitude (simplified Meeus algorithm)
// - Lunar phase calculation
// - Sunrise/sunset (simplified)
// - Solar terms (24 Jieqi) via solar longitude
//
// This is a standard-accuracy embedded provider. Results carry accuracy metadata.

enum AstronomyEngine {
    
    static let providerID = "astronomy.embedded-standard-v1"
    static let version = "1.0.0"
    static let expectedErrorEnvelope = "±0.3° solar longitude, ±0.1 day lunar phase"
    
    // MARK: - Solar Longitude (simplified VSOP87)
    
    /// Calculate solar longitude (λ☉) in degrees [0, 360) for a given Julian Day
    /// Based on simplified Meeus formula (good to ~0.01° for modern dates)
    static func solarLongitude(julianDay: Double) -> Double {
        let T = (julianDay - 2451545.0) / 36525.0  // Julian centuries from J2000
        
        // Mean longitude of the Sun
        let L0 = 280.46646 + 36000.76983 * T + 0.0003032 * T * T
        
        // Mean anomaly of the Sun
        let M = 357.52911 + 35999.05029 * T - 0.0001537 * T * T
        
        // Eccentricity of Earth's orbit
        // let e = 0.016708634 - 0.000042037 * T - 0.0000001267 * T * T
        
        // Sun's equation of center
        let M_rad = M * .pi / 180.0
        let C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * sin(M_rad)
              + (0.019993 - 0.000101 * T) * sin(2 * M_rad)
              + 0.000289 * sin(3 * M_rad)
        
        // True longitude
        let trueLong = L0 + C
        
        // Normalize to [0, 360)
        return trueLong.truncatingRemainder(dividingBy: 360.0) + (trueLong < 0 ? 360 : 0)
    }
    
    // MARK: - Lunar Phase
    
    /// Calculate moon phase as a fraction [0, 1) where 0 = new moon
    static func lunarPhase(julianDay: Double) -> Double {
        // Mean synodic month
        let synodicMonth = 29.530588853
        
        // Known new moon: 2000-01-06 18:14 UTC = JD 2451550.1
        let knownNewMoon = 2451550.1
        
        let phase = ((julianDay - knownNewMoon) / synodicMonth).truncatingRemainder(dividingBy: 1.0)
        return phase < 0 ? phase + 1 : phase
    }
    
    /// Get moon phase name and emoji
    static func moonPhaseInfo(phase: Double) -> (name: String, emoji: String, illumination: Double) {
        let illumination = (1 - cos(phase * 2 * .pi)) / 2  // 0 = new, 1 = full
        
        switch phase {
        case 0..<0.03, 0.97...1:
            return ("New Moon", "🌑", illumination)
        case 0.03..<0.22:
            return ("Waxing Crescent", "🌒", illumination)
        case 0.22..<0.28:
            return ("First Quarter", "🌓", illumination)
        case 0.28..<0.47:
            return ("Waxing Gibbous", "🌔", illumination)
        case 0.47..<0.53:
            return ("Full Moon", "🌕", illumination)
        case 0.53..<0.72:
            return ("Waning Gibbous", "🌖", illumination)
        case 0.72..<0.78:
            return ("Last Quarter", "🌗", illumination)
        case 0.78..<0.97:
            return ("Waning Crescent", "🌘", illumination)
        default:
            return ("New Moon", "🌑", illumination)
        }
    }
    
    // MARK: - Sunrise/Sunset (simplified NOAA algorithm)
    
    /// Calculate sunrise and sunset times for a given date and location
    /// Returns nil if the sun doesn't rise/set (polar regions)
    static func sunRiseSet(
        date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone
    ) -> (sunrise: Date?, sunset: Date?) {
        let cal = Calendar(identifier: .gregorian)
        var calendar = cal
        calendar.timeZone = timeZone
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        
        // Solar declination (approximate)
        let gamma = 2 * .pi / 365.0 * Double(dayOfYear - 1)
        let declination = 0.006918 - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2*gamma) + 0.000907 * sin(2*gamma)
            - 0.002697 * cos(3*gamma) + 0.00148 * sin(3*gamma)
        
        let latRad = latitude * .pi / 180.0
        let cosHourAngle = -tan(latRad) * tan(declination)
        
        // No sunrise/sunset in polar regions
        guard abs(cosHourAngle) <= 1.0 else {
            if cosHourAngle < -1 {
                // Midnight sun — sun is always up
                return (date, date)
            } else {
                // Polar night
                return (nil, nil)
            }
        }
        
        let hourAngle = acos(cosHourAngle) * 180.0 / .pi / 15.0  // hours
        
        // Solar noon (approximate)
        let longitudeHours = longitude / 15.0
        let solarNoon = 12.0 - longitudeHours + timeZone.secondsFromGMT() / 3600.0
        
        let sunriseHour = solarNoon - hourAngle
        let sunsetHour = solarNoon + hourAngle
        
        // Convert to Date
        let startOfDay = calendar.startOfDay(for: date)
        
        let sunrise = calendar.date(byAdding: .second, value: Int(sunriseHour * 3600), to: startOfDay)
        let sunset = calendar.date(byAdding: .second, value: Int(sunsetHour * 3600), to: startOfDay)
        
        return (sunrise, sunset)
    }
    
    // MARK: - Julian Day from Date
    
    static func julianDay(from date: Date) -> Double {
        return date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }
    
    // MARK: - Solar Term from Solar Longitude
    
    /// Get the current solar term based on solar longitude
    static func currentSolarTerm(longitude: Double) -> String {
        let terms = [
            (0, "春分 Spring Equinox"), (15, "清明 Pure Brightness"),
            (30, "穀雨 Grain Rain"), (45, "立夏 Start of Summer"),
            (60, "小滿 Grain Buds"), (75, "芒種 Grain in Ear"),
            (90, "夏至 Summer Solstice"), (105, "小暑 Minor Heat"),
            (120, "大暑 Major Heat"), (135, "立秋 Start of Autumn"),
            (150, "處暑 End of Heat"), (165, "白露 White Dew"),
            (180, "秋分 Autumn Equinox"), (195, "寒露 Cold Dew"),
            (210, "霜降 Frost's Descent"), (225, "立冬 Start of Winter"),
            (240, "小雪 Minor Snow"), (255, "大雪 Major Snow"),
            (270, "冬至 Winter Solstice"), (285, "小寒 Minor Cold"),
            (300, "大寒 Major Cold"), (315, "立春 Start of Spring"),
            (330, "雨水 Rain Water"), (345, "驚蟄 Awakening of Insects"),
        ]
        
        var current = terms[0]
        for (deg, name) in terms {
            if longitude >= Double(deg) {
                current = (deg, name)
            }
        }
        return current.name
    }
}
