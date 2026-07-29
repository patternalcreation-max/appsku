# CHANGELOG.md — appsku / K3Browser Living State

Update terakhir: 2026-07-29 18:36 UTC

> Living doc. Replace current state; do not append indefinitely.

## Current state

```txt
Project: appsku / K3Browser
Release: v0.5.0 PEAK, build 7
Tag: k3browser-v0.5.0
Status: GitHub Actions build/release PASS; IPA structure verified; device acceptance pending
Install repo: https://raw.githubusercontent.com/patternalcreation-max/appsku/main/apps-browser.json
IPA: https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.5.0/K3Browser.ipa
Size: 576,821 bytes
SHA-256: a05e7f8edb31a76516314f7b1958439147bf646078e8ff66337e473ea93792b5
```

## v0.5.0 PEAK

Shipped one substantive build combining Release A, Release A.5, and adaptive agent shell.

### Runtime foundation

- Immutable run context and UUID.
- Cancellation and stale async-callback rejection.
- Exact `WKNavigation` identity and bounded settlement for direct/JS-triggered navigation.
- HTTPS-only model endpoint.
- Centralized redaction across errors, model/parser excerpts, previews, logs, notes, and exports.
- Current input values/hidden fields excluded from structured snapshots.
- Keychain-backed secret storage; persistence and export success are reported truthfully.

### Engagement Authority

- Platform-neutral Engagement Profiles with operator activation.
- Active scope binds immutable UUID + canonical hash.
- Deny-first, fail-closed domain/path matching.
- Exact/wildcard semantics and canonical path hardening, including C1 controls.
- Serialized, bounded, regular-file-only persistence using one nonblocking descriptor.

### Native operator shell

- Full-page WKWebView remains the workspace.
- Adaptive Agent Dock replaces the legacy bottom command bar.
- Dock collapses to a draggable, edge-snapping Agent Ball.
- Collapsed state and final position persist; drag frames do not write continuously.
- One agent composer only.
- Mission Control replaces the duplicate cockpit workflow.
- Existing approval tray remains run-bound, auto-shows, and can be reopened from Dock.
- Keyboard/Dynamic Type height is strictly bounded and scrollable.

## Verification evidence

```txt
Release A focused review: APPROVED
Release A.5 focused review: APPROVED
Dock/Ball focused review: PASS
BrowserView integration review: PASS
Linux validators: PASS
GitHub Actions #19 foundation compile: PASS
GitHub Actions #20 v0.5.0/build 7 compile: PASS
GitHub Actions #21 tag release: PASS
IPA zip/Info.plist/Mach-O/zero-PlugIns inspection: PASS
```

Linux validators are source-invariant/semantic-mirror checks. They do not replace Xcode or real-device behavior.

## Device acceptance pending

1. Install through Feather/KSign.
2. Run `ini web apa`; expect a final answer without approval.
3. After baseline passes, run one gated search and verify approval/resume.
4. Verify Dock/Ball drag, relaunch persistence, keyboard/Dynamic Type, Stop, redirects, and timeout recovery.

## Known limitations

- No automated Xcode unit/UI test target.
- Real WKWebView callback ordering and runtime hit testing require device verification.
- WKWebView does not provide complete HAR/CDP/MITM/raw HTTPS interception under current constraints.
- Optional relay, durable evidence bundles, recipes, checkpoints, and broader Mission Control depth remain future slices.
- DDG fork path remains abandoned.
