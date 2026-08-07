# ADR: Astronomy Provider Decision

Date: 2026-08-07
Status: PROPOSED (pending operator approval)
Decision: HYBRID

## Context

Meta Calendar's AstronomyEngine uses simplified formulas:
- Solar longitude: ±0.01° (Meeus Ch.25 simplified) — GOOD for calendar use
- Lunar phase: ±0.3 days (mean synodic month) — BAD, misses own ±0.1d target
- Sunrise/sunset: up to ~1 hour error — BAD (missing equation of time + refraction)
- Equinox/solstice: fixed dates ±1 day — should be computed

SwiftAA v3.0.0 (MIT, iOS 13+) offers:
- Solar longitude: sub-arcsecond (VSOP87 full)
- Lunar phase: arcsecond-level (ELP/MPP02 full)
- Sunrise/sunset: includes refraction, equation of time
- BUT: +3-8 MB binary (current IPA = 634 KB → 5-12× increase)
- BUT: 4 open rise/set bugs (#128, #104, #101, #124)
- BUT: No polar test coverage in SwiftAA suite

## Options

### Option A: KEEP (stay with existing embedded engine)
- **Pros:** Zero binary size increase. No new dependencies. Already tested (56 tests). Works offline.
- **Cons:** Lunar phase ±0.3d (misses target). Sunrise ±1h. Fixed equinox dates. No path to precision without rewrite.
- **When to choose:** If binary size is critical AND calendar accuracy is "good enough" for cultural/traditional use.

### Option B: REPLACE (switch to SwiftAA)
- **Pros:** Best accuracy (sub-arcsecond solar, arcsecond lunar). Full VSOP87/ELP. Refraction in sunrise.
- **Cons:** +3-8 MB binary (634 KB → ~5 MB). 4 open rise/set bugs. C++17 + libc++ dependency. xcodegen must handle SPM package. No polar tests.
- **When to choose:** If precision is the product's core value AND binary size is acceptable.

### Option C: HYBRID (recommended) ✅
- **Pros:**
  - Keep existing engine as default (zero binary increase)
  - Improve specific weak spots without full replacement:
    1. Fix sunrise/sunset: add equation of time + refraction correction (pure Swift, ~50 LOC, no dependency)
    2. Improve lunar phase: add 2-3 Meeus perturbation terms (pure Swift, ~30 LOC)
    3. Compute equinox/solstice from solar longitude crossing (already have the function)
  - Defer SwiftAA until M7 (native adapters) when location-based precision matters more
  - If SwiftAA is needed later, the AstronomyProviding protocol + provider pattern makes swap clean
- **Cons:** More work than KEEP, less precision than REPLACE. But addresses the 3 worst accuracy issues without any dependency.
- **When to choose:** When you want measurable accuracy improvements without 5× binary bloat.

## Decision: HYBRID

1. **M2 (now):** Add provenance to existing engine (DONE). Characterize all outputs (DONE).
2. **M2 follow-up:**
   - Fix sunrise/sunset equation of time + refraction (pure Swift, no dependency)
   - Add lunar phase correction terms (Meeus Ch.47, top 3 terms)
   - Compute equinox/solstice from solar longitude crossing (not fixed dates)
3. **M7 (deferred):** Evaluate SwiftAA again when:
   - Location-aware features (CoreLocation) need per-user precision
   - Binary size budget allows 3-8 MB addition
   - SwiftAA rise/set bugs are fixed (#128, #104, #101)

## Rationale

The hybrid approach fixes the 3 worst accuracy problems (sunrise ±1h, lunar phase ±0.3d, fixed equinox dates) with ~100 LOC of pure Swift — no dependency, no binary increase, no C++ toolchain complexity. SwiftAA's 1000× better lunar precision matters for scientific applications, but Meta Calendar's lunar use case is cultural/traditional (pasaran, weton), where ±0.3 days → ±0.05 days is sufficient improvement.

SwiftAA's binary cost (5-12× increase) and rise/set bugs make it premature now. Re-evaluate at M7 when location precision matters.

## Falsification criteria

This decision is WRONG if:
1. Users report incorrect lunar dates after hybrid improvement (→ need SwiftAA)
2. Sunrise/sunset is still >15 min off after equation-of-time fix (→ need SwiftAA)
3. A new release of SwiftAA fixes all 4 rise/set bugs (→ reconsider REPLACE)
