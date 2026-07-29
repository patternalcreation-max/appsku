# STACK.md — appsku / K3Browser

Update terakhir: 2026-07-29 18:36 UTC

## Read first

K3Browser is a native SwiftUI + WKWebView mobile operator browser distributed without a local Mac:

```txt
Swift source → GitHub Actions macos-15/Xcode 16.4 → unsigned IPA
→ GitHub Release → apps-browser.json → Feather/KSign → iPhone
```

Canonical truth order:

1. `PRODUCT.md`
2. `docs/STACK.md`
3. `docs/CHANGELOG.md`
4. `K3Browser/K3BROWSER_MAX_PLAN.md`

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
Version: 0.5.0
Build: 7
Tag: k3browser-v0.5.0
Bundle ID: com.patternalcreation.k3browser
Display name: K3 Browser
Min iOS: 15.0
SDK: iphoneos18.5
Xcode: 16.4 / DTXcode 1640
IPA size: 576,821 bytes
IPA SHA-256: a05e7f8edb31a76516314f7b1958439147bf646078e8ff66337e473ea93792b5
Executable: Mach-O 64-bit little-endian, 71,800 bytes
PlugIns/extensions: 0
Tag workflow: Run #21, success
```

Install repo:

```txt
https://raw.githubusercontent.com/patternalcreation-max/appsku/main/apps-browser.json
```

Direct IPA:

```txt
https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.5.0/K3Browser.ipa
```

## v0.5 PEAK architecture

Page remains the main workspace. Agent UX has one command boundary:

- adaptive Agent Dock;
- collapsible draggable Agent Ball with persisted edge/Y/collapsed state;
- Mission Control without a duplicate composer;
- existing approval checkpoint reused and reopenable from Dock.

Device Runtime owns authority:

- immutable run UUID/context;
- cancellation and stale-callback rejection;
- exact `WKNavigation` identity for navigation settlement;
- bounded no-navigation and action timeouts;
- typed tools and local risk policy;
- centralized redaction for prompts, errors, logs, exports, previews, and URLs;
- HTTPS-only model endpoint with nonempty host;
- Keychain for model credentials; no secret values in model/log/evidence/export.

Authorized security research is platform-neutral:

- operator reviews and activates an Engagement Profile;
- active authority binds immutable profile UUID + canonical hash;
- deny-first and fail-closed matching;
- exact domain/path semantics; `*.example.com` excludes apex;
- canonical paths reject ambiguous encoded separators/percent, backslashes, duplicate slash, malformed escapes, userinfo, non-default ports, and Unicode controls including C1;
- regular-file-only bounded profile reads use one nonblocking descriptor;
- imported/platform rules remain drafts until local activation.

WKWebView limitation: this build does not claim complete HAR/CDP/MITM/raw HTTPS interception. Heavy capture/replay and long-running work belong to an optional external relay/proxy.

## Runtime and model

Default preset:

```txt
Endpoint: https://api.z.ai/api/coding/paas/v4/chat/completions
Model: glm-5.2
Credential: app Keychain only
```

If model output is non-JSON, fix prompt/parser tolerance; do not silently discard it.

## Verification gates

Deterministic Linux gates:

```bash
python3 K3Browser/scripts/validate_release_a.py
python3 K3Browser/scripts/validate_release_a5.py
python3 K3Browser/scripts/validate_agent_dock.py
python3 -m json.tool apps-browser.json
git diff --check
```

These prove source invariants and semantic mirrors, not Swift compilation or device behavior.

Actual build evidence:

```txt
Run #19: foundation source compiled successfully
Run #20: exact v0.5.0/build 7 compiled successfully
Run #21: tag build + GitHub Release succeeded
```

## Release procedure

1. Run all local validators and secret scan.
2. Commit source to `main`; verify branch CI.
3. Set `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`; verify exact-version CI.
4. Push annotated tag `k3browser-vX.Y.Z`.
5. Verify tag workflow and release asset.
6. Download IPA; validate zip, Info.plist, executable, size/hash, and zero PlugIns.
7. Update `apps-browser.json`, README, STACK, and CHANGELOG with measured facts.
8. Push docs/manifest and verify raw manifest.

Never retag a shipped release silently. Use a new patch version if post-release source changes.

## Workspace rules

- Living docs are replaced/updated, not appended forever.
- No credentials in repo, prompts, logs, artifacts, or reports.
- UI from older builds is disposable when a verified replacement removes duplicate workflow.
- No blind build loops: one material fix, local gates, independent review, CI.
- DDG fork path remains abandoned because entitlement/App Group/extension coupling does not fit generic sideload signing.
- No automated Xcode test target currently exists.

## Next gates

1. Install v0.5.0 through Feather/KSign.
2. Baseline command: `ini web apa` — expected final answer without approval.
3. Only after baseline passes, test a gated search action and approval flow.
4. Verify Dock/Ball drag, persistence, Dynamic Type, keyboard, stale callbacks, redirect/navigation timeout, and Stop on a real device.
5. Continue Mission Control/artifact/evidence/recipe depth only from measured device results.
