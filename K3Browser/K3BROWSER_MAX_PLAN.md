# K3Browser MAX Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Turn K3Browser into an iPhone-first autonomous operator browser and generic authorized security-research workstation with a draggable adaptive Agent Ball/Dock, typed local tool execution, durable settings/soul/memory, evidence-grade research artifacts, and an optional Hermes remote brain—without hardcoding any bounty platform, target, vulnerability class, exploit, or platform rule.

**Architecture:** The iPhone is the execution and approval authority. A bounded on-device runtime owns WKWebView, snapshots, typed tools, redaction, policy, approvals, secrets, engagement scope, and artifacts. An optional user-owned Hermes relay may plan, delegate, schedule, use MCP/terminal, and return proposals or artifacts, but every browser effect is revalidated and executed locally. Imported scope/rules, page content, model output, and relay output are untrusted proposals until the operator reviews and activates an exact normalized profile digest. K3 records operator-declared authorization and enforced controls; it does not claim to independently prove legal authorization.

**Tech Stack:** Swift 5, SwiftUI, UIKit, WKWebView, Foundation, Security/Keychain, SQLite3, Vision, PDFKit where needed, XcodeGen, GitHub Actions macOS 15/Xcode 16.x, unsigned IPA.

---

## 1. Product contract

K3Browser MAX is not a chatbot overlay. The page is the workspace. The user gives a goal; K3 inspects, plans, acts within a bounded capability envelope, checks the outcome, and delivers reusable artifacts.

### Efficiency and simplification gates

- One composer, one active-run coordinator, one settings owner, and one durable source of truth per data class.
- New UI replaces superseded controls in the same change; no hidden legacy cockpit/composer remains as a second workflow.
- Scope matching, redaction, hashing, diffing, budgets, persistence, and validation are deterministic local code and never consume an LLM call.
- Direct mode handles foreground page work. Relay is used only for capabilities the device cannot perform efficiently or truthfully: long-running jobs, delegation, terminal/MCP, desktop browser, raw HTTP/DNS/TLS, heavy source analysis, or scheduled work.
- Persist immutable artifacts once by content hash and reference them from runs/findings; do not duplicate snapshot bodies across stores.
- Derived UI state is recomputed from canonical runtime/storage state, not separately persisted.
- Every new abstraction must remove a concrete duplication, security ambiguity, or measured bottleneck. Premature service layers and generic frameworks are rejected.
- Release A/A.5/Dock/Mission Control ships as one verified v0.5 PEAK build. No intermediate tag, IPA, or manifest churn.

### Binding rules

- One primary goal composer only.
- Current v0.4.1 UI may be replaced completely.
- Browser canvas receives most of the viewport.
- The agent control morphs between an expanded bottom dock and a draggable floating ball.
- The ball snaps to the nearest safe left/right edge and persists its normalized position.
- Read-only public research may run autonomously inside explicit budgets.
- Side effects are authorized by deterministic local policy, never by prompt text or relay output.
- Secrets never enter snapshots, model payloads, logs, memory, recipes, exports, or relay messages.
- Imported engagement rules remain an inactive draft until the operator reviews unresolved clauses and activates the exact normalized digest locally.
- Scope is deny-by-default. Explicit exclusions win; redirects and popup targets are revalidated; `*.example.com` matches subdomains only and requires a separate exact rule for the apex.
- A bounded plan may authorize repeated unchanged actions. K3 pauses only when target, method, effect, auth context, data class, rate, destination, or scope expands.
- Effective risk comes from the local tool registry and resolved live effect; inbound page/model/file/recipe/relay risk labels are ignored.
- No new entitlements, extensions, App Groups, NetworkExtension, private APIs, background daemon, or third-party packages.

## 2. UI direction: Adaptive Agent Dock

### Expanded dock states

```text
Idle:       [Back] [Page title / Search or URL] [Tabs] [K3]
Compose:    [Close] [Tell K3 what you need…] [Run]
Running:    [Stop] [Step N/M · human-readable status] [Inspect]
Approval:   approval tray above dock; page remains visible
Completed:  [Done] [Artifact/result title] [Open]
```

