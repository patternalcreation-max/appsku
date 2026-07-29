import Foundation

enum EngagementScopeMatcher {
    static func match(url: URL, profile: EngagementProfile, now: Date = Date()) -> EngagementStatus {
        do {
            try profile.validate(now: now)
        } catch {
            return .invalid("Engagement profile is invalid or inactive")
        }
        guard profile.outOfScopeAssets.allSatisfy({ $0.isWellFormed }),
              profile.inScopeAssets.allSatisfy({ $0.isWellFormed }) else {
            return .invalid("A scope asset is malformed or unsupported")
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let rawHost = components.host?.lowercased(),
              !rawHost.isEmpty,
              rawHost.unicodeScalars.allSatisfy({ $0.isASCII }),
              components.user == nil,
              components.password == nil,
              isDefaultPort(components.port, for: scheme),
              let canonicalPath = EngagementPathCanonicalizer.candidatePath(components.percentEncodedPath) else {
            return .invalid("URL has an unsupported or ambiguous HTTP(S) target")
        }

        // Deny first: an out-of-scope rule always overrides an allow rule.
        if let denied = profile.outOfScopeAssets.first(where: { $0.matches(scheme: scheme, host: rawHost, canonicalPath: canonicalPath) }) {
            return EngagementStatus(disposition: .outOfScope, reason: "URL matched an explicit out-of-scope asset", matchedAsset: denied)
        }
        if let allowed = profile.inScopeAssets.first(where: { $0.matches(scheme: scheme, host: rawHost, canonicalPath: canonicalPath) }) {
            return EngagementStatus(disposition: .inScope, reason: "URL matched an in-scope asset", matchedAsset: allowed)
        }
        return .neutral("URL did not match a declared scope asset")
    }

    private static func isDefaultPort(_ port: Int?, for scheme: String) -> Bool {
        guard let port = port else { return true }
        return (scheme == "http" && port == 80) || (scheme == "https" && port == 443)
    }
}

enum EngagementPathCanonicalizer {
    struct RulePath: Equatable {
        let value: String
        let isPrefix: Bool
    }

    static func rulePath(_ raw: String) -> RulePath? {
        guard raw.hasPrefix("/"),
              raw.filter({ $0 == "*" }).count <= 1,
              !raw.contains("*") || raw.hasSuffix("*") else { return nil }
        let isPrefix = raw.hasSuffix("*")
        let pathOnly = isPrefix ? String(raw.dropLast()) : raw
        guard let value = normalize(pathOnly) else { return nil }
        return RulePath(value: value, isPrefix: isPrefix)
    }

    static func candidatePath(_ percentEncodedPath: String) -> String? {
        normalize(percentEncodedPath.isEmpty ? "/" : percentEncodedPath)
    }

    private static func normalize(_ raw: String) -> String? {
        guard raw.hasPrefix("/"), raw.utf8.count <= EngagementProfile.maximumPathBytes else { return nil }

        let bytes = Array(raw.utf8)
        var index = 0
        while index < bytes.count {
            if bytes[index] == 0x25 { // "%"
                guard index + 2 < bytes.count,
                      let high = hexValue(bytes[index + 1]),
                      let low = hexValue(bytes[index + 2]) else { return nil }
                let decoded = (high << 4) | low
                // Encoded separators and encoded percent are routing/double-decode ambiguities.
                guard decoded != 0x2F, decoded != 0x5C, decoded != 0x25, decoded != 0x00 else { return nil }
                index += 3
            } else {
                guard bytes[index] != 0x5C else { return nil }
                index += 1
            }
        }

        guard let decoded = raw.removingPercentEncoding?.precomposedStringWithCanonicalMapping,
              decoded.hasPrefix("/"),
              !decoded.contains("\\"),
              !decoded.contains("*"),
              !decoded.contains("//"),
              decoded.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }

        let segments = decoded.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.first?.isEmpty == true else { return nil }
        let hasTrailingSlash = decoded.count > 1 && decoded.hasSuffix("/")
        var stack: [Substring] = []

        for (offset, segment) in segments.dropFirst().enumerated() {
            let isLast = offset == segments.count - 2
            if segment.isEmpty {
                guard isLast && hasTrailingSlash else {
                    if decoded == "/" && isLast { continue }
                    return nil
                }
                continue
            }
            if segment == "." { continue }
            if segment == ".." {
                guard !stack.isEmpty else { return nil }
                stack.removeLast()
                continue
            }
            stack.append(segment)
        }

        var result = "/" + stack.joined(separator: "/")
        if hasTrailingSlash && result != "/" { result += "/" }
        return result
    }

    private static func hexValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: return byte - 48
        case 65...70: return byte - 55
        case 97...102: return byte - 87
        default: return nil
        }
    }
}

extension EngagementAsset {
    var isWellFormed: Bool {
        let normalized = domain.lowercased()
        let base = normalized.hasPrefix("*.") ? String(normalized.dropFirst(2)) : normalized
        guard !base.isEmpty,
              base.utf8.count <= 253,
              !base.contains(":"),
              !base.contains("/"),
              base.unicodeScalars.allSatisfy({ $0.isASCII }),
              EngagementPathCanonicalizer.rulePath(path) != nil else {
            return false
        }
        let labels = base.split(separator: ".", omittingEmptySubsequences: false)
        return labels.allSatisfy { label in
            guard !label.isEmpty, label.count <= 63,
                  label.first != "-", label.last != "-" else { return false }
            return label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
    }

    fileprivate func matches(scheme candidateScheme: String, host: String, canonicalPath: String) -> Bool {
        let schemeMatches = scheme == .any || scheme.rawValue == candidateScheme
        guard schemeMatches else { return false }

        let normalized = domain.lowercased()
        let hostMatches: Bool
        if normalized.hasPrefix("*.") {
            let base = String(normalized.dropFirst(2))
            hostMatches = host.hasSuffix("." + base) && host != base
        } else {
            hostMatches = host == normalized
        }
        guard hostMatches, let rule = EngagementPathCanonicalizer.rulePath(path) else { return false }

        return rule.isPrefix ? canonicalPath.hasPrefix(rule.value) : canonicalPath == rule.value
    }
}
