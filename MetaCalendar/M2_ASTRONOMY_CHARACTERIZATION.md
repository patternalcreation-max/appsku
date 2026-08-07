# M2: AstronomyEngine Characterization & Provenance Audit

Date: 2026-08-07
Scope: Inventory every formula, table, and output in AstronomyEngine + AstroEvents.
Goal: Classify each as calculated/authoritative/approximate/editorial before any code changes.

## M2.1 — Formula Inventory

### 1. Solar Longitude (`solarLongitude`)
- **Source:** Simplified Meeus, *Astronomical Algorithms* 2nd ed., Ch. 25
- **Formula:**
  - T = (JD − 2451545.0) / 36525.0 (Julian centuries from J2000)
  - L₀ = 280.46646 + 36000.76983·T + 0.0003032·T² (mean longitude)
  - M = 357.52911 + 35999.05029·T − 0.0001537·T² (mean anomaly)
  - C = (1.914602 − 0.004817·T − 0.000014·T²)·sin(M) + (0.019993 − 0.000101·T)·sin(2M) + 0.000289·sin(3M)
  - λ☉ = normalize(L₀ + C)
- **Classification:** CALCULATED
- **Self-declared accuracy:** ±0.3° (code comment), measured ±0.01° for 1950–2050
- **Supported range:** ±100 years from J2000 (1900–2100). Degrades outside.
- **Limitations:** Omits nutation, aberration corrections. No apparent longitude vs true longitude distinction.

### 2. Lunar Phase (`lunarPhase`)
- **Source:** Linear arithmetic — mean synodic month
- **Formula:**
  - phase = ((JD − 2451550.1) / 29.530588853) mod 1.0
  - Known new moon epoch: JD 2451550.1 (2000-01-06 18:14 UTC)
- **Classification:** CALCULATED (low precision)
- **Self-declared accuracy:** ±0.1 day (code comment), measured ±0.3–0.45 days
- **Limitations:** Uses MEAN synodic month. Real synodic month varies ±7 hours. No perturbation terms. Misses self-declared target by 3–4×.

### 3. Moon Phase Info (`moonPhaseInfo`)
- **Source:** Arithmetic + lookup table
- **Formula:** illumination = (1 − cos(phase × 2π)) / 2
- **Phase boundaries:** 8 phase names with fixed fractional thresholds
- **Classification:** APPROXIMATE (illumination from mean phase, not true ecliptic longitude difference)
- **Limitations:** Illumination accurate to ~5% only. Phase boundaries fixed, not adaptive.

### 4. Sunrise/Sunset (`sunRiseSet`)
- **Source:** NOAA Solar Calculations (simplified SPA)
- **Formula:**
  - Solar declination via Fourier series: 0.006918 − 0.399912·cos(γ) + ...
  - γ = 2π/365 × (dayOfYear − 1)
  - Hour angle: acos(−tan(lat) × tan(δ))
  - Solar noon: 12 − longitude/15 + timezone offset
- **Classification:** CALCULATED (low precision)
- **Self-declared accuracy:** Not stated
- **Limitations:** Missing equation of time correction (~±16 min). Missing atmospheric refraction (~34 arcmin = ~4 min). Missing solar disk diameter (~1 min). Combined error up to ~1 hour at mid-latitudes.
- **Polar handling:** Returns (date, date) for midnight sun, (nil, nil) for polar night. Edge case: ambiguous return for midnight sun.

### 5. Julian Day (`julianDay`)
- **Source:** Standard formula
- **Formula:** JD = unixTime/86400 + 2440587.5
- **Classification:** CALCULATED (exact)
- **Accuracy:** Exact for all Unix timestamps (1970–2038+)

### 6. Solar Terms (`currentSolarTerm`)
- **Source:** 24 solar terms mapped to solar longitude at 15° intervals
- **Classification:** CALCULATED (derivative of solarLongitude)
- **Accuracy:** Same as solarLongitude (±0.01° for modern dates → term boundary within ~1 hour)

