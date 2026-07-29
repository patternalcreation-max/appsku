# STACK.md — appsku / K3Browser

Update terakhir: 2026-07-29 20:23 UTC

## Read first

K3Browser is a native SwiftUI + WKWebView mobile operator browser distributed without a local Mac:

```txt
Swift source → deterministic source/mutation gates → GitHub Actions macos-26/Xcode 26.6
→ unsigned IPA → GitHub Release → apps-browser.json → Feather/KSign → iPhone
```

Canonical truth order:

1. `PRODUCT.md`
2. `DESIGN.md`
3. `K3Browser/K3BROWSER_AGENT_UI_REDESIGN_GUIDE.md`
4. `docs/STACK.md`
5. `docs/CHANGELOG.md`
6. `K3Browser/K3BROWSER_MAX_PLAN.md`

## Repository

```txt
Local: /root/k3-calculator
GitHub: https://github.com/patternalcreation-max/appsku
Remote: git@github.com:patternalcreation-max/appsku.git
Branch: main
Workflow: .github/workflows/build-k3browser.yml
XcodeGen: K3Browser/project.yml
App source: K3Browser/Browser/
Manifest: apps-browser.json
```

## Current verified release

```txt
Version: 0.7.0
Build: 9
Tag: k3browser-v0.7.0
Source/tag SHA: e0cdcd4e3f0cd818950c2f81c4caa8ad45c12c13
Bundle ID: com.patternalcreation.k3browser
Display name: K3 Browser
Min iOS: 26.0
SDK: iphoneos26.5 / platform 26.5
Xcode: 26.6 / DTXcodeBuild 17F113
IPA size: 698,964 bytes
IPA SHA-256: 2291139329f87cc6c470a0fdafcb84b99a45cddec6c925084fb43ca2f452f320
Launch stub: arm64 Mach-O, 72,688 bytes
Launch stub SHA-256: 0c8f81eeb1a06057be7e9688dbcc2697dc93ec1030b1ceed7b023d9ea0fecc85
App code dylib: 3,019,848 bytes
App code dylib SHA-256: 603774136f19dd9309f60da5a8d557c91a2eff80c3e31fcf296dfd2721de0ef2
PlugIns/extensions: 0
Exact-SHA CI: 30487937170, success
Tag release CI: 30488078408, success
```

Install repo:

```txt
https://raw.githubusercontent.com/patternalcreation-max/appsku/main/apps-browser.json
```

Direct IPA:

```txt
https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.7.0/K3Browser.ipa
```

## v0.7 Magnetic Capsule UI

The page remains the stable primary workspace:

- quiet native browser rail with Back, Forward, address/search, Reload/Stop, and stable progress;
- no agent `safeAreaInset` or page-resizing Shelf;
- persisted draggable Agent Ball is the only floating object;
- exclusive collapsed, compose, active, and durable result surfaces;
- exactly one agent command composer, absent while busy;
- compact/AX adaptive layout, keyboard-safe Capsule, 44pt controls, Dark Mode, VoiceOver, and Reduce Motion crossfade;
- no fake tabs/library/lock, gradients, glow, chat bubbles, or card-stack dashboard.

Approval remains an authority boundary:

- full background hit testing and accessibility are blocked;
- render preview/reason only, never raw arguments;
- context scrolls while exact Deny/one-time approval actions stay pinned;
- arrival announcement, explicit-reopen focus to Deny, and Escape-to-Deny;
- one mutually exclusive router coordinates Mission Control, Share, and approval reveal.

Mission Control uses `NavigationStack` and medium/large detents. It contains Current Run, Activity, Page Snapshot, Manual Tools, and Agent Settings, with no second composer.

## Runtime and authority foundation

Device Runtime remains authoritative:

- immutable run UUID/context;
- cancellation, timeout, and stale-callback rejection;
- exact `WKNavigation` identity and bounded settlement;
- typed tools and local risk policy;
- centralized redaction for prompts, errors, logs, exports, previews, URLs, and terminal UI;
- HTTPS-only model endpoint and Keychain-backed credential storage;
- immutable Engagement Profile binding with deny-first, fail-closed scope matching.

UI leaves receive values, bindings, and closures. They cannot execute JavaScript, tools, models, storage, or authority classification.

WKWebView limitation: this build does not claim complete HAR/CDP/MITM/raw HTTPS interception.

## Runtime and model

```txt
Endpoint: https://api.z.ai/api/coding/paas/v4/chat/completions
Model: glm-5.2
Credential: app Keychain only
```

If model output is non-JSON, fix prompt/parser tolerance; do not silently discard it.

## Verification gates

```bash
python3 K3Browser/scripts/validate_release_a.py
python3 K3Browser/scripts/validate_release_a5.py
python3 K3Browser/scripts/validate_agent_dock.py
python3 K3Browser/scripts/validate_ui_architecture.py
python3 -m json.tool apps-browser.json
# Run py_compile with PYTHONPYCACHEPREFIX outside the repo.
git diff --check
```

The GitHub workflow runs all four gates before XcodeGen and unsigned arm64 `xcodebuild`. Static gates prove source invariants; Xcode CI proves compilation; package inspection proves release metadata and binary structure. Physical-device rendering and assistive technology still require device acceptance.

## Release procedure

1. Run validators and secret scan.
2. Commit source/version to `main`; verify exact-SHA CI.
3. Push immutable annotated `k3browser-vX.Y.Z` tag.
4. Verify tag workflow and published release asset.
5. Download IPA; inspect Info.plist, Mach-O/app-code binary, size/hash, and PlugIns.
6. Replace manifest/living docs with measured facts.
7. Push metadata and verify raw manifest.

Never silently move a shipped tag.

## Workspace rules

- Living docs are replaced/updated, not appended indefinitely.
- No credentials in repo, prompts, logs, artifacts, or reports.
- UI replacement removes the superseded workflow; no hidden duplicate composer/cockpit.
- No blind build loops: one material fix, local gates, latest-code review, CI.
- No automated Xcode unit/UI test target currently exists.

## Next gates

1. Install v0.7.0 through Feather/KSign.
2. Run `ini web apa`; expect a final answer without approval.
3. Verify gated action, explicit Deny/Approve, resume, and result deferral.
4. Test stale-error precedence after a prior successful run.
5. Test 320/375/390/430pt widths, Light/Dark, AX5, VoiceOver, keyboard, Reduce Motion, Ball persistence, Stop, redirects, and timeout recovery.
6. Only fix issues reproduced on the actual v0.7.0 device build.
