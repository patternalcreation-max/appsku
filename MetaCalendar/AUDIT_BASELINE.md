# Source Baseline Audit — Meta Calendar v2.0.0

Date: 2026-08-07
Auditor: SUPERAGENT (source author)
Tag: `metacalendar-v2.0.0`
Commit: `35aaf4b` (main branch)

## 1. Source truth

- Repository: `patternalcreation-max/appsku` (monorepo)
- Subfolder: `MetaCalendar/`
- Source: 23 Swift files, 5,560 lines
- Git proxy: `/root/k3-calculator/` → pushes to `git@github.com:patternalcreation-max/appsku.git`
- Working tree: clean (no uncommitted owner changes)

## 2. Build environment

- Runner: GitHub Actions `macos-15`
- Xcode: 16.0 (latest available on runner)
- SDK: iPhoneOS 18.0
- Swift: 5.0 (project setting)
- Deployment target: iOS 17.0
- Code signing: DISABLED (unsigned IPA)
- Required build flags: `-destination 'generic/platform=iOS'`, `ARCHS=arm64`, `ASSETCATALOG_COMPILER_SKIP_VALIDATION=YES` (workaround for Xcode 16 actool simulator-runtime bug on macos-15 runners)

## 3. Project structure

```
MetaCalendar/
  project.yml                    # XcodeGen spec
  apps.json                      # Sideload manifest
  App/
    MetaCalendarApp.swift        # 113 lines — 5-tab TabView + settings gear
    Core/
      CalendarTypes.swift        # 274 lines — FixedDay (CC4 RD), Instant, CalendarCoordinate, CalendarProjection, ProjectionStatus, TimeZoneMode, RulesetSelection, GeoPoint, CalculationContext
      GregorianAdapter.swift     # 55 lines — Foundation bridge
      MetaSolarEngine.swift      # 222 lines — 13×28 calendar, MetaSolarDayCoordinate enum
      HijriAdapter.swift         # 161 lines — Tabular + Umm al-Qura
      ChineseAdapter.swift       # 129 lines — Foundation + 24 solar terms + sexagenary
      JavaneseAdapter.swift      # 228 lines — Anchor 17 Aug 1945 = Jumat Legi, wuku, neptu
      AstronomyEngine.swift      # 174 lines — Solar longitude, lunar phase, sunrise/sunset
      CalendarEngine.swift       # 199 lines — Orchestrator, project(), resolve(), ProjectionBundle, AstronomyData
      CalendarEvents.swift       # 512 lines — EventCategory, CalendarEvent struct, eventsForMonth(), notableUpcoming()
      WorldEvents.swift          # 349 lines — Global observances, sport, eclipses (v1.3.0)
      AstroEvents.swift          # 337 lines — NASA eclipse catalog, meteor, historical anniversaries (v1.4.0)
      AlignmentFinder.swift      # 262 lines — 11 condition types, async search, cycleRealignment
    Views/
      Theme.swift                # 546 lines — Meta design system, AppState (@Observable), MetaCard, MetaProjectionCard, MetaProvenanceSheet, MetaBackground, OrbitHero, DayStepper, MetaInfoRow
      TodayView.swift            # 107 lines — Tab 1 (Sekarang)
      CalendarGridView.swift     # 326 lines — Tab 2 (Kalender)
      ExploreView.swift          # 116 lines — Conversion tool
      AlignmentView.swift        # 335 lines — Tab 3a (Selaras)
      TimeRingsView.swift        # 217 lines — Tab 4a (Cincin)
      CycleLabView.swift         # 170 lines — Tab 4b (Siklus)
      TimelineView.swift         # 304 lines — Event timeline
      CosmicSignatureView.swift  # 257 lines — Tab 5a (Sidik)
      SettingsView.swift         # 167 lines — Settings sheet
  App/Assets.xcassets/           # AppIcon only
```

## 4. Navigation map

| Tab | Label | View |
|-----|-------|------|
| 1 | Sekarang | TodayView |
| 2 | Kalender | CalendarGridView |
| 3 | Selaras | AlignmentView |
| 4 | Kosmos | TimelineView + TimeRingsView + CycleLabView |
| 5 | Diri | CosmicSignatureView |
| — | Settings | SettingsView (sheet via gear icon) |

## 5. Persistence

**Current state: NONE.** No SwiftData, Core Data, UserDefaults, or @AppStorage usage.
AppState is `@Observable` (in-memory only). All state resets on app relaunch.
- Location defaults to Jakarta (-6.2088, 106.8456)
- Timezone defaults to `.autoupdatingCurrent`
- Ruleset defaults to `.default`
- No user preferences persisted

## 6. Calendar profiles