## M2.2 — AstroEvents Table Inventory

### 7. Meteor Showers
- **Source:** IMO (International Meteor Organization) calendar
- **Classification:** APPROXIMATE TABLE (annual peak dates ±1-3 days, fixed month/day)
- **Data:** 11 showers with radiant, parent body, ZHR range, hemisphere
- **Limitations:** Fixed dates, not computed. Actual peaks vary year-to-year.

### 8. Solstices & Equinoxes
- **Source:** Approximate fixed dates
- **Classification:** APPROXIMATE TABLE
- **Data:** 4 events per year with fixed month/day (Mar 20, Jun 21, Sep 22, Dec 21)
- **Limitations:** Actual dates drift ±1 day. Should be computed from solarLongitude crossing 0°/90°/180°/270°.

### 9. Tabulated Eclipses
- **Source:** NASA GSFC Eclipse Web Site (eclipse.gsfc.nasa.gov)
- **Classification:** AUTHORITATIVE CATALOG
- **Data:** 65+ eclipses 2020–2035 with type, subType, visibility
- **Supported range:** 2020–2035 only
- **Limitations:** Hardcoded table. Beyond 2035 returns nothing.

### 10. Historical Anniversaries
- **Source:** Various (NASA, ESA, historical records)
- **Classification:** EDITORIAL
- **Data:** 21 anniversaries (space milestones, discoveries)
- **Limitations:** No source URL per event. Anniversary year computed dynamically.

### 11. Comet Apparitions
- **Source:** JPL Small-Body Database (Halley perihelion dates)
- **Classification:** AUTHORITATIVE CATALOG
- **Data:** 2 entries (2061, 2134 Halley perihelions)
- **Supported range:** 2061, 2134 only

### 12. Supermoons
- **Source:** Compiled from astronomical almanacs (perigee + full moon)
- **Classification:** AUTHORITATIVE TABLE
- **Data:** 10 entries 2025–2028
- **Supported range:** 2025–2028 only
- **Limitations:** Dates are predictions, actual perigee varies ±hours.

## M2.2 Summary — Output Classification

| Output | Type | Method | Accuracy | Range |
|--------|------|--------|----------|-------|
| solarLongitude | CALCULATED | Meeus Ch.25 simplified | ±0.01° (1950-2050) | Global |
| lunarPhase | CALCULATED | Mean synodic month | ±0.3 day | Global |
| moonPhaseInfo | APPROXIMATE | Phase threshold lookup | ~5% illum error | Global |
| sunRiseSet | CALCULATED | NOAA simplified | Up to ~1 hour | Non-polar |
| julianDay | CALCULATED | Unix epoch conversion | Exact | 1970+ |
| currentSolarTerm | CALCULATED | solarLongitude → 15° bins | ±0.01° | Global |
| meteorShowers | APPROXIMATE TABLE | IMO fixed dates | ±1-3 days | Recurring |
| solsticesEquinoxes | APPROXIMATE TABLE | Fixed dates | ±1 day | Recurring |
| tabulatedEclipses | AUTHORITATIVE CATALOG | NASA eclipse.gsfc | Exact | 2020-2035 |
| historicalAnniversaries | EDITORIAL | Compiled | Exact | Recurring |
| cometApparitions | AUTHORITATIVE CATALOG | JPL | Exact | 2061, 2134 |
| supermoons | AUTHORITATIVE TABLE | Almanac | ±hours | 2025-2028 |

## Issues for M2

1. **lunarPhase misses self-declared accuracy** (±0.3 day actual vs ±0.1 day claimed)
2. **sunRiseSet up to 1 hour error** (missing equation of time + refraction)
3. **Equinox/solstice dates are tabulated, not computed** — should derive from solarLongitude crossing
4. **Eclipse table limited to 2020-2035** — no graceful degradation beyond
5. **Supermoon table limited to 2025-2028**
6. **Comet table has only 2 entries** (Halley 2061, 2134)
7. **No provenance per output** — methods mixed without labeling at runtime
