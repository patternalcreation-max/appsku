# CHANGELOG.md — appsku / K3Browser Living State

Update terakhir: 2026-07-29 19:12 UTC

> Living doc. Replace current state; do not append indefinitely.

## Current state

```txt
Project: appsku / K3Browser
Release: v0.6.0 Adaptive Native UI, build 8
Tag: k3browser-v0.6.0
Source SHA: d384d8b6c067f61b3de85af31051a2df1bc81310
Status: exact-SHA CI PASS; tag release PASS; IPA internals verified; device acceptance pending
Install repo: https://raw.githubusercontent.com/patternalcreation-max/appsku/main/apps-browser.json
IPA: https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.6.0/K3Browser.ipa
Size: 641,753 bytes
SHA-256: b3ebcf17418baa2e21b9ce52ba2a449e9c7c931d5263642c9018e1d6d7b397ac
```

## v0.6.0 Adaptive Native UI

### Browser workspace

- Replaced generic top toolbar with a shallow native browser rail.
- Back, Forward, address/search, Reload/Stop, and stable progress use 44pt targets.
- WKWebView remains the dominant visual workspace.
- No fake tabs, library, lock, or unsupported browser capability.

### Agent Shelf and Ball

- Expanded K3 is a bottom safe-area shelf that resizes the page.
- One command composer only.
- Run and Stop are mutually exclusive.
- Agent Ball remains 56pt, draggable, edge-snapping, and persistent.
- Dynamic Type, Reduce Motion, safe-area clamping, and VoiceOver move actions are enforced.

### Approval authority

- Replaced floating tray treatment with a blocking bottom decision surface.
- Review context is bounded and scrollable; decisions remain pinned.
- Exact affirmative labels identify each one-action authority.
- Background page/Dock leave touch and accessibility trees while pending.
- VoiceOver announcement, explicit focus-to-Deny, and Escape-to-Deny are present.
- Indigo CTA improves contrast; orange remains a risk accent.
- Mission Control and Share use one presentation router; approval reveals only after active presentation dismissal.

### Mission Control

- Replaced four-way segmented dashboard with native hierarchical lists/forms.
- Root destinations: Current Run, Activity, Page Snapshot, Manual Tools, Agent Settings.
- Manual tools still stage normal approval.
- API key remains a SecureField backed by the existing Keychain flow.
- No second command composer.

### Quality system

- Added `K3VisualSystem.swift` and canonical `DESIGN.md`.
- Added deterministic `validate_ui_architecture.py` with mutation gates.
- GitHub Actions now runs Release A, A.5, Dock, and UI validators before Xcode build.

## Verification evidence

```txt
Initial 3-lens UI council: complete
Swift/iOS15 compile-plausibility review: PASS
Native UX/accessibility review: blockers found and fixed
Approval/presentation authority review: blockers found and fixed
Focused closure review: APPROVED
Local deterministic gates: PASS
Exact-SHA CI 30483116606: PASS
Tag release CI 30483243293: PASS
IPA Info.plist/Mach-O/app-code-dylib/zero-PlugIns inspection: PASS
```

The Xcode 16 package uses a stable 71,800-byte launch stub plus `K3Browser.debug.dylib` for app code. The v0.6 app-code dylib differs from v0.5 and grew from 2,215,840 to 2,565,008 bytes, proving the new UI binary is present.

## Device acceptance pending

1. Install through Feather/KSign.
2. Run `ini web apa`; expect a final answer without approval.
3. Run one gated action and verify approval presentation/resume.
4. Test 320pt/AX5/VoiceOver, Light/Dark, keyboard, Reduce Motion, Ball persistence, Stop, redirects, and timeout recovery.

## Known limitations

- No automated Xcode unit/UI test target.
- Real WKWebView callback ordering, SwiftUI layout, hit testing, and assistive-technology behavior require device verification.
- WKWebView does not provide complete HAR/CDP/MITM/raw HTTPS interception under current constraints.
- DDG fork path remains abandoned.
