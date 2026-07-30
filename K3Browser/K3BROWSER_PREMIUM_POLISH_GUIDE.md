# K3Browser — Premium UI/UX Polish Guide

Concrete, implementable SwiftUI recommendations to take K3Browser from
"functional prototype" to "$5 App Store polish." Every recommendation is
grounded in the actual codebase and respects the **restraint principles**
already established in `K3BROWSER_AGENT_UI_REDESIGN_GUIDE.md` (no glass on
every layer, no mesh gradients, no looping glow, no custom haptic sequences).
The goal is **execution quality within the existing design language**, not a
visual rewrite.

---

## 0. Audit: What the code has today

| Surface | Current state | Gap vs. premium |
|---|---|---|
| **BrowserChromeView** | Flat `.systemBackground`, flat TextField, 2px progress line | No depth, no material, progress bar invisible at a glance |
| **TabStripView** | Text-only capsule pills, solid indigo active fill | No favicons, no visual identity, no swipe-to-close, pills feel like buttons not tabs |
| **AgentDock (Ball)** | `.regularMaterial`, `matchedGeometryEffect`, phase symbols | Best-polished surface — but symbols swap statically, no `symbolEffect` |
| **MissionControlView** | `.insetGrouped` List, NavigationLinks | Functional but default — no visual hierarchy, no search, no section iconography |
| **HistoryBookmarksView** | Plain `VStack` rows, text-only | No favicons, no time grouping, no visual scanning affordance |
| **Haptics** | **Zero implementations** in Swift (guide calls for them) | Completely missing |
| **TabItem model** | `id, url, title` only | No favicon, no loading state, no screenshot |
| **Empty states** | Single `Label("No history yet", systemImage: "clock")` | No illustration, no call-to-action, no personality |
| **Typography** | `.caption`, `.body`, `.headline` scattered | No type scale, no weight discipline, no tracking |

---

## 1. Visual patterns top iOS browsers use that K3Browser lacks

### 1.1 Translucent chrome with real material depth

**The problem:** `BrowserChromeView` uses `K3VisualSystem.Palette.rail` which is
solid `.systemBackground`. Safari, Orion, and Pine all use `.bar`/`.thinMaterial`
so the page content glows *through* the chrome, creating depth without
heaviness.

**The fix** (additive — one line in the background):

```swift
// BrowserChromeView.swift — replace the .background modifier
.background(.bar)  // was: K3VisualSystem.Palette.rail
```

`.bar` is Apple's standard chrome material — it's thicker than `.thinMaterial`,
respects scroll underneath, and automatically adapts to light/dark. The address
bar TextField should get its own subtle material:

```swift
// Inside BrowserChromeView, the TextField
TextField("Search or enter website", text: $address)
    // ...existing modifiers...
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(.separator.opacity(0.5), lineWidth: 0.5)
    }
```

> **Restraint note:** This keeps glass on chrome (where Apple puts it) and on
> the Ball (already there). It does NOT add glass to list rows or the tab strip.
> The redesign guide says "glass on every chrome layer" is rejected — but a
> single `.bar` on the nav chrome IS the standard chrome treatment, not a layer
> spree.

### 1.2 Reader / privacy state in the address bar

Premium browsers show a lock icon, reader-mode toggle, or share button *inside*
the address bar field, not as separate chrome buttons. Add a leading icon:

```swift
TextField("Search or enter website", text: $address)
    // ...existing modifiers...
    .overlay(alignment: .leading) {
        Image(systemName: isSecureConnection ? "lock.fill" : "magnifyingglass")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.leading, 10)
            .accessibilityHidden(true)
    }
    .padding(.leading, 24) // make room for the icon
```

You already track navigation state in `BrowserView.swift`. Expose
`isSecureConnection` (scheme == "https") from the WKWebView delegate
(`didCommit`/`didFinish` already exist at lines 1292/1317).

### 1.3 Bottom-tab large-tile tab switcher (Arc/Safari pattern)

