# K3Browser MAX — Capability, Settings & UI Roadmap

Updated: 2026-07-29
Status: **council-approved product/architecture direction; implementation not started**
Current anchor: **K3Browser v0.7.0 build 9, immutable tag `k3browser-v0.7.0`**

## Council record

This roadmap replaces the stale pre-v0.7 plan. It was shaped through:

- four independent GLM 5.2 passes: tools/runtime, settings/data, latest-iOS UI, authority/failure modes;
- one GLM 5.2 convergence pass;
- one concise SuperGrok adversarial review;
- one GLM 5.2 adjudication pass;
- final source-grounded moderator corrections.

The council produced about 158k characters before distillation. External reports remain temporary review artifacts and are not product truth. This document is the single living MAX roadmap.

## Verdict

K3Browser should become a **page-first mobile operator workstation**, not a larger chatbot and not a Mission Control dashboard mall.

MAX means:

1. richer perception and extraction;
2. stable typed interaction against live page identity;
3. useful persistent artifacts, evidence, and resumable checkpoints;
4. low-friction autonomy for read/scroll/wait work;
5. strict per-effect authority for navigation, mutation, capture, downloads, and relay work;
6. truthful on-device versus relay capability boundaries.

Before adding interactive tools, fix the remaining substrate: stringly arguments, substring risk classification, approval bound only to run, selectors without stable references, and Engagement scope not wired into execution.

---

## 1. Shipped truth: v0.7.0

### Already shipped

- latest-iOS 26.0 native SwiftUI + WKWebView app;
- one `WKWebView`, `BrowserState`, active-run coordinator, composer, and presentation router;
- Magnetic Capsule states: collapsed Ball, compose, active peek, persistent result peek;
- sanitized DOM snapshots: text, headings, buttons, input metadata, links, forms, tables;
- 19 known tools;
- direct OpenAI-compatible/GLM model calls;
- file-backed notes and Markdown/JSON/CSV exports through Share Sheet;
- blocking one-time approval UI;
- cancellation, navigation identity, timeout, stale-callback rejection, redaction;
- Engagement Profile/store/scope-matcher foundation;
- six model turns maximum, one tool proposal per model turn, foreground only.

### Shipped limitations that MAX must remove

- tool arguments flatten to `[String:String]`;
- `classify()` relies on tool/argument substring matching;
- approval is not bound to page generation, canonical origin, argument digest, or live target fingerprint;
- approved DOM targets are not re-resolved at commit time;
- Engagement scope is not yet on the browser-tool execution path;
- no stable element references, visual perception, downloads, evidence store, recipes, sessions, relay, or SQLite event store;
- file-backed notes have no metadata index;
- no automated Swift/XCTest target yet.

---

## 2. Non-negotiable architecture

### Device authority

Swift runtime owns browser lifecycle, run/action identity, page identity, snapshots, typed-tool registry, budgets, scope, redaction, approvals, commit, persistence, and settlement. Model, page, injected script, file, recipe, and relay only provide untrusted data or proposals.

### Two gates

1. **Dispatch gate:** decode typed schema; verify active run, capability version, canonical origin, effective scope, budgets, static effect descriptor, and approval policy.
2. **Commit gate:** atomically consume a single-use approval token; verify expiry, run/action/page/origin/argument digest; re-resolve the live target; compare target fingerprint and live field/form classification; then execute.

Mismatch consumes or invalidates approval and returns a replan error. Authority never broadens silently.

### Device-owned page identity

Use a native navigation generation owned by `WKNavigationDelegate` and URL observation. Same-document instrumentation may provide hints, but never authority. A sanitized snapshot records the current navigation generation plus its own snapshot ID. Snapshot capture does not itself advance navigation generation.

Commit protection combines:

- run ID and action ID;
- native navigation generation;
- canonical origin;
- snapshot ID;
- stable element reference;
- strict live target fingerprint.

### Typed static registry

Replace substring classification with a compiled descriptor per tool:

- typed input and result schemas;
- effect class;
- settlement class;
- default approval policy;
- scope requirement;
- timeout and budgets;
- redaction and evidence policy;
- replay policy;
- descriptor version.

Live DOM analysis occurs at commit, not inside a fantasy dynamic registry at dispatch.

### Bounded autonomy

An approved immutable plan may automatically execute only:

- page reads;
- extraction;
- bounded scroll;
- bounded wait/settlement;
- bounded local temporary observations.

Unknown future actions are never pre-approved. Navigation, click, fill, select, submit, capture retention, download, export/share, external relay, or scope expansion pauses for the relevant approval.

