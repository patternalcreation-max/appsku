# K3Browser Interaction Architecture Upgrade

**Status:** Proposal · **Target:** iOS 26 SDK (backward-compatible to iOS 17) · **Constraint:** sideload-safe, no entitlements

---

## Executive summary

The Magnetic Capsule (Ball → Compose → Peek) is the right core metaphor and should stay. Five targeted upgrades make the UX dramatically smoother without rewriting the state machine:

1. **Continuous run ribbon** — the capsule stops collapsing on Run; it morphs compose → active → result in place.
2. **Layered z-stack with safe zones** — chrome, tabs, page, and agent get explicit layers; the ball respects a tap-exclusion zone.
3. **Lighter approval card** — replace the full-screen dim wall with a bottom-anchored material card that keeps the page partially visible for verification.
4. **Mission Control reorganized by frequency** — Now / Tools / Library / Setup instead of the flat 4-section list.
5. **Gesture layer** — edge-swipe tab cycling, drag-down capsule collapse, long-press ball quick actions.

All changes are additive — the existing `AgentSurfaceMode` enum, `DockPreferences`, and `ApprovalAuthority` remain untouched.

---

## 1. Agent interaction model: continuous run ribbon

### Current friction

`runIfAllowed()` calls `setSurface(.collapsed)` immediately on Run:

```swift
// AgentDock.swift:382
private func runIfAllowed() {
    guard isConfigured, !phase.isBusy, !isCommandBlank else { return }
    composerIsFocused = false
    setSurface(.collapsed)   // ← kills the conversation context
    onRun()
}
```

The user hits Run → capsule vanishes → ball shows a tiny phase icon → seconds/minutes later a `resultPeek` appears. The gap between "I submitted" and "I see a result" is a dead zone. The `activePeek` mode exists but is only reachable by tapping the ball again.

### Proposed: morph, don't collapse

Keep the capsule visible through the entire run. The surface mode transitions become:

```
collapsed → compose → (Run tapped) → activePeek → resultPeek → (tap/timeout) → collapsed
```

**Change in `runIfAllowed()`:**

```swift
private func runIfAllowed() {
    guard isConfigured, !phase.isBusy, !isCommandBlank else { return }
    composerIsFocused = false
    setSurface(.activePeek)   // ← morph in place, keep context
    onRun()
}
```

The `activePeek` capsule already shows live status (`statusText ?? phase.label`) and a Stop button. The matched geometry effect (`agentMatchedGeometry`) handles the morph animation for free.

### Auto-collapse terminal results

Add a gentle auto-dismiss for `resultPeek` so the page reclaims attention, with reduce-motion and accessibility respect:

```swift
@State private var resultDismissTask: Task<Void, Never>?

private func revealTerminalResultIfEligible() {
    guard isTerminal(phase),
          !resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          pendingApprovalCount == 0,
          !hasPresentationConflict else { return }
    composerIsFocused = false
    setSurface(.resultPeek)
    scheduleResultAutoCollapse()
}

private func scheduleResultAutoCollapse() {
    resultDismissTask?.cancel()
    guard !reduceMotion else { return }  // respect reduce-motion: stay visible
    resultDismissTask = Task {
        try? await Task.sleep(for: .seconds(6))
        if !Task.isCancelled, surfaceMode == .resultPeek {
            setSurface(.collapsed)
        }
    }
}
```

**Why this works:** the capsule becomes a single continuous "agent speech" surface. The user never loses track of what they asked and what's happening. The ball is still the resting state — the capsule just persists through the conversation arc instead of blinking out.

---

## 2. Tabs, agent, and browsing: layered coexistence

### Current layout

```swift
// BrowserView.swift:1462
VStack(spacing: 0) {
    BrowserChromeView(...)      // address bar + nav
    TabStripView(state: state)  // horizontal pill scroll
    WebViewContainer(webView: state.webView)
}
// agentOverlay floats in a ZStack on top — can overlap anything
```

The agent ball can drift over the address bar tap zone or the tab strip. The tab strip is always visible even with one tab.

### Proposed: explicit layers with safe zones

```
┌─────────────────────────────────────┐
│  Layer 1: Chrome (collapsible)       │  ← .topBar opacity ties to scroll
│  Layer 2: Tab strip (conditional)    │  ← hidden when tabs.count == 1
├─────────────────────────────────────┤
│  Layer 0: WebView (full bleed)       │
│                                      │
│         ┌─────────┐                  │
│         │  Agent   │  ← Layer 3: floating
│         │  Ball    │     respects safe zone
│         └─────────┘                  │
└─────────────────────────────────────┘
```

#### Tab strip visibility

Hide the strip when there's only one tab — reclaim vertical space for the page:

