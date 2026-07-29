# K3Browser v0.4.0 Hermes-Lite — Canonical Real Plan

> Build target: browser-only Hermes runtime inside native iOS WKWebView. This is the implementation source of truth.

**Goal:** turn K3Browser v0.3.1 from manual “Ask Page + tools” into a Hermes-like browser agent: observe page → reason → propose tool → safety approval → execute → observe again.

**Hard constraints:** iOS 15, SwiftUI + WKWebView, no external packages, no App Groups, no extensions, no NetworkExtension, no iCloud, no Associated Domains, no background daemon, no private APIs. Build remains unsigned via GitHub Actions macos-15 and signed by Feather/KSign.

---

## 1. Product definition

K3Browser v0.4.0 = **Hermes-Lite Browser Runtime**.

It only replicates Hermes browser-support features:

- observe current page
- extract DOM/text/links/forms/tables
- call AI with current browser context
- parse tool-call JSON
- ask approval for risky actions
- execute browser tools via native Swift/WKWebView
- log every step
- save/export output locally

It does **not** attempt full Hermes features:

- no terminal
- no Linux filesystem
- no cron/daemon
- no server-side subagents
- no MCP runtime inside iOS
- no wallet/browser extension entitlement

---

## 2. Final v0.4.0 scope

### Must ship

1. **Agent loop**
   - max 6–8 steps
   - stop button
   - phase/status UI
   - action timeline

2. **Tool-call parser**
   - OpenAI-compatible JSON tool emulation
   - parse fenced/plain JSON
   - reject bad/unknown tools safely

3. **Tool executor**
   - read tools auto-run
   - risky tools require approval
   - all results go to action log

4. **Approval tray**
   - one action at a time
   - `Run once`, `Edit`, `Deny`
   - no approve-all
   - stop/close = deny

5. **DOM Snapshot V2**
   - title/url/text
   - headings
   - links
   - buttons
   - inputs/forms
   - tables
   - selectors
   - visible metadata
   - password/OTP/card masking/block rules

6. **Local memory + export**
   - save note
   - read notes
   - export run as Markdown/JSON/CSV via ShareSheet

7. **UX cockpit**
   - bottom command bar
   - agent status pill
   - suggested chips
   - cockpit sheet with timeline

### Explicitly out of scope for v0.4.0

- multi-tab/session restore
- OCR
- screenshots as first-class workflow
- downloads/import files
- workflow recipe editor
- Hermes relay
- profile autofill system
- background monitoring

Those go v0.5+.

---

## 3. Target file tree

All files stay under `K3Browser/Browser/` so XcodeGen `sources: Browser` picks them up recursively.

```txt
Browser/
  K3BrowserApp.swift
  BrowserView.swift                         # composition root only

  BrowserCore/
    BrowserState.swift                      # ObservableObject facade
    URLNormalizer.swift                     # URL/search parsing
    WebViewContainer.swift                  # UIViewRepresentable + WK delegates
    JavaScriptBridge.swift                  # evaluate JS helpers

  PagePerception/
    PageSnapshot.swift                      # v0.3-compatible snapshot model
    DOMSnapshot.swift                       # DOMSnapshotV2 Codable models
    SnapshotExtractor.swift                 # JS extractor + decoder
    SnapshotPromptFormatter.swift           # compact context for LLM

  AgentCore/
    AgentSettings.swift                     # Keychain/UserDefaults settings
    LLMClient.swift                         # OpenAI-compatible chat call
    AgentModels.swift                       # AgentPhase/Step/Session/ToolResult
    ToolCall.swift                          # JSONValue + ToolCall parser
    ToolRegistry.swift                      # known browser tools
    ToolExecutor.swift                      # execute tools against BrowserState
    ActionPolicy.swift                      # safety classification
    AgentRuntime.swift                      # observe/reason/approve/execute loop
    PromptBuilder.swift                     # Hermes-Lite system prompt

  SafetyUI/
    ApprovalQueue.swift
    ApprovalTrayView.swift
    RiskBadgeView.swift

  Storage/
    KeychainStore.swift
    AppStoragePaths.swift
    JSONFileStore.swift
    MemoryStore.swift

  Files/
    ExportService.swift
    MarkdownExporter.swift
    CSVExporter.swift

  UI/
    TopBarView.swift
    BottomCommandBarView.swift
    AgentCockpitView.swift
    AskView.swift                           # keep manual Ask compatibility
    SnapshotView.swift
    ManualToolsView.swift
    SettingsView.swift
    ActionLogView.swift
    ShareSheet.swift
    EmptyStateView.swift
```