Every premium iOS browser uses a **scrollable grid/stack of page thumbnails**
for tab switching, not a horizontal text strip. The current `TabStripView` is
fine for 1-3 tabs but doesn't scale. Add a "tab overview" as a separate
full-screen cover (like Safari's tab grid) triggered from the tab count:

```swift
// New view — present via .fullScreenCover when user taps a "tabs" button
ScrollView([.horizontal, .vertical]) {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
        ForEach(state._tabs) { tab in
            TabCard(tab: tab, isActive: tab.id == state._tabs[state._activeTabIndex].id)
        }
    }
    .padding(16)
}
```

This is **additive** — the existing `TabStripView` stays for quick switching;
the grid is for managing many tabs.

---

## 2. SwiftUI techniques for depth, materials, and elevation

### 2.1 Shadow elevation for the Ball and approval sheet

The Ball (`AgentDock.swift`) currently has `.regularMaterial` + a hairline
stroke. Premium floating elements have a **soft drop shadow** that anchors
them in space. Add:

```swift
// AgentDock.swift — collapsedBall, after .overlay(Circle().stroke(...))
.shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
.shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)  // tighter contact shadow
```

Two stacked shadows (wide+soft + tight+sharp) is the iOS HIG pattern for
"physical object floating above content." Same treatment for the capsule:

```swift
// AgentDock.swift — capsuleMaterial extension
.shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 6)
```

### 2.2 `matchedGeometryEffect` for tab → card expansion

You already use `matchedGeometryEffect` on the Ball↔Capsule. Use the same
technique for tab pills in the strip — when a tab is tapped, the active pill
morphs to indicate focus:

```swift
@Namespace private var tabNamespace

// In tabPill, for the active tab background:
.background {
    if isActive {
        K3VisualSystem.Palette.interaction
            .matchedGeometryEffect(id: "active-tab", in: tabNamespace)
    }
}
```

This makes the indigo highlight **slide** between tabs when switching, like
Safari's segmented control, instead of crossfading.

### 2.3 `.shadow` + `.offset` press feedback on buttons

Replace the flat `.buttonStyle(.plain)` on chrome buttons with a reusable
press-feedback style:

```swift
struct PressableChromeButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// Usage:
Button(action: onBack) { Image(systemName: "chevron.left")... }
    .buttonStyle(PressableChromeButton())
```

This gives every chrome button a tactile "push-in" feel — the single biggest
difference between "this is a prototype" and "this is a real app."

---

## 3. Tab management UX

### 3.1 Favicon in every tab pill (see §4 for the model)

```swift
// TabStripView.swift — inside tabPill HStack
HStack(spacing: K3VisualSystem.Space.compact) {
    FaviconView(url: tab.url, size: 16)  // new — see §4.2
    Text(displayTitle)
        .font(.caption.weight(isActive ? .semibold : .regular))
        .lineLimit(1)
    // ...close button
}
```

### 3.2 Swipe-to-close gesture

Add a horizontal swipe on each pill:

```swift
.offset(x: swipeOffset)
.gesture(
    DragGesture(minimumDistance: 10)
        .onChanged { value in
            if abs(value.translation.width) > abs(value.translation.height) {
                swipeOffset = value.translation.width
            }
        }
        .onEnded { value in
            if value.translation.width < -60 {
                withAnimation(.easeOut(duration: 0.2)) {
                    state.closeTab(at: index)
                }
            } else {
                withAnimation(.spring()) { swipeOffset = 0 }
            }
        }
)
```

### 3.3 Long-press drag reorder + close context menu

```swift
.contextMenu {
    Button("Close Tab", systemImage: "xmark", role: .destructive) {
        state.closeTab(at: index)
    }
    Button("Close All Other Tabs", systemImage: "xmark.octagon") {
        // close all except this one
    }
    Button("Duplicate", systemImage: "plus.square.on.square") { }
}
```

### 3.4 Tab count badge on a dedicated "tabs" button

Replace the tiny `+` in the strip with a button that shows the tab count in
Safari's style:

```swift
Button { showTabGrid = true } label: {
    ZStack(alignment: .topTrailing) {
        Image(systemName: "square.on.square")
            .font(.body)
        Text("\(state._tabs.count)")
            .font(.caption2.weight(.bold))
            .padding(3)
            .background(Capsule().fill(K3VisualSystem.Palette.interaction))
            .foregroundStyle(.white)
            .offset(x: 8, y: -8)
    }
    .frame(width: 32, height: 32)
}
```

---

## 4. Favicon / visual identity in tabs and history

### 4.1 Extend `TabItem` (and `HistoryEntry`/`Bookmark`)

```swift
// TabManager.swift — extend TabItem
struct TabItem: Identifiable, Equatable {
    let id: UUID
    var url: String
    var title: String
    var faviconURL: String?     // NEW
    var isLoading: Bool         // NEW — for spinner on pill
    var isSecure: Bool          // NEW — for lock icon
}
```

### 4.2 `FaviconView` — sideload-safe, no entitlements

Fetch favicons via Google's favicon service (no API key, no entitlements) or
build a ` WKURLSchemeHandler`-based fetcher. The simplest sideload-safe
approach — fetch from the favicon URL directly:

```swift
struct FaviconView: View {
    let url: String
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Branded letter-fallback — derive first letter from domain
                Text(String(hostFirstLetter ?? "?").uppercased())
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(
                        Circle().fill(fallbackColor)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        .task { await loadFavicon() }
    }

    private var hostFirstLetter: Character? {
        URL(string: url)?.host?.first
    }

    // Deterministic color from domain — every site gets a stable color
    private var fallbackColor: Color {
        let hash = (URL(string: url)?.host ?? "").hashValue
        let palette: [Color] = [.blue, .purple, .orange, .pink, .teal, .indigo, .green]
        return palette[abs(hash) % palette.count]
    }

    private func loadFavicon() async {
        guard let host = URL(string: url)?.host,
              let faviconURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=64") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: faviconURL)
            if let img = UIImage(data: data) {
                await MainActor.run { self.image = img }
            }
        } catch { /* fallback letter shows automatically */ }
    }
}
```

**Important for sideload-safety:** `URLSession.shared` requires no entitlements.
If you want offline cache, store in `FileManager` temp directory (also no
entitlement). Do NOT use `NSCache` with a memory-pressure concern — use a
simple `[String: UIImage]` dictionary in an `@Observable` cache object.

### 4.3 Favicon in History and Bookmarks rows

```swift
// HistoryBookmarksView.swift — replace the VStack rows
HStack(spacing: 12) {
    FaviconView(url: entry.url, size: 28)
    VStack(alignment: .leading, spacing: 2) {
        Text(entry.title.isEmpty ? entry.url : entry.title)
            .font(.body)
            .lineLimit(2)
        Text(entry.url)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}
```

---

## 5. Empty state design

### 5.1 A reusable empty-state component

The current empty states are one-line `Label`s. Premium apps use a
**centered icon + title + subtitle + action**:

```swift
struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(symbol: String, title: String, message: String,
         actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.symbol = symbol; self.title = title; self.message = message
        self.actionTitle = actionTitle; self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.quaternary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

`.symbolRenderingMode(.hierarchical)` is key — it gives SF Symbols automatic
depth (the top layer is full opacity, inner layers fade). This is free polish.

### 5.2 Apply to History, Bookmarks, Activity

```swift
// HistoryView — empty branch
if state.history.isEmpty {
    EmptyStateView(
        symbol: "clock.arrow.circlepath",
        title: "No History Yet",
        message: "Pages you visit will appear here.",
        actionTitle: "Browse",
        action: { state.navigate(to: "https://duckduckgo.com") }
    )
    .listRowSeparator(.hidden)
    .listRowBackground(Color.clear)
}
```

### 5.3 Empty new-tab state (the "Speed Dial" page)

When a new tab opens and the URL is the default homepage, show a **start
page** with favorite/quick links instead of loading DuckDuckGo directly. This
is the #1 thing Safari/Edge/Chrome do that makes them feel polished:

```swift
// In browserWorkspace, before WebViewContainer, if newTab && not loading:
if isNewTabPage {
    StartPageView(
        bookmarks: state.bookmarks,
        onOpen: { url in state.navigate(to: url) }
    )
    .transition(.opacity)
} else {
    WebViewContainer(webView: state.webView)
}
```

The `StartPageView` would show a search field + a grid of bookmark "tiles"
(favicon + title) — this is the most impactful single feature for "feeling
like a real browser."

---

## 6. Typography hierarchy

### 6.1 Define a type scale in `K3VisualSystem`

```swift
// K3VisualSystem.swift — add to the enum
enum Type {
    static let largeTitle  = Font.largeTitle.weight(.bold)
    static let title       = Font.title2.weight(.semibold)
    static let headline    = Font.headline
    static let body        = Font.body
    static let callout     = Font.callout
    static let subheadline = Font.subheadline
    static let footnote    = Font.footnote
    static let caption     = Font.caption
    static let mono        = Font.caption.monospaced()

    // Semantic
    static let tabTitle    = Font.caption.weight(.medium)
    static let addressBar  = Font.body.weight(.medium)
    static let phaseLabel  = Font.subheadline.weight(.semibold)
    static let detailLabel = Font.caption.foregroundStyle(.secondary)
}
```

### 6.2 Apply consistent weights

- **Tab titles:** `.caption.weight(.medium)` — currently `.caption` (regular)
- **Address bar text:** `.body.weight(.medium)` — currently no weight
- **Phase labels in capsule:** `.subheadline.weight(.semibold)` — already good
- **History row title:** `.body` with `.lineLimit(2)` — currently fine
- **History URL subtitle:** `.caption.foregroundStyle(.secondary)` — add
  `.tracking(-0.2)` for tighter, more "designed" look:

```swift
Text(entry.url)
    .font(.caption)
    .tracking(-0.2)
    .foregroundStyle(.secondary)
```

Negative tracking on small monospaced-ish text (URLs) is a detail that
subliminally reads as "designed by someone who cares."

### 6.3 Tabular numbers for the progress percentage

If you ever show a percentage, use tabular figures so digits don't jitter:

```swift
Text("\(Int(estimatedProgress * 100))%")
    .monospacedDigit()
```

---

## 7. Micro-interactions and haptics

### 7.1 Haptics (currently ZERO in the codebase)

The redesign guide (§5.5) calls for haptics on edge snap, approval arrival,
Stop, and terminal result. None are implemented. Create a centralized helper:

```swift
// K3VisualSystem.swift — add to the enum
enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func soft() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
```

**Wire-up points (all additive, all in existing closures):**

| Event | Location in code | Haptic |
|---|---|---|
| Ball edge snap | `AgentDock.swift` → `snapAndPersist()` | `.medium()` |
| Ball tap → compose | `AgentDock.swift` → `handleBallTap()` | `.light()` |
| Tab switch | `TabStripView.swift` → `state.switchTab` closure | `.selection()` |
| Tab close | `TabStripView.swift` → `closeTab` closure | `.soft()` |
| Approval arrives | `BrowserView.swift` → `onChange(of: state.pendingApproval)` where `approvalID != nil` | `.warning()` |
| Approve tapped | `BrowserView.swift` → `onApprove` closure | `.success()` |
| Deny tapped | `BrowserView.swift` → `onDeny` closure | `.error()` |
| Agent done (terminal) | `AgentDock.swift` → `revealTerminalResultIfEligible()` | `.success()` |
| Agent error (terminal) | same location, `isErrorPhase` branch | `.error()` |
| Address submitted | `BrowserChromeView` → `onSubmitAddress` | `.light()` |
| Bookmark toggled | `BrowserChromeView` → `onToggleBookmark` | `.selection()` |

> **Restraint:** This matches the guide's "only for edge snap, approval
> arrival, Stop acknowledgment, and terminal result" — the tab/button haptics
> are `.selection()` / `.soft()` which are Apple's standard micro-feedback and
> don't count as "custom sequences."

### 7.2 `symbolEffect` for the Ball phase icon (iOS 17+)

The Ball's phase symbol currently swaps statically. SF Symbols 5+ supports
`.symbolEffect` for built-in animations — no looping pulse, just discrete
animate-on-change:

```swift
// AgentDock.swift — collapsedBall, the Image(systemName:)
Image(systemName: presentation.symbol)
    .font(.system(size: 21, weight: .semibold))
    .foregroundStyle(presentation.color)
    .contentTransition(.symbolEffect(.replace))  // smooth morph between symbols
    .symbolEffect(.bounce, value: phase)          // one bounce when phase changes
    .accessibilityHidden(true)
```

`.contentTransition(.symbolEffect(.replace))` crossfades symbol outlines
during `withAnimation`. `.symbolEffect(.bounce, value: phase)` fires a single
bounce when `phase` changes — discrete, not looping.

### 7.3 Progress bar with gradient + animated mask

Replace the flat 2px progress line in `BrowserChromeView` with an indeterminate
shimmer during loading and a smooth determinate fill:

```swift
// BrowserChromeView — replace the GeometryReader progress block
GeometryReader { geometry in
    ZStack(alignment: .leading) {
        Rectangle().fill(.clear)
        if isLoading {
            RoundedRectangle(cornerRadius: 1)
                .fill(
                    LinearGradient(
                        colors: [K3VisualSystem.Palette.interaction.opacity(0.3),
                                 K3VisualSystem.Palette.interaction],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: max(40, geometry.size.width * CGFloat(estimatedProgress)))
                .animation(.easeOut(duration: 0.3), value: estimatedProgress)
        }
    }
}
.frame(height: 3)  // was 2 — 3px reads better
```

### 7.4 Scroll-to-top tap on the status bar area

Not strictly necessary, but add a "scroll to top" when tapping the chrome bar:

```swift
// BrowserChromeView — wrap the top HStack
.onTapGesture(count: 2) {
    state.webView.scrollView.setContentOffset(.zero, animated: true)
}
```

### 7.5 `sensoryFeedback` (alternative to UIKit — iOS 17+)

If you prefer pure-SwiftUI over UIKit generators, `.sensoryFeedback` is
available on iOS 17+:

```swift
// On the Ball
.sensoryFeedback(.impact(weight: .medium), trigger: dockPreferences.edge)
.sensoryFeedback(.success, trigger: phase == .done)
.sensoryFeedback(.error, trigger: phase == .error)
```

This is cleaner but less control than the `Haptics` enum. The codebase imports
UIKit already, so the enum approach is consistent.

---

## 8. Quick wins (smallest change, highest perceived quality)

In priority order — each is a 1-2 line change:

1. **`.background(.bar)` on `BrowserChromeView`** — instant depth
2. **Add `Haptics` enum + wire to tab switch and approval** — instant tactility
3. **`.contentTransition(.symbolEffect(.replace))` on the Ball icon** — smooth phase morphs
4. **`.shadow` on the Ball** — floats above the page
5. **`FaviconView` in tab pills + history rows** — visual identity everywhere
6. **`EmptyStateView` component** — replaces 3 one-line labels
7. **`PressableChromeButton` style** — every button gets tactile feedback
8. **Tab count badge** — Safari-style tab management entry point

---

## 9. What NOT to do (preserving existing restraint)

Per `K3BROWSER_AGENT_UI_REDESIGN_GUIDE.md` §5-6, avoid:

- ❌ Glass/material on list rows or the tab strip background
- ❌ Mesh gradients, refraction backgrounds, neon glows
- ❌ Looping pulse/glow animations on the Ball
- ❌ Custom haptic patterns (use standard `.light`/`.medium`/`.soft`/`.success`)
- ❌ 3D card depth / spatial-computing imitation
- ❌ Particle or parallax effects
- ❌ Monospaced font as decorative "terminal" branding

The recommendations above deliberately stay within these bounds: `.bar` material
is Apple-standard chrome, the shadows are standard iOS elevation, haptics are
built-in generators, and `symbolEffect` is Apple's first-party symbol animation.
