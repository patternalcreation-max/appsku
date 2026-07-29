# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Primary user is an operator who works from an iPhone and wants a capable browser agent without depending on a Mac, heavyweight browser fork, or locked SaaS interface. The product should also remain usable as a normal browser when the agent is idle.

## Product Purpose

K3Browser is a native SwiftUI + WKWebView operator browser. It observes the active page, reasons with an LLM, proposes or executes typed browser tools, preserves task context, and produces auditable results. It can also become a generic authorized security-research workspace when the operator imports an explicit engagement scope. Success means multi-step research and browser work can be completed from an iPhone with minimal manual interaction while authority, scope, evidence, and risky effects remain visible and controllable.

## Positioning

K3Browser owns the execution layer: Swift controls browser state, perception, tools, files, memory, approvals, and recovery. The LLM plans; untrusted web content never receives authority. It can operate directly with an OpenAI-compatible model or optionally hand long-running reasoning to a user-owned Hermes relay.

## Operating Context

- Installed as an unsigned IPA built by GitHub Actions and signed through Feather/KSign.
- Used on iPhone in short foreground sessions, with optional handoff of long-running work to a remote Hermes relay.
- Direct model credentials are stored in the app Keychain.
- Browser artifacts, runs, recipes, and notes live in the app sandbox and can be exported explicitly.
- Security-research authority is imported as a platform-neutral Engagement Profile; Immunefi, private programs, and other platforms are data sources, never hardcoded execution paths.
- GitHub repository and active sideload manifest are documented in `docs/STACK.md`.

## Capabilities and Constraints

Confirmed capabilities include native browsing, structured DOM snapshots, GLM 5.2/OpenAI-compatible inference, a bounded agent loop, typed browser actions, approval UI, action timeline, local notes, and file export.

Binding constraints:

- iOS 15+, SwiftUI, WKWebView, native Apple frameworks.
- No App Groups, keychain access groups, extensions, NetworkExtension, private APIs, background daemon, iCloud dependency, or external package manager.
- Build with GitHub Actions `macos-15`, Xcode 16.x, unsigned `xcodebuild build`, manual IPA packaging, and zero PlugIns.
- Read-only work may run autonomously. Side effects use explicit capability scopes and fail closed. Passwords, OTP/2FA, payment, destructive account actions, and wallet signing are never silently automated.
- Engagement scope never exposes secret values to the model, relay, logs, evidence, or exports. Test credentials may be referenced only through local Keychain-backed handles and resolved at the final governed action boundary.
- WKWebView cannot provide raw HTTPS navigation interception or act as an on-device MITM proxy under the current no-entitlement constraint. K3Browser may observe DOM, resource timing, and page-initiated fetch/XHR; raw traffic capture/replay belongs to an external proxy or optional relay workflow.
- UI may be redesigned or replaced; shipped UI is evidence, not a binding visual authority. Replacement work must remove the workflow it supersedes.

Open decisions to validate through implementation:

- Scope and authentication contract of the optional Hermes relay.
- Whether visual perception ships first as screenshot-only, OCR, or numbered element overlays.
- Exact evidence bundle canonicalization and compatibility contract.

## Brand Commitments

- Product name: K3Browser / K3 Browser.
- Voice: direct, operator-focused, technical without corporate language.
- The experience should feel like an instrument for operating the web, not a chat widget placed over a browser.

## Evidence on Hand

- Working release: K3Browser v0.5.0 PEAK build 7.
- Verified launch-safe custom WKWebView shell, adaptive Dock/Ball integration, GitHub Actions Xcode compile, unsigned release pipeline, and IPA structure.
- Existing source and runtime state: `K3Browser/Browser/BrowserView.swift`.
- Canonical implementation history and constraints: `docs/STACK.md`, `docs/CHANGELOG.md`, and `K3Browser/K3BROWSER_MAX_PLAN.md`.
- No current automated Swift test target; v0.5 real-device behavior still requires explicit acceptance testing.

## Product Principles

1. **Browser is the workspace.** Agent controls stay close to the page and never hide the object being operated on.
2. **Autonomy is scoped, not timid.** Approve a bounded plan or capability once; interrupt only when scope expands or risk changes.
3. **Typed tools beat prompt tricks.** Every action is validated, logged, replayable where safe, and attributable to a run.
4. **Local execution, optional remote leverage.** The app remains useful without a relay; Hermes adds durable and multi-agent power rather than becoming a launch dependency.
5. **Recovery is a feature.** Runs checkpoint state, survive expected interruptions, and explain failures without blind retries.
6. **Scope before probes.** Security-testing tools exist only inside a valid operator-activated Engagement Profile; out-of-scope actions fail closed.
7. **Evidence is a product primitive.** Findings persist across runs and reference redacted, reproducible, tamper-evident evidence rather than unverifiable agent prose.

## Accessibility & Inclusion

Use native controls and Dynamic Type where practical, maintain VoiceOver labels and visible state, preserve keyboard-safe layouts, and never encode approval risk by color alone.