---

## 3. MAX tool registry

### Execution boundaries

| Boundary | Credible capability | Hard limit |
|---|---|---|
| Native Swift | policy, storage, Vision OCR, PDF, files, Keychain, budgets, WKDownload, model/relay clients | no terminal, daemon, or raw system traffic interception |
| WKWebView JS invoked by Swift | DOM snapshot, element inspection, interaction, scrolling | page context is untrusted; no arbitrary model-authored JS |
| Document-start instrumentation | SPA hints, mutation/settlement hints, page fetch/XHR observation where compatible | partial/spoofable; not raw HAR/CDP/MITM |
| Hermes relay/external proxy | long-running analysis, terminal/MCP, raw HTTP/DNS/TLS, scheduled work | output is an untrusted proposal; cannot commit device effects |

### Effect policy legend

- **AUTO:** automatic within run/origin/time/byte budgets.
- **PLAN:** automatic only inside an approved immutable read/scroll/wait manifest.
- **APPROVE:** one exact action, one token.
- **ALWAYS:** approval cannot be delegated to a plan.
- **SCOPED:** active Engagement Profile must permit the page/effect.
- **NO-REPLAY:** a new proposal and live validation are required.

### A. Page perception and inspection

| Tools | Stage | Policy | Result/evidence |
|---|---|---|---|
| `snapshot_page`, `extract_text`, `extract_links`, `extract_forms`, `extract_tables` | shipped; re-type in Peak 1 | AUTO/PLAN; SCOPED when engagement active | sanitized snapshot/extraction IDs |
| `inspect_element(ref)` | next credible | AUTO/PLAN | role, label, tag, safe attributes, bounds, fingerprint; never current value |
| `find_in_page(query, mode)` | next credible | AUTO/PLAN | stable element refs and excerpts |
| `extract_records(schema, root_refs)` | later | AUTO/PLAN | bounded structured records; declarative schema only |
| `compare_snapshots(a,b)` | later | AUTO/PLAN | deterministic redacted diff and citations |
| `inspect_page_metadata` | later | AUTO/PLAN | origin, canonical URL, document metadata, script/form/resource-origin summary |
| `observe_page_requests` | experimental on-device | AUTO/PLAN + visible limitation label | only instrumented page fetch/XHR/resource timing; never claims raw traffic completeness |

Every stable element reference binds snapshot ID, native page generation, canonical origin, role/tag, accessible label digest, and target fingerprint. It expires on page identity change.

### B. Browser navigation and settlement

| Tools | Stage | Policy | Settlement/replay |
|---|---|---|---|
| `scroll` | shipped; change policy in Peak 1 | PLAN or APPROVE; bounded distance/count | immediate observation; fresh page check |
| `wait_for(condition, timeout)` | next credible | AUTO/PLAN | native timer + instrumentation hint; hard timeout/cancel |
| `open_url`, `back`, `forward`, `reload` | shipped; re-type in Peak 1 | APPROVE; SCOPED when engagement active | exact `WKNavigation` identity; NO-REPLAY |
| popup/new-window handling | later | APPROVE | one coordinator decides open-in-current, external, or deny |
| session checkpoint restore | Peak 3 | APPROVE | loads last URL as interrupted/review-required; not live-tab restoration |

Back, Forward, Reload, and Open URL are not idempotent and never auto-replayed after crash or timeout.

### C. Element and form actions

| Tools | Stage | Policy | Commit requirements |
|---|---|---|---|
| `click_element(ref)` | replaces `click_selector` | APPROVE; SCOPED; NO-REPLAY | live ref/fingerprint, effect preview, navigation settlement |
| `fill_element(ref,value)` | replaces `fill_selector` | APPROVE; SCOPED; NO-REPLAY | live field-class recheck; blocks credential/OTP/payment/wallet classes |
| `select_option(ref,option)` | re-typed | APPROVE; SCOPED; NO-REPLAY | live options and target fingerprint |
| `submit_form(ref)` | re-typed | ALWAYS; SCOPED; NO-REPLAY | live form action/method/data-class digest; redirect interception |
| `focus_element(ref)` | later | APPROVE only when it changes operator context | no text injection |

Model-visible tools never receive or resolve password, OTP, recovery code, card/PIN, session token, API/private key, seed phrase, or wallet-signing value. Credential entry remains an operator gesture through system input/AutoFill.

### D. Visual and document perception

