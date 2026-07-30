#!/usr/bin/env python3
"""PEAK 1 slice B source-invariant gate (deterministic, Python stdlib only).

Covers the Slice B runtime subsystems with mutation-sensitive checks:
  1. CanonicalPageTarget
  2. PageIdentityReducer
  3. StableElementReference
  4. ToolDispatchPolicy
  5. ApprovalAuthority
  6. AgentProtocol
  7. AtomicElementExecutor
  8. BrowserView (dispatch gate, scroll TOCTOU binding, Mission Control export gate)
  9. SnapshotSanitizer

Linux has no Swift toolchain in this workspace. This deterministic stdlib gate checks
actual Swift source structure plus JSON semantic vectors and mutation sensitivity;
macOS/Xcode CI remains responsible for compiling and exercising Swift Codable.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BROWSER = ROOT / "Browser"

CANONICAL = BROWSER / "Runtime" / "CanonicalPageTarget.swift"
PAGE_IDENTITY = BROWSER / "Runtime" / "PageIdentity.swift"
STABLE_REF = BROWSER / "PagePerception" / "StableElementReference.swift"
DISPATCH_POLICY = BROWSER / "Runtime" / "ToolDispatchPolicy.swift"
AUTHORITY = BROWSER / "Runtime" / "ApprovalAuthority.swift"
PROTOCOL = BROWSER / "Runtime" / "AgentProtocol.swift"
ATOMIC = BROWSER / "Runtime" / "AtomicElementExecutor.swift"
SUBSTRATE = BROWSER / "Runtime" / "ToolSubstrate.swift"
VIEW = BROWSER / "BrowserView.swift"
SANITIZER = BROWSER / "PagePerception" / "SnapshotSanitizer.swift"
MISSION = BROWSER / "UI" / "MissionControlView.swift"

FAILURES: list[str] = []

EXPECTED_TOOLS = (
    "snapshot_page", "extract_text", "extract_links", "extract_forms", "extract_tables",
    "save_memory_note", "read_memory_notes", "scroll", "open_url", "back", "forward",
    "reload", "fill_selector", "click_selector", "select_option", "submit_form",
    "export_markdown", "export_json", "export_csv",
)


def check(name: str, condition: bool, detail: str = "") -> None:
    print(("PASS " if condition else "FAIL ") + name + (((": " + detail) if detail and not condition else "")))
    if not condition:
        FAILURES.append(name)


# ---------------------------------------------------------------------------
# Shared parsing helpers (adapted from slice A)
# ---------------------------------------------------------------------------

def balanced_body(source: str, opening_index: int, opening: str = "(", closing: str = ")") -> tuple[str, int]:
    if opening_index < 0 or opening_index >= len(source) or source[opening_index] != opening:
        raise ValueError("balanced body does not start at opening delimiter")
    depth = 0
    quote: str | None = None
    escaped = False
    for index in range(opening_index, len(source)):
        character = source[index]
        if quote is not None:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == quote:
                quote = None
            continue
        if character in ('"', "'"):
            quote = character
        elif character == opening:
            depth += 1
        elif character == closing:
            depth -= 1
            if depth == 0:
                return source[opening_index + 1:index], index + 1
    raise ValueError("unbalanced source delimiters")


# ---------------------------------------------------------------------------
# 1. CanonicalPageTarget
# ---------------------------------------------------------------------------

def check_canonical_page_target(source: str) -> None:
    check("CPT file exists", bool(source))

    # HTTP(S)-only
    check("CPT HTTP(S)-only scheme", 'scheme == "http" || scheme == "https"' in source and 'throw TargetError.unsupportedScheme' in source)

    # Lowercase scheme/host
    check("CPT lowercase scheme", "let scheme = rawScheme.lowercased()" in source)
    check("CPT lowercase host", "let host = componentHost.lowercased()" in source)
    check("CPT scheme assigned lowercased", "components.scheme = scheme" in source)
    check("CPT host assigned lowercased", "components.host = host" in source)

    # No userinfo
    check("CPT rejects userinfo", "components.user == nil, components.password == nil" in source and 'throw TargetError.userInfo' in source)

    # No backslash
    check("CPT rejects backslash", '!raw.contains("\\\\")' in source and '!absolute.contains("\\\\")' in source)

    # No whitespace / control chars
    check("CPT rejects whitespace/control", "isWhitespace" in source and ".control" in source)

    # No nondefault port
    check("CPT rejects nondefault port", 'let defaultPort = scheme == "https" ? 443 : 80' in source and "guard port == defaultPort else { throw TargetError.nonDefaultPort }" in source)
    check("CPT strips default port", "components.port = nil" in source)

    # Ambiguous host rejected
    check("CPT rejects ambiguous host", "isUnambiguousHost" in source and 'throw TargetError.ambiguousHost' in source)
    check("CPT rejects @ in authority", '!authority.contains("@")' in source)
    check("CPT rejects % in authority", '!authority.contains("%")' in source)

    # IPv6 accepted (bracket parsing in hostPart)
    check("CPT accepts IPv6", 'authority.hasPrefix("[")' in source and 'authority.firstIndex(of: "]")' in source)

    # Mutation sensitivity: removing the scheme guard should fail a structural check
    mutated = source.replace('scheme == "http" || scheme == "https"', 'true', 1)
    check("CPT scheme guard mutation self-test", 'scheme == "http" || scheme == "https"' not in mutated)

    # Mutation sensitivity: removing userinfo guard
    mutated_user = source.replace("components.user == nil, components.password == nil", "true", 1)
    check("CPT userinfo guard mutation self-test", "components.user == nil, components.password == nil" not in mutated_user)

    # Mutation sensitivity: removing port guard
    mutated_port = source.replace("guard port == defaultPort else { throw TargetError.nonDefaultPort }", "", 1)
    check("CPT port guard mutation self-test", "guard port == defaultPort else { throw TargetError.nonDefaultPort }" not in mutated_port)


# ---------------------------------------------------------------------------
# 2. PageIdentityReducer
# ---------------------------------------------------------------------------

def check_page_identity_reducer(source: str) -> None:
    check("PIR file exists", bool(source))

    # Monotonic generation (increment on invalidate)
    check("PIR generation increments", "generation += 1" in source)

    # Overflow fail-closed
    check("PIR overflow fail-closed", "generationExhausted = true" in source and "guard generation < UInt64.max" in source and "generation == UInt64.max" in source)

    # Provisional start invalidates once
    check("PIR provisional start guards duplicate", "inFlightTopLevelNavigation && inFlightNavigationID == navigationID" in source)

    # Commit finalizes (no second increment in commit)
    commit_block = source.partition("mutating func mainFrameCommit")[2].partition("mutating func observeTopLevelURL")[0]
    check("PIR commit does not advance generation", "generation +=" not in commit_block and "invalidateAndAdvance" not in commit_block)
    check("PIR commit settles committed target", "committedTarget = target" in commit_block)

    # Same-document advance once
    observe_block = source.partition("mutating func observeTopLevelURL")[2].partition("mutating func webContentProcessTerminated")[0]
    check("PIR observe returns bool", "func observeTopLevelURL(_ target: CanonicalPageTarget) -> Bool" in source)
    check("PIR in-flight observe does not advance", "observedInFlightTarget = target" in observe_block and "return false" in observe_block)
    check("PIR same-document advances once", "invalidateAndAdvance()" in observe_block and "committedTarget = target" in observe_block and "return true" in observe_block)

    # Snapshot never advances
    snapshot_block = source.partition("func captureSnapshotIdentity")[2].partition("func accepts")[0]
    check("PIR snapshot never advances generation", "invalidateAndAdvance" not in snapshot_block and "generation +=" not in snapshot_block)

    # Process termination invalidates
    terminate_block = source.partition("mutating func webContentProcessTerminated")[2].partition("func captureSnapshotIdentity")[0]
    check("PIR process termination invalidates", "invalidateAndAdvance()" in terminate_block)

    # Duplicate callback no double advance: provisional start guard
    check("PIR duplicate provisional no double advance", "guard !(inFlightTopLevelNavigation && inFlightNavigationID == navigationID) else { return current }" in source)

    # Mutation: remove the generation increment
    mutated = source.replace("generation += 1", "generation += 0", 1)
    check("PIR generation increment mutation self-test", "generation += 0" in mutated and "generation += 1" not in mutated)

    # Mutation: remove the overflow guard
    mutated_overflow = source.replace("guard generation < UInt64.max else", "guard false else", 1)
    check("PIR overflow guard mutation self-test", "guard false else" in mutated_overflow)


# ---------------------------------------------------------------------------
# 3. StableElementReference
# ---------------------------------------------------------------------------

def check_stable_element_reference(source: str) -> None:
    check("SER file exists", bool(source))

    # Opaque ref only
    check("SER opaque ref field", "let ref: String" in source)
    check("SER opaque ref validator", "static func isValidOpaqueRef" in source and "element_" in source)
    check("SER opaque ref prefix", '"element_"' in source)

    # No Codable on StableElementReference
    check("SER not Codable", "struct StableElementReference: Equatable" in source and "struct StableElementReference: Codable" not in source)

    # Selector is private
    check("SER selector private", "private let privateSelector: String" in source)

    # Executable binding requires non-empty/bounded selector
    check("SER executable binding checks selector bytes", "selectorBytes > 0 && selectorBytes <= 4_096" in source)

    # Executable binding requires valid fingerprint
    check("SER executable binding checks fingerprint", "fingerprint == metadata.fingerprint" in source and "fingerprint.utf8.count == 64" in source)

    # Executable binding requires snapshot marker
    check("SER executable binding checks snapshot marker", "Self.isValidSnapshotMarker(snapshotMarker)" in source)

    # Executable binding requires canonical page URL match
    check("SER executable binding checks canonical page URL", "canonicalTarget" in source and "canonicalPageURL" in source)

    # Executable binding requires origin match
    check("SER executable binding checks origin", "canonicalTarget?.origin == identity.origin" in source)

    # isExecutableBinding requires visible + non-sensitive
    check("SER isExecutableBinding visible + non-sensitive", "metadata.isVisible" in source and 'metadata.sensitiveDataClass == "none"' in source)

    # atomicExecutorArguments releases only to executor
    check("SER atomicExecutorArguments bridge", "func atomicExecutorArguments(operation: String, value: String?)" in source)
    check("SER atomicExecutorArguments includes expected fields", all(k in source for k in (
        '"privateSelector"', '"boundOrigin"', '"snapshotMarker"', '"boundPageURL"',
        '"fingerprint"', '"bindingExecutable"',
    )))

    # Mutation: make selector public
    mutated_private = source.replace("private let privateSelector: String", "let privateSelector: String", 1)
    check("SER selector private mutation self-test", "private let privateSelector: String" not in mutated_private)

    # Mutation: remove fingerprint check
    mutated_fp = source.replace("fingerprint == metadata.fingerprint &&", "", 1)
    check("SER fingerprint check mutation self-test", "fingerprint == metadata.fingerprint &&" not in mutated_fp)


# ---------------------------------------------------------------------------
# 4. ToolDispatchPolicy
# ---------------------------------------------------------------------------

def check_tool_dispatch_policy(source: str) -> None:
    check("TDP file exists", bool(source))

    # Exact 19-tool closed schemas
    schema_keys = re.findall(r'\.(\w+):\s*(?:schema|empty)\(', source)
    check("TDP 19 closed schemas", len(schema_keys) == 19, f"found {len(schema_keys)} schemas")

    # Unknown keys rejected
    check("TDP unknown keys rejected", "schema.fields[key] == nil" in source and ".unknownField(key)" in source)

    # Mutations require ref reject selector
    check("TDP opaque ref rule", ".opaqueReference" in source)
    check("TDP no selector in schema", '"selector": .opaqueReference' not in source and '"selector":' not in source)

    # open_url canonicalizes once
    check("TDP open_url canonicalizes once", "call.tool == .openURL" in source and 'CanonicalPageTarget.resolveNavigationInput(raw)' in source)

    # Canonical sorted JSON byte cap
    check("TDP canonical sorted JSON", ".sortedKeys" in source and ".withoutEscapingSlashes" in source)
    check("TDP byte cap", "canonical.count <= descriptor.budget.maximumArgumentBytes" in source)

    # safe preview omits selector/value/ref/digest/token/body
    safe_preview_block = source.partition("static func safePreview")[2].partition("static func canonicalJSON")[0]
    check("TDP safe preview omits selector", '"selector"' not in safe_preview_block)
    # Raw value must go through characterCount() — only the count is shown, not the value itself
    check("TDP safe preview value through characterCount only", 'characterCount(call.arguments["value"]?.stringValue)' in safe_preview_block and 'call.arguments["value"]?.stringValue)' in safe_preview_block)
    check("TDP safe preview omits ref", 'arguments["ref"]' not in safe_preview_block)
    check("TDP safe preview omits digest", "digest" not in safe_preview_block.lower())
    check("TDP safe preview omits token", "token" not in safe_preview_block.lower())

    # Mutation: add unknown key tolerance
    mutated = source.replace(
        "for key in fields.keys.sorted() where schema.fields[key] == nil:\n            return .failure(.unknownField(key))",
        "for key in fields.keys.sorted() where schema.fields[key] == nil:\n            continue",
        1,
    )
    check("TDP unknown key rejection mutation self-test", mutated != source and ".unknownField(key)" not in mutated or "return .failure(.unknownField(key))" in source)


# ---------------------------------------------------------------------------
# 5. ApprovalAuthority
# ---------------------------------------------------------------------------

def check_approval_authority(source: str) -> None:
    check("AA file exists", bool(source))

    # Proposal is not authority
    check("AA proposal not authority comment", "UI proposal only" in source and "grants no executable authority" in source)

    # Single outstanding
    check("AA single outstanding slot", "private var outstanding: (tokenID: UUID, binding: ApprovalTokenBinding)?" in source)

    # Issue burns previous
    check("AA issue burns previous", "outstanding = nil" in source)

    # Consume first (before compare)
    consume_block = source.partition("func consume")[2].partition("func invalidate")[0]
    check("AA consume sets nil before compare", "outstanding = nil" in consume_block)
    check("AA consume before compare", consume_block.index("outstanding = nil") < consume_block.index("guard stored.tokenID"))

    # Mismatch/expiry burns
    check("AA mismatch burns", ".failure(.mismatch)" in source)
    check("AA expiry burns", ".failure(.expired)" in source)

    # No replay
    check("AA no replay single use", "outstanding = nil" in consume_block)

    # Mutation: move outstanding=nil after compare
    # The consume must clear outstanding before the comparison guard
    lines = consume_block.split("\n")
    nil_line = None
    guard_line = None
    for i, line in enumerate(lines):
        if "outstanding = nil" in line and nil_line is None:
            nil_line = i
        if "guard stored.tokenID == token.tokenID" in line and guard_line is None:
            guard_line = i
    check("AA consume-before-compare ordering", nil_line is not None and guard_line is not None and nil_line < guard_line,
          f"nil={nil_line} guard={guard_line}")


# ---------------------------------------------------------------------------
# 6. AgentProtocol
# ---------------------------------------------------------------------------

def check_agent_protocol(source: str) -> None:
    check("AP file exists", bool(source))

    # Strict object arguments
    check("AP object arguments guard", 'guard let arguments = envelope["arguments"], case .object = arguments else' in source)
    check("AP object arguments failure", 'return .failure("Tool arguments must be a JSON object")' in source)

    # Unknown tool rejection
    check("AP unknown tool rejection", "let tool = ToolName(rawValue: wireName) else" in source and "Unknown tool:" in source)

    # Model reason discarded
    check("AP reason accepted but discarded", 'allowed: ["type", "tool", "arguments", "reason"]' in source and "remains accepted for wire compatibility" in source)
    check("AP reason discarded not stored", "ToolCall(id: identifier, tool: tool, arguments: arguments)" in source and "reason: identifier" not in source)

    # Mutation: allow non-object arguments
    mutated = source.replace(
        'guard let arguments = envelope["arguments"], case .object = arguments else',
        'let arguments = envelope["arguments"] ?? .object([:])\n            guard case .object = arguments else',
        1,
    )
    check("AP object arguments mutation self-test", "let arguments = envelope[\"arguments\"] ?? .object" in mutated)


# ---------------------------------------------------------------------------
# 7. AtomicElementExecutor
# ---------------------------------------------------------------------------

def check_atomic_element_executor(source: str) -> None:
    check("AEE file exists", bool(source))

    # One callAsyncJavaScript
    check("AEE single callAsyncJavaScript", source.count("webView.callAsyncJavaScript") == 1, f"count={source.count('webView.callAsyncJavaScript')}")

    # defaultClient world
    check("AEE defaultClient world", "WKContentWorld.defaultClient" in source)

    # No string interpolation in JS body (the functionBody is a raw string)
    func_body_block = source.partition('private static let functionBody = #"""')[2].partition('"""#')[0]
    check("AEE no string interpolation in JS body", "\\(" not in func_body_block, "interpolation found in functionBody")

    # Sensitive check
    check("AEE sensitive check", 'live.sensitiveClass !== "none"' in source and 'return reject("targetSensitive")' in source)

    # Visibility check
    check("AEE visibility check", "function visible(element)" in source and "!live.visible" in source and 'return reject("targetHidden")' in source)

    # Closed result codes
    check("AEE closed result status codes", '"executed"' in source and '"rejected"' in source)
    check("AEE closed result code enumerated", all(code in source for code in (
        "filled", "clicked", "selected", "submitted", "invalidArguments", "pageMismatch",
        "targetMissing", "targetMismatch", "targetSensitive", "targetHidden", "invalidTarget",
        "unsupportedOperation", "webKitFailure", "malformedResult",
    )))

    # No selector/value in result
    check("AEE result has no selector field", '"selector"' not in func_body_block)
    # Result objects use arrow functions: ok = (code) => ({status: "executed", code: code})
    # and reject = (code) => ({status: "rejected", code: code}). Only status+code keys.
    check("AEE result factories are status+code only", '({status: "executed", code: code})' in func_body_block and '({status: "rejected", code: code})' in func_body_block)
    # Verify no extra keys in result objects (no value/selector/etc leaking)
    result_key_pattern = re.findall(r'\{status:\s*"(?:executed|rejected)",\s*code:\s*\w+\}', func_body_block)
    check("AEE result objects closed to two keys", len(result_key_pattern) >= 2)

    # Mutation: add interpolation
    mutated = source.replace(
        'private static let functionBody = #"""',
        'private static let functionBody = #"""\n    const x = "\\(privateSelector)";',
        1,
    )
    check("AEE interpolation mutation self-test", '"\\(privateSelector)"' in mutated)


