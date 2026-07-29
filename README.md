# appsku / K3Browser Workspace

Update terakhir: 2026-07-29 20:23 UTC

Baca sebelum kerja:

1. `PRODUCT.md` — product truth dan hard boundaries.
2. `DESIGN.md` — canonical shipped UI contract.
3. `K3Browser/K3BROWSER_AGENT_UI_REDESIGN_GUIDE.md` — detailed Magnetic Capsule interaction and acceptance guide.
4. `docs/STACK.md` — source of truth arsitektur, release, paths, dan gates.
5. `docs/CHANGELOG.md` — current state dan next acceptance tests.
6. `K3Browser/K3BROWSER_MAX_PLAN.md` — canonical MAX architecture plan.

## Current release

```txt
K3Browser v0.7.0 Magnetic Capsule — build 9
Bundle ID: com.patternalcreation.k3browser
Min iOS: 26.0
SDK: iphoneos26.5
```

Install repo:

```txt
https://raw.githubusercontent.com/patternalcreation-max/appsku/main/apps-browser.json
```

Direct IPA:

```txt
https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.7.0/K3Browser.ipa
```

Release status: deterministic source and mutation gates PASS; final source review blockers fixed; exact-SHA and tag Xcode 26.6 builds PASS; public IPA internals verified. Real-device visual/runtime acceptance is still required.
