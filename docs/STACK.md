# STACK.md — appsku / K3Browser

Update terakhir: 2026-07-29 16:53 UTC

## Read-me-first

Project ini adalah pipeline produksi iOS sideloading tanpa Mac:

```txt
Swift/SwiftUI source
→ GitHub Actions macos-15 + XcodeGen
→ unsigned IPA in GitHub Releases
→ repo manifest JSON
→ Feather/KSign signs and installs on iPhone
```

Operator boleh `/new`; agent baru wajib baca file ini + `docs/CHANGELOG.md` dulu.

## Repo / paths

```txt
Local workspace: /root/k3-calculator
GitHub repo: https://github.com/patternalcreation-max/appsku
Remote SSH: git@github.com:patternalcreation-max/appsku.git
Branch: main
```

Important files:

```txt
README.md

docs/STACK.md                    # this file, source of truth
docs/CHANGELOG.md                # living state doc, REPLACE not append forever

K3Browser/project.yml            # XcodeGen iOS target config
K3Browser/Browser/K3BrowserApp.swift
K3Browser/Browser/BrowserView.swift
K3Browser/HERMES_LITE_V04_PLAN.md
K3Browser/AGENT_BROWSER_ROADMAP.md

.github/workflows/build-k3browser.yml
apps-browser.json                # active Feather/KSign repo manifest

apps-ddg.json                    # historical DDG manifest; DDG path abandoned
apps-ddg-canary.json             # historical DDG canary; do not use unless debugging history
```

## Active install URLs

Feather/KSign repo URL:

```txt
https://raw.githubusercontent.com/patternalcreation-max/appsku/main/apps-browser.json
```

Latest direct IPA:

```txt
https://github.com/patternalcreation-max/appsku/releases/download/k3browser-v0.4.1/K3Browser.ipa
```

## Current shipped app

```txt
Name: K3 Browser
Bundle ID: com.patternalcreation.k3browser
Version: 0.4.1
Build: 6
IPA size: 353,639 bytes
Min iOS: 15.0
SDK: iphoneos18.5
Xcode: 16.4
PlugIns/extensions: 0
```

v0.4.1 purpose:

```txt
Hermes-Lite GLM preset fix:
- default endpoint: https://api.z.ai/api/coding/paas/v4/chat/completions
- default model: glm-5.2
- auto-normalizes /v4 endpoint to /chat/completions
- Settings button: Use GLM 5.2 / Z.AI preset
```

## K3Browser feature state

Current v0.4.1 includes:

```txt
WKWebView native browser
URL/search bar
back/forward/reload/share
bottom command bar
K3 Agent cockpit sheet
Keychain API key storage
OpenAI-compatible chat completions call
GLM 5.2/Z.AI preset
Settings Test API
DOM Snapshot V2
JSON tool-call parser
Hermes-Lite agent loop max 6 steps
Stop Agent kill switch
action timeline
approval tray: Run once / Deny
local memory notes
export log/files
manual selector tools
```

Browser-support tools implemented:

```txt
snapshot_page
extract_text
extract_links
extract_forms
extract_tables
save_memory_note
read_memory_notes
scroll
open_url
back
forward
reload
fill_selector
click_selector
select_option
submit_form
export_markdown
export_json
export_csv
```

Safety policy:

```txt
Auto allowed:
- snapshot/extract/read notes/save local note/final answer

Approval required:
- click/fill/submit/scroll/open/back/forward/reload/export

Blocked/hard-gated:
- password, OTP/2FA, credit card, payment, buy/purchase,
  delete/remove, crypto/wallet/sign/swap/transfer
```

## API / GLM notes

Local Hermes env has:

```txt
ZAI_BASE_URL=https://api.z.ai/api/coding/paas/v4
GLM_BASE_URL=https://api.z.ai/api/coding/paas/v4
ZAI_API_KEY is set locally, but NEVER copy/log it.
```

K3Browser must use chat endpoint:

```txt
https://api.z.ai/api/coding/paas/v4/chat/completions
model: glm-5.2
header: Authorization: Bearer <ZAI_API_KEY>
```