| System | Profile ID | Ruleset ID | Status | Algorithm |
|--------|-----------|-----------|--------|-----------|
| MetaSolar-13 | `metasolar13.dev-v2` | `dev-v2` | experimental | 13×28 + bridge day, epoch Jan 1 2000 |
| Gregorian | `gregorian.standard` | `standard` | computed | Foundation Calendar |
| Chinese | `chinese.foundation` | `foundation` | computed | Foundation .chinese Calendar |
| Hijri | `hijri.ummalqura` | `ummalqura` | computed | Foundation .islamicUmmAlQura + tabular fallback |
| Javanese | `javanese.legacy` | `legacy` | computed | Anchor 17 Aug 1945 = Jumat Legi, modular arithmetic |

## 7. Astronomy methods

| Method | Provider | Version | Source | Accuracy |
|--------|---------|---------|--------|----------|
| Solar longitude | `astronomy.embedded-standard-v1` | `1.0.0` | Simplified VSOP | ±0.3° |
| Lunar phase | `astronomy.embedded-standard-v1` | `1.0.0` | Mean lunar elongation | ±0.1 day |
| Sunrise/sunset | `astronomy.embedded-standard-v1` | `1.0.0` | NOAA solar calculator | ±2 min |
| Julian Day | `astronomy.embedded-standard-v1` | `1.0.0` | Standard formula | exact |

## 8. Event datasets

| Source | Events | Range | Type |
|--------|--------|-------|------|
| CalendarEvents.swift | ~80 | perpetual | Religious, cultural, national observances |
| WorldEvents.swift | ~40 | 2024-2030 | Global observances, sport, eclipses |
| AstroEvents.swift | ~60 | 2020-2061 | NASA eclipses, meteor showers, anniversaries, supermoons |

## 9. FixedDay algorithm

- System: Rata Die (RD) from "Calendrical Calculations" (Reingold & Dershowitz, CC4)
- Epoch: Jan 1, 1 CE (Gregorian proleptic) = RD 1
- `fromGregorian` / `toGregorian` — exact CC4 formulas
- `weekday(fd)` → 0=Sunday ... 6=Saturday
- `toJulianDayNumber(fd)` → JDN for astronomy

## 10. Alignment Finder behavior

- 11 condition types: weekday, pasaran, moonPhase, metaSolarMonth, metaSolarDay, hijriMonth, hijriDay, chineseLunarMonth, seasonalMarker, bridgeDay, weton
- Search: iterate day-by-day from start date, up to 50 years
- Realignment: LCM of cycle lengths
- `cycleRealignment(days:)` returns LCM via `reduce(lcm)`
- `gcd` and `lcm` static helpers

## 11. Signing status

- **UNSIGNED.** No code signature, no provisioning profile in the IPA.
- GitHub Actions CI builds unsigned `.app` → zips to `.ipa`
- Installation requires sideload via Feather/KSign/ESign or similar
- No TestFlight or App Store distribution configured

## 12. Tests

- **NONE.** No test targets exist.
- No `MetaCalendarTests/` or `MetaCalendarUITests/` directories
- CI only verifies compilation success (xcodebuild build)

## 13. Known issues

1. ~~Settings shows "Meta Calendar v1.2.0"~~ → FIXED (now reads from bundle)
2. WorldEventsView.swift deleted (dead code, replaced by TimelineView)
3. actool requires `ASSETCATALOG_COMPILER_SKIP_VALIDATION=YES` on macos-15 CI
4. MetaSolar epoch alignment may drift over centuries (dev profile, not scientifically calibrated)
5. Javanese wuku list incomplete (30 of 210 wuku names)
6. No persistence — all user preferences lost on relaunch
7. No test suite

## 14. Differences from IPA audit

- IPA audit found `v1.2.0` string → confirmed and fixed in source
- IPA audit found Xcode 16.4 → CI uses Xcode 16.0 (runner latest)
- IPA audit found SDK 18.5 → CI builds with SDK 18.0 (runner latest)
- No discrepancies in features or architecture

## 15. Reproducibility

```bash
# Clone repo
git clone git@github.com:patternalcreation-max/appsku.git
cd appsku/MetaCalendar

# Generate Xcode project
brew install xcodegen && xcodegen generate

# Build (unsigned)
xcodebuild build \
  -project MetaCalendar.xcodeproj \
  -scheme MetaCalendar \
  -sdk iphoneos \
  -configuration Release \
  -derivedDataPath build \
  -destination 'generic/platform=iOS' \
  ARCHS=arm64 \
  ASSETCATALOG_COMPILER_SKIP_VALIDATION=YES \
  CODE_SIGNING_ALLOWED=NO \
  DEVELOPMENT_TEAM=""

# Package IPA
mkdir -p build/Payload
cp -r $(find build/Build/Products -name "*.app") build/Payload/
cd build && zip -r MetaCalendar.ipa Payload
```

CI workflow: `.github/workflows/build-metacalendar.yml`
Tag release: `metacalendar-v2.0.0` → IPA at GitHub Releases
