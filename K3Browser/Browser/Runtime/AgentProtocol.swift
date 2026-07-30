import Foundation

enum AgentProtocol {
    static let maximumEnvelopeBytes = 65_000
    static let maximumFinalMessageBytes = 32_768

    static func parse(_ text: String, idGenerator: () -> String = { UUID().uuidString }) -> AgentParseResult {
        guard text.utf8.count <= maximumEnvelopeBytes else {
            return .failure("Model response exceeds byte limit")
        }
        guard let raw = unwrapSingleJSONFence(text),
              let data = raw.data(using: .utf8),
              data.count <= maximumEnvelopeBytes,
              let decoded = try? JSONDecoder().decode(JSONValue.self, from: data),
              case .object(let envelope) = decoded else {
            return .failure("Model did not return a JSON object")
        }
        guard let type = envelope["type"]?.stringValue else {
            return .failure("Model response type must be a string")
        }

        switch type {
        case "final":
            guard hasOnlyKeys(envelope, allowed: ["type", "message"]),
                  let message = envelope["message"]?.stringValue,
                  message.utf8.count <= maximumFinalMessageBytes else {
                return .failure("Invalid final response schema")
            }
            return .success(AgentResponse(kind: .final(message)))

        case "tool_call":
            // `reason` remains accepted for wire compatibility, but is discarded here
            // and can never influence previews, approval, or execution authority.
            guard hasOnlyKeys(envelope, allowed: ["type", "tool", "arguments", "reason"]) else {
                return .failure("Invalid tool response schema")
            }
            if let reason = envelope["reason"] {
                guard let text = reason.stringValue, text.utf8.count <= 2_048 else {
                    return .failure("Invalid model reason")
                }
            }
            guard let wireName = envelope["tool"]?.stringValue,
                  wireName.utf8.count <= 64,
                  let tool = ToolName(rawValue: wireName) else {
                let safeName = envelope["tool"]?.stringValue.map { String($0.prefix(64)) } ?? ""
                return .failure("Unknown tool: \(safeName)")
            }
            guard let arguments = envelope["arguments"], case .object = arguments else {
                return .failure("Tool arguments must be a JSON object")
            }
            let identifier = idGenerator()
            guard !identifier.isEmpty, identifier.utf8.count <= 128 else {
                return .failure("Invalid generated action identifier")
            }
            return .success(AgentResponse(kind: .tool(ToolCall(id: identifier, tool: tool, arguments: arguments))))

        default:
            return .failure("Unknown response type")
        }
    }

    private static func hasOnlyKeys(_ object: [String: JSONValue], allowed: Set<String>) -> Bool {
        Set(object.keys).isSubset(of: allowed)
    }

    private static func unwrapSingleJSONFence(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }
        guard let firstLineEnd = trimmed.firstIndex(of: "\n") else { return nil }
        let opening = String(trimmed[..<firstLineEnd]).lowercased()
        guard opening == "```" || opening == "```json" else { return nil }
        let bodyStart = trimmed.index(after: firstLineEnd)
        guard trimmed.hasSuffix("```"),
              let closingStart = trimmed.range(of: "```", options: .backwards)?.lowerBound,
              closingStart >= bodyStart else { return nil }
        let suffixAfterFence = trimmed[trimmed.index(closingStart, offsetBy: 3)...]
        guard suffixAfterFence.isEmpty else { return nil }
        return String(trimmed[bodyStart..<closingStart]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
