# FixedDay Semantic Impact Audit — v2.1.1 → v2.1.2

Date: 2026-08-07
Bug: `FixedDay.fromGregorian` had a constant +367-day offset from correct Rata Die values.
Cause: Wrong month-term formula `(367*adjustedM - 362)/12` produced incorrect values for all dates.
Fix: Replaced with explicit cumulative-days lookup table + leap-year adjustment.

## Offset analysis

The old formula produced values 367 higher than correct RD for ALL dates.
This constant offset has these modular effects:

| Cycle | Modulus | Offset (367 mod m) | Impact |
|-------|---------|-------------------|--------|
| Weekday | 7 | 3 | All weekdays shifted 3 days |
| Pasaran | 5 | 2 | Pasaran shifted 2 positions (but self-corrected via anchor) |
| Weton | 35 | 17 | Weton index shifted (but self-corrected via anchor) |
| Wuku | 210 | 157 | Wuku shifted (but self-corrected via anchor) |

## Affected components (user-visible errors in v1.0.0–v2.1.0)

### 1. Hijri dates — WRONG
`HijriAdapter.epochFixedDay` is hardcoded at 227015 (CC4 value).
With +367 offset, `hijriFromFixedDay(fd)` received inflated fixed days,
producing incorrect Hijri year/month/day.

**Before:** Jan 1, 2024 → FD 738595 → Hijri ~1445/6/19
**After:** Jan 1, 2024 → FD 738228 → Hijri ~1445/6/19 (correct)
(Difference: ~367 days / 30 = ~12 Hijri days off)

### 2. Javanese saptawara (weekday) — WRONG
`saptawaraIndex(fixedDay) = FixedDay.weekday(fixedDay)`
No anchor compensation. Weekday shifted by 3.

**Before:** 17 Aug 1945 → weekday 1 = Senin (Monday) — WRONG
**After:** 17 Aug 1945 → weekday 5 = Jumat (Friday) — CORRECT

### 3. Javanese weton names — WRONG
`wetonName(saptawara:pasaran:)` used wrong saptawara index.
All weton names were wrong by 3 weekday positions.

**Before:** 17 Aug 1945 → "Senin Legi" — WRONG (should be Jumat Legi)
**After:** 17 Aug 1945 → "Jumat Legi" — CORRECT

### 4. Javanese neptu — WRONG
`saptawaraNeptu[sapta]` used wrong saptawara index.
Total neptu values were wrong.

### 5. AlignmentFinder weekday conditions — WRONG
`case .weekday(let target): FixedDay.weekday(fixedDay) == target`
Weekday matching used inflated fixed days, producing wrong results.

### 6. AlignmentFinder weton conditions — WRONG
`case .wetonDay(let w)` used `wetonDay(fixedDay)` which is anchor-relative
(self-correcting for pasaran), but `weekdayName` property used
`FixedDay.weekday()` (NOT self-correcting), so display was wrong.

## NOT affected

| Component | Why preserved |
|-----------|--------------|
| Gregorian calendar | Uses Foundation Calendar, not FixedDay |
| Chinese calendar | Uses Foundation Calendar, not FixedDay |
| AstronomyEngine | Uses Foundation Date → Julian Day, not FixedDay |
| MetaSolar | Epoch computed from fromGregorian → self-referential → self-correcting |
| Pasaran | Uses anchor offset (anchor shifts by same 367) → self-correcting |
| Wuku | Uses anchor offset → self-correcting |

## Method version bump

FixedDay algorithm version bumped from implicit `1.0.0` to `2.0.0`.
This ensures old and new results are not treated as identical by provenance.

## Correctness verification

17 Aug 1945 (Indonesian Independence Day, known Jumat Legi):
- RD: 710260 ✓
- Weekday: 5 (Friday) ✓
- Pasaran: 0 (Legi) ✓
- JDN: 2431685 ✓

Jan 1, 2000 (MetaSolar epoch, known Saturday):
- RD: 730120 ✓
- Weekday: 6 (Saturday) ✓
- JDN: 2451545 ✓

Jan 1, 1 CE (RD epoch):
- RD: 1 ✓
- Weekday: 1 (Monday) ✓