### Collapsed Agent Ball

- 52–58 pt circular native material control; touch target at least 44 pt.
- Drag anywhere inside the current safe viewport; on release, spring-snap to nearest left/right edge.
- Persist `edge`, normalized vertical position, and collapsed preference in UserDefaults.
- Re-clamp after rotation, keyboard changes, safe-area changes, and Dynamic Type changes.
- Tap expands the dock. Long press opens quick actions: New Goal, Inspect Page, Stop, Library.
- Badge semantics: blue working, amber approval with count/text accessibility label, red failed, green completed.
- Never steal focus or cover a pending approval. During approval, ball expands or anchors the tray.
- Honor Reduce Motion with fade/instant transitions.

### Main surfaces

1. **Browser Workspace** — WKWebView, compact top security/title strip, target highlight, adaptive dock.
2. **Mission Control** — goal, plan, current checkpoint, approval, result/artifacts, readable timeline, diagnostics disclosure.
3. **Tabs** — tab owner (`user`/`agent`), origin, screenshot, run status, artifacts.
4. **Library** — Runs, Notes, Files, Recipes, Bookmarks, Site Memory.
5. **Settings** — Model, Soul, Autonomy, Data, Relay, Privacy, Advanced.
6. **Research Workspace** — Engagement, Scope Inspector, Auth Contexts, Test Notebook, Evidence Vault, Findings, and Report Builder inside Mission Control; never a second composer.

## 3. Settings, soul, and persistence

### Storage ownership

| Data | Store | Rule |
|---|---|---|
| Provider API keys, relay token | Keychain | This-device-only; never copied into DB/log/export |
| Small UI preferences | UserDefaults | Dock edge/position, appearance, selected model ID, autonomy preset |
| Soul/persona | Application Support JSON | Versioned, atomic write, user-editable; cannot override core policy |
| Engagement profiles | Application Support JSON | Platform-neutral, versioned, hash-validated, activated only by explicit operator gesture |
| Sessions/runs/events/approvals/checkpoints | SQLite3 | Append events + materialized state; pending approvals invalid after relaunch |
| Memory, recipes, metadata | SQLite3 | Provenance, trust label, quotas, content hash |
| Findings/evidence chain | SQLite3 + Application Support/Evidence | Redact before canonical hash; bound to engagement, origin, run, tool, and page epoch |
| Notes/files/screenshots/downloads | Application Support/Files | Atomic writes, opaque IDs, DB metadata, quota and cleanup |
| Temporary run artifacts | Caches/Run/<runID> | Reclaimable; promote explicitly to Library |

### Soul layers

```text
Compiled Core Policy        immutable, not user-editable
Operator Soul               editable name/voice/working style/default behavior
Autonomy Profile            Observe / Research / Operate-Carefully / Custom budgets
Recipe Instructions         scoped to exact recipe hash and declared capabilities
Site Memory                 facts/preferences with source and trust label
Untrusted Page/File/OCR     data only; never policy or authority
```

`OperatorSoul` fields:

```text
schemaVersion, displayName, identity, voice, language,
workingStyle, defaultGoalRules, preferredOutput,
createdAt, updatedAt
```

Changing Soul never weakens redaction, target validation, approval rules, domain boundaries, or hard blocks.

### Settings sections

- **Model:** Direct/Relay/Hybrid, trusted endpoint presets, model, connectivity test.
- **Soul:** identity, tone, language, working rules, reset/export/import without secrets.
- **Autonomy:** preset, read budgets, approved plan defaults, cross-origin behavior, Stop semantics.
- **Data:** storage usage, notes/runs/recipes, retention, export, selective delete.
- **Privacy:** what may go to model/relay, snapshot redaction preview, history query stripping.
- **Relay:** endpoint trust, token Keychain, capability handshake, last sync.
- **Advanced:** diagnostics, raw tool details, test fixtures; manual selectors live here only.

## 4. Runtime trust model

### Control plane

Authority comes only from user gesture, user goal, compiled local policy, and a locally approved capability plan.

### Data plane

