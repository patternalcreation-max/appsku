# K3Browser Agent UI Redesign Guide — Magnetic Capsule

Status: **IMPLEMENTED IN SOURCE — XCODE CI / DEVICE VERIFICATION PENDING**
Updated: 2026-07-29
Target policy: **latest public iOS only; old-iOS compatibility is not a product requirement**

This guide is the synthesis of:

- paid SuperGrok design council, rounds 1–2;
- GLM 5.2 native interaction council, rounds 1–2;
- UI/UX Pro Max guidance used only as a quality rubric;
- iPhone-first operator UI and Impeccable shape/new-work guidance.

It supersedes no shipped implementation until Xcode CI and release verification pass. K3Browser v0.6.0 remains the current released UI until then.

---

## 1. Decision

Replace the v0.6 expanded Agent Shelf with one interaction model:

> **The Ball is the agent. The Magnetic Capsule is temporary speech. The page never yields layout to agent chrome.**

### Selected direction

**Magnetic Capsule**

- Idle browsing shows only the draggable Agent Ball.
- Tapping the idle Ball morphs it into a bottom command capsule.
- Submitting a command collapses the capsule back into a live Ball.
- Tapping the live Ball opens a compact run peek with status and Stop, never a second composer.
- Completion opens a compact result peek so the answer is not lost.
- Approval remains a separate blocking authority surface.
- Mission Control remains the durable evidence/settings workspace, opened through an explicit secondary control.

### Rejected direction

**Edge-Anchor Ribbon** is rejected as primary chrome.

Why:

- a persistent ribbon is a thinner version of the current shelf;
- it makes the product feel like chat chrome;
- it competes with the home indicator and keyboard;
- keeping it open during runs taxes the page continuously;
- side-edge composition is poor at 320pt and for mixed left/right-handed use.

---

## 2. Why v0.6 feels wrong

Ranked by impact:

1. **Wrong state model.** The UI only knows expanded form or mute Ball, while the real jobs are compose, watch, stop, approve, inspect, and read results.
2. **The shelf damages the workspace.** `safeAreaInset` shrinks the WKWebView to display controls, contradicting page-first behavior.
3. **It reads like a Settings form.** Status header + TextField + equal-width Mission/Review/Run buttons create admin-panel hierarchy.
4. **Ball and shelf lack spatial identity.** The floating Ball disappears and an unrelated bottom slab replaces it.
5. **Live work is under-communicated.** Phase text exists, but current tool, stop access, completion, and result are not naturally attached to the page.
6. **Mission Control is over-promoted yet detached.** It competes with Run in the shelf but removes the operator from page context when opened.
7. **Approval is safe but emotionally generic.** It communicates “modal warning” before communicating the exact one-time action.
8. **System materials have no product signature.** The implementation is competent but visually indistinguishable from a SwiftUI utility sample.

Spacing or new colors alone will not fix these structural problems.

---

## 3. Interaction architecture

### 3.1 Presentation ownership

Keep authority and presentation concerns separate:

```text
AgentSurfaceMode
├── collapsed
├── compose
├── activePeek
└── resultPeek

BrowserPresentation
├── missionControl
└── share

Approval
└── existing pending-approval authority path; always supersedes both above
```

Rules:

- `AgentSurfaceMode` owns only the Ball/Capsule presentation.
- Runtime phase remains the source of truth for idle/busy/done/error.
- Mission Control and Share remain on one mutually exclusive router.
- Approval remains outside ordinary presentation state and has highest priority.
- Do not duplicate pending approval, run phase, or authority inside UI-local state.

### 3.2 State transitions

```text
collapsed + tap idle Ball       → compose
collapsed + tap busy Ball       → activePeek
collapsed + completed result    → resultPeek
compose + valid Run/keyboard Go → collapsed + live Ball
compose + explicit collapse     → collapsed
activePeek + collapse           → collapsed + live Ball
resultPeek + dismiss            → collapsed
resultPeek + Details            → Mission Control / Current Run
any state + pending approval    → approval after routed sheet dismissal
approval + Approve/Deny/Escape  → collapsed, live if runtime remains busy
```

Hard constraints:

- Entering busy always removes the command TextField from the hierarchy.
- No command composer exists in activePeek, resultPeek, approval, or Mission Control.
- Approval cannot coexist visually with the Capsule or another sheet.
- Ball edge and normalized Y persist; drag frames, approval, busy, and result presentation do not persist.

---

## 4. State-by-state contract

### 4.1 Collapsed

**Visible**

- 56pt Agent Ball only.
- Quiet phase symbol and semantic stroke.
- Approval badge when a request is pending.

**Behavior**

- Tap while idle: compose.
- Tap while busy: activePeek.
- Drag ≥8pt: move and snap to left/right edge; persist only after snap.
- VoiceOver actions: Compose/Open status, Move Left, Move Right, Stop when busy, Review when pending, Mission Control.

**Page**

- Full frame, fully interactive.
- No dim, blur, or layout change.

### 4.2 Compose

**Geometry**

