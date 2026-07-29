# STACK.md — appsku / K3Browser

Update terakhir: 2026-07-29 19:12 UTC

## Read first

K3Browser is a native SwiftUI + WKWebView mobile operator browser distributed without a local Mac:

```txt
Swift source → deterministic source gates → GitHub Actions macos-15/Xcode 16.4
→ unsigned IPA → GitHub Release → apps-browser.json → Feather/KSign → iPhone
```

Canonical truth order:

1. `PRODUCT.md`
2. `DESIGN.md`
3. `docs/STACK.md`
4. `docs/CHANGELOG.md`
5. `K3Browser/K3BROWSER_MAX_PLAN.md`

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
Version: 0.6.0
Build: 8
Tag: k3browser-v0.6.0
Source/tag SHA: d384d8b6c067f61b3de85af31051a2df1bc81310
Bundle ID: com.patternalcreation.k3browser
Display name: K3 Browser
Min iOS: 15.0
SDK: iphoneos18.5
Xcode: 16.4 / DTXcodeBuild 16F6
IPA size: 641,753 bytes
IPA SHA-256: b3ebcf17418baa2e21b9ce52ba2a449e9c7c931d5263642c9018e1d6d7b397ac
Launch stub: Mach-O 64-bit little-endian, 71,800 bytes
App code dylib: 2,565,008 bytes
App code dylib SHA-256: 8c765e831873e342f25fb64b7644f90a390a84fd2322f645d7f83c201049d42e
PlugIns/extensions: 0
Exact-SHA CI: 30483116606, success
Tag release CI: 30483243293, success
```

Install repo:

```txt
https://raw.githubusercontent.com/patternalcreation-max/appsku/main/apps-browser.json
```

Direct IPA:

```txt
https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.6.0/K3Browser.ipa
```

## v0.6 Adaptive Native UI

The page remains the primary workspace.

- shallow native browser rail with Back, Forward, address/search, Reload/Stop, and stable progress;
- expanded Agent Shelf uses a bottom safe-area inset and resizes the page;
- persisted draggable Agent Ball is the only floating object;
- exactly one agent command composer;
- semantic indigo interaction, orange approval accent, red error/Stop, system Light/Dark materials;
- Dynamic Type stacks controls and keeps the shelf bounded/scrollable;
- Reduce Motion removes custom spatial animation;
- VoiceOver supports Ball movement and approval navigation;
- no fake tabs/library/lock, neon, gradients, chat bubbles, or card-stack dashboard.

Approval is an authority boundary:

- full background hit testing and accessibility are blocked;
- context is bounded and scrollable;
- exact Deny/Approve actions remain pinned at 44pt minimum;
- initial arrival announces without stealing focus;
- explicit reopen focuses Deny;
- accessibility Escape denies;
- one mutually exclusive router coordinates Mission Control, Share, and approval reveal.

Mission Control is a native `NavigationView` hierarchy: Current Run, Activity, Page Snapshot, Manual Tools, and Agent Settings. It has no second command composer.

See `DESIGN.md` for canonical visual and interaction rules.

## Runtime and authority foundation

Device Runtime remains authoritative:

- immutable run UUID/context;
- cancellation and stale-callback rejection;
- exact `WKNavigation` identity and bounded settlement;
- typed tools and local risk policy;
- centralized redaction for prompts, errors, logs, exports, previews, and URLs;
- HTTPS-only model endpoint;
- Keychain-backed credential storage;
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
git diff --check
```

The GitHub workflow runs all four source gates before XcodeGen and unsigned arm64 `xcodebuild`.

Static gates prove source invariants, not physical-device rendering. The package inspection verified Info.plist, version/build, bundle, Mach-O launch stub, changed app-code dylib, IPA hash/size, and zero PlugIns.

## Release procedure

1. Run validators and secret scan.
2. Commit source/version to `main`; verify exact-SHA CI.
3. Push immutable annotated `k3browser-vX.Y.Z` tag.
4. Verify tag workflow and published release asset.
5. Download IPA; inspect Info.plist, executable/app-code binary, size/hash, and PlugIns.
6. Update manifest/living docs with measured facts.
7. Push metadata and verify raw manifest.

Never silently move a shipped tag.

## Workspace rules

- Living docs are replaced/updated, not appended indefinitely.
- No credentials in repo, prompts, logs, artifacts, or reports.
- UI replacement removes superseded workflow; no hidden duplicate composer/cockpit.
- No blind build loops: one material fix, local gates, latest-code review, CI.
- No automated Xcode unit/UI test target currently exists.

## Next gates

1. Install v0.6.0 through Feather/KSign.
2. Run `ini web apa`; expect a final answer without approval.
3. Run one gated action and verify sheet dismissal → approval reveal → exact decision → resume.
4. Test 320/375/390/430pt widths, Light/Dark, AX5 Dynamic Type, VoiceOver, keyboard, Reduce Motion, Ball persistence, Stop, redirects, and timeouts.
5. Only fix issues reproduced on the actual v0.6.0 device build.
