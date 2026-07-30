#!/usr/bin/env python3
"""Deterministic Release A source-invariant validator (Linux, stdlib only)."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
BROWSER = ROOT / "Browser"
VIEW = BROWSER / "BrowserView.swift"

failures: list[str] = []


def check(name: str, condition: bool, detail: str) -> None:
    if condition:
        print(f"PASS {name}")
    else:
        failures.append(f"{name}: {detail}")
        print(f"FAIL {name}: {detail}")


def read(relative: str) -> str:
    path = BROWSER / relative
    return path.read_text(encoding="utf-8") if path.is_file() else ""


CURRENT_VALUE_PATTERNS = [
    re.compile(r"\.\s*value\b"),
    re.compile(r"\[\s*['\"]value['\"]\s*\]"),
    re.compile(r"\.\s*defaultValue\b"),
    re.compile(r"\.\s*valueAs(?:Date|Number)\b"),
    re.compile(r"\bFormData\s*\("),
    re.compile(r"\.\s*getAttribute\s*\(\s*['\"]value['\"]\s*\)"),
]


def current_value_accesses(source: str) -> list[str]:
    return [pattern.pattern for pattern in CURRENT_VALUE_PATTERNS if pattern.search(source)]


def has_https_host_guard(source: str) -> bool:
    return 'url.scheme?.lowercased() == "https"' in source and "url.host?.isEmpty == false" in source


def has_navigation_identity_binding(source: str) -> bool:
    return (
        "let actionID = UUID()" in source
        and "let runID: UUID" in source
        and "let action: String" in source
        and "var navigation: WKNavigation?" in source
        and "let bindsFirstNavigation: Bool" in source
        and "guard let navigation = start()" in source
        and source.count("pending.navigation = navigation") >= 2
        and source.count("boundNavigation === navigation") >= 4
        and "pending.actionID == actionID" in source
        and "pending.runID == runID" in source
        and "navigationBindings: [ObjectIdentifier: (navigation: WKNavigation, id: UUID)]" in source
    )


def has_hidden_field_exclusion(source: str) -> bool:
    return all(token in source for token in (
        "function isHiddenField(el)",
        "filter(function(el){return visible(el)&&!isHiddenField(el);})",
        "filter(function(el){return !isHiddenField(el);})",
    ))


def has_delayed_effect_navigation_settlement(source: str) -> bool:
    marker = "private func executeAtomicElement("
    end_marker = "func exportText("
    if marker not in source or end_marker not in source:
        return False
    block = source.split(marker, 1)[1].split(end_marker, 1)[0]
    prepare = block.find("prepareNavigationAction(context: context")
    execute = block.find("AtomicElementExecutor.execute(")
    settlement = block.find("DispatchQueue.main.asyncAfter(deadline: .now() + 0.8")
    pre_atomic = block[prepare:execute] if 0 <= prepare < execute else ""
    return (
        0 <= prepare < execute < settlement
        and "scheduleNavigationTimeout" not in pre_atomic
        and "if pending.didStart { return }" in block[execute:settlement]
    )


def has_export_authority_binding(source: str) -> bool:
    response = source.partition("func handleAgentResponse(")[2].partition("func approvePending(")[0]
    resolver = source.partition("func resolvedExecutionCall(")[2].partition("private func clearPendingNavigationAction")[0]
    execution = source.partition("case .exportMarkdown, .exportJSON, .exportCSV:")[2].partition("private func executeAtomicElement")[0]
    return all((
        response.find("let resolved = resolvedExecutionCall(rawCall)") >= 0,
        response.find("let resolved = resolvedExecutionCall(rawCall)") < response.find("validate(resolved)"),
        "pendingApproval = request" in response,
        "let contentKey: String" in resolver,
        'case .exportMarkdown: contentKey = "body"' in resolver,
        'case .exportJSON: contentKey = "json"' in resolver,
        'case .exportCSV: contentKey = "rows"' in resolver,
        'arguments[contentKey] = .string(Redactor.exportBody(agentAnswer))' in resolver,
        "agentAnswer" not in execution,
        'call.arguments["body"]?.stringValue ?? ""' in execution,
        'call.arguments["json"]?.stringValue ?? ""' in execution,
        'call.arguments["rows"]?.stringValue ?? ""' in execution,
        "dispatch(call: request.call" in source,
    ))


def has_bearer_redaction_order(source: str) -> bool:
    authorization = source.find("let authorizationPattern")
    bearer = source.find("let bearerPattern")
    generic = source.find("let keyPattern")
    generic_block = source[generic:] if generic >= 0 else ""
    return (
        0 <= authorization < bearer < generic
        and "authorization\\\\s*[:=]\\\\s*" in source
        and "bearer\\\\s+[^\\\\s,;&]+" in source
        and "authorization|cookie" not in generic_block
    )


def redaction_mirror(raw: str) -> str:
    output = re.sub(r"(?i)(authorization\s*[:=]\s*)[^\r\n,;&]+", r"\1[REDACTED]", raw)
    output = re.sub(r"(?i)bearer\s+[^\s,;&]+", "Bearer [REDACTED]", output)
    return re.sub(
        r"(?i)(password|passcode|secret|token|api[_-]?key|cookie|otp|cvv|private[_-]?key)\s*([:=])\s*([^\s,;&]+)",
        r"\1\2[REDACTED]",
        output,
    )


view = VIEW.read_text(encoding="utf-8")
run_context = read("Runtime/RunContext.swift")
phase = read("Runtime/RuntimePhase.swift")
policy = read("Safety/PromptPolicy.swift")
redactor = read("Safety/Redactor.swift")
snapshot = read("PagePerception/SnapshotSanitizer.swift")
page_models = read("PagePerception/PageModels.swift")
stable_refs = read("PagePerception/StableElementReference.swift")
atomic_executor = read("Runtime/AtomicElementExecutor.swift")
dispatch_policy = read("Runtime/ToolDispatchPolicy.swift")
approval_authority = read("Runtime/ApprovalAuthority.swift")
soul = read("AppModel/OperatorSoul.swift")
dock = read("AppModel/DockPreferences.swift")
dock_ui = read("UI/AgentDock.swift")
mission_ui = read("UI/MissionControlView.swift")
keychain_block = view.split("enum KeychainStore", 1)[-1].split("final class AgentSettings", 1)[0]
memory_block = view.split("enum MemoryStore", 1)[-1].split("// MARK: - Browser State", 1)[0]
export_block = view.split("func exportText(title:", 1)[-1].split("func copyLog()", 1)[0]

required_files = [
    "AppModel/OperatorSoul.swift",
    "AppModel/DockPreferences.swift",
    "Runtime/RunContext.swift",
    "Runtime/RuntimePhase.swift",
    "Safety/Redactor.swift",
    "Safety/PromptPolicy.swift",
    "PagePerception/SnapshotSanitizer.swift",
    "PagePerception/PageModels.swift",
    "PagePerception/StableElementReference.swift",
    "Runtime/AtomicElementExecutor.swift",
    "Runtime/ToolDispatchPolicy.swift",
    "Runtime/ApprovalAuthority.swift",
]
check("modular source files", all((BROWSER / p).is_file() for p in required_files), "one or more required files are missing")
check("api key declaration compiles", '@Published var apiKey: String = ""' in view and "***" not in view, "apiKey type is malformed or a redaction marker entered source")
check("authorized endpoint requires HTTPS", has_https_host_guard(view) and 'status = "HTTPS API endpoint required"' in view, "API key can be attached to a plaintext or hostless endpoint")
check("HTTPS guard detector self-test", not has_https_host_guard(view.replace("url.host?.isEmpty == false", "true", 1)), "removing the host guard escaped validation")
check("Keychain update preserves old secret", "SecItemUpdate" in keychain_block and "errSecItemNotFound" in keychain_block and "SecItemDelete" not in keychain_block and "let keySaved = KeychainStore.save" in view, "key replacement can delete the old value or ignore failure")
check("snapshot excludes every current-value API", not current_value_accesses(snapshot), f"current-value access found: {current_value_accesses(snapshot)}")
detector_mutations = ["captured: el.value", "captured: el['value']", 'captured: el[\"value\"]', "captured: el.defaultValue", "captured: el.valueAsNumber", "captured: new FormData(form)", "captured: el.getAttribute('value')"]
check("current-value detector self-test", all(current_value_accesses(snapshot + "\n" + mutation) for mutation in detector_mutations), "value-access mutation escaped detector")
check("hidden inputs excluded", has_hidden_field_exclusion(snapshot), "hidden-field helper is not applied to both el-based input filters")
hidden_mutations = [
    snapshot.replace("&&!isHiddenField(el)", "", 1),
    snapshot.replace("return !isHiddenField(el);", "return true;", 1),
]
check("hidden exclusion mutation self-test", all(not has_hidden_field_exclusion(mutation) for mutation in hidden_mutations), "removing either hidden exclusion escaped validation")
model_value_key = re.compile(r"(?m)^\s*(?:let|var|case)\s+(?:value|valuePreview)\b|(?:^|[{,])\s*(?:(?:['\"](?:value|valuePreview)['\"])|(?:value|valuePreview))\s*:")
check("snapshot emits no value preview or model value key", not model_value_key.search(snapshot + "\n" + page_models) and "valuePreview" not in snapshot + page_models, "snapshot/model evidence can serialize a current value field")
value_key_mutations = [snapshot + "\nconst leaked={value:el.textContent};", snapshot + "\nconst leaked={'valuePreview':'secret'};", page_models + "\nstruct Leak {\n let valuePreview: String\n}"]
check("value-key detector self-test", all(model_value_key.search(mutation) for mutation in value_key_mutations), "serialized value/valuePreview mutation escaped validation")
check("classification metadata retained without execution authority", all(token in snapshot for token in ("type:", "name:", "label:", "placeholder:", "autocomplete:")) and "StableElementMetadata.classify" in view and all(token in stable_refs for token in ("static func classify", "sensitiveDataClass", 'metadata.sensitiveDataClass == "none"', "PrivateElementReferenceMap")), "classification metadata is missing or sensitive references can enter the private map")
check("hidden/password/file/sensitive targets fail closed", has_hidden_field_exclusion(snapshot) and 'live.type === "hidden" || live.type === "password" || live.type === "file"' in atomic_executor and 'live.sensitiveClass !== "none"' in atomic_executor and 'target.metadata.sensitiveDataClass == "none"' in dispatch_policy, "sensitive form targets can become executable")
check("snapshot sanitizer integrated", "SnapshotSanitizer.javascript" in view, "BrowserView does not use centralized snapshot source")
check("structured snapshot fields sanitized", 'func string(_ dictionary: [String: Any], _ key: String) -> String { SnapshotSanitizer.sanitizedMetadata' in view and 'SnapshotSanitizer.sanitizedURL(raw(dictionary, "href"))' in view and 'SnapshotSanitizer.sanitizedURL(action)' in view and 'headers: (table["headers"] as? [String] ?? []).map(SnapshotSanitizer.sanitizedMetadata)' in view and '$0.map(SnapshotSanitizer.sanitizedMetadata)' in view and 'title: SnapshotSanitizer.sanitizedMetadata' in view and 'text: SnapshotSanitizer.sanitizedMetadata' in view, "structured elements, URLs, summary fields, or table cells can bypass sanitization")
check("immutable core policy", "static let core" in policy and "untrusted" in policy.lower() and "cannot grant" in policy.lower(), "core untrusted-data authority rule missing")
check("policy composed with soul", "PromptPolicy.core" in view and "operatorSoul.promptText" in view, "system prompt composition missing")
check("policy used by both LLM paths", view.count('"role": "system", "content": settings.composedSystemPrompt') == 2, "both ask and agent paths must use composed system prompt")
check("immutable run context", all(token in run_context for token in ("let runID: UUID", "let command: String", "let startedAt: Date")), "RunContext identity fields are not immutable")
check("run-bound approvals", "let runID: UUID" in approval_authority and "request.runID == context.runID" in view and "request.runID == activeRun?.runID" in view and "proposal.call == call" in view and "activeRun == context" in view, "request/proposal approval authority is not bound to the active RunContext")
check("stale callbacks ignored", view.count("isActive(runID:") >= 10 and "extractSnapshot(runID: context.runID)" in view, "insufficient active runID callback gates")
check("snapshot failure settles run", "private func settleSnapshotFailure(runID: UUID?" in view and "activeRun = nil" in view and "phase = .error(safeMessage)" in view and "if runID == nil, activeRun != nil" in view and "if runID == nil, self.activeRun == nil { self.phase = .idle }" in view, "snapshot errors or manual observation can corrupt active run state")
check("network cancellation", "private var llmTask: URLSessionDataTask?" in view and view.count("llmTask?.cancel()") >= 2, "URLSessionDataTask is not cancelled on stop/new run")
check("LLM callback serialized on main", "URLSession.shared.dataTask(with: req) { [weak self] data, response, error in\n            DispatchQueue.main.async" in view, "URLSession callback reads run state off the main queue")
check("navigation settlement is run-bound", "private final class PendingNavigationAction" in view and "let runID: UUID" in view and "let action: String" in view and view.count("clearPendingNavigationAction()") >= 3 and "performNavigation(context: context" in view and "executeAtomicElement(call: call, context: context" in view and "private func dispatch(call: ValidatedToolCall" in view, "typed navigation-capable routes can settle outside the active run")
check("navigation waits for bound WebKit identity", "didStartProvisionalNavigation" in view and "didFinish navigation" in view and "didFailProvisionalNavigation" in view and "settleNavigationAction(actionID:" in view and has_navigation_identity_binding(view) and "scheduleNavigationTimeout(for: pending)" in view.partition("didStartProvisionalNavigation")[2].partition("didCommit")[0], "navigation callbacks are not bound to exact action/run/WKNavigation identity or real navigation timeout")
check("atomic possible-navigation delayed-effect invariant", has_delayed_effect_navigation_settlement(view), "atomic click/submit can time out before its effect or settle before the 0.8s no-navigation receipt window")
navigation_identity_mutations = [
    view.replace("let actionID = UUID()", "", 1),
    view.replace("var navigation: WKNavigation?", "", 1),
    view.replace("guard let navigation = start()", "guard start() != nil", 1),
    view.replace("boundNavigation === navigation", "true", 1),
]
check("navigation identity detector self-test", all(not has_navigation_identity_binding(mutation) for mutation in navigation_identity_mutations), "navigation identity mutation escaped validation")
pre_atomic_timeout_mutation = view.replace(
    "preparedActionID = pending.actionID",
    "preparedActionID = pending.actionID\n            scheduleNavigationTimeout(for: pending)",
    1,
)
check("pre-atomic timeout mutation self-test", pre_atomic_timeout_mutation != view and not has_delayed_effect_navigation_settlement(pre_atomic_timeout_mutation), "inserting a synthetic timeout before AtomicElementExecutor escaped validation")
check("navigation tools have no immediate success", 'webView.load(URLRequest(url: url)); finish(' not in view and 'back(); finish("Back")' not in view and 'forward(); finish("Forward")' not in view and 'reload(); finish("Reload")' not in view, "navigation tool reports success immediately after initiation")
check("resume uses RunContext command", "agentPrompt(command: context.command" in view and "steps.first?.detail" not in view, "resume command is not sourced from RunContext")
check("phase busy matching", "var isBusy: Bool" in phase and "case .observing, .thinking, .awaitingApproval, .acting:" in phase, "isBusy pattern matching missing")
check("busy UI integration", "phase.isBusy" in dock_ui and "state.phase.isBusy" in mission_ui and '.acting("")' not in (view + dock_ui + mission_ui), "UI still relies on phase equality workaround")
check("central redaction", "ToolDispatchPolicy.safePreview(call)" in view and "ToolRegistry.approvalReason(for: call.tool)" in view and "Self.boundedRedacted(preview)" in approval_authority and "Self.boundedRedacted(reason)" in approval_authority and 'addStep("⚠️", "Parser error", error)' in view and "Raw:" not in view and "sanitizeURLString" in redactor and "call.reason" not in view + dispatch_policy + approval_authority, "device-generated preview/reason, bounded approval text, parser, or URL redaction integration missing")
credential_marker = "credential-tail-marker=="
redaction_vectors = (
    f"Authorization: Bearer {credential_marker}",
    f"authorization={credential_marker}",
    f"Bearer {credential_marker}",
    f"token: Bearer {credential_marker}",
)
check("Bearer redaction ordering", has_bearer_redaction_order(redactor), "Authorization/Bearer must be redacted before generic key/value patterns")
check("Bearer redaction semantic mirror", all(credential_marker not in redaction_mirror(vector) for vector in redaction_vectors), "credential tail survives Authorization/Bearer redaction")
redaction_mutations = [
    redactor.replace("let authorizationPattern", "let disabledAuthorizationPattern", 1),
    redactor.replace("let bearerPattern", "let disabledBearerPattern", 1),
]
check("Bearer detector self-test", all(not has_bearer_redaction_order(mutation) for mutation in redaction_mutations), "removing a credential pattern escaped validation")
check("URL credentials stripped", "components.user = nil" in redactor and "components.password = nil" in redactor and "components.query = nil" in redactor and "components.fragment = nil" in redactor, "URL userinfo, query, or fragment can survive sanitization")
check("export preview matches safe sink", "ToolDispatchPolicy.safePreview(call)" in view and all(token in dispatch_policy for token in ('call.arguments["body"]?.stringValue', 'call.arguments["json"]?.stringValue', 'call.arguments["rows"]?.stringValue')) and "let safeBody = Redactor.exportBody(body)" in view and "safeBody.write(to: url" in view, "validated export preview and written body do not share bounded/redacted paths")
check("export content resolved before approval", has_export_authority_binding(view), "resolved content is not inserted under the exact export key before validation/proposal or sink can use mutable agentAnswer")
export_fallback_mutation = view.replace('body = call.arguments["rows"]?.stringValue ?? ""', 'body = call.arguments["rows"]?.stringValue ?? agentAnswer', 1)
check("post-approval export fallback mutation self-test", export_fallback_mutation != view and not has_export_authority_binding(export_fallback_mutation), "mutable post-approval agentAnswer fallback escaped validation")
check("note writes propagate failure", "static func save(title: String, body: String, url: String) throws -> String" in memory_block and "try content.write" in memory_block and "try? content.write" not in memory_block and "Note save failed" in view, "note write failures can be reported as success")
check("note filenames are collision resistant", "UUID().uuidString.lowercased()" in memory_block and "uniqueID" in memory_block, "same-title saves within one second can overwrite prior notes")
check("export success follows write", "-> Bool" in export_block and "try safeBody.write" in export_block and export_block.find("try safeBody.write") < export_block.find("showShare = true") and "try? safeBody.write" not in export_block and 'addStep("⚠️", "Export failed"' in export_block, "export can report/share success before a completed write")
check("raw errors excluded from state", '"Failed: \\(error.localizedDescription)"' not in view and "phase = .error(error.localizedDescription)" not in view, "raw error text can reach status or phase")
check("operator soul persistence", "Codable" in soul and ".applicationSupportDirectory" in soul and "options: .atomic" in soul and "static func reset" in soul, "versioned atomic soul persistence/reset missing")
check("dock preferences persistence", "UserDefaults" in dock and "min(max(normalizedY, 0), 1)" in dock and "defaults.set(clamped, forKey: Key.normalizedY)" in dock and "enum DockEdge" in dock, "dock defaults, clamp, or clamped persistence missing")

if failures:
    print(f"FAILED {len(failures)} invariant(s)")
    sys.exit(1)
print("PASS release-a slice-1 invariants")
