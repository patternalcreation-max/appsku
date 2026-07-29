# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Primary user is an operator who works from a latest-generation iPhone and wants a capable browser agent without depending on a Mac, heavyweight browser fork, or locked SaaS interface. The product remains usable as a normal browser when the agent is idle.

## Product Purpose

K3Browser is a native SwiftUI + WKWebView operator browser. It observes the active page, reasons with an LLM, proposes or executes typed browser tools, preserves task context, and produces auditable results. It can also become a generic authorized security-research workspace when the operator imports an explicit engagement scope. Success means multi-step research and browser work can be completed from an iPhone with minimal manual interaction while authority, scope, evidence, and risky effects remain visible and controllable.

## Positioning

K3Browser owns the execution layer: Swift controls browser state, perception, tools, files, memory, approvals, and recovery. The LLM plans; untrusted web content never receives authority. It can operate directly with an OpenAI-compatible model or optionally hand long-running reasoning to a user-owned Hermes relay.

## Operating Context

- Installed as an unsigned IPA built by GitHub Actions and signed through Feather/KSign.
- Used on the latest iOS generation in short foreground sessions, with optional handoff of long-running work to a remote Hermes relay.
- Direct model credentials are stored in the app Keychain.
- Browser artifacts, runs, recipes, and notes live in the app sandbox and can be exported explicitly.
- Security-research authority is imported as a platform-neutral Engagement Profile; platforms are data sources, never hardcoded execution paths.
- GitHub repository and active sideload manifest are documented in `docs/STACK.md`.

## Capabilities and Constraints

Confirmed capabilities include native browsing, structured DOM snapshots, GLM 5.2/OpenAI-compatible inference, a bounded agent loop, typed browser actions, blocking approval UI, action timeline, local notes, file export, and the Magnetic Capsule agent surface.

Binding constraints:

- Latest-iOS-only baseline: minimum iOS 26.0 for v0.7.0; no old-iOS fallback requirement.
- SwiftUI, WKWebView, and native Apple frameworks only.
- No App Groups, keychain access groups, extensions, NetworkExtension, private APIs, background daemon, iCloud dependency, or external package manager.
- Build with GitHub Actions `macos-26`, Xcode 26.6, unsigned `xcodebuild build`, manual IPA packaging, and zero PlugIns.
- Read-only work may run autonomously. Side effects use explicit capability scopes and fail closed. Passwords, OTP/2FA, payment, destructive account actions, and wallet signing are never silently automated.
- Engagement scope never exposes secret values to the model, relay, logs, evidence, or exports. Test credentials may be referenced only through local Keychain-backed handles and resolved at the final governed action boundary.
- WKWebView cannot provide raw HTTPS navigation interception or act as an on-device MITM proxy under the current no-entitlement constraint. K3Browser may observe DOM, resource timing, and page-initiated fetch/XHR; raw traffic capture/replay belongs to an external proxy or optional relay workflow.
- UI may evolve, but replacement work must remove the workflow it supersedes and preserve runtime/authority invariants.

Open decisions to validate through implementation:

- Scope and authentication contract of the optional Hermes relay.
- Whether visual perception ships first as screenshot-only, OCR, or numbered element overlays.
- Exact evidence bundle canonicalization and compatibility contract.

## Brand Commitments

- Product name: K3Browser / K3 Browser.
- Voice: direct, operator-focused, technical without corporate language.
- The experience should feel like an instrument for operating the web, not a chat widget placed over a browser.

## Evidence on Hand

- Current release: K3Browser v0.7.0 Magnetic Capsule build 9.
- Verified latest-iOS 26.0 target, stable page-first WKWebView workspace, Magnetic Capsule states, persisted draggable Agent Ball, blocking approval review, `NavigationStack` Mission Control, exact-SHA/tag Xcode 26.6 builds, unsigned release pipeline, and public IPA internals.
- Exact source/tag SHA: `e0cdcd4e3f0cd818950c2f81c4caa8ad45c12c13`.
- Existing source and runtime state: `K3Browser/Browser/BrowserView.swift`.
- Canonical implementation history and constraints: `DESIGN.md`, `docs/STACK.md`, `docs/CHANGELOG.md`, and `K3Browser/K3BROWSER_MAX_PLAN.md`.
- No current automated Swift test target; v0.7 real-device behavior still requires explicit acceptance testing.

## Product Principles

1. **Browser is the workspace.** Agent chrome overlays rather than resizes the page.
2. **Autonomy is scoped, not timid.** Approve a bounded plan or capability once; interrupt only when scope expands or risk changes.
3. **Typed tools beat prompt tricks.** Every action is validated, logged, replayable where safe, and attributable to a run.
4. **Local execution, optional remote leverage.** The app remains useful without a relay; Hermes adds durable and multi-agent power rather than becoming a launch dependency.
5. **Recovery is a feature.** Runs checkpoint state, survive expected interruptions, and explain failures without blind retries.
6. **Scope before probes.** Security-testing tools exist only inside a valid operator-activated Engagement Profile; out-of-scope actions fail closed.
7. **Evidence is a product primitive.** Findings persist across runs and reference redacted, reproducible, tamper-evident evidence rather than unverifiable agent prose.

## Accessibility & Inclusion

Use native controls and Dynamic Type, maintain named VoiceOver actions and visible state, preserve keyboard-safe layouts, respect Reduce Motion, keep controls at least 44pt, and never encode approval/result meaning by color alone.