| Tools | Stage | Policy | Truthful boundary |
|---|---|---|---|
| `capture_screenshot(mode)` | Peak 2 | APPROVE for retention/model/export | policy capture; known sensitive-region exclusion; fail closed on insufficient confidence |
| `ocr_extract(capture_id)` | Peak 2 | AUTO on approved capture | best-effort/untrusted text; centralized redaction |
| `create_pdf` / `extract_pdf_text` | Peak 2 | APPROVE to retain/export | native PDF artifact; sanitized extraction |

DOM occlusion alone is not a secret guarantee. Screenshots use `disabled`, `redacted`, or `explicitReview` policy. Any retained, exported, model-bound, or relay-bound image requires the configured gate and redaction pipeline.

### E. Artifacts, evidence, downloads

| Tools | Stage | Policy | Persistence/replay |
|---|---|---|---|
| `save_note`, `read_notes` | shipped; re-type/index later | bounded local save AUTO; reads AUTO | file-backed; safe filename only in timeline |
| `export_markdown/json/csv/pdf` | CSV/JSON/MD shipped; PDF later | APPROVE | atomic temp file + Share Sheet; NO-REPLAY |
| `save_finding` | Peak 2 | AUTO for redacted textual finding within quota; approval when sensitive artifact attached | SQLite ID + provenance |
| `save_evidence` | Peak 2 | policy by artifact class | redacted content hash + prior hash + run/page/tool binding |
| `accept_download` | Peak 2 | APPROVE | `WKDownload` from navigation/user gesture only; quarantine; no auto-open |
| arbitrary agent URL fetch/download | experimental relay-only | APPROVE + SCOPED | never disguised as WKWebView download |

### F. History, recipes, and relay

| Tools | Stage | Policy | Boundary |
|---|---|---|---|
| `search_runs`, `read_run`, `list_artifacts` | Peak 3 | AUTO local | redacted SQLite/files only |
| `save_recipe` | Peak 3 | APPROVE | typed immutable manifest + capability versions; no JS/shell |
| `dry_run_recipe` | Peak 3 | AUTO | resolves current scope/targets/effects without commit |
| `run_recipe` | Peak 3 | APPROVE manifest; side effects pause per action | fresh page identity, scope, budgets, and approvals; never blind replay |
| `delegate_to_relay` | Peak 4 | APPROVE + SCOPED + time/byte budget | redacted task package; async task ID; device remains authority |
| external HTTP/DNS/TLS probe | Peak 4 relay only | ALWAYS + active Engagement scope | evidence returned as untrusted external observation |

No on-device exploit/scanner suite is exposed before scope, evidence, budget, relay, and report contracts exist.

---

## 4. Settings MAX

Every visible control must map to an implemented runtime read point. Conditional sections stay absent until their capability ships.

| Section | Controls | Storage | Applies |
|---|---|---|---|
| **Model & Operator** | provider preset, HTTPS endpoint, model, Keychain API key, connection test, name/persona/style/output language | Keychain + UserDefaults + versioned JSON | next run; test immediate |
| **Browser** | search engine, external-link handling, popup behavior when implemented, clear website data, download review policy when implemented | UserDefaults + `WKWebsiteDataStore` action | next navigation or immediate destructive action |
| **Agent Behavior** | response detail, default run step/page/time budgets, read-only/scroll/wait autonomy preset | versioned JSON | next run; descriptor-enforced |
| **Authority** | read-only effective capability/approval summary, next-run step/page/time budget defaults, active budget use | computed + versioned JSON | next run/revalidation; never pre-approves an effect |
| **Engagement** | import, review, activate/deactivate profile; scope inspector; window/budget status | atomic hashed App Support JSON | explicit gesture; immediate revalidation |
| **Data & Privacy** | storage use, retention, export all, selective delete, screenshot policy, read-only redaction preview | UserDefaults + SQLite/files actions | immediate/next capture |
| **Appearance & Accessibility** | reset Ball position, haptics, operator detail density; system Dark Mode/Dynamic Type/Reduce Motion status | UserDefaults + system environment | immediate presentation only |
| **Relay** | endpoint, Keychain token, capability handshake, last status, disconnect | Keychain + versioned JSON | appears only in Peak 4; next relay task |
| **Diagnostics** | connection test, runtime/schema versions, effective tool descriptors, migration status, redacted log export, verbose safe previews | computed + UserDefaults | never alters authority |

### Never a setting

- global Approve All;
- disable redaction;
- show/copy raw secrets;
- arbitrary JavaScript or shell;
- bypass scope/commit validation;
- background daemon;
- claim raw interception, secure page, or OCR safety without evidence;
- model/page/relay-defined tool installation;
- “Hybrid mode” before relay handshake exists;
- control for an unimplemented runtime feature.