DOM, OCR, PDF, downloads, imported notes/recipes, model output, and relay output are untrusted data. They may propose but never authorize actions.

### Typed proposal envelope

Every proposal includes protocol version, run ID, plan ID, call ID, sequence, capability version, typed arguments, tab ID, origin, navigation epoch, snapshot digest, target fingerprint, reason, and expiry.

### Two deterministic gates

1. **Dispatch validation:** schema, run/plan/budget, canonical URL/origin, data class, predicted effect.
2. **Commit-time validation:** active run, single-use nonce, non-expired approval, same tab/origin/epoch, target re-resolution/fingerprint, live field/form metadata, navigation/download interception.

Mismatch means invalidate and re-plan. Never silently broaden scope.

## 5. Autonomy model

### Automatic inside budget

- Sanitized snapshot, article/text/link/form/table extraction.
- Local screenshot and OCR after sensitive-region redaction.
- Same-origin GET research covered by an approved plan.
- Agent-owned tab creation/close within plan limits.
- Temporary artifacts and checkpoints.
- Local history metadata reads with stripped queries.

### Approve bounded plan once

A research plan may grant exact origins, GET-only navigation, maximum tabs/pages/runtime/bytes, allowed data classes, local artifact writes, and stop criteria. Any domain/effect/data-class expansion pauses for amendment.

### Per-effect approval

- Fill/click/submit, server-state mutation, origin expansion.
- Upload/download/open file, clipboard, share/export.
- User-owned tab navigation/close.
- Reading user-selected files or sending artifacts to relay.
- Endpoint/relay host change or imported recipe first run/hash change.

### Manual takeover / hard block

Password, OTP/2FA/recovery codes, session/API/private keys, cards/PIN, wallet signing/seed, payments, transfers/swaps, destructive account/security changes, legal signature, CAPTCHA bypass, executable/profile/certificate installation.

Authorized research does not send these values through the model. Where program rules allow authenticated testing, the model may propose a typed action containing a local `SecretHandle`; only the device policy engine can resolve that handle from Keychain at commit time after scope and approval checks. Raw secret values never enter prompts, logs, evidence, relay payloads, or exports.

## 5A. Generic authorized security-research capability

Security research is a capability layer, not an Immunefi mode and not an unrestricted safety bypass.

### Engagement authority

- `EngagementProfile` is imported and activated only by explicit operator gesture.
- It records program label/type, policy-document hash, in-scope and deny-first out-of-scope assets, path/protocol rules, testing window, forbidden actions, effect/rate/time budgets, and operator authorization declaration.
- Platform reference is optional free text. No platform URL, API, taxonomy, or submission flow is hardcoded.
- Core policy remains immutable. The profile supplies constrained capability grants that the local policy engine evaluates; page/model/recipe/relay data cannot modify scope or budgets.
- No engagement: general browser policy. Active + in scope: only granted research tools are exposed. Active + out of scope: research tools are disabled and actions fail closed.

### Research primitives

- Scope indicator in the address bar and Agent Ball; out-of-scope state cannot be represented by color alone.
- Finding notebook persists across runs: hypothesis, category, affected asset, repro steps, impact, severity reasoning, status, and evidence references.
- Evidence chain is distinct from the runtime audit log. Every redacted observation records engagement/run/tab/origin/page epoch, timestamp, tool, canonical argument digest, previous hash, and entry hash.
- Evidence/report artifacts are generic Markdown/JSON/PDF or a self-contained bundle. Program-specific templates are user-imported data.
- On-device observation may use DOM, screenshots/OCR, Resource Timing, and a compatibility-tested document-start wrapper for page-initiated fetch/XHR.
- WKWebView cannot intercept raw HTTPS browser navigation or provide system-wide MITM under the no-entitlement constraint. Full raw traffic capture/replay is external-proxy or relay territory.

### Research hard boundaries

- Deny-first scope matching; out-of-scope research effects never execute.
- Testing-window expiry, profile hash mismatch, missing operator declaration, or exhausted budget invalidates the grant.
- Secret values never enter model/relay/log/evidence/export. Auth automation requires typed `SecretHandle` resolution on-device.
- Program-forbidden actions, destructive effects without an explicit grant, uncontrolled rate/stress testing, and authority expansion remain blocked.