---

## 4. Core runtime contract

### 4.1 Agent phases

```swift
enum AgentPhase: Equatable {
    case idle
    case observing
    case thinking
    case awaitingApproval
    case acting(String)
    case done
    case stopped
    case error(String)
}
```

UI status copy:

```txt
Ready
Observing…
Thinking…
Approval needed
Acting…
Done
Stopped
Error
```

### 4.2 Agent loop

```txt
1. user enters command
2. AgentRuntime.start(command)
3. capture DOMSnapshotV2
4. build prompt with tool schema + compact page context
5. call LLM
6. parse response:
   - final answer -> log + done
   - tool call -> safety gate
7. safety gate:
   - auto -> execute
   - approval -> enqueue + pause
   - blocked -> log blocked + ask alternative or stop
8. execute tool
9. observe page again if tool changed page
10. repeat until final/maxSteps/stop/error
```

Default max steps: `6`. Hard upper bound: `8`.

Stop behavior:

- cancels current run flag
- denies pending approval
- prevents next tool execution
- logs `Stopped by operator`

---

## 5. Tool schema

Model must return **only JSON**:

### Final answer

```json
{"type":"final","message":"Done. Summary: ..."}
```

### Tool call

```json
{
  "type": "tool_call",
  "tool": "fill_selector",
  "arguments": {
    "selector": "input[name=q]",
    "value": "K3Browser Hermes-Lite"
  },
  "reason": "User asked to search the page"
}
```

Parser requirements:

- accepts plain JSON or fenced ```json blocks
- strips Markdown fences
- response cap 64 KB
- rejects unknown `type`
- rejects unknown `tool`
- rejects missing required args
- never crashes UI; parser error becomes action-log item

---

## 6. v0.4.0 tool registry

| Tool | Args | Risk | Behavior |
|---|---|---:|---|
| `snapshot_page` | `{}` | auto | capture DOMSnapshotV2 |
| `extract_text` | `{}` | auto | return visible text summary |
| `extract_links` | `{limit?}` | auto | return links with labels/hrefs/selectors |
| `extract_forms` | `{}` | auto | return forms/fields/selectors |
| `extract_tables` | `{limit?}` | auto | return table headers/rows |
| `save_memory_note` | `{title, body}` | auto | save local Markdown/JSON note |
| `read_memory_notes` | `{limit?}` | auto | return recent local notes |
| `scroll` | `{direction, amount?}` | approval | scroll page |
| `open_url` | `{url}` | approval/block | navigate current WKWebView |
| `back` | `{}` | approval | browser back |
| `forward` | `{}` | approval | browser forward |
| `reload` | `{}` | approval | reload page |
| `fill_selector` | `{selector, value}` | approval/block | fill input + dispatch events |
| `click_selector` | `{selector}` | approval/block | scroll into view + click |
| `select_option` | `{selector, value}` | approval/block | set select value |
| `submit_form` | `{selector}` | approval/block | submit form |
| `export_markdown` | `{title, body}` | explicit UI/share | write file + ShareSheet |
| `export_json` | `{title, json}` | explicit UI/share | write file + ShareSheet |
| `export_csv` | `{title, rows}` | explicit UI/share | write CSV + ShareSheet |

---

## 7. Safety policy

### Auto allowed

```txt
snapshot_page
extract_text
extract_links
extract_forms
extract_tables
save_memory_note
read_memory_notes
final answer
```

### Approval required

```txt
scroll
open_url
back/forward/reload
fill_selector
click_selector
select_option
submit_form
export/share/clipboard if not direct user button
```

### Blocked / extra-hard gate

Block if selector/element/field/page indicates:

```txt
password
passcode
otp
2fa
credit card
card number
cvv
payment
buy
purchase
checkout
delete
remove
transfer
send money
swap
wallet
connect wallet
sign transaction
approve token
confirm order
```

Blocked result must say exactly why in timeline.

---

## 8. DOM Snapshot V2

### Models

```swift
struct DOMSnapshot: Codable {
    let title: String
    let url: String
    let text: String
    let headings: [DOMElement]
    let buttons: [DOMElement]
    let inputs: [DOMElement]
    let links: [PageLink]
    let forms: [PageForm]
    let tables: [PageTable]
}

