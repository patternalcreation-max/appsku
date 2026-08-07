# Meta Calendar Design Principles
Vom Operator wejangan, 2026-08-07.

These principles govern ALL milestones from M2 onward.

1. **Build self-auditing** — BuildManifest in bundle, CI verifies IPA = source
2. **Four astronomy origins** — algorithmic/authoritativeCatalog/approximateTable/observedFeed (not just EpistemicClass)
3. **Accuracy Registry** — every claim backed by measured error (sample count, max/median, reference dataset)
4. **Time scales separated** — UTC (display), JD (calculation), TT (ephemeris), UT1 (Earth rotation), ΔT model
5. **SwiftAA: integrate later, spike now** — use as differential oracle in tests/nightly CI first
6. **Astronomy invariants** — illumination 0...1, phase normalized, no double events, TZ-independent globals
7. **M3 persistence isolates domain** — @Model only in data layer, domain stays immutable, versioned schema
8. **MetaEvent identity stable** — canonical ID from kind+instant+frame+origin+methodVersion, not translation
9. **No metaphysics in astronomy core** — Physical fact → Calendar projection → Traditional interpretation → Symbolic lens → Personal reflection
10. **Release pipeline checks final artifact** — reopen IPA, assert version/icon/no-coverage/manifest, record SHAs
11. **Release hygiene** — strip, dSYM separate, no leaked CI paths
12. **Milestone discipline** — one milestone per batch, gated, never merge M2+M3+M4