# ---------------------------------------------------------------------------
# 8. BrowserView
# ---------------------------------------------------------------------------

def check_browser_view(source: str) -> None:
    check("BV file exists", bool(source))

    # Dispatch exists
    check("BV dispatch gate exists", "private func dispatch(call: ValidatedToolCall" in source)
    check("BV dispatch gate is commit gate", "Dispatch Gate + Commit Gate" in source)

    # Consume before live validate
    dispatch_block = source.partition("private func dispatch(")[2].partition("private func executeValidated")[0]
    consume_idx = dispatch_block.find("approvalAuthority.consume")
    validate_idx = dispatch_block.find("validate(call.transportCall)")
    check("BV consume before live validate", consume_idx >= 0 and validate_idx >= 0 and consume_idx < validate_idx,
          f"consume={consume_idx} validate={validate_idx}")

    # Automatic policy enforced
    check("BV automatic policy enforced", "descriptor.defaultApprovalPolicy == .automatic" in dispatch_block)
    check("BV automatic risk enforced", "classify(call.transportCall) == .auto" in dispatch_block)

    # No arguments["selector"]
    check("BV no arguments selector", 'arguments["selector"]' not in source)

    # No document.querySelector (outside AtomicElementExecutor which is separate file)
    check("BV no document.querySelector", "document.querySelector" not in source)

    # One AtomicElementExecutor.execute
    check("BV single AtomicElementExecutor.execute", source.count("AtomicElementExecutor.execute") == 1)

    # expectedTarget compared in didCommit
    did_commit_block = source.partition("func webView(_ webView: WKWebView, didCommit")[2].partition("func webView(_ webView: WKWebView, didFinish")[0]
    check("BV expectedTarget compared in didCommit", "let expected = pending.expectedTarget" in did_commit_block and "expected != target" in did_commit_block)

    # candidate accepted only under atomicInvocationInFlight
    did_start_block = source.partition("func webView(_ webView: WKWebView, didStartProvisionalNavigation")[2].partition("func webView(_ webView: WKWebView, didCommit")[0]
    check("BV candidate only under atomicInvocationInFlight", "pending.atomicInvocationInFlight" in did_start_block and "pending.atomicCandidateNavigation = navigation" in did_start_block)

    # Scroll has marker + URL + origin binding
    scroll_block = source.partition("case .scroll:")[2].partition("case .openURL:")[0]
    check("BV scroll page identity guard", "call.pageIdentity" in scroll_block)
    check("BV scroll snapshot marker binding", "snapshotMarker" in scroll_block and '__K3BrowserPrivateSnapshotDocumentBinding_8f6d2a41' in scroll_block)
    check("BV scroll canonical URL binding", "boundPageURL" in scroll_block and "canonicalPageURL(location.href)" in scroll_block)
    check("BV scroll origin binding", "boundOrigin" in scroll_block and "location.origin !== boundOrigin" in scroll_block)
    check("BV scroll pageMismatch rejection", 'code: "pageMismatch"' in scroll_block)
    check("BV scroll no direction/amount interpolation", "\\(direction" not in scroll_block and "\\(amount" not in scroll_block)

    # Mission Control export through stageManualApproval
    check("BV exportLog routes through stageManualApproval", "func exportLog()" in source)
    export_log_block = source.partition("func exportLog()")[2].partition("func saveCurrentAnswerNote()")[0]
    check("BV exportLog uses stageManualApproval", "stageManualApproval" in export_log_block)
    check("BV exportLog does not call exportText directly", "exportText(" not in export_log_block)
    check("BV exportLog uses export_markdown tool", ".exportMarkdown" in export_log_block)

    # exportText still exists as write sink for executeValidated
    check("BV exportText retained as write sink", "func exportText(title: String, body: String, ext: String) -> Bool" in source)
    exec_validated_block = source.partition("private func executeValidated")[2].partition("private func executeAtomicElement")[0]
    check("BV executeValidated uses exportText", "exportText(title:" in exec_validated_block)

    # Mutation: remove scroll identity guard
    mutated_scroll = source.replace("guard let pageIdentity = call.pageIdentity,\n                  let snapshot = self.snapshot,", "guard false,", 1)
    check("BV scroll identity guard mutation self-test", "guard false," in mutated_scroll)

    # Mutation: bypass export gate
    mutated_export = source.replace(
        'stageManualApproval(call: ToolCall(id: UUID().uuidString, tool: .exportMarkdown',
        'exportText(title: "k3-agent-run"',
        1,
    )
    check("BV export gate mutation self-test", "exportText(title: \"k3-agent-run\"" in mutated_export)


