# CHANGELOG.md — appsku / K3Browser Living State

Update terakhir: 2026-07-29 16:53 UTC

> Living doc: replace/update this file as state changes. Keep concise.

## Current state

```txt
Project: appsku / K3Browser
Local: /root/k3-calculator
Repo: https://github.com/patternalcreation-max/appsku
Active manifest: apps-browser.json
Install URL: https://raw.githubusercontent.com/patternalcreation-max/appsku/main/apps-browser.json
Latest shipped: K3Browser v0.4.1 build 6
```

## Latest verified release

```txt
Tag: k3browser-v0.4.1
Direct IPA: https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.4.1/K3Browser.ipa
Size: 353,639 bytes
App dir: Payload/K3Browser.app
Display: K3 Browser
Bundle ID: com.patternalcreation.k3browser
Version: 0.4.1
Build: 6
MinimumOSVersion: 15.0
DTSDKName: iphoneos18.5
DTXcode: 1640
PlugIns/extensions: 0
```

Raw manifest verified after commit:

```txt
version 0.4.1
downloadURL https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.4.1/K3Browser.ipa
size 353639
```

## What changed recently

### K3Browser v0.4.1

Fixed GLM/Z.AI endpoint problem after user saw:

```txt
⚠️ LLM error — unsupported URL
```

Root cause:

```txt
App/user endpoint used base /v4 URL, but Z.AI needs /chat/completions suffix.
```

Patch:

```txt
Default baseURL = https://api.z.ai/api/coding/paas/v4/chat/completions
Default model = glm-5.2
AgentSettings.normalizedChatURLString() appends /chat/completions when user enters /v4 or /v1 base
Settings button: Use GLM 5.2 / Z.AI preset
callLLM() and testConnection() both use settings.chatURL()
```

User later got:

```txt
HTTP 401: {"error":{"code":"1000","message":"身份验证失败。"}}
```

Diagnosis:

```txt
URL/header/model correct; key invalid/mis-pasted.
Local test with ~/.hermes/.env ZAI_API_KEY returned HTTP 200 against same endpoint.
User pasted new API key and confirmed it worked.
```

### K3Browser v0.4.0

Implemented Hermes-Lite browser runtime:

```txt
bottom command bar
agent loop max 6 steps
Stop Agent
DOM Snapshot V2
JSON tool-call parser
tool executor
approval tray Run once / Deny
action timeline
local memory notes
export log/files
gated browser tools
```

CI issues fixed:

```txt
Swift string escape in JS snapshot regex
Result<AgentResponse, String> invalid; replaced with AgentParseResult
```

### K3Browser v0.3.x

Baseline before Hermes-Lite:

```txt
v0.3.0: Keychain API key, OpenAI-compatible Ask Page, snapshot/forms/links, fill/click selector, custom JS
v0.3.1: API Test button/status and copy AI answer
```

### K3Browser v0.1/v0.2

```txt
v0.1.0: launch-safe WKWebView baseline proved sideload pipeline works
v0.2.0: Agent Snapshot panel with page title/url/text/links/forms copy/share
```

## Current known behavior to test on device

User confirmed app/API key can work after new API key. Next tests:

### Read-only command

```txt
Open any page
Command: ini web apa
Expected: final answer, no approval needed
```

### Gated DuckDuckGo search

```txt
Open https://duckduckgo.com
Command: Find the search box and search for K3Browser Hermes Lite.
Expected:
▶️ Started
👁 Observed page
💭 Thinking
⏸ Needs approval fill_selector
Run once
⚙️ Running fill_selector
⏸ Needs approval submit/click/open
Run once
observe result
```

If GLM returns non-JSON/parser error, next patch should tune `systemPrompt`/`agentPrompt` and maybe add tolerant extraction for JSON embedded in prose.

## Current source/doc state

Important docs now exist:

```txt
README.md
docs/STACK.md
docs/CHANGELOG.md
K3Browser/HERMES_LITE_V04_PLAN.md
K3Browser/AGENT_BROWSER_ROADMAP.md
K3Browser/.hermes/plans/2026-07-29_161425-k3browser-v0.4.0-hermes-lite-plan.md
K3Browser/docs/plans/2026-07-29-v0.4.0-hermes-lite-ux-product-plan.md
```

Note: `/root/.hermes/plans/2026-07-29_161411-k3browser-v040-hermes-lite-swift-plan.md` was created by a planner subagent outside repo; canonical repo plan is `K3Browser/HERMES_LITE_V04_PLAN.md`.

## DDG decision state

DDG path is abandoned unless explicitly reopened.

Reason:

```txt
DDG no-agent/probe/LITE builds still force-closed on iPhone.
3-agent debug converged on App Groups/keychain/NetworkExtension/browser entitlement coupling.
Custom K3Browser WKWebView path is proven launch-safe and much smaller.
```

## Active risks / blockers

```txt
No current build blocker.
Runtime behavior depends on GLM returning strict JSON for agent loop.
BrowserView.swift is monolithic (~850 lines); refactor later after device runtime stabilizes.
GitHub API artifacts/logs need auth; public annotations now expose compiler errors.
Feather/KSign may cache manifests; remove/re-add source if old version shown.
```

## Next actions

Priority order:

```txt
1. User tests v0.4.1 with valid ZAI key.
2. If read-only command fails with parser error, patch prompt/parser tolerance.
3. If gated search works, improve UX: Edit approval, clearer final output, better timeline.
4. Split BrowserView.swift into modules only after runtime confirmed.
5. Add v0.5 features: tabs/session restore, OCR/screenshot, workflow recipes, Hermes relay optional.
```
