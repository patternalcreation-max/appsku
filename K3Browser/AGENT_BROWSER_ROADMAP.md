# K3Browser Peak Native iOS Agent Browser Roadmap

Status baseline: v0.3.1 is a launch-safe SwiftUI + WKWebView browser with URL bar, Agent panel, page snapshot, Keychain API key, OpenAI-compatible chat completion, Ask Page, summarize, CSS fill/click, custom JS probe, copy/share. The next architecture should keep the same sideload-safe posture: no App Groups, no extensions, no NetworkExtension/VPN, no Autofill extension, no private entitlements.

## 1. Ultimate product vision

K3Browser should become a **native iOS agent cockpit around WKWebView**: a browser where the page is the workspace, the agent has structured perception + tool execution, and every risky action is user-gated. Not a fragile fork of Safari/DDG/Brave; a small, owned, sideload-safe shell that can iterate quickly through GitHub Actions and Feather/KSign.

The peak version is:

- **Agent-first mobile browser**: URL bar + tabs + bookmarks are normal browser basics, but the main differentiator is a page-aware agent that can inspect, plan, click, fill, extract, compare, save, and hand off.
- **Native tool runtime**: Swift owns browsing state, files, downloads, tab/session memory, screenshots, OCR, document import/export, clipboard/share sheet, and safe UI gates. JavaScript is only the page bridge.
- **Local-first trust model**: API keys in Keychain; user data in app sandbox; memory stored in SQLite/JSON files under Documents/Application Support; optional remote Hermes relay only when explicitly configured.
- **Operator-gated autonomy**: agent can propose a multi-step plan, but clicks/submits/navigation/file uploads/payments are paused in an approval tray. Low-risk read-only extraction can run freely.
- **Workflow browser**: saved “recipes” turn repeated browsing tasks into one-tap workflows: summarize current page, extract leads, compare prices, fill standard profile form, monitor page changes, scrape table to CSV, draft reply, etc.

North-star tagline: **“Safari Reader + Shortcuts + mobile Operator agent, but sideload-safe and fully yours.”**

## 2. Highest-leverage features

### A. Real agent loop, not just Ask Page

Add an agent runtime that loops through `observe -> reason -> propose action -> approval -> execute -> observe` with step limits.

Core actions:

- `snapshot_page`: structured DOM/text/links/forms/buttons/headings/tables.
- `click_selector`, `fill_selector`, `select_option`, `submit_form`.
- `scroll`, `back`, `forward`, `reload`, `open_url`.
- `extract_table`, `extract_links`, `extract_readable_article`.
- `screenshot_viewport`, `ocr_screenshot` when enabled.
- `download_current`, `save_note`, `export_csv/json/markdown`.

High leverage because current v0.3.1 already has snapshot + fill/click; this turns it into a controlled autonomous agent.

### B. Safety gates / approval tray

Do not let the agent freely click arbitrary page controls. Classify tools:

- **Read-only auto-allowed**: snapshot, summarize, extract text/links/forms, screenshot, OCR, local note creation.
- **Low-risk gated optional**: scroll, open URL in same tab, focus field.
- **Always require approval**: click, fill, submit, file upload, clipboard write, download, external share, navigation to non-current domain.
- **Hard block / extra confirmation**: payments, crypto wallet pages, login password fields, deleting data, account settings, 2FA flows.

UI pattern: a compact bottom tray, not fullscreen modal. It shows selector, element label, domain, risk reason, and buttons: `Run once`, `Deny`, `Edit selector/value`. Never “approve all future actions.”

### C. Better page perception

Current text snapshot is useful but shallow. Add multi-layer perception:

- DOM outline with stable selectors, labels, aria, role, visibility, bounding boxes.
- Form schema: fields, types, placeholders, required status, current values masked for passwords.
- Link graph: internal/external/download/mailto/tel.
- Tables/lists/cards extraction.
- Reader-mode article extraction via JS heuristics.
- Element hit-map: clickable candidates with index numbers rendered in overlay for user/agent reference.