struct DOMElement: Identifiable, Codable {
    let id: UUID
    let selector: String
    let tag: String
    let text: String
    let ariaLabel: String
    let role: String
    let type: String
    let name: String
    let placeholder: String
    let isVisible: Bool
    let rect: DOMRect
}
```

### JS extractor requirements

- use stable-ish selector generator:
  - id selector if available and safe
  - name/type for inputs
  - nth-of-type fallback
- exclude invisible elements when possible
- cap text to avoid huge model payloads
- mask values for password/OTP/card fields
- dispatch `input` and `change` events after fill
- wrap JS in IIFE and return JSON string

---

## 9. UX plan

### Main screen

```txt
Top: compact browser bar
Middle: WKWebView full canvas
Bottom: command bar + approval tray overlay
```

Bottom command bar copy:

```txt
Tell K3 what to do…
Run
Stop
```

Status pill:

```txt
Ready
Observing…
Thinking…
Approval needed
Acting…
Done
Error
```

Suggested chips:

```txt
Summarize
Find forms
Extract links
Extract tables
Save note
```

### Cockpit sheet sections

```txt
K3 Agent
status subtitle: Ready on {host} / Step 2/6: Thinking
Command input
Suggested actions
Pending approval card
Action timeline
Memory/export row
More tools
API & model settings
```

### Approval tray exact copy

```txt
Approve action?
{Tool label} on {host}
Target: {selector}
Value: {masked/plain if fill}
Risk: {risk reason}
[Run once] [Edit] [Deny]
```

Rules:

- no fullscreen modal
- no approve-all
- close tray = deny
- stop agent = deny pending action
- one approval at a time

### Timeline item copy

```txt
👁 Observed page · 4,200 chars, 18 links, 7 controls
💭 Plan · Find search input then fill query
⏸ Needs approval · Fill field
✅ Approved · Run once
⚙️ Ran fill_selector · OK
💾 Saved note · K3Browser/Notes/...
⚠️ Error · selector not found
```

---

## 10. Implementation task order

### Task 1 — Safety snapshot before refactor

Files:

- read: `Browser/BrowserView.swift`
- read: `project.yml`
- no code change

Steps:

1. Save current git status.
2. Confirm v0.3.1 builds in CI history or local file state.
3. Do not touch signing/workflow.

Gate:

```txt
git status --short clean except plan docs
```

---

### Task 2 — Extract pure storage/settings modules

Create:

```txt
Browser/Storage/KeychainStore.swift
Browser/AgentCore/AgentSettings.swift
Browser/Storage/AppStoragePaths.swift
Browser/Storage/JSONFileStore.swift
Browser/Storage/MemoryStore.swift
```

Modify:

```txt
Browser/BrowserView.swift
```

Move existing `KeychainStore` and `AgentSettings` out of monolith.

Gate:

```txt
xcodebuild build succeeds in CI
Settings still save/test API
API key still in Keychain
```

---

### Task 3 — Extract browser core

Create:

```txt
Browser/BrowserCore/URLNormalizer.swift
Browser/BrowserCore/WebViewContainer.swift
Browser/BrowserCore/BrowserState.swift
Browser/BrowserCore/JavaScriptBridge.swift
```

Move:

- URL/search normalization
- WKWebView wrapper
- navigation/progress state
- evaluateJavaScript helper

Gate:

```txt
browser opens
back/forward/reload works
share current URL works
```

---

### Task 4 — Add PagePerception DOMSnapshotV2

Create:

```txt
Browser/PagePerception/PageSnapshot.swift
Browser/PagePerception/DOMSnapshot.swift
Browser/PagePerception/SnapshotExtractor.swift
Browser/PagePerception/SnapshotPromptFormatter.swift
```

Implement:

- current snapshot parity
- headings/buttons/inputs/forms/tables
- selector generator
- field masking
- bounded prompt formatter

Gate:

```txt
Snapshot shows title/url/text/links/forms/tables
No crash on empty page
Long page truncates safely
```

---

### Task 5 — Add Agent data models + parser

Create:

```txt
Browser/AgentCore/AgentModels.swift
Browser/AgentCore/ToolCall.swift
Browser/AgentCore/ToolRegistry.swift
Browser/AgentCore/PromptBuilder.swift
```

Implement:

- `AgentPhase`
- `ToolRisk`
- `ToolCall`
- `ToolResult`
- `ApprovalRequest`
- `AgentStep`
- `AgentSession`
- JSON parser for final/tool_call
- fenced JSON stripping

Gate:

```txt
parser accepts valid final JSON
parser accepts valid tool_call JSON
parser rejects invalid/unknown tool without crash
```

---

### Task 6 — Add LLMClient structured mode

Create:

```txt
Browser/AgentCore/LLMClient.swift
```

Move old OpenAI-compatible call here.

New method:

```swift
func complete(messages: [ChatMessage], settings: AgentSettings, completion: @escaping (Result<String, Error>) -> Void)
```

Gate:

```txt
Ask Page still works
Test API still works
Network errors show friendly messages
```

---

### Task 7 — Add SafetyGate + ApprovalQueue

Create:

```txt
Browser/AgentCore/ActionPolicy.swift
Browser/SafetyUI/ApprovalQueue.swift
Browser/SafetyUI/ApprovalTrayView.swift
Browser/SafetyUI/RiskBadgeView.swift
```

Implement:

- classify tool risk
- block dangerous selectors/labels/field types
- enqueue pending approval
- run-once / edit / deny callbacks

Gate:

```txt
click/fill cannot run automatically
password/OTP/card fields blocked
deny cancels action
stop cancels pending approval
```

---

### Task 8 — Add ToolExecutor

Create:

```txt
Browser/AgentCore/ToolExecutor.swift
```

Implement tools:

```txt
snapshot_page
extract_text
extract_links
extract_forms
extract_tables
scroll
open_url
back
forward
reload
fill_selector
click_selector
select_option
submit_form
save_memory_note
read_memory_notes
```

Gate:

```txt
read tools auto-run
risky tools return approval request before execution
approved fill/click executes once
selector not found returns error, no crash
```

---

### Task 9 — Add AgentRuntime

Create:

```txt
Browser/AgentCore/AgentRuntime.swift
Browser/AgentCore/AgentRunLog.swift
```

Implement:

- loop max steps
- observe/reason/parse/safety/execute
- pause on approval
- resume after approval
- stop/cancel
- action log append

Gate:

```txt
Command: summarize page -> final answer
Command: find search box and search X -> approval -> execute -> observe
Max steps stops runaway loop
Stop button works
```

---

### Task 10 — UI cockpit

Create:

```txt
Browser/UI/TopBarView.swift
Browser/UI/BottomCommandBarView.swift
Browser/UI/AgentCockpitView.swift
Browser/UI/ActionLogView.swift
Browser/UI/AskView.swift
Browser/UI/SnapshotView.swift
Browser/UI/ManualToolsView.swift
Browser/UI/SettingsView.swift
Browser/UI/ShareSheet.swift
Browser/UI/EmptyStateView.swift
```

Modify:

```txt
Browser/BrowserView.swift
```

Implement:

- composition root
- bottom command bar
- cockpit sheet
- timeline
- approval tray overlay
- keep old manual tools under `More tools`

Gate:

```txt
UI fits iPhone narrow width
keyboard does not hide command input
old settings still reachable
old snapshot/manual tools still reachable
```

---

### Task 11 — Export service

Create:

```txt
Browser/Files/ExportService.swift
Browser/Files/MarkdownExporter.swift
Browser/Files/CSVExporter.swift
```

Implement:

- write run log markdown
- write snapshot/table CSV
- write JSON dump
- ShareSheet export

Gate:

```txt
Copy log works
Export MD opens share sheet
Exported file has expected content
```

---

### Task 12 — Version/release

Modify:

```txt
K3Browser/project.yml
/root/k3-calculator/apps-browser.json
```

Set:

```txt
MARKETING_VERSION: "0.4.0"
CURRENT_PROJECT_VERSION: "5"
tag: k3browser-v0.4.0
```

Manifest:

```txt
version: 0.4.0
versionDescription: Hermes-Lite browser runtime with agent loop, approval tray, DOM Snapshot V2, tool executor, local memory, and export.
downloadURL: https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.4.0/K3Browser.ipa
```

Gate:

```txt
CI success
IPA downloaded and inspected
Info.plist version 0.4.0 build 5
PlugIns count 0
bundle id com.patternalcreation.k3browser
manifest raw points to v0.4.0 and correct size
```

---

## 11. Manual acceptance tests

### Browser basics

- open app
- search query from URL bar
- navigate to webpage
- back/forward/reload
- share URL

### Settings/API

- save API key
- app restart keeps settings
- Test API returns `Connection OK` or clear HTTP error

### Snapshot V2

Open pages:

```txt
https://duckduckgo.com
https://example.com
any page with table/form
```

Verify:

- text extracted
- links extracted
- forms extracted
- table rows extracted if table exists
- long page bounded
- empty page no crash

### Agent loop demo 1 — read-only

Command:

```txt
Summarize this page and save a note.
```

Expected:

- observe
- think
- save note auto
- final answer
- timeline complete
- note exists in local memory

### Agent loop demo 2 — gated action

Open DuckDuckGo.

Command:

```txt
Find the search box and search for K3Browser Hermes Lite.
```

Expected:

- observe search field
- proposes `fill_selector`
- approval tray shows target/value
- tap `Run once`
- field fills
- proposes `submit` or `click`
- approval required again
- after approval page navigates/searches

### Safety tests

- ask agent to fill password field → blocked
- ask agent to click payment/buy/delete button → blocked/extra-hard gate
- deny approval → no page action happens
- stop while approval pending → pending action denied

### Export tests

- copy log
- export run Markdown
- export snapshot JSON/CSV if data exists
- ShareSheet opens

### Install/sideload checks

After release IPA:

- `Payload/K3Browser.app/Info.plist` exists
- binary exists
- `CFBundleIdentifier = com.patternalcreation.k3browser`
- `CFBundleShortVersionString = 0.4.0`
- `CFBundleVersion = 5`
- `PlugIns/extensions = 0`
- size reasonable

---

## 12. Risk gates before implementation

Do **not** add:

```txt
App Groups
Keychain access groups
NetworkExtension
Autofill extension
Share extension
Widgets
Background modes
iCloud
Associated Domains
Push dependency
Private WebKit APIs
External package managers
```

Do **not** let LLM execute:

```txt
click/fill/submit/navigation/share/export/clipboard
```

without explicit user approval or direct user button.

---

## 13. Recommended execution strategy

Because this is a large refactor, implement in 3 commits before release:

### Commit A — modular refactor, parity only

```txt
storage/settings/browser core/page snapshot moved out
v0.3.1 behavior unchanged
```

### Commit B — agent runtime core

```txt
ToolCall parser
ToolRegistry
SafetyGate
ToolExecutor
AgentRuntime
ActionLog
```

### Commit C — cockpit UI + export + version bump

```txt
Bottom command bar
Approval tray
Agent cockpit timeline
Export service
0.4.0 bump
```

Then tag:

```bash
git tag k3browser-v0.4.0
git push origin main
git push origin k3browser-v0.4.0
```

---

## 14. Final go/no-go criteria

Ship v0.4.0 only if:

```txt
CI build success
IPA verified
PlugIns count 0
old browser basics work
API settings work
read-only agent loop works
approval tray blocks risky action until Run once
deny/stop fail closed
manifest points to verified IPA
```

If refactor causes compile instability, fallback:

```txt
Keep monolithic BrowserView.swift for v0.4.0
Add only AgentRuntime + ApprovalQueue + ToolCall parser inside fewer files
Do module split after working Hermes-Lite runtime is confirmed on device
```
