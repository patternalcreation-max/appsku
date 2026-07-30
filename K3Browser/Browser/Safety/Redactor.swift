import Foundation

enum Redactor {
    private static let sensitiveFragments = [
        "password", "passcode", "passwd", "secret", "token", "api_key", "apikey",
        "authorization", "cookie", "session", "otp", "2fa", "cvv", "cvc",
        "cardnumber", "card_number", "privatekey", "private_key", "mnemonic", "seed"
    ]

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