- Bottom overlay, 16pt horizontal inset.
- Does not use an agent `safeAreaInset` on the WKWebView.
- Single-row default height around 56–64pt; Dynamic Type may stack content vertically.
- Tracks the keyboard and remains above the home indicator.
- The page frame remains identical to collapsed mode.

**Contents**

```text
[K3 / Mission] [Agent command........................] [Run]
```

- Exactly one TextField.
- Leading K3 control explicitly opens Mission Control; do not rely only on long-press.
- Trailing action is Run only.
- Return key uses Go/Run semantics.
- Explicit collapse affordance is reachable at 44pt.
- No permanent status header or three-button action rack.

**Dismissal**

- Run commit or explicit collapse.
- Do not dismiss on outside page tap; the operator may need to read the page while composing.

**Page**

- Unchanged and interactive outside the Capsule hit region.
- No dim or blur.

### 4.3 Active Peek

Opened by tapping the live Ball.

**Contents**

```text
[phase symbol] [Reading page / Acting: click / Waiting…] [Stop] [collapse]
```

- No TextField.
- Current phase/tool is one concise line.
- Stop is explicit, red, and one tap away.
- Mission Control is available as a secondary 44pt action.
- Do not show a raw event log here.

**Page**

- Unchanged and interactive unless the runtime itself requires a temporary interaction lock.
- No dim or blur.

### 4.4 Result Peek

A successful or failed terminal result must not disappear as a 300ms symbol flash.

**Behavior**

- Ball gives one restrained symbol transition and terminal haptic.
- Ball morphs into a compact result Capsule when it will not interrupt approval or another authority surface.
- Show a one- or two-line redacted result excerpt.
- Provide `Details` to Current Run and an explicit dismiss control.
- Do not auto-dismiss before the operator can read it.
- Long results remain in Mission Control; the Capsule is an acknowledgment surface, not a transcript.

**Error variant**

- Red semantic icon and concise failure reason.
- Offer Details; offer Retry only when the runtime already has a truthful retry operation.

### 4.5 Approval

Approval remains the strongest surface.

**Visual hierarchy**

1. Exact one-time action title.
2. Tool name as secondary technical context.
3. `request.preview` and `request.reason` only.
4. Pinned Deny and action-specific Approve.

**Rules retained**

- Page remains visible but receives no touch or VoiceOver focus.
- No page blur; use a stable dim layer.
- No outside-tap or swipe dismissal.
- No implicit, batch, or optimistic approval.
- Accessibility Escape = Deny.
- New request announces without stealing focus mid-edit.
- Explicit reopen focuses Deny.
- Raw arguments never render.

**Craft change**

- Emphasize the action identity, not generic “Approval required” boilerplate.
- Orange is a 3pt risk edge/accent, not a full orange panel.
- Keep decision controls on a solid/readable material above the bottom safe area.

### 4.6 Mission Control

- Modern detented system sheet: glance height for Current Run/Activity, full height for Settings/Tools.
- Modern stack navigation; no command composer.
- Entry is explicit from the compose/active/result Capsule and available as a Ball accessibility/context action.
- Do not make long-press the only discoverability path.
- Approval dismisses Mission Control before revealing its decision surface.
- Start with background interaction disabled; enable it only if device tests prove it does not create authority or focus ambiguity.

---

## 5. Visual system

### 5.1 Material hierarchy

```text
1. WKWebView                 opaque workspace
2. Browser rail             quiet system bar / opaque-enough material
3. Ball + Magnetic Capsule  one restrained modern glass/material family
4. Mission Control          native system sheet
5. Approval                 stable material panel + dim + orange risk edge
```

Use modern/latest-iOS glass behavior only on the Ball/Capsule identity where transparency explains “agent over page.” Do not turn the browser rail, address field, sheet rows, and approval into a Liquid Glass showcase.

### 5.2 Shape language

- Ball: 56pt circle.
- Compose Capsule: continuous pill/rounded rectangle, 16pt side inset.
- Active/result Capsule: same outer geometry; contents change, object identity does not.
- Approval: full-width bottom authority panel with restrained top corners.
- No floating card stacks, nested cards, chat bubbles, dashboard tiles, or generic AI orb.

### 5.3 Typography

- SF system typography throughout.
- `.body` for command and result excerpt.
- `.headline` for approval action.
- Monospaced only for real tools, selectors, URLs, hashes, and timestamps.
- Do not use monospace as decorative “terminal” branding.

### 5.4 Color

- Neutral material at idle.
- Indigo: interaction/focus.
- Orange: pending approval/risk accent.
- Red: Stop/error/blocked.
- Green: terminal success acknowledgment only.
- Never rely on color alone.
- Reject AI-purple/pink gradients, neon, mesh gradients, and glowing phase loops.

### 5.5 Motion and haptics

- Ball ↔ Capsule: 180–240ms shared-geometry transition.
- Edge snap: 150–200ms.
- Approval rise: 200–250ms.
- Phase symbols: discrete replacement, never continuous pulse.
- Haptics only for edge snap, approval arrival, Stop acknowledgment, and terminal result.
- Reduce Motion: crossfade; no spatial morph, no symbol choreography.