### D. Tabs + sessions + memory

Browser basics become agent power:

- Multiple tabs with per-tab WKWebView/session state.
- Session restore.
- Bookmarks/favorites/history.
- Per-site memory: preferences, last task, extracted facts, saved selectors.
- Global agent notebook: local Markdown/JSON notes generated from pages.

### E. Workflow recipes

Saved workflows are more valuable than generic chat. Examples:

- `Summarize + save note`.
- `Extract all links as Markdown`.
- `Extract table to CSV`.
- `Fill this form from my profile`.
- `Compare current product across search results`.
- `Monitor page for price/status text change`.
- `Research mode`: open N links, summarize each, synthesize.

Recipes should be JSON/plist definitions in app sandbox, user-editable/exportable.

### F. Files, downloads, imports, exports

Use only sandbox-safe APIs:

- WKDownloadDelegate / navigation-response download handling where available.
- UIDocumentPicker for importing files into sandbox.
- UIDocumentInteractionController / ShareSheet for exporting files.
- Store generated Markdown, CSV, JSON, screenshots in Documents/K3Browser.

This makes K3Browser a real research/extraction tool, not just chat overlay.

### G. Screenshot/OCR layer

Sideload-safe options:

- `WKWebView.takeSnapshot` for viewport screenshots.
- `Vision` framework `VNRecognizeTextRequest` for OCR on screenshot images. No entitlement required.
- `PDFKit`/UIKit print formatter can export page to PDF if implemented carefully.

Use OCR as fallback when DOM is blocked, canvas-heavy, image-heavy, or shadow DOM hides text.

### H. Optional Hermes relay / remote brain

Keep direct OpenAI-compatible mode as default. Add optional relay mode:

- `Direct`: app calls OpenAI-compatible endpoint itself.
- `Relay`: app sends snapshots/actions to a user-owned Hermes endpoint with an API token.
- `Hybrid`: local app executes tools; Hermes performs long research, memory sync, multi-agent delegation.

Relay must be optional; no background daemon, no VPN, no extension.

## 3. Native iOS capabilities available without risky entitlements

Safe APIs/capabilities:

- `WKWebView`, `WKNavigationDelegate`, `WKUIDelegate`, `WKScriptMessageHandler`.
- `WKUserScript` injection at document start/end.
- `evaluateJavaScript` for DOM tools.
- `WKWebsiteDataStore.default()` for cookies/local storage.
- `WKWebView.takeSnapshot` for viewport screenshots.
- `Vision` framework OCR (`VNRecognizeTextRequest`) on local screenshots/images.
- `URLSession` for LLM API/relay calls and normal network fetches.
- `Keychain` generic passwords, without keychain access groups.
- `UserDefaults` for settings.
- App sandbox file storage: Documents, Caches, Application Support.
- `SQLite3` or file-backed JSON for history/memory/workflows.
- `PhotosUI` / `UIImagePickerController` for user-selected image import if needed.
- `UIDocumentPickerViewController` for explicit user-picked files.
- `UIActivityViewController` ShareSheet for export/share.
- `UIPasteboard` with explicit user action.
- `SFSafariViewController` as an optional external-safe viewer, not necessary.
- Local notifications only if user grants permission; avoid for early builds.
- Biometrics (`LocalAuthentication`) for locking API key/settings, optional, no entitlement.

Safe but version-gated:

- `WKDownloadDelegate`: target iOS 15+ is okay, but implement fallback via navigation-response and URLSession.
- SwiftUI detents/navigation APIs: keep iOS 15 compatibility by avoiding iOS 16/17-only UI or guard with `#available`.

## 4. Features to avoid

Avoid anything that increases sideload signing/crash risk:

- App Groups / shared containers.
- Keychain Access Groups.
- NetworkExtension, VPN, packet tunnel, content filter.
- Safari Web Extension / browser extension targets.
- Autofill credential provider extension.
- Share extension, widgets, intents extension, background extension targets.
- Default browser entitlement assumptions.
- Push notification entitlement dependency.
- iCloud/CloudKit entitlement dependency.
- Associated Domains / Universal Links dependency.
- Background modes for crawler/monitoring in MVP.
- Injecting dylibs into third-party browser IPAs.
- Private WebKit/Safari APIs.
- Heavy OSS browser forks that force unwrap entitlements/app group paths.
- Auto-clicking payment/login/crypto flows without explicit confirmation.
- Storing user secrets in UserDefaults/plain JSON.

## 5. Phased build plan

### Phase 0 — Refactor v0.3.1 into modules

Goal: same behavior, cleaner architecture.

- Split current monolithic `BrowserView.swift` into Browser, Agent, Tools, Storage, UI modules.
- Keep feature parity.
- Add tiny unit-testable pure Swift models where possible.
- CI still builds unsigned IPA exactly like current workflow.

### MVP: v0.4 “Agent Loop + Safety Tray”

Goal: make the agent act in steps, safely.

Deliver:

- `AgentRuntime` with step loop, max steps, cancellation.
- `ToolRegistry` + typed `AgentToolCall` JSON parsing.
- Approval tray for click/fill/submit/navigation.
- Read-only tools auto-run.
- Structured DOM snapshot v2: headings, buttons, inputs, links, tables, visible text, selectors.
- Action log timeline: thought/action/result.
- Kill switch: Stop Agent.
- Export run log as Markdown.

Acceptance:

- Ask “find the search box and search for X” -> agent proposes fill/click -> user approves -> page updates.
- No action can execute without approval when classified risky.
- Build remains no-entitlement, no PlugIns.

### Max: v0.5–v0.8 “Browser becomes workstation”

Goal: real daily-driver agent browser.

Deliver:

- Tabs and session restore.
- Bookmarks/history.
- Downloads and file exports.
- Screenshot + OCR.
- Reader/article extraction.
- Table/list/card extractor to CSV/JSON.
- Workflow recipes: save/run/edit.
- Local memory notebook, per-site notes/selectors.
- Profile autofill data stored locally, but not iOS Autofill extension.
- Prompt/tool templates.
- Domain safety policy editor.
- Improved iPhone UI: compact address bar, bottom agent dock/peek mode, keyboard-safe approval tray.

Acceptance:

- User can research across tabs, save extracted notes, export CSV/Markdown, and run a saved workflow without touching code.

### Endgame: v1.0+ “Mobile operator OS”

Goal: K3Browser as a self-owned mobile agent platform.

Deliver:

- Optional Hermes relay mode with remote multi-agent planning.
- Long-running task handoff: app sends current state to Hermes; user returns for approvals/results.
- Sync/export memory bundle; maybe WebDAV/GitHub gist manual sync via user token, not iCloud entitlement.
- Workflow marketplace as plain JSON files/import URLs.
- Site-specific adapters: Gmail-like pages, marketplaces, dashboards, docs, crypto scanners, etc.
- Visual element overlay: numbered clickable targets on page screenshot.
- Test harness pages bundled in repo for CI smoke tests.

Acceptance:

- K3Browser can perform complex browsing workflows while preserving user control and sideload stability.

## 6. Exact code modules to create

Recommended file tree under `K3Browser/Browser/`:

```text
Browser/
  App/
    K3BrowserApp.swift

  BrowserCore/
    BrowserState.swift              # owns tabs/session facade, current active tab
    BrowserTab.swift                # one WKWebView + navigation/progress state
    WebViewContainer.swift          # UIViewRepresentable + delegates
    URLNormalizer.swift             # search/URL parsing
    NavigationPolicy.swift          # domain/risk classification

  PagePerception/
    PageSnapshot.swift              # current model, expanded
    DOMSnapshotV2.swift             # headings/buttons/forms/tables/bounds
    SnapshotExtractor.swift         # JS strings + decoder
    ReaderExtractor.swift           # readable article heuristics
    TableExtractor.swift            # HTML table/list/card to structured rows
    ScreenshotService.swift         # WKWebView.takeSnapshot
    OCRService.swift                # Vision OCR, #available-safe
    SelectorGenerator.js            # optional reference JS stored as Swift string or resource

  AgentCore/
    AgentSettings.swift             # model/baseURL/system prompt, direct/relay mode
    AgentRuntime.swift              # loop, state machine, cancellation, max steps
    AgentModels.swift               # ToolCall, AgentMessage, StepResult, RiskLevel
    LLMClient.swift                 # OpenAI-compatible client
    PromptBuilder.swift             # system prompt + page context compaction
    ToolRegistry.swift              # maps tool names to executors
    ToolExecutor.swift              # executes tools against BrowserState/PageServices
    ActionPolicy.swift              # read-only vs approval vs block
    AgentRunLog.swift               # timeline/export markdown

  AgentTools/
    SnapshotTool.swift
    ClickTool.swift
    FillTool.swift
    SelectOptionTool.swift
    ScrollTool.swift
    NavigationTool.swift
    ExtractLinksTool.swift
    ExtractTableTool.swift
    ScreenshotTool.swift
    OCRTool.swift
    FileSaveTool.swift
    ClipboardTool.swift             # explicit user-triggered only

  SafetyUI/
    ApprovalRequest.swift
    ApprovalQueue.swift
    ApprovalTrayView.swift          # bottom tray, one action at a time
    RiskBadge.swift
    ActionPreviewView.swift

  Storage/
    KeychainStore.swift
    AppStoragePaths.swift
    JSONStore.swift                 # generic atomic read/write
    HistoryStore.swift
    BookmarkStore.swift
    WorkflowStore.swift
    MemoryStore.swift
    DownloadStore.swift

  Workflows/
    Workflow.swift
    WorkflowRunner.swift
    WorkflowEditorView.swift
    BuiltInWorkflows.swift

  Files/
    DownloadManager.swift           # WKDownloadDelegate/fallback
    DocumentImportService.swift
    ExportService.swift             # ShareSheet/document export
    MarkdownExporter.swift
    CSVExporter.swift

  Relay/
    RelaySettings.swift
    HermesRelayClient.swift         # optional; disabled by default
    RelayModels.swift

  UI/
    BrowserView.swift               # composition only
    TopBarView.swift
    BottomAgentDockView.swift
    AgentPanelView.swift
    AskView.swift
    SnapshotView.swift
    ToolsView.swift
    SettingsView.swift
    TabsView.swift
    BookmarksView.swift
    HistoryView.swift
    ShareSheet.swift
    EmptyStateView.swift
```

XcodeGen note: because `project.yml` already includes `sources: - Browser`, these files can be added without changing the source list. Only add frameworks in code imports; no entitlements file should be introduced.

## Implementation order that minimizes risk

1. Split files with no behavior change.
2. Add `DOMSnapshotV2` + `SnapshotExtractor` behind existing Extract button.
3. Add `AgentRuntime` in read-only mode only.
4. Add typed tool JSON parsing and run log.
5. Add approval tray, then enable click/fill through the tray.
6. Add scroll/navigation tools.
7. Add tabs/session restore.
8. Add file exports/downloads.
9. Add screenshot/OCR.
10. Add workflows.
11. Add optional Hermes relay.

## Non-negotiable build rules

- Keep `runs-on: macos-15` and Xcode 16.x selection.
- Keep unsigned `xcodebuild build`, not archive.
- Keep `CODE_SIGNING_ALLOWED=NO`, no development team.
- Keep unique bundle ID and app icon.
- Keep `plugins_count = 0` in IPA.
- Do not add `.entitlements` unless there is a very explicit reason; default answer is no.
- Target iOS 15 unless a feature justifies bumping.