Destructive settings such as clearing site data, deleting evidence, or rotating/removing credentials require specific confirmation and truthful completion.

---

## 5. UI MAX

### Browser Rail

Retain a shallow native rail:

- Back;
- Forward;
- canonical address/search field;
- Reload or Stop Loading;
- conditional session/checkpoint control only after Peak 3;
- conditional download status only while a real download exists.

No fake lock, tab count, network capture, security score, or unsupported button.

### Magnetic Capsule

Retain exactly four modes:

1. **Collapsed Ball:** agent identity; draggable; persistent status/approval/result semantics.
2. **Compose:** the only command composer.
3. **Active Peek:** current step, safe tool label, progress/budget, Stop, Details.
4. **Result Peek:** truthful redacted result/error, evidence/artifact count, Details, explicit dismiss.

Result state remains persistent until viewed/dismissed; green is only truthful completion. Approval-needed uses orange plus text/VoiceOver semantics. No `planPeek` mode.

### Approval Review

The existing blocking authority surface handles both:

- one exact effect; or
- one immutable read/scroll/wait plan manifest.

It shows safe preview, target origin, resolved target description, scope state, budget, expiry, and reason. Plan review adds Amend/Approve/Decline inside the same authority surface. Raw arguments and secrets never render. Any target/effect drift invalidates the review.

### Mission Control: thin core

Always-visible destinations:

1. **Current Run** — goal, phase, step/budget, Stop.
2. **Timeline** — redacted safe previews, results, timestamps, citations.
3. **Inspect** — sanitized snapshot, find, read-only element metadata, snapshot diff when available.
4. **Settings** — hierarchical native forms.

Conditional destinations appear only after backing stores/runtime exist:

- **Library:** notes, exports, run history, session checkpoints;
- **Evidence:** findings, evidence chain, artifact preview/report export;
- **Engagement:** active profile, scope inspector, budget/window status;
- **Recipes:** manifests, capability diff, dry-run result;
- **Downloads:** quarantine/review state.

Mission Control has no second composer and no element-to-action shortcut that bypasses normal approval. Use native `NavigationStack`, lists, disclosure, search, and sheets—not dashboard-card stacks.

### Latest-iOS quality contract

- page frame identical across Ball/Capsule states;
- compact 320pt and AX5 layouts;
- VoiceOver named actions and predictable focus;
- hardware/software keyboard safe;
- 44pt minimum controls;
- Dark Mode, Increased Contrast, Reduce Motion crossfade;
- 150–300ms purposeful native motion;
- presentation router serializes Mission, Share, capture review, download review, and approval;
- target highlight appears only for truthful inspect/approval context and never implies authorization.

---

## 6. Persistence ownership

| Data | Owner |
|---|---|
| API keys and relay token | Keychain, this-device-only |
| Ball position, haptics, display/detail preferences | UserDefaults |
| Soul, autonomy profile, Engagement profiles, relay config | versioned atomic App Support JSON |
| Runs, events, approvals, snapshot metadata, findings, evidence, recipes, indexes | SQLite from Peak 2 onward |
| Existing notes | remain file-backed; SQLite adds metadata/search index only |
| Screenshots, PDFs, downloads, evidence attachments | Application Support files with opaque IDs and quotas |
| Temporary run output | per-run Caches; promoted explicitly |

### Recovery truth

Peak 1 stores a minimal redacted interrupted-run checkpoint as versioned atomic App Support JSON: run ID, sanitized last URL, phase, step count, last completed safe-step summary, and timestamp. It contains no raw arguments, current form values, approval token, or replay payload. Full event/timeline persistence begins only with SQLite in Peak 2.

After crash/relaunch:

- show “Interrupted — review required”;
- reload last URL only after operator choice;
- show only the minimal checkpoint in Peak 1; show a persisted timeline only after Peak 2;
- invalidate pending approvals;
- never auto-replay an incomplete side effect.

K3 cannot restore live WKWebView form values, JS context, scroll state, Service Worker state, or exact page memory after process death. UI must say so.

---

## 7. Four PEAK releases after v0.7

No version number is assigned until a slice passes its exit gates.

### PEAK 1 — Authority Foundation

**Deliver:** typed `JSONValue`; per-tool schemas/results; static descriptors; device-owned page identity; stable refs/fingerprints; single-use approval tokens; commit-time re-resolution; Engagement scope on every page-bound tool; bounded read/scroll/wait plans; `wait_for`; minimal atomic-JSON interrupted checkpoint; XCTest/adversarial fixtures.