If iPhone shows:

```txt
HTTP 401: {"error":{"code":"1000","message":"身份验证失败。"}}
```

Then endpoint is reachable but key is invalid/mis-pasted. User confirmed pasting a new valid API key fixed it.

## DDG history / decision

DuckDuckGo fork path is abandoned.

Why:

```txt
DDG builds succeeded but force-closed on iPhone across no-agent/probe/LITE variants.
3-agent RCA converged on entitlement/app-group/keychain/extension coupling.
DDG iOS hard-requires Apple entitlements that generic sideload signing cannot grant.
```

Do not continue DDG build-build unless operator explicitly asks for historical debugging. Prefer custom K3Browser WKWebView path.

Historical DDG tags:

```txt
ddg-v0.3.3 baseline build success, device force-close
ddg-v0.4.0 native agent force-close
ddg-v0.4.1 launch-safe overlay force-close
ddg-v0.4.2 probe-only canary force-close
ddg-v0.4.3 marked baseline force-close
ddg-v0.4.4 LITE custom bundle/no PlugIns still zonk
```

## Build/release workflow

Build workflow:

```txt
.github/workflows/build-k3browser.yml
```

Key constraints:

```txt
runs-on: macos-15
selects Xcode 16.4 fallback 16.3/16.2
xcodegen generate
xcodebuild build, not archive
manual Payload/ packaging
CODE_SIGNING_ALLOWED=NO
Release only on k3browser-v* tags
```

Release flow:

```bash
git add <files>
git commit -m "..."
git tag k3browser-vX.Y.Z
git push origin main
git push origin k3browser-vX.Y.Z
```

If retagging failed build with same tag:

```bash
git tag -f k3browser-vX.Y.Z
git push origin main
git push origin :refs/tags/k3browser-vX.Y.Z
git push origin k3browser-vX.Y.Z
```

After CI success:

1. Download IPA from GitHub release.
2. Inspect IPA zip:
   - `Payload/K3Browser.app/Info.plist`
   - bundle id/version/build
   - `PlugIns/extensions = 0`
3. Update `apps-browser.json` `version`, `downloadURL`, `size`.
4. Commit/push manifest.
5. Verify raw manifest returns new version/size.

## Known CI/debug notes

`gh` is installed but not logged in. Public GitHub UI hides full logs without sign-in.

Workflow was patched to surface Swift compiler errors as GitHub annotations. If CI fails:

```txt
Open Actions run summary → Annotations
```

Known fixed compile issues during v0.4.0:

```txt
- Swift multiline JS needed escaped regex: /\\s+/ not /\s+/
- Result<AgentResponse, String> invalid because String does not conform to Error; replaced with AgentParseResult enum
```

## Operator preferences / rules

```txt
Language: Indonesian casual lo/gue.
Style: verdict-first, terse, execution-focused.
Do not ask many clarifying questions when default path is obvious.
For "gaskan/orchestrate" execute directly.
No blind build loops; patch + verify.
For major next direction, brainstorm with 3 subagents, synthesize real plan.
No credentials in prompt/output/docs.
Secrets live in ~/.hermes/.env or app Keychain.
```

## Workspace governance

- `docs/STACK.md` = source of truth, update when architecture/paths/build rules change.
- `docs/CHANGELOG.md` = living state, **replace/update**, do not append forever.
- One topic = one doc.
- Protected docs: README, STACK, CHANGELOG, HERMES_LITE_V04_PLAN.
- Subagents should not write living docs unless explicitly instructed; they may write draft plans under `docs/plans/`.
- Commit significant workspace docs updates.

## Next likely work

If user continues after `/new`, likely tasks:

```txt
1. Tune GLM prompt/parser if GLM returns non-JSON.
2. Test command: "ini web apa" should produce final answer.
3. Test gated action on DuckDuckGo search box.
4. Improve approval tray with Edit button/value edit.
5. Add native tool-call format support if GLM supports tools field reliably.
6. Split monolithic BrowserView.swift into modules after runtime behavior confirmed on device.
```
