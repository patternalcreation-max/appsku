import Foundation

enum Redactor {
    private static let sensitiveFragments = [
        "password", "passcode", "passwd", "secret", "token", "api_key", "apikey",
        "authorization", "cookie", "session", "otp", "2fa", "cvv", "cvc",
        "cardnumber", "card_number", "privatekey", "private_key", "mnemonic", "seed"
    ]

    static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased().replacingOccurrences(of: "-", with: "_")
        if normalized == "value" || normalized == "body" { return true }
        return sensitiveFragments.contains { normalized.contains($0) }
    }

    static func redact(value: String, forKey key: String) -> String {
        isSensitiveKey(key) && !value.isEmpty ? "[REDACTED]" : sanitizeURLString(value)
    }

    static func redactedArguments(_ arguments: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: arguments.map { key, value in
            (key, redact(value: value, forKey: key))
        })
    }

    static func preview(tool: String, arguments: [String: String]) -> String {
        if tool.hasPrefix("export_") {
            let content = arguments["body"] ?? arguments["json"] ?? arguments["rows"] ?? ""
            let safeContent = exportBody(content)
            let excerpt = String(safeContent.prefix(160)).replacingOccurrences(of: "\n", with: " ↵ ")
            let title = arguments["title"].map { redact(value: $0, forKey: "title") } ?? ""
            let suffix = safeContent.count > 160 ? "…" : ""
            return "\(tool) title=\(title), content=\(excerpt)\(suffix) [\(safeContent.count) chars]"
        }
        let fields = redactedArguments(arguments)
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
        return fields.isEmpty ? tool : "\(tool) \(fields)"
    }

    static func exportBody(_ raw: String) -> String {
        text(raw)
    }

    static func sanitizeURLString(_ raw: String) -> String {
        guard var components = URLComponents(string: raw), components.scheme != nil else { return raw }
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        return components.string ?? raw
    }

    static func text(_ raw: String) -> String {
        var output = raw
        let authorizationPattern = "(?i)(authorization\\s*[:=]\\s*)[^\\r\\n,;&]+"
        if let regex = try? NSRegularExpression(pattern: authorizationPattern) {
            let range = NSRange(output.startIndex..., in: output)
            output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: "$1[REDACTED]")
        }
        let bearerPattern = "(?i)bearer\\s+[^\\s,;&]+"
        if let regex = try? NSRegularExpression(pattern: bearerPattern) {
            let range = NSRange(output.startIndex..., in: output)
            output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: "Bearer [REDACTED]")
        }
        let keyPattern = "(?i)(password|passcode|secret|token|api[_-]?key|cookie|otp|cvv|private[_-]?key)\\s*([:=])\\s*([^\\s,;&]+)"
        if let regex = try? NSRegularExpression(pattern: keyPattern) {
            let range = NSRange(output.startIndex..., in: output)
            output = regex.stringByReplacingMatches(in: output, range: range, withTemplate: "$1$2[REDACTED]")
        }
        return output
    }
}