---

## 6. Latest-iOS capability policy

### Product-defining

- Shared-object Ball ↔ Capsule transition.
- Reliable keyboard-following overlay without resizing the WKWebView.
- Detented Mission Control sheet.
- Modern stack navigation.
- Semantic phase symbol transitions.
- Native sensory feedback.

### Tasteful craft

- Continuous shape interpolation.
- System glass/material on the sole agent object.
- Modern text input and submit behavior.
- Native sheet background and drag indication.

### Reject as fashion

- Glass on every chrome layer.
- Mesh gradients or refraction backgrounds.
- Particle/parallax agent effects.
- Looping pulse/glow.
- Custom haptic sequences.
- 3D card depth or spatial-computing imitation.

Implementation must verify exact APIs against the selected latest Xcode/iOS SDK. The capability is binding; an unverified API spelling is not.

---

## 7. Implementation boundary

### Presentation files expected to change after approval

- `Browser/UI/AgentDock.swift`
- `Browser/BrowserView.swift` composition only
- `Browser/UI/ApprovalReviewOverlay.swift` hierarchy/craft only
- `Browser/UI/MissionControlView.swift`
- `Browser/Design/K3VisualSystem.swift`
- UI architecture/Dock validators
- `project.yml`, CI Xcode selection, and deployment target for latest-iOS-only policy
- `DESIGN.md` only after the new UI is built and verified

### Must remain untouched in behavior

- one `BrowserState`;
- one `AgentSettings` owner;
- one WKWebView;
- one command composer;
- Device Runtime authority;
- immutable run/action/navigation identity;
- cancellation and stale-callback rejection;
- navigation settlement;
- redaction and snapshot sanitation;
- Keychain secret handles;
- Engagement Profile and deny-first scope matching;
- approval classification, one-time semantics, and fail-closed behavior;
- one presentation router.

UI leaves continue receiving values, bindings, and closures only. They do not evaluate JS, dispatch tools, access Keychain, classify risk, or widen authority.

---

## 8. Subtraction list

Delete from the new design:

1. Expanded bottom shelf that resizes the page.
2. Permanent status-header block.
3. Equal-weight Mission Control / Review / Run button row.
4. Command TextField while busy.
5. Mission Control as the only place to see the latest result.
6. Generic “Approval required” as the strongest approval headline.
7. Hidden long-press-only navigation.
8. Continuous phase animations.
9. iOS 15 compatibility branches and validator bans after deployment target migration.

Keep:

- page-first browsing;
- one composer;
- draggable persisted Ball;
- blocking approval;
- exact one-time CTA labels;
- durable Mission Control evidence/settings;
- all runtime/security enforcement.

---

## 9. Acceptance and falsification gates

The direction is wrong or incomplete if any test fails:

1. **Page geometry:** collapsed, compose, activePeek, and resultPeek retain the exact WKWebView frame. Keyboard movement may reposition the Capsule, not mutate the page contract.
2. **Command speed:** collapsed Ball → focused command → Run is three operator actions or fewer.
3. **Busy exclusivity:** after Run, the TextField leaves the hierarchy within one transition; tapping the live Ball opens status/Stop, not compose.
4. **Stop discoverability:** a first-time operator can stop a run without opening Mission Control or learning a hidden gesture.
5. **Result legibility:** completion produces a readable, dismissible result acknowledgment; the answer does not vanish as a brief green flash.
6. **Mission discoverability:** Settings and Activity are findable without a tutorial or long-press-only knowledge.
7. **Approval supremacy:** approval dismisses/queues competing presentations, blocks page touch/focus, cannot be externally dismissed, and Escape denies.
8. **320pt + keyboard:** Capsule retains ≥44pt controls and no command/action truncation at compact width.
9. **AX5/VoiceOver:** no duplicate composer, hidden background focus, clipped approval actions, or inaccessible Stop.
10. **Reduce Motion:** all spatial morphs reduce to stable crossfades.
11. **Persistence purity:** only final Ball edge/normalizedY and an explicitly approved idle preference survive relaunch.
12. **Runtime purity:** UI changes do not alter tool execution, authority, storage, navigation settlement, or redaction behavior.

---

## 10. Council dissent resolved

- **GLM initially preferred Edge-Anchor Ribbon;** latest-only correction converged on Magnetic Capsule.
- **GLM proposed `safeAreaInset` while claiming no page resize;** rejected. Agent chrome must overlay the workspace without changing WKWebView geometry.
- **Both models suggested very brief success flashes;** strengthened to a readable result Peek.
- **Both considered long-press Mission Control;** retained only as a secondary shortcut, never the sole path.
- **Modern sheet background interaction** remains off by default until device evidence proves it safe and comprehensible.

---

## 11. Raw council artifacts

- `/tmp/k3-ui-brainstorm-supergrok.md`
- `/tmp/k3-ui-brainstorm-glm52.md`
- `/tmp/k3-ui-brainstorm-supergrok-round2.md`
- `/tmp/k3-ui-brainstorm-glm52-round2.md`

These are research artifacts. This document is the canonical synthesis for operator approval.
