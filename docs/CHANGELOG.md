# CHANGELOG.md — appsku / K3Browser Living State

Update terakhir: 2026-07-29 20:23 UTC

> Living doc. Replace current state; do not append indefinitely.

## Current state

```txt
Project: appsku / K3Browser
Release: v0.7.0 Magnetic Capsule, build 9
Tag: k3browser-v0.7.0
Source SHA: e0cdcd4e3f0cd818950c2f81c4caa8ad45c12c13
Status: exact-SHA CI PASS; tag release PASS; public IPA internals verified; device acceptance pending
Install repo: https://raw.githubusercontent.com/patternalcreation-max/appsku/main/apps-browser.json
IPA: https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.7.0/K3Browser.ipa
Size: 698,964 bytes
SHA-256: 2291139329f87cc6c470a0fdafcb84b99a45cddec6c925084fb43ca2f452f320
```

## v0.7.0 Magnetic Capsule

### Page-first agent surface

- Removed the page-resizing Agent Shelf.
- WKWebView remains stable while agent surfaces overlay it.
- Ball is the agent; compose, active, and result Capsules are temporary speech.
- One composer exists only in compose state and leaves hierarchy while busy.
- Active Peek exposes concise status, Stop, Mission Control, and collapse.
- Durable Result Peek distinguishes success/error and waits for explicit dismissal or Details.

### Compact, keyboard, and accessibility behavior

- 56pt Ball, 8pt drag threshold, safe-area clamping, edge snap, and final-only position persistence.
- Compose/active/result layouts adapt at compact width and accessibility Dynamic Type.
- Controls remain at least 44pt.
- Named VoiceOver Compose/Open status/Review/Stop/Mission/Move actions.
- Reduce Motion uses a real opacity crossfade; normal mode uses shared geometry.
- Browser workspace ignores keyboard resizing while Capsule remains keyboard-safe.

### Truthful terminal presentation

- Centralized redacted result fallback covers done/error paths without `agentAnswer`.
- Current terminal error outranks stale output from an older run.
- Result completion behind Mission/Share/approval is deferred and revealed after the conflict clears.
- Mutation gates cover result precedence, conflict recovery, compact/AX layout, Reduce Motion, VoiceOver conditions, and minimum control size.

### Approval and Mission Control

- Approval closure invariants remain intact: preview/reason only, no raw arguments, pinned decisions, explicit Deny, one-time tool approval, no outside dismissal, announcement, focus-to-Deny, Escape-to-Deny, and blocked background accessibility.
- Approval hierarchy now leads with the exact action; orange risk accent is one hairline.
- Mission Control uses `NavigationStack` with medium/large detents and no second composer.
- One router serializes Mission Control, Share, and approval.

### Latest-iOS release baseline

- Minimum iOS: 26.0.
- Build runner: GitHub Actions `macos-26`.
- Compiler: Xcode 26.6 (`DTXcodeBuild 17F113`).
- SDK: `iphoneos26.5`.
- No Xcode 27 beta dependency.

## Verification evidence

```txt
Local Release A/A.5/Magnetic Capsule/UI mutation gates: PASS
Final source review: initial blockers found; exact blockers fixed
Exact-SHA CI 30487937170: PASS
Tag release CI 30488078408: PASS
Tag target equals e0cdcd4e3f0cd818950c2f81c4caa8ad45c12c13
IPA version/build/bundle/minimum OS/SDK/Mach-O/zero-PlugIns inspection: PASS
Launch stub: arm64 Mach-O, 72,688 bytes, SHA-256 0c8f81eeb1a06057be7e9688dbcc2697dc93ec1030b1ceed7b023d9ea0fecc85
App-code dylib: 3,019,848 bytes, SHA-256 603774136f19dd9309f60da5a8d557c91a2eff80c3e31fcf296dfd2721de0ef2
```

## Device acceptance pending

1. Install v0.7.0 through Feather/KSign.
2. Run `ini web apa`; expect a final answer without approval.
3. Run one gated action; verify sheet dismissal → approval → exact one-time decision → resume.
4. Reproduce stale-result test: finish success, remove API key, run again; current error must replace old success.
5. Test 320/375/390/430pt widths, AX5, Light/Dark, VoiceOver actions/focus/Escape, keyboard, Reduce Motion, Ball persistence, Stop, deferred result, redirects, and timeout recovery.

## Known limitations

- No automated Xcode unit/UI test target.
- Real WKWebView callback ordering, SwiftUI layout/hit testing, keyboard geometry, and assistive-technology behavior still require device verification.
- WKWebView does not provide complete HAR/CDP/MITM/raw HTTPS interception under current constraints.
- DDG fork path remains abandoned.