**Explicitly exclude:** SQLite warehouse, screenshot/OCR, downloads, sessions, recipes, relay, new conditional settings/UI.

**Exit gates:** stale SPA/page/selector target blocked; text→password mutation blocked; expired/replayed approval blocked; scope denial works on non-navigation page tool; plan cannot grow or mutate/submit/navigate; crash restores interrupted with no replay; Xcode/device tests pass.

### PEAK 2 — Perception & Evidence

**Deliver:** stable element inspect/find; structured extraction; snapshot diff; screenshot policy; Vision OCR; PDF artifact; SQLite event/evidence store; note metadata index; findings/evidence chain; `WKDownload` quarantine; Activity citations; conditional Evidence/Downloads/Data UI.

**Exit gates:** known sensitive fixtures are redacted before retention/model/export; captures with uncertain sensitive-region coverage fail closed or require explicit operator review and are never claimed universally secret-safe; OCR redaction verified; file cannot auto-open; evidence-chain tampering detected; SQLite round-trip/migration/rollback verified; notes remain intact.

### PEAK 3 — Sessions & Recipes

**Deliver:** review-required session checkpoints—not tabs; run/artifact search; Library; retention/export/delete; typed recipe manifest; capability diff; dry run; fresh validation and per-effect approval on replay.

**Exit gates:** restored session never claims live state; pending approvals invalid; recipe hash/capability drift forces review; side effects never blind-replay; no permanent tab strip or second composer; retention and deletion are truthful and recoverable where promised.

### PEAK 4 — Relay & Authorized Research

**Deliver:** authenticated capability handshake; redacted task packages; relay task lifecycle; external HTTP/DNS/TLS observation/probes under active Engagement scope; evidence ingestion; generic report builder; conditional Relay/Engagement UI.

**Exit gates:** relay cannot expand scope or approve device effects; disconnect pauses safely; replayed task/action rejected; token leak scan covers model/log/evidence/export; external results labeled untrusted; rate/time/byte budgets enforced; no hardcoded bounty platform or target taxonomy.

---

## 8. Experimental / later

Evaluate only after Peak 4 evidence:

- limited page fetch/XHR instrumentation;
- visual numbered-element overlay;
- arbitrary agent URL fetch via relay;
- multiple live WKWebViews;
- background task handoff that obeys iOS lifecycle;
- report templates imported as data;
- richer local model inference if measured device performance allows.

Experimental controls stay absent from production UI until runtime and falsification gates exist.

---

## 9. Do not build

- arbitrary `execute_javascript` or shell tool;
- on-device CDP/HAR/MITM claims;
- multi-tab strip or “Workspace” pretending one reloaded WKWebView is live tabs;
- global/session Approve All;
- agent credential/OTP/payment/wallet automation;
- agent-resolved SecretHandle in model tools;
- automatic CAPTCHA bypass;
- raw secret/cookie/session export;
- auto-open downloaded executable/profile/certificate;
- security probes before scope/evidence/budget contracts;
- fake lock, security score, interception, OCR-safe, or authority indicator;
- permanent agent shelf, second composer, `planPeek`, or Mission Control mall;
- dead settings and capability placeholders;
- automatic side-effect replay after crash, timeout, or relay reconnect.

---

## 10. Falsification and device acceptance

The MAX direction fails if any of these occur:

1. page frame changes across agent states;
2. more than one composer exists;
3. stale run/page/target/approval changes the current page;
4. current input or secret reaches model/log/note/evidence/export/relay;
5. model/page/file/recipe/relay expands authority;
6. out-of-scope page-bound effect executes;
7. unknown future mutation is covered by broad plan approval;
8. navigation or download settles before real WebKit completion;
9. Stop leaves model/navigation/timer/relay continuation active;
10. result/evidence disappears behind another presentation;
11. screenshot/OCR UI implies safety the runtime cannot prove;
12. recovery silently replays or claims restored live state;
13. conditional UI appears before persistence/runtime exists;
14. Mission Control becomes the primary workspace instead of the page;
15. release adds undeclared entitlement, extension, package, or signing fragility.

Each PEAK requires deterministic validators, mutation tests, XCTest on target SDK, exact-source Xcode CI, unsigned IPA inspection, and real-device acceptance for 320pt/AX5, keyboard, VoiceOver, Reduce Motion, approval/deny/reopen, redirects, timeouts, Stop, stale target, result deferral, capture/download review, and recovery semantics.