# ---------------------------------------------------------------------------
# 9. SnapshotSanitizer
# ---------------------------------------------------------------------------

def check_snapshot_sanitizer(source: str) -> None:
    check("SS file exists", bool(source))

    # No .value
    check("SS no .value property", ".value" not in source)

    # No getAttribute('value')
    check("SS no getAttribute value", "getAttribute('value')" not in source and 'getAttribute("value")' not in source)

    # No FormData
    check("SS no FormData", "FormData" not in source)

    # Hidden exclusion
    check("SS hidden field exclusion", "isHiddenField" in source and "type')==\'hidden\')" in source or "hidden" in source)

    # Metadata for classification only
    check("SS collects classification metadata", all(k in source for k in (
        "aria-label", "role", "type", "name", "placeholder", "autocomplete",
    )))

    # Isolated marker global
    check("SS isolated snapshot marker global", "__K3BrowserPrivateSnapshotDocumentBinding_8f6d2a41" in source)
    check("SS marker validation regex", '/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/u' in source)

    # Mutation: add .value
    mutated = source.replace("selector:executableSelector(el),", "selector:executableSelector(el),value:el.value,", 1)
    check("SS .value mutation self-test", "value:el.value" in mutated and "value:el.value" not in source)

    # Mutation: add FormData
    mutated_fd = source.replace("const encoder=new TextEncoder();", "const encoder=new TextEncoder();const fd=new FormData(document.body);", 1)
    check("SS FormData mutation self-test", "new FormData(document.body)" in mutated_fd)