```swift
// TabStripView.swift
var body: some View {
    Group {
        if state._tabs.count > 1 {
            ScrollViewReader { proxy in
                // existing pill scroll...
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    .animation(K3VisualSystem.Motion.animation(reduceMotion: reduceMotion), value: state._tabs.count)
}
```

#### Chrome collapse on scroll (iOS 26)

Use the new scroll-linked APIs to compact the address bar as the user scrolls down, Safari-style:

```swift
// iOS 26: scrollEdgeEffectStyle + containerRelativeFrame
// Pre-iOS 26 fallback: observe WKWebView scrollView.contentOffset
BrowserChromeView(...)
    .scrollEdgeEffectStyle(.automatic, for: .top)
```

If targeting < iOS 26, wire `webView.scrollView.contentOffset` to a `@State` offset and collapse the chrome height proportionally.

#### Ball safe zone

Add a top exclusion band so the ball never parks over the chrome/tab controls:

```swift
// AgentDock.swift — safeBallBounds()
private func safeBallBounds(in geometry: GeometryProxy) -> BallBounds {
    let radius = ballDiameter / 2
    let safeInsets = geometry.safeAreaInsets
    let sideMargin = K3VisualSystem.Space.standard
    let chromeExclusion: CGFloat = 120  // chrome + tab strip height
    let topMargin = safeInsets.top + chromeExclusion + K3VisualSystem.Space.standard
    let bottomMargin = K3VisualSystem.Space.generous
    // ... rest unchanged
}
```

---

## 3. Approval flow: lighter card, keep the gate

### Current

`ApprovalReviewOverlay` is a full-screen ZStack at `zIndex(100)` with a 42%-opacity black scrim. Everything behind is `.disabled` + `.accessibilityHidden`. This is **correct for safety** but visually destroys context — the user can't see the page element they're about to approve an action on.

### Recommendation: keep the hard gate, soften the visual

The approval must remain a non-bypassable modal interaction (you cannot let the page receive touches during approval). But the visual treatment should shift from "wall" to "focused card":

- **Partial scrim** (25% instead of 42%) so the page stays partially visible
- **Bottom-anchored card** using the same material as the capsule (visual continuity)
- **Same matched geometry namespace** so the approval card feels like it grew from the ball

```swift
struct ApprovalCardOverlay: View {
    let request: ApprovalRequest
    let focusDeny: Bool
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Partial scrim — page stays visible for verification
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { }  // swallow, don't dismiss

                VStack(spacing: 0) {
                    // grabber
                    Capsule()
                        .fill(.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)

                    ScrollView { contentBlock }
                        .frame(maxHeight: geometry.size.height * 0.5)

                    actionRow
                }
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
```

### Why not a tray/card that's always visible?

An always-visible approval tray would train users to ignore it (banner blindness). Approvals should be **interruptive by design** — they exist precisely because the action is consequential. The card approach keeps the interruptiveness while restoring page context.

### Batch approvals

If the agent queues multiple approvals in a run, show a count in the card header and let the user approve/deny-all-similar:

```swift
HStack {
    Text("Action 2 of 3")
        .font(.caption)
        .foregroundStyle(.secondary)
    Spacer()
    Button("Approve all fill actions") { ... }
        .font(.caption)
}
```

This requires extending `ApprovalRequest` / `ApprovalAuthority` to expose a queue — minimal surface change.

---

## 4. Mission Control: reorganize by frequency

### Current structure (flat)

```
Current Run
Inspect
  ├ Activity
  └ Page Snapshot
Sessions
  ├ History
  └ Bookmarks
Operate
  ├ Manual Tools
  ├ Workflows
  ├ Agent Settings
  └ Relay
```