## 6. P0 defects to remove before expanding tools

1. Snapshot currently leaks input values through generic `inputs[].text`.
2. Page text is mixed with instructions without a trust boundary.
3. Policy scans model arguments instead of the resolved live target.
4. Approval is not bound to run/tab/origin/page/target/expiry.
5. Navigation tools report success before commit/settle.
6. Stop does not cancel network work or reject stale callbacks.
7. `.acting("")` equality fails to detect actual busy state.
8. Tool args lose types in `[String:String]`.
9. JS and selector errors can be mislabeled success.
10. Logs/previews may persist raw values and model responses.
11. Editable system prompt conflates persona with immutable policy.
12. No durable session/event/checkpoint model or automated test target exists.

## 7. Release train

### Release A — v0.5.0 MAX Foundation + Adaptive Dock

**Objective:** remove critical trust leaks, establish run identity and settings/soul storage, and ship the new signature control without expanding risky tools.

Files to create:

```text
Browser/AppModel/AppSettings.swift
Browser/AppModel/OperatorSoul.swift
Browser/AppModel/DockPreferences.swift
Browser/Runtime/RunContext.swift
Browser/Runtime/RuntimePhase.swift
Browser/Runtime/RuntimeEvent.swift
Browser/Runtime/RuntimeCoordinator.swift
Browser/Tools/JSONValue.swift
Browser/Tools/ToolModels.swift
Browser/Safety/Redactor.swift
Browser/Safety/PromptPolicy.swift
Browser/PagePerception/SnapshotSanitizer.swift
Browser/UI/AdaptiveAgentDock.swift
Browser/UI/AgentBall.swift
Browser/UI/MissionControlView.swift
Browser/UI/SettingsRootView.swift
```

Files to modify:

```text
Browser/BrowserView.swift
project.yml
.github/workflows/build-k3browser.yml
apps-browser.json (only after verified release IPA)
```

Acceptance:

- Input values never appear in sanitized snapshot/model/log fixtures.
- Immutable core policy and editable Soul are separate.
- Every callback is rejected unless `runID` matches active run.
- `phase.isBusy` works for every busy associated-value state.
- Stop cancels active URLSession task and invalidates callbacks/approval.
- One command composer remains.
- Dock expands/collapses; ball drags, snaps, clamps, and persists position.
- Existing read-only and approval workflows remain reachable.
- CI builds unsigned; IPA has zero PlugIns and no entitlement file.

### Release A.5 — Engagement Authority Foundation (ships in the same v0.5 PEAK build)

- Versioned `EngagementProfile` model, atomic local persistence, profile hash validation, activation/deactivation, and operator declaration.
- Deny-first origin/path scope matcher with explicit wildcard semantics and testing-window/budget checks.
- Neutral/in-scope/out-of-scope status exposed to the adaptive dock and Mission Control.
- No active probing tools yet; this release creates authority and UX boundaries before Release B expands tools.

Acceptance: malformed/expired/tampered profiles fail closed; out-of-scope always beats in-scope; page/model/relay cannot mutate profile; no platform name or endpoint is required by the schema.

### Release B — v0.6.0 Typed Tools + Bound Approval

- `JSONValue`/typed per-tool arguments and strict results.
- Target resolver and target fingerprints.
- Single-use approval token bound to run/tab/origin/epoch/snapshot/target/expiry.
- Human effect previews, Edit, Show Target.
- Navigation coordinator and popup/redirect/download interception.
- Bundled adversarial HTML fixtures and XCTest target.

Acceptance: stale/changed target cannot execute; no JS failure becomes success; every mutating action is exactly-once.

### Release C — v0.7.0 Latest-iOS Magnetic Capsule

- Latest-iOS-only deployment baseline.
- Page-first Magnetic Capsule with collapsed Ball, compose, active, and durable result surfaces.
- Modern Mission Control sheet, adaptive 320pt/AX layout, and Reduce Motion crossfade.
- Runtime, approval authority, redaction, navigation settlement, and one-owner invariants retained.

