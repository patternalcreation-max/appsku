import Foundation

struct ValidatedToolCall: Equatable {
    let id: String
    let tool: ToolName
    let arguments: [String: JSONValue]
    let canonicalArguments: Data
    let canonicalArgumentDigest: String
    let effectiveTarget: CanonicalPageTarget?
    let pageIdentity: SnapshotIdentity?
    let target: StableElementReference?

    var transportCall: ToolCall { ToolCall(id: id, tool: tool, arguments: .object(arguments)) }
}

enum ToolDispatchError: Error, Equatable, LocalizedError {
    case argumentsMustBeObject
    case unknownField(String)
    case missingField(String)
    case wrongType(String)
    case outOfBounds(String)
    case argumentBytes
    case invalidURL
    case pageUnavailable
    case staleReference

    var errorDescription: String? {
        switch self {
        case .argumentsMustBeObject: return "Tool arguments must be a JSON object"
        case .unknownField(let key): return "Unknown tool argument: \(key)"
        case .missingField(let key): return "Missing tool argument: \(key)"
        case .wrongType(let key): return "Wrong type for tool argument: \(key)"
        case .outOfBounds(let key): return "Tool argument out of bounds: \(key)"
        case .argumentBytes: return "Canonical tool arguments exceed descriptor byte limit"
        case .invalidURL: return "Invalid canonical HTTP(S) target"
        case .pageUnavailable: return "Committed page identity unavailable"
        case .staleReference: return "Unknown or stale element reference"
        }
    }
}

private enum ArgumentRule: Equatable {
    case string(minimumUTF8Bytes: Int, maximumUTF8Bytes: Int)
    case integer(ClosedRange<Int>)
    case enumeration(Set<String>, maximumUTF8Bytes: Int)
    case opaqueReference
}

private struct ClosedToolSchema {
    let required: Set<String>
    let fields: [String: ArgumentRule]
}