**Problems:**
- "Current Run" duplicates the capsule's live status.
- "Agent Settings" (API key, model — the #1 first-run task) is buried at the bottom.
- No quick path to compose a new command from inside Mission Control.
- All rows are the same visual weight despite wildly different usage frequency.

### Proposed: 4 tiers, frequency-ordered

```
┌─ NOW ────────────────────────────────┐
│  [Live status badge]                  │
│  [Inline compose field if idle]       │  ← quick command without dismissing
│  [Stop button if busy]                │
├─ TOOLS ───────────────────────────────┤
│  Manual Tools                         │
│  Workflows                            │
│  Page Snapshot                        │
├─ LIBRARY ─────────────────────────────┤
│  History                              │
│  Bookmarks                            │
│  Notes & Memory                       │  ← promote from Manual Tools
├─ SETUP ───────────────────────────────┤
│  Agent Settings  ⚡ first-run badge   │  ← promote to top of Setup
│  Relay                                │
└───────────────────────────────────────┘
```

#### SwiftUI pattern: inline compose in the NOW section

```swift
Section {
    if state.phase.isBusy {
        statusRow
        Button(role: .destructive, action: state.stopAgent) {
            Label("Stop active run", systemImage: "stop.fill")
        }
    } else {
        TextField("Quick command", text: $quickCommand, axis: .vertical)
            .lineLimit(1...4)
            .onSubmit { runFromMissionControl() }
        Button("Run", action: runFromMissionControl)
            .disabled(quickCommand.trimmingCharacters(in: .whitespaces).isEmpty)
    }
} header: {
    Label("Now", systemImage: K3VisualSystem.presentation(for: state.phase).symbol)
}
```

#### First-run badge for Agent Settings

```swift
NavigationLink(destination: AgentSettingsView(settings: settings)) {
    HStack {
        Label("Agent Settings", systemImage: "gearshape")
        if settings.apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(K3VisualSystem.Palette.error)
                .accessibilityLabel("Setup required")
        }
    }
}
```

#### iOS 26: use Form with new container backgrounds

```swift
.formStyle(.grouped)
.scrollContentBackground(.hidden)
.background(.regularMaterial)
```

---

## 5. Gesture layer

### Swipe between tabs

Edge-swipe on the WebView content cycles tabs. Detect via a transparent gesture layer or by intercepting the WKWebView's scroll view:

```swift
// In WebViewContainer or a wrapper
.simultaneousGesture(
    DragGesture(minimumDistance: 30, coordinateSpace: .local)
        .onEnded { value in
            let horizontalDominant = abs(value.translation.width) > abs(value.translation.height)
            guard horizontalDominant else { return }
            // Only trigger from screen edges to avoid stealing page gestures
            guard value.startLocation.x < 30 || value.startLocation.x > geometry.size.width - 30 else { return }
            if value.translation.width < 0 {
                state.switchToAdjacentTab(direction: .right)
            } else {
                state.switchToAdjacentTab(direction: .left)
            }
        }
)
```

Add to `BrowserState`:

```swift
enum TabDirection { case left, right }

func switchToAdjacentTab(direction: TabDirection) {
    let next: Int
    switch direction {
    case .left: next = max(0, _activeTabIndex - 1)
    case .right: next = min(_tabs.count - 1, _activeTabIndex + 1)
    }
    switchTab(to: next)
}
```

### Drag-down to collapse capsule

The capsule currently requires tapping the chevron. Add a drag-down gesture:

```swift
// Apply to capsuleForCurrentMode
.gesture(
    DragGesture(minimumDistance: 20, coordinateSpace: .local)
        .onEnded { value in
            if value.translation.height > 40, abs(value.translation.width) < 60 {
                collapse()
            }
        }
)
```

### Long-press ball: quick actions

```swift
.collapsibleContextMenu {
    Button("Mission Control", systemImage: "scope") { onOpenMissionControl() }
    if phase.isBusy {
        Button("Stop", role: .destructive) { onStop() }
    }
    Button("New tab", systemImage: "plus") { /* delegate */ }
    Divider()
    Button(dockPreferences.edge == .left ? "Move right" : "Move left",
           systemImage: "arrow.left.and.right") {
        moveBall(to: dockPreferences.edge == .left ? .right : .left)
    }
}
```

### Pull-to-refresh

`WKWebView` doesn't natively support pull-to-refresh and injecting a `UIRefreshControl` into its scroll view is fragile across iOS versions. **Keep the reload button.** It's more reliable and sideload-safe.

---

## iOS 26 API opportunities

| API | Use |
|-----|-----|
| `.scrollEdgeEffectStyle(.automatic)` | Chrome collapse on scroll |
| New `.glassEffect()` / thicker materials | Capsule + approval card depth |
| `containerRelativeFrame` | Adaptive capsule sizing |
| `.symbolEffect(.pulse)` | Ball phase animation (thinking, observing) |
| `Animation.smooth(duration:bounce:)` | Replace `.easeInOut` for spring-like morphs |
| `.scrollTargetBehavior(.paging)` | Tab strip paging if switching to paged layout |

All degrade gracefully — gate behind `if #available(iOS 26, *)` and fall back to existing `.regularMaterial` / `.easeInOut`.

---

## Migration safety

- **No state machine rename:** `AgentSurfaceMode` stays; only `runIfAllowed()` changes its target mode.
- **No new entitlements:** all gestures use `DragGesture` / `.contextMenu`, no `UIGestureRecognizer` subclasses that might trip sideloading.
- **No approval model change:** `ApprovalAuthority` is untouched; only the presentation view swaps.
- **Feature flags:** wrap each change in a `@AppStorage("ux.continuousRibbon")` bool for staged rollout.

---

## Priority order

1. **Continuous run ribbon** (§1) — highest impact, smallest diff (one line + auto-collapse task)
2. **Approval card** (§3) — highest UX win for trust/verification
3. **Mission Control reorg** (§4) — discoverability, first-run experience
4. **Ball safe zone + tab strip visibility** (§2) — polish
5. **Gestures** (§5) — power-user delight, ship last