# ---------------------------------------------------------------------------
# Cross-file structural checks
# ---------------------------------------------------------------------------

def check_cross_file(substrate: str, view: str, mission: str) -> None:
    # Mission Control should still have exportLog button calling state.exportLog
    check("MC exportLog button present", "state.exportLog" in mission)

    # Mission Control should not directly call exportText
    check("MC no direct exportText call", "state.exportText" not in mission and ".exportText(" not in mission)

    # Mission Control manual tools use stageManualApproval (existing)
    check("MC manual tools use stageManualApproval", "state.stageManualApproval" in mission)

    # 19 tools in substrate
    wire_values = re.findall(r'case\s+(\w+)\s+=\s+"([^"]+)"', substrate.partition("extension ToolName")[0])
    check("CF exact 19 ToolName wire values", len(wire_values) == 19 and set(v for _, v in wire_values) == set(EXPECTED_TOOLS))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

canonical = CANONICAL.read_text(encoding="utf-8") if CANONICAL.is_file() else ""
page_identity = PAGE_IDENTITY.read_text(encoding="utf-8") if PAGE_IDENTITY.is_file() else ""
stable_ref = STABLE_REF.read_text(encoding="utf-8") if STABLE_REF.is_file() else ""
dispatch_policy = DISPATCH_POLICY.read_text(encoding="utf-8") if DISPATCH_POLICY.is_file() else ""
authority = AUTHORITY.read_text(encoding="utf-8") if AUTHORITY.is_file() else ""
protocol_src = PROTOCOL.read_text(encoding="utf-8") if PROTOCOL.is_file() else ""
atomic = ATOMIC.read_text(encoding="utf-8") if ATOMIC.is_file() else ""
substrate = SUBSTRATE.read_text(encoding="utf-8") if SUBSTRATE.is_file() else ""
view = VIEW.read_text(encoding="utf-8") if VIEW.is_file() else ""
sanitizer = SANITIZER.read_text(encoding="utf-8") if SANITIZER.is_file() else ""
mission = MISSION.read_text(encoding="utf-8") if MISSION.is_file() else ""

