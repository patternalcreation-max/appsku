# DESIGN.md — K3Browser Magnetic Capsule

Updated: 2026-07-29

Current implementation anchor: **K3Browser v0.7.0 build 9**. Detailed interaction and acceptance contract: `K3Browser/K3BROWSER_AGENT_UI_REDESIGN_GUIDE.md`.

## Thesis

K3Browser is a page-first native operator instrument. The webpage is the workspace. The Ball is the agent; capsules are temporary speech. Agent chrome never resizes the WKWebView.

## Visual world

- Latest-generation native SwiftUI, SF Symbols, semantic system colors, and restrained system material.
- Indigo: interaction and active state.
- Orange: approval only.
- Red: error, blocked, and Stop.
- Green: completed result only.
- No gradients, glow, pulse, AI orb, terminal chrome, chat bubbles, floating card stacks, fake security indicators, or unsupported capability buttons.

## Composition

```text
┌ Native browser rail ┐
│                     │
│   WKWebView page    │  Stable primary workspace
│               ● K3 │  Collapsed movable Ball
│                     │
└─────────────────────┘

Tap idle Ball → bottom compose Capsule overlays page.
Tap busy Ball → compact active-status Capsule overlays page.
Terminal result → durable result Capsule overlays page.
Approval → blocking authority surface above page and agent.
```

## Magnetic Capsule states

### Collapsed

- One 56pt draggable Ball; the only floating object.
- Drag threshold 8pt; clamp to safe area; snap left/right.
- Persist only final edge and normalized Y, never drag frames or runtime state.
- Tap idle opens compose; tap busy opens active status; pending approval opens Review.
- VoiceOver actions include Compose/Open status, Review, Stop, Mission Control, Move Left, and Move Right as context allows.

### Compose

- Bottom overlay with 16pt horizontal inset; keyboard moves the Capsule, not the WKWebView.
- Exactly one `TextField`, one Run action, explicit Mission Control, and explicit collapse.
- Valid Run removes the field from hierarchy before runtime proceeds.
- 320pt and accessibility Dynamic Type use an adaptive stacked layout; controls remain at least 44pt.

### Active

- Compact status/tool text, one-tap red Stop, Mission Control, and collapse.
- No composer while runtime is busy.

### Result

- Success/error excerpt remains until explicit dismiss or Details.
- Terminal errors outrank any answer left by an older run.
- Results completing behind approval or another presentation are deferred and revealed when authority conflict clears.
- Every displayed result passes centralized redaction.

## Browser rail

- Back, Forward, address/search, Reload or Stop Loading.
- Every icon target is at least 44×44pt.
- Stable progress height; no fake lock, tabs, library, profile, or unsupported browser controls.

## Approval authority

- Approval is a blocking authority boundary, not a notification.
- Render only exact action title, tool, `request.preview`, and `request.reason`; never raw arguments.
- Page and Agent leave touch and accessibility trees while pending.
- Context scrolls; Deny and tool-specific one-time approval remain pinned and at least 44pt.
- Orange accent is one hairline; primary approval uses indigo.
- Initial arrival announces without stealing focus. Explicit reopen focuses Deny. VoiceOver Escape denies.
- No outside dismissal, optimistic execution, batch approval, or session-wide approval.

## Mission Control

- Native `NavigationStack` presented with medium/large detents.
- Root destinations: Current Run, Activity, Page Snapshot, Manual Tools, Agent Settings.
- No command composer. Manual actions stage the normal approval path.
- One presentation router serializes Mission Control, Share, and approval reveal.

## Motion and accessibility

- Normal Ball↔Capsule transition: 180–240ms shared geometry.
- Reduce Motion: short opacity crossfade with no spatial morph.
- Support Dark Mode, safe areas, keyboard, 320pt compact width, AX5 Dynamic Type, VoiceOver, and 44pt minimum targets.
- Color never carries approval/result meaning alone.

## Hard boundaries

- One `BrowserState`, one `AgentSettings`, one `DockPreferences`, one `WKWebView`, one command composer, one active-run coordinator, and one presentation router.
- UI leaves receive values, bindings, and closures; they do not execute JavaScript, tools, model calls, storage, or authority classification.
- Device Runtime remains enforcement authority. Page/model/file/relay content cannot grant authority.
- UI changes cannot weaken immutable run identity, cancellation, stale-callback rejection, navigation settlement, redaction, Keychain truthfulness, approval classification, scope matching, canonical hashing, or budgets.

## Quality gate

```bash
python3 K3Browser/scripts/validate_release_a.py
python3 K3Browser/scripts/validate_release_a5.py
python3 K3Browser/scripts/validate_agent_dock.py
python3 K3Browser/scripts/validate_ui_architecture.py
```

Then require XcodeGen + unsigned arm64 Xcode build. Real-device acceptance remains required for baseline command, approval/reopen/Deny, keyboard, 320pt/AX5, Dark Mode, VoiceOver, Reduce Motion, Ball persistence, Stop, result deferral, redirects, and timeout recovery.