### Future Release — Browser Workstation (version TBD)

- Multi-tab ownership/session restore.
- SQLite sessions/runs/events/checkpoints and hash-chained redacted audit log.
- Notes/Files/Runs Library.
- Downloads quarantine, Markdown/JSON/CSV/PDF export.
- Screenshot, Vision OCR, reader/table/card extraction.

### Future Release — Recipes + Memory (version TBD)

- Typed declarative recipes; no raw JS/shell/dynamic tools.
- Recipe hash/capability diff and saved exact-scope grants.
- Site memory and Operator profile fields with provenance/data class.
- Research plan approval with origin/effect budgets.

### Future Release — Hermes Relay (version TBD)

- Direct/Relay/Hybrid modes.
- Versioned capability handshake and signed run nonce.
- Durable remote research/delegation/cron/webhook/MCP/terminal jobs.
- Redacted task packages and artifact sync.
- Relay returns answers/artifacts/proposals only; local device remains execution authority.

## 8. Verification matrix

### Pure tests

- Runtime state transition table and terminal states.
- Stale callback from run A after run B starts.
- Stop during model request, snapshot, approval, execution, and navigation wait.
- JSONValue nested round-trip and strict argument validation.
- Redaction for password, OTP, card, token, hidden input, query token, log preview.
- Soul save/load/migrate/reset and inability to override policy.
- Dock normalized position clamp/snap math across representative safe-area sizes.
- Engagement wildcard/path/deny precedence, expiry, profile hash, declaration, and budget tests.
- `SecretHandle` payload contains only an opaque identifier and never serializes the resolved value.

### Adversarial fixtures

- Visible/ARIA/alt/table/PDF prompt injection.
- Sensitive values present before snapshot.
- Target changes after approval.
- Same selector moved to different form.
- Cross-origin redirect, popup, download, custom scheme.
- JS throw, invalid selector, delayed navigation, SPA route mutation.
- Old relay response/replayed call ID.

### Release gates

```text
XCTest/static validation green
XcodeGen generation green
unsigned device build green
Info.plist version/build verified
MinimumOSVersion = 26.0
PlugIns/extensions = 0
no .entitlements
no package dependency
manifest version/downloadURL/size verified from raw GitHub
manual device: read-only goal, approval, deny, stop, dock drag/collapse, Soul persistence
```

## 9. Falsification criteria

The direction is wrong if:

- K3 still feels like a chat panel attached to a browser.
- More than one primary composer remains.
- Idle dock covers more than roughly 15% of the viewport or the ball cannot be moved away from content.
- Keyboard or safe area hides Stop/approval.
- A stale callback or approval can affect a newer run/page.
- Any sensitive field value reaches model, log, memory, export, or relay.
- A page, recipe, model, or relay can expand its own authority.
- An out-of-scope URL can execute a research tool, or a tampered/expired engagement remains active.
- Evidence tampering is not detected, or a report cites evidence that cannot be reproduced to a page epoch/tool digest.
- Read-only research triggers approval fatigue.
- Final results disappear into a timeline instead of becoming artifacts.
- Release adds signing fragility, PlugIns, entitlements, or external packages.

## 10. Immediate execution order

1. Add characterization/static safety tests for current snapshot/prompt/runtime invariants.
2. Implement run identity, real busy state, cancellation generation, and immutable goal context.
3. Implement centralized redaction and sanitized snapshot construction.
4. Split immutable core policy from editable Operator Soul.
5. Implement settings storage ownership and migrations.
6. Add EngagementProfile persistence, deny-first scope matcher, and inactive/in-scope/out-of-scope status without adding probe tools.
7. Build Adaptive Agent Dock + draggable snapping Agent Ball with engagement/status badges.
8. Replace duplicate composer/cockpit shell with Mission Control while preserving existing tools.
9. Run static checks; commit Release A/A.5 source.
10. Push main, tag `k3browser-v0.5.0`, verify CI/release IPA.
11. Inspect IPA and publish manifest only after verified artifact.