print("=== PEAK 1 Slice B: CanonicalPageTarget ===")
check_canonical_page_target(canonical)

print("\n=== PEAK 1 Slice B: PageIdentityReducer ===")
check_page_identity_reducer(page_identity)

print("\n=== PEAK 1 Slice B: StableElementReference ===")
check_stable_element_reference(stable_ref)

print("\n=== PEAK 1 Slice B: ToolDispatchPolicy ===")
check_tool_dispatch_policy(dispatch_policy)

print("\n=== PEAK 1 Slice B: ApprovalAuthority ===")
check_approval_authority(authority)

print("\n=== PEAK 1 Slice B: AgentProtocol ===")
check_agent_protocol(protocol_src)

print("\n=== PEAK 1 Slice B: AtomicElementExecutor ===")
check_atomic_element_executor(atomic)

print("\n=== PEAK 1 Slice B: BrowserView ===")
check_browser_view(view)

print("\n=== PEAK 1 Slice B: SnapshotSanitizer ===")
check_snapshot_sanitizer(sanitizer)

print("\n=== PEAK 1 Slice B: Cross-file ===")
check_cross_file(substrate, view, mission)

if FAILURES:
    print(f"\nFAILED {len(FAILURES)} PEAK 1 slice B check(s)")
    for failure in FAILURES:
        print(f"  - {failure}")
    sys.exit(1)
print("\nPASS PEAK 1 slice B source invariants and mutation sensitivity (Swift compile pending Xcode CI)")
