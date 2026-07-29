# DESIGN.md — K3Browser Adaptive Native UI

Updated: 2026-07-29

Current implementation anchor: K3Browser v0.6.0 build 8.

## Thesis

K3Browser is a page-first native operator instrument. The webpage is the workspace. Browser chrome stays quiet while browsing; K3 becomes visually assertive only while observing, acting, awaiting approval, or presenting a result.

## Visual world

- Native iOS 15 SwiftUI surfaces and SF Symbols.
- Semantic system colors; no fixed hex/RGB palette.
- Indigo: interaction and active agent state.
- Orange: approval accent only.
- Red: error, blocked, and Stop.
- Green: completed state only.
- System backgrounds/materials adapt to Light and Dark Mode.
- SF typography; monospaced text only for URLs, selectors, tool names, timestamps, hashes, and diagnostics.

Do not add gradients, glow, pulse effects, AI orbs, terminal chrome, chat bubbles, floating card stacks, card-inside-card dashboards, or ornamental metrics.

## Composition

```text
┌ Native browser rail ┐
│                     │
│   WKWebView page    │  Primary workspace
│                     │
├ Agent shelf ────────┤  Expanded; resizes page
└ Home safe area ─────┘

Collapsed: only the movable 56pt Agent Ball overlays the page.
```

### Browser rail

- Back, Forward, address/search, Reload or Stop Loading.
- Every icon target is at least 44×44 pt.
- No fake lock, tabs, library, profile, or capability buttons.
- Progress occupies stable height and never shifts layout.

### Agent shelf

- Exactly one command composer in the entire app.
- Header states the current operational phase.
- Run and Stop are mutually exclusive.
- Mission Control remains available while idle.
- Expanded shelf uses a bottom safe-area inset and resizes the page.
- Accessibility Dynamic Type stacks controls vertically and keeps the shelf scrollable.

### Agent Ball

- The only floating object.
- 56pt diameter with semantic phase symbol and border.
- Drag threshold: 8pt.
- Snaps left/right in 150–250ms unless Reduce Motion is enabled.
- Persist only collapsed state, final edge, and final normalized Y—not drag frames.
- VoiceOver supports Expand, Move Left, and Move Right.

### Approval review

- Approval is a blocking authority boundary, not a notification.
- The page remains visible but cannot receive touch or accessibility focus.
- Review context is vertically scrollable.
- Deny and exact action-specific approval remain pinned and at least 44pt.
- Orange marks risk; the primary CTA uses high-contrast indigo.
- Initial presentation announces without stealing focus. Explicit reopening focuses Deny.
- VoiceOver Escape denies the action.
- No outside-tap dismissal, optimistic execution, batch approval, or session-wide approval.
- Mission Control and Share must dismiss before approval is revealed.

### Mission Control

- Native `NavigationView`, inset-grouped lists/forms, and `NavigationLink` hierarchy.
- Root destinations: Current Run, Activity, Page Snapshot, Manual Tools, Agent Settings.
- No command composer.
- No four-way segmented dashboard.
- Manual actions stage the same normal approval flow.
- API key remains a `SecureField` backed by the existing Keychain path.

## Interaction story

1. Browse with quiet chrome and maximum page area.
2. Expand K3 from the Agent Ball.
3. Enter one bounded operation.
4. Observe a plain-language runtime phase.
5. Review any consequential action in the blocking approval surface.
6. Inspect results/evidence in Mission Control.
7. Collapse K3 and return the page to maximum area.

## Hard product boundaries

- One `BrowserState`, one `AgentSettings`, one `WKWebView`, one command composer.
- UI leaves receive values, bindings, and closures; they do not execute JavaScript, tools, model calls, storage, or authority classification.
- Device Runtime remains the enforcement authority.
- Page/model/file/relay content cannot grant authority.
- UI extraction must not change run identity, stale callback rejection, navigation settlement, redaction, storage truthfulness, or approval classification.

## Quality gate

A UI release is incomplete until it passes:

```bash
python3 K3Browser/scripts/validate_release_a.py
python3 K3Browser/scripts/validate_release_a5.py
python3 K3Browser/scripts/validate_agent_dock.py
python3 K3Browser/scripts/validate_ui_architecture.py
```

Then require XcodeGen + unsigned arm64 `xcodebuild` in GitHub Actions.

Real-device acceptance remains required at 320/375/390/430pt widths, Light/Dark Mode, AX5 Dynamic Type, VoiceOver, software keyboard, Reduce Motion, and pending-approval presentation transitions.