enum ToolDispatchPolicy {
    private static let schemas: [ToolName: ClosedToolSchema] = [
        .snapshotPage: empty(),
        .extractText: empty(),
        .extractLinks: empty(),
        .extractForms: empty(),
        .extractTables: empty(),
        .saveMemoryNote: schema(required: [], fields: [
            "title": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 256),
            "body": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 32_768),
        ]),
        .readMemoryNotes: empty(),
        .scroll: schema(required: ["direction", "amount"], fields: [
            "direction": .enumeration(["up", "down"], maximumUTF8Bytes: 4),
            "amount": .integer(1...2_000),
        ]),
        .openURL: schema(required: ["url"], fields: [
            "url": .string(minimumUTF8Bytes: 1, maximumUTF8Bytes: 4_096),
        ]),
        .back: empty(),
        .forward: empty(),
        .reload: empty(),
        .fillSelector: schema(required: ["ref", "value"], fields: [
            "ref": .opaqueReference,
            "value": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 16_384),
        ]),
        .clickSelector: schema(required: ["ref"], fields: ["ref": .opaqueReference]),
        .selectOption: schema(required: ["ref", "value"], fields: [
            "ref": .opaqueReference,
            "value": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 4_096),
        ]),
        .submitForm: schema(required: ["ref"], fields: ["ref": .opaqueReference]),
        .exportMarkdown: schema(required: ["body"], fields: [
            "title": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 256),
            "body": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 60_000),
        ]),
        .exportJSON: schema(required: ["json"], fields: [
            "title": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 256),
            "json": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 60_000),
        ]),
        .exportCSV: schema(required: ["rows"], fields: [
            "title": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 256),
            "rows": .string(minimumUTF8Bytes: 0, maximumUTF8Bytes: 60_000),
        ]),
    ]

    static func validate(
        _ call: ToolCall,
        pageIdentity: SnapshotIdentity?,
        resolveReference: (String, SnapshotIdentity) -> StableElementReference?
    ) -> Result<ValidatedToolCall, ToolDispatchError> {
        guard case .object(var fields) = call.arguments else { return .failure(.argumentsMustBeObject) }
        guard let schema = schemas[call.tool] else { return .failure(.unknownField("tool")) }

        for key in fields.keys.sorted() where schema.fields[key] == nil {
            return .failure(.unknownField(key))
        }
        for key in schema.required.sorted() where fields[key] == nil {
            return .failure(.missingField(key))
        }
        for key in fields.keys.sorted() {
            guard let value = fields[key], let rule = schema.fields[key] else { return .failure(.unknownField(key)) }
            if let error = validate(value, key: key, rule: rule) { return .failure(error) }
        }

        // Resolve navigation text exactly once. The canonical effective target replaces
        // the raw input before hashing, previewing, approval, and dispatch.
        var effectiveTarget: CanonicalPageTarget?
        if call.tool == .openURL {
            guard let raw = fields["url"]?.stringValue,
                  let target = try? CanonicalPageTarget.resolveNavigationInput(raw) else {
                return .failure(.invalidURL)
            }
            effectiveTarget = target
            fields["url"] = .string(target.serializedURL)
        }

        let descriptor = ToolRegistry.descriptor(for: call.tool)
        if descriptor.isPageBound && pageIdentity == nil { return .failure(.pageUnavailable) }

        var targetReference: StableElementReference?
        if Self.isElementMutation(call.tool) {
            guard let identity = pageIdentity,
                  let ref = fields["ref"]?.stringValue,
                  let target = resolveReference(ref, identity),
                  target.isBound(to: identity),
                  target.fingerprint == target.metadata.fingerprint,
                  target.metadata.isVisible,
                  target.metadata.sensitiveDataClass == "none" else {
                return .failure(.staleReference)
            }
            targetReference = target
        }

        guard let canonical = try? canonicalJSON(.object(fields)),
              canonical.count <= descriptor.budget.maximumArgumentBytes else {
            return .failure(.argumentBytes)
        }
        return .success(ValidatedToolCall(
            id: call.id,
            tool: call.tool,
            arguments: fields,
            canonicalArguments: canonical,
            canonicalArgumentDigest: SHA256Digest.hex(canonical),
            effectiveTarget: effectiveTarget,
            pageIdentity: descriptor.isPageBound ? pageIdentity : nil,
            target: targetReference
        ))
    }

    /// Device-generated effect summaries only. Never serialize generic arguments here.
    static func safePreview(_ call: ValidatedToolCall) -> String {
        switch call.tool {
        case .snapshotPage: return "Capture sanitized page snapshot"
        case .extractText: return "Extract sanitized page text"
        case .extractLinks: return "Extract sanitized page links"
        case .extractForms: return "Extract sanitized page forms"
        case .extractTables: return "Extract sanitized page tables"
        case .saveMemoryNote:
            return "Save redacted note (\(characterCount(call.arguments["body"]?.stringValue)) characters)"
        case .readMemoryNotes: return "Read recent local notes"
        case .scroll:
            let direction = call.arguments["direction"]?.stringValue == "up" ? "up" : "down"
            return "Scroll \(direction) \(call.arguments["amount"]?.integerValue ?? 0) points"
        case .openURL:
            return "Open " + safePreviewText(call.effectiveTarget?.redactedDisplayHostAndPath ?? "validated-host/", maximumBytes: 1_024)
        case .back: return "Navigate back"
        case .forward: return "Navigate forward"
        case .reload: return "Reload current page"
        case .fillSelector:
            return "Fill \(targetDescription(call.target)) (\(characterCount(call.arguments["value"]?.stringValue)) characters)"
        case .clickSelector: return "Click \(targetDescription(call.target))"
        case .selectOption: return "Select option in \(targetDescription(call.target))"
        case .submitForm: return "Submit \(targetDescription(call.target))"
        case .exportMarkdown:
            return "Export redacted Markdown (\(characterCount(call.arguments["body"]?.stringValue)) characters)"
        case .exportJSON:
            return "Export redacted JSON (\(characterCount(call.arguments["json"]?.stringValue)) characters)"
        case .exportCSV:
            return "Export redacted CSV (\(characterCount(call.arguments["rows"]?.stringValue)) characters)"
        }
    }

    static func canonicalJSON(_ value: JSONValue) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func validate(_ value: JSONValue, key: String, rule: ArgumentRule) -> ToolDispatchError? {
        switch rule {
        case .string(let minimum, let maximum):
            guard let string = value.stringValue else { return .wrongType(key) }
            guard string.utf8.count >= minimum && string.utf8.count <= maximum else { return .outOfBounds(key) }
        case .integer(let range):
            guard let integer = value.integerValue else { return .wrongType(key) }
            guard range.contains(integer) else { return .outOfBounds(key) }
        case .enumeration(let values, let maximum):
            guard let string = value.stringValue else { return .wrongType(key) }
            guard string.utf8.count <= maximum && values.contains(string) else { return .outOfBounds(key) }
        case .opaqueReference:
            guard let string = value.stringValue else { return .wrongType(key) }
            guard StableElementReference.isValidOpaqueRef(string) else { return .outOfBounds(key) }
        }
        return nil
    }

    private static func isElementMutation(_ tool: ToolName) -> Bool {
        switch tool {
        case .fillSelector, .clickSelector, .selectOption, .submitForm: return true
        default: return false
        }
    }

    private static func targetDescription(_ target: StableElementReference?) -> String {
        guard let metadata = target?.metadata else { return "validated element" }
        let rawLabel = metadata.accessibleLabel.isEmpty ? (metadata.name.isEmpty ? metadata.tag : metadata.name) : metadata.accessibleLabel
        let label = safePreviewText(rawLabel, maximumBytes: 80)
        let kind = safePreviewText(metadata.role.isEmpty ? metadata.tag : metadata.role, maximumBytes: 32)
        return (label.isEmpty ? "validated" : label) + " " + (kind.isEmpty ? "element" : kind)
    }

    private static func safePreviewText(_ raw: String, maximumBytes: Int) -> String {
        let cleanedScalars = raw.unicodeScalars.filter {
            !$0.properties.isControl && !$0.properties.isWhitespace || $0 == " "
        }
        let cleaned = String(String.UnicodeScalarView(cleanedScalars))
        guard cleaned.utf8.count > maximumBytes else { return cleaned }
        var result = ""
        for character in cleaned {
            let next = String(character)
            guard result.utf8.count + next.utf8.count <= maximumBytes else { break }
            result.append(character)
        }
        return result
    }

    private static func characterCount(_ value: String?) -> Int { value?.count ?? 0 }
    private static func empty() -> ClosedToolSchema { schema(required: [], fields: [:]) }
    private static func schema(required: Set<String>, fields: [String: ArgumentRule]) -> ClosedToolSchema {
        ClosedToolSchema(required: required, fields: fields)
    }
}
