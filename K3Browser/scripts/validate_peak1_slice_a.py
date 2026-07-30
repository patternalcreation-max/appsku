#!/usr/bin/env python3
"""PEAK 1 slice A typed-tool source invariants and semantic vectors.

Linux has no Swift toolchain in this workspace. This deterministic stdlib gate checks
actual Swift source structure plus JSON semantic vectors and mutation sensitivity;
macOS/Xcode CI remains responsible for compiling and exercising Swift Codable.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
BROWSER = ROOT / "Browser"
SUBSTRATE = BROWSER / "Runtime" / "ToolSubstrate.swift"
PROTOCOL = BROWSER / "Runtime" / "AgentProtocol.swift"
AUTHORITY = BROWSER / "Runtime" / "ApprovalAuthority.swift"
DISPATCH_POLICY = BROWSER / "Runtime" / "ToolDispatchPolicy.swift"
VIEW = BROWSER / "BrowserView.swift"
REDACTOR = BROWSER / "Safety" / "Redactor.swift"
MISSION = BROWSER / "UI" / "MissionControlView.swift"
APPROVAL = BROWSER / "UI" / "ApprovalReviewOverlay.swift"
FAILURES: list[str] = []

EXPECTED_TOOLS = (
    "snapshot_page", "extract_text", "extract_links", "extract_forms", "extract_tables",
    "save_memory_note", "read_memory_notes", "scroll", "open_url", "back", "forward",
    "reload", "fill_selector", "click_selector", "select_option", "submit_form",
    "export_markdown", "export_json", "export_csv",
)

# effect, settlement, approval, page-bound, scope, timeout, invocations,
# argument bytes, result bytes, replay, descriptor version
READ = ("pageRead", "snapshot", "automatic", True, "currentPageWhenEngagementActive", 15, 6, 8_192, 65_536, "reobserveBeforeReplay", 1)
ACTION_VIEWPORT = ("viewportMutation", "immediateJavaScript", "requireApproval", True, "currentPageWhenEngagementActive", 30, 6, 16_384, 16_384, "reobserveBeforeReplay", 1)
NAV_CURRENT = ("navigation", "webKitNavigation", "requireApproval", True, "currentPageWhenEngagementActive", 30, 6, 16_384, 16_384, "noReplay", 1)
DOM_IMMEDIATE = ("domMutation", "immediateJavaScript", "requireApproval", True, "currentPageWhenEngagementActive", 30, 6, 16_384, 16_384, "noReplay", 1)
EXPECTED_DESCRIPTOR_MATRIX = {
    "snapshot_page": READ,
    "extract_text": READ,
    "extract_links": READ,
    "extract_forms": READ,
    "extract_tables": READ,
    "save_memory_note": ("localPersistence", "localPersistence", "automatic", False, "none", 10, 6, 65_536, 65_536, "noReplay", 1),
    "read_memory_notes": ("localRead", "localPersistence", "automatic", False, "none", 10, 6, 65_536, 65_536, "idempotentLocalRead", 1),
    "scroll": ACTION_VIEWPORT,
    "open_url": ("navigation", "webKitNavigation", "requireApproval", True, "targetURLWhenEngagementActive", 30, 6, 16_384, 16_384, "noReplay", 1),
    "back": NAV_CURRENT,
    "forward": NAV_CURRENT,
    "reload": NAV_CURRENT,
    "fill_selector": DOM_IMMEDIATE,
    "click_selector": ("domMutation", "possibleWebKitNavigation", "requireApproval", True, "currentPageWhenEngagementActive", 30, 6, 16_384, 16_384, "noReplay", 1),
    "select_option": DOM_IMMEDIATE,
    "submit_form": ("domMutation", "possibleWebKitNavigation", "alwaysRequireApproval", True, "currentPageWhenEngagementActive", 30, 6, 16_384, 16_384, "noReplay", 1),
    "export_markdown": ("externalShare", "presentation", "requireApproval", False, "none", 10, 6, 65_536, 65_536, "noReplay", 1),
    "export_json": ("externalShare", "presentation", "requireApproval", False, "none", 10, 6, 65_536, 65_536, "noReplay", 1),
    "export_csv": ("externalShare", "presentation", "requireApproval", False, "none", 10, 6, 65_536, 65_536, "noReplay", 1),
}


def check(name: str, condition: bool, detail: str = "") -> None:
    print(("PASS " if condition else "FAIL ") + name + ((": " + detail) if detail and not condition else ""))
    if not condition:
        FAILURES.append(name)


def enum_case_names(source: str) -> dict[str, str]:
    block = source.partition("enum ToolName:")[2].partition("extension ToolName:")[0]
    return dict(re.findall(r'^\s*case\s+(\w+)\s*=\s*"([^"]+)"', block, re.MULTILINE))


def enum_wire_values(source: str) -> tuple[str, ...]:
    return tuple(enum_case_names(source).values())


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


def split_top_level(raw: str) -> list[str]:
    parts: list[str] = []
    start = 0
    stack: list[str] = []
    quote: str | None = None
    escaped = False
    pairs = {"(": ")", "[": "]", "{": "}"}
    for index, character in enumerate(raw):
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
        elif character in pairs:
            stack.append(pairs[character])
        elif stack and character == stack[-1]:
            stack.pop()
        elif character == "," and not stack:
            parts.append(raw[start:index].strip())
            start = index + 1
    tail = raw[start:].strip()
    if tail:
        parts.append(tail)
    return parts


def named_arguments(raw: str) -> dict[str, str]:
    parsed: dict[str, str] = {}
    for part in split_top_level(raw):
        name, separator, value = part.partition(":")
        if not separator or not name.strip() or name.strip() in parsed:
            raise ValueError(f"invalid or duplicate named argument: {part!r}")
        parsed[name.strip()] = value.strip()
    return parsed


def swift_int(raw: str) -> int:
    return int(raw.replace("_", ""))


def swift_case(raw: str) -> str:
    if not re.fullmatch(r"\.\w+", raw):
        raise ValueError(f"expected enum case, got {raw!r}")
    return raw[1:]


def parse_budgets(source: str) -> dict[str, tuple[int, int, int, int]]:
    budgets: dict[str, tuple[int, int, int, int]] = {}
    pattern = re.compile(r"\b(?:private\s+)?static\s+let\s+(\w+)\s*=\s*ToolBudgetMetadata\s*\(")
    for match in pattern.finditer(source):
        body, _ = balanced_body(source, match.end() - 1)
        fields = named_arguments(body)
        expected = ("timeoutSeconds", "maximumInvocationsPerRun", "maximumArgumentBytes", "maximumResultBytes")
        if set(fields) != set(expected) or match.group(1) in budgets:
            raise ValueError(f"bad budget definition {match.group(1)}")
        budgets[match.group(1)] = tuple(swift_int(fields[name]) for name in expected)  # type: ignore[assignment]
    return budgets


def parse_descriptor_matrix(source: str) -> dict[str, tuple[object, ...]]:
    cases = enum_case_names(source)
    budgets = parse_budgets(source)
    registry_start = source.find("static let descriptors:")
    registry_end = source.find("static func descriptor", registry_start)
    if registry_start < 0 or registry_end < 0:
        raise ValueError("descriptor registry markers missing")
    block = source[registry_start:registry_end]
    entry_pattern = re.compile(r"(?m)^\s*\.(\w+)\s*:\s*ToolDescriptor\s*\(")
    matrix: dict[str, tuple[object, ...]] = {}
    required = {
        "effectClass", "settlementClass", "defaultApprovalPolicy", "isPageBound",
        "scopeRequirement", "budget", "replayPolicy", "descriptorVersion",
    }
    for match in entry_pattern.finditer(block):
        case_name = match.group(1)
        body, _ = balanced_body(block, match.end() - 1)
        fields = named_arguments(body)
        if set(fields) != required or case_name not in cases:
            raise ValueError(f"bad descriptor fields or unknown ToolName case: {case_name}")
        budget_name = fields["budget"]
        if budget_name not in budgets:
            raise ValueError(f"unknown budget {budget_name!r} for {case_name}")
        page_bound = {"true": True, "false": False}.get(fields["isPageBound"])
        if page_bound is None:
            raise ValueError(f"non-literal isPageBound for {case_name}")
        wire_name = cases[case_name]
        if wire_name in matrix:
            raise ValueError(f"duplicate descriptor for {wire_name}")
        timeout, invocations, argument_bytes, result_bytes = budgets[budget_name]
        matrix[wire_name] = (
            swift_case(fields["effectClass"]),
            swift_case(fields["settlementClass"]),
            swift_case(fields["defaultApprovalPolicy"]),
            page_bound,
            swift_case(fields["scopeRequirement"]),
            timeout,
            invocations,
            argument_bytes,
            result_bytes,
            swift_case(fields["replayPolicy"]),
            swift_int(fields["descriptorVersion"]),
        )
    return matrix


def descriptor_matrix_errors(source: str) -> list[str]:
    try:
        actual = parse_descriptor_matrix(source)
    except (ValueError, KeyError) as error:
        return [str(error)]
    errors: list[str] = []
    if set(actual) != set(EXPECTED_DESCRIPTOR_MATRIX):
        errors.append(f"tool set: {sorted(actual)}")
    for tool, expected in EXPECTED_DESCRIPTOR_MATRIX.items():
        if actual.get(tool) != expected:
            errors.append(f"{tool}: expected {expected!r}, got {actual.get(tool)!r}")
    return errors


def mutate_descriptor(source: str, case_name: str, field: str, replacement: str) -> str:
    pattern = re.compile(rf"(?m)^\s*\.{re.escape(case_name)}\s*:\s*ToolDescriptor\s*\(")
    match = pattern.search(source)
    if not match:
        raise ValueError(f"descriptor not found: {case_name}")
    body, end = balanced_body(source, match.end() - 1)
    mutated_body, count = re.subn(rf"\b{re.escape(field)}\s*:\s*([^,]+)", f"{field}: {replacement}", body, count=1)
    if count != 1:
        raise ValueError(f"descriptor field not found: {case_name}.{field}")
    return source[:match.end()] + mutated_body + source[end - 1:]


def mutate_budget(source: str, budget_name: str, field: str, replacement: str) -> str:
    pattern = re.compile(rf"\bstatic\s+let\s+{re.escape(budget_name)}\s*=\s*ToolBudgetMetadata\s*\(")
    match = pattern.search(source)
    if not match:
        raise ValueError(f"budget not found: {budget_name}")
    body, end = balanced_body(source, match.end() - 1)
    mutated_body, count = re.subn(rf"\b{re.escape(field)}\s*:\s*([^,]+)", f"{field}: {replacement}", body, count=1)
    if count != 1:
        raise ValueError(f"budget field not found: {budget_name}.{field}")
    return source[:match.end()] + mutated_body + source[end - 1:]


def has_json_value_contract(source: str) -> bool:
    start = source.find("indirect enum JSONValue:")
    end = source.find("// MARK: - Static typed tool registry", start)
    if start < 0 or end < 0:
        return False
    block = source[start:end]
    declarations = re.findall(r"(?m)^\s{4}case\s+(object|array|string|number|bool|null)(?:\(([^\n]+)\))?\s*$", block)
    expected = {
        ("object", "[String: JSONValue]"), ("array", "[JSONValue]"), ("string", "String"),
        ("number", "Double"), ("bool", "Bool"), ("null", ""),
    }
    decode_tokens = (
        "container.decodeNil()", "container.decode(Bool.self)", "container.decode(Double.self)",
        "container.decode(String.self)", "container.decode([JSONValue].self)",
        "container.decode([String: JSONValue].self)", "throw DecodingError.typeMismatch",
    )
    encode_cases = ("case .object", "case .array", "case .string", "case .number", "case .bool", "case .null")
    return (
        "indirect enum JSONValue: Codable, Equatable" in block
        and set(declarations) == expected
        and len(declarations) == len(expected)
        and all(token in block for token in decode_tokens)
        and all(token in block for token in encode_cases)
        and "guard value.isFinite" in block
    )


def approval_reason_contract(source: str, substrate_source: str, authority_source: str) -> bool:
    requests: list[str] = []
    for match in re.finditer(r"\bApprovalRequest\s*\(", source):
        try:
            body, _ = balanced_body(source, match.end() - 1)
        except ValueError:
            return False
        requests.append(body)
    tool_call_block = substrate_source.partition("struct ToolCall:")[2]
    reason_builder = substrate_source.partition("static func approvalReason(for tool: ToolName)")[2].partition("\n    }\n}")[0]
    return all((
        len(requests) == 1,
        all("reason: ToolRegistry.approvalReason(for: call.tool)" in request for request in requests),
        all("call.reason" not in request and "Type hunter2" not in request for request in requests),
        "call.reason" not in source,
        "let reason:" not in tool_call_block,
        "descriptor.defaultApprovalPolicy" in reason_builder,
        "descriptor.effectClass" in reason_builder,
        "call.arguments" not in reason_builder,
        "Self.boundedRedacted(preview)" in authority_source,
        "Self.boundedRedacted(reason)" in authority_source,
    ))


def has_descriptor_driven_classification(source: str) -> bool:
    block = source.partition("func classify(_ call: ToolCall)")[2].partition("func blockReason")[0]
    return all((
        bool(block),
        "ToolRegistry.descriptor(for: call.tool)" in block,
        "descriptor.defaultApprovalPolicy" in block,
        "SensitiveToolPolicy.blockReason" in block,
        "call.arguments.values.joined" not in block,
        "approval.contains" not in block,
    ))


def has_no_string_dictionary_arguments(source: str) -> bool:
    return not re.search(r"(?:arguments|args)\s*:\s*\[String\s*:\s*String\]", source)


def has_explicit_object_arguments_guard(source: str) -> bool:
    parser = source.partition("static func parse(")[2].partition("private static func hasOnlyKeys")[0]
    return all((
        bool(parser),
        'guard let arguments = envelope["arguments"], case .object = arguments else' in parser,
        'return .failure("Tool arguments must be a JSON object")' in parser,
        'envelope["arguments"] ?? .object([:])' not in parser,
    ))


def has_fail_closed_registry(source: str) -> bool:
    fallback = source.partition("private static let failClosedDescriptor")[2].partition("static func descriptor")[0]
    lookup = source.partition("static func descriptor(for tool: ToolName)")[2].partition("static var promptToolList")[0]
    return all(token in fallback for token in (
        "defaultApprovalPolicy: .alwaysRequireApproval",
        "maximumInvocationsPerRun: 0",
        "maximumArgumentBytes: 0",
        "maximumResultBytes: 0",
        "descriptorVersion: 0",
    )) and "descriptors[tool] ?? failClosedDescriptor" in lookup


def has_opaque_ref_schemas(source: str) -> bool:
    return all((
        'required: ["ref", "value"]' in source,
        source.count('required: ["ref"]') == 2,
        source.count('"ref": .opaqueReference') == 4,
        'arguments["selector"]' not in source,
        '"selector": .opaqueReference' not in source,
    ))


def parse_tool_call_arguments(raw: str):
    """Linux semantic mirror: tool_call arguments must be present and an object."""
    envelope = json.loads(raw)
    if not isinstance(envelope, dict) or envelope.get("type") != "tool_call":
        raise ValueError("not a tool_call envelope")
    if "arguments" not in envelope or not isinstance(envelope["arguments"], dict):
        raise ValueError("tool arguments must be a JSON object")
    return envelope["arguments"]


def json_semantic_round_trip(raw: str) -> bool:
    decoded = json.loads(raw)
    encoded = json.dumps(decoded, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return json.loads(encoded) == decoded


def decode_json_value(raw: str):
    """Semantic mirror of the six fail-closed Swift cases for Linux fixtures."""
    value = json.loads(raw, parse_constant=lambda token: (_ for _ in ()).throw(ValueError(token)))

    def typed(item):
        if item is None:
            return ("null", None)
        if isinstance(item, bool):
            return ("bool", item)
        if isinstance(item, (int, float)):
            return ("number", float(item))
        if isinstance(item, str):
            return ("string", item)
        if isinstance(item, list):
            return ("array", [typed(child) for child in item])
        if isinstance(item, dict):
            return ("object", {key: typed(child) for key, child in item.items()})
        raise TypeError(type(item).__name__)

    return typed(value)


substrate = SUBSTRATE.read_text(encoding="utf-8") if SUBSTRATE.is_file() else ""
protocol = PROTOCOL.read_text(encoding="utf-8") if PROTOCOL.is_file() else ""
authority = AUTHORITY.read_text(encoding="utf-8") if AUTHORITY.is_file() else ""
dispatch_policy = DISPATCH_POLICY.read_text(encoding="utf-8") if DISPATCH_POLICY.is_file() else ""
view = VIEW.read_text(encoding="utf-8") if VIEW.is_file() else ""
redactor = REDACTOR.read_text(encoding="utf-8") if REDACTOR.is_file() else ""
mission = MISSION.read_text(encoding="utf-8") if MISSION.is_file() else ""
approval = APPROVAL.read_text(encoding="utf-8") if APPROVAL.is_file() else ""
all_authoritative = "\n".join((substrate, protocol, authority, dispatch_policy, view, redactor, mission))

check("typed substrate file exists", SUBSTRATE.is_file())
check("JSONValue structural contract", has_json_value_contract(substrate))
json_shape_mutation = substrate.replace("case bool(Bool)", "case boolean(Bool)", 1)
check("JSONValue structural mutation self-test", not has_json_value_contract(json_shape_mutation))
check("safe typed JSONValue accessors", all(token in substrate for token in (
    "var objectValue: [String: JSONValue]?", "var arrayValue: [JSONValue]?",
    "var stringValue: String?", "var numberValue: Double?", "var boolValue: Bool?",
    "var integerValue: Int?", "subscript(key: String) -> JSONValue?",
)))
check("nested JSON semantic vectors", all(json_semantic_round_trip(vector) for vector in (
    '{"selector":"#q","nested":{"array":[1,true,null,"x"],"object":{"n":-2.5}}}',
    '{"unicode":"磁気","empty":{},"items":[[],{"ok":false}]}',
)))
typed_nested = decode_json_value('{"nested":{"array":[1,true,null,"x"]}}')
check("six-case decode semantic mirror", typed_nested == (
    "object", {"nested": ("object", {"array": ("array", [
        ("number", 1.0), ("bool", True), ("null", None), ("string", "x")
    ])})}
))
try:
    decode_json_value('{"bad":NaN}')
    nonfinite_rejected = False
except ValueError:
    nonfinite_rejected = True
check("non-finite JSON number rejected", nonfinite_rejected)

wire_values = enum_wire_values(substrate)
case_map = enum_case_names(substrate)
check("exact 19 ToolName wire values", len(wire_values) == 19 and set(wire_values) == set(EXPECTED_TOOLS), repr(wire_values))
check("ToolName fail-closed Codable", "enum ToolName: String, Codable, CaseIterable" in substrate and "case unknown" not in substrate.lower())
check("unknown parser rejection", 'let tool = ToolName(rawValue: wireName) else' in protocol and "Unknown tool:" in protocol and "case unknown" not in substrate.lower())
check("unknown rejection semantic vector", "definitely_not_a_tool" not in set(wire_values))

matrix_errors = descriptor_matrix_errors(substrate)
check("exact 19-tool descriptor matrix", not matrix_errors, "; ".join(matrix_errors))
check("registry lookup fail closed", has_fail_closed_registry(substrate))
registry_fallback_mutations = [
    substrate.replace("maximumInvocationsPerRun: 0", "maximumInvocationsPerRun: 1", 1),
    substrate.replace("maximumArgumentBytes: 0", "maximumArgumentBytes: 1", 1),
    substrate.replace("maximumResultBytes: 0", "maximumResultBytes: 1", 1),
    substrate.replace("descriptorVersion: 0", "descriptorVersion: 1", 1),
    substrate.replace("descriptors[tool] ?? failClosedDescriptor", "descriptors[tool]!", 1),
]
check("registry fail-closed mutation self-test", all(not has_fail_closed_registry(mutation) for mutation in registry_fallback_mutations))
mutations = {
    "submit approval": mutate_descriptor(substrate, "submitForm", "defaultApprovalPolicy", ".requireApproval"),
    "submit effect": mutate_descriptor(substrate, "submitForm", "effectClass", ".pageRead"),
    "submit settlement": mutate_descriptor(substrate, "submitForm", "settlementClass", ".immediateJavaScript"),
    "open URL replay": mutate_descriptor(substrate, "openURL", "replayPolicy", ".reobserveBeforeReplay"),
    "open URL scope": mutate_descriptor(substrate, "openURL", "scopeRequirement", ".currentPageWhenEngagementActive"),
    "local read page-bound": mutate_descriptor(substrate, "readMemoryNotes", "isPageBound", "true"),
    "local read effect": mutate_descriptor(substrate, "readMemoryNotes", "effectClass", ".pageRead"),
    "budget": mutate_budget(substrate, "actionBudget", "maximumArgumentBytes", "16_385"),
    "version": mutate_descriptor(substrate, "snapshotPage", "descriptorVersion", "2"),
}
for mutation_name, mutation_source in mutations.items():
    check(f"descriptor matrix rejects {mutation_name} mutation", bool(descriptor_matrix_errors(mutation_source)))

check("authoritative ToolCall uses JSONValue object", "let tool: ToolName" in substrate and "let arguments: JSONValue" in substrate and "guard case .object = arguments" in substrate)
check("no string dictionary tool arguments", has_no_string_dictionary_arguments(all_authoritative))
string_dictionary_mutation = substrate.replace("let arguments: JSONValue", "let arguments: [String: String]", 1)
check("string dictionary mutation self-test", not has_no_string_dictionary_arguments(string_dictionary_mutation))
tool_call_block = substrate.partition("struct ToolCall:")[2]
check("ToolCall authority contains no Any", "Any" not in tool_call_block)
check("parser preserves nested JSONValue", "JSONDecoder().decode(JSONValue.self, from: data)" in protocol and "case .object(let envelope) = decoded" in protocol and 'let arguments = envelope["arguments"], case .object = arguments' in protocol and "AgentWireEnvelope" not in protocol)
check("parser requires explicitly present object arguments", has_explicit_object_arguments_guard(protocol))
opaque_ref = "element_00000000-0000-4000-8000-000000000001"
valid_arguments = parse_tool_call_arguments('{"type":"tool_call","tool":"submit_form","arguments":{"ref":"' + opaque_ref + '","nested":{"confirm":true,"items":[1,null,false]}}}')
check("object arguments semantic fixture accepted", valid_arguments == {"ref": opaque_ref, "nested": {"confirm": True, "items": [1, None, False]}} and "selector" not in valid_arguments)
invalid_argument_fixtures = {
    "missing": '{"type":"tool_call","tool":"submit_form"}',
    "null": '{"type":"tool_call","tool":"submit_form","arguments":null}',
    "string": '{"type":"tool_call","tool":"submit_form","arguments":"form"}',
    "array": '{"type":"tool_call","tool":"submit_form","arguments":[]}',
    "number": '{"type":"tool_call","tool":"submit_form","arguments":1}',
    "bool": '{"type":"tool_call","tool":"submit_form","arguments":false}',
}
for fixture_name, fixture in invalid_argument_fixtures.items():
    try:
        parse_tool_call_arguments(fixture)
        fixture_rejected = False
    except ValueError:
        fixture_rejected = True
    check(f"{fixture_name} tool arguments semantic fixture rejected", fixture_rejected)
nil_fallback_mutation = protocol.replace(
    'guard let arguments = envelope["arguments"], case .object = arguments else',
    'let arguments = envelope["arguments"] ?? .object([:])\n            guard case .object = arguments else',
    1,
)
check(
    "nil-to-empty arguments fallback mutation self-test",
    nil_fallback_mutation != protocol and not has_explicit_object_arguments_guard(nil_fallback_mutation),
)
check("manual calls use typed arguments", 'tool: .fillSelector' in mission and 'arguments: .object(' in mission)
check("element tools require opaque ref not selector", has_opaque_ref_schemas(dispatch_policy))
selector_schema_mutation = dispatch_policy.replace('"ref": .opaqueReference', '"selector": .opaqueReference', 1)
check("raw selector schema mutation self-test", selector_schema_mutation != dispatch_policy and not has_opaque_ref_schemas(selector_schema_mutation))
check("typed execution dispatch", "switch call.tool" in view and "case .snapshotPage" in view and 'case "snapshot_page"' not in view)
check("prompt registry generated", "ToolRegistry.promptToolList" in view)

check("descriptor-driven base classification", has_descriptor_driven_classification(view))
classification_mutation = view.replace("descriptor.defaultApprovalPolicy", "ToolApprovalPolicy.requireApproval", 1)
check("classification mutation self-test", not has_descriptor_driven_classification(classification_mutation))
substring_classification_mutation = view.replace(
    "let descriptor = ToolRegistry.descriptor(for: call.tool)",
    'let joined = call.tool.rawValue + " " + call.arguments.values.joined(separator: " ")',
    1,
)
check("substring-only classification mutation self-test", not has_descriptor_driven_classification(substring_classification_mutation))
check("sensitive checks only restrict", "if SensitiveToolPolicy.blockReason(for: call.arguments) != nil { return .blocked }" in view)
check("sensitive/payment/wallet blocks retained", all(fragment in substrate for fragment in (
    "password", "passcode", "otp", "2fa", "credit card", "cvv", "payment", "purchase",
    "checkout", "delete", "remove", "send money", "transfer", "swap", "wallet",
    "connect wallet", "sign transaction", "approve token", "confirm order",
)))
check("trusted descriptor approval reasons", approval_reason_contract(view, substrate, authority))
reason_fixture_mutation = view.replace(
    "reason: ToolRegistry.approvalReason(for: call.tool)",
    'reason: "Type hunter2"',
    1,
)
check("approval reason fixture mutation rejected", not approval_reason_contract(reason_fixture_mutation, substrate, authority))
reason_flow_mutation = view.replace(
    "reason: ToolRegistry.approvalReason(for: call.tool)",
    "reason: call.reason",
    1,
)
check("model reason flow mutation rejected", not approval_reason_contract(reason_flow_mutation, substrate, authority))
check("wire reason retained only as ignored protocol field", 'allowed: ["type", "tool", "arguments", "reason"]' in protocol and 'if let reason = envelope["reason"]' in protocol and "reason.stringValue" in protocol and "text.utf8.count <= 2_048" in protocol and "ToolCall(id: identifier, tool: tool, arguments: arguments)" in protocol and "call.reason" not in all_authoritative)
check("raw arguments absent from approval UI", "request.call.arguments" not in approval)
check("raw arguments absent from parser logs", "Raw:" not in view and "arguments.description" not in view)
check("one runtime and webview owner retained", view.count("@StateObject private var state = BrowserState()") == 1 and view.count("let webView: WKWebView") == 2 and view.count("WebViewContainer(webView: state.webView)") == 1)

if FAILURES:
    print(f"FAILED {len(FAILURES)} PEAK 1 slice A check(s)")
    sys.exit(1)
print("PASS PEAK 1 slice A typed-tool invariants and semantic vectors (Swift compile pending Xcode CI)")
