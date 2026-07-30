import Foundation
import Darwin

/// The authority representation of an effective HTTP(S) navigation target.
/// Display redaction must never be used to construct or compare this value.
struct CanonicalPageTarget: Codable, Equatable, Hashable {
    let url: URL
    let serializedURL: String
    let origin: String

    enum TargetError: Error, Equatable {
        case invalid
        case unsupportedScheme
        case userInfo
        case ambiguousHost
        case nonDefaultPort
    }

    init(validating raw: String) throws {
        guard !raw.isEmpty,
              raw.utf8.count <= 4_096,
              raw.unicodeScalars.allSatisfy({ !$0.properties.isWhitespace && $0.properties.generalCategory != .control }),
              !raw.contains("\\"),
              let parsed = URL(string: raw) else {
            throw TargetError.invalid
        }
        try self.init(validating: parsed)
    }

    init(validating candidate: URL) throws {
        let absolute = candidate.absoluteString
        guard !absolute.isEmpty,
              absolute.utf8.count <= 4_096,
              absolute.unicodeScalars.allSatisfy({ !$0.properties.isWhitespace && $0.properties.generalCategory != .control }),
              !absolute.contains("\\"),
              var components = URLComponents(url: candidate, resolvingAgainstBaseURL: false),
              let rawScheme = components.scheme else {
            throw TargetError.invalid
        }

        let scheme = rawScheme.lowercased()
        guard scheme == "http" || scheme == "https" else { throw TargetError.unsupportedScheme }
        guard components.user == nil, components.password == nil else { throw TargetError.userInfo }

        // Inspect the serialized authority as well as URLComponents. This prevents
        // Foundation from silently normalizing percent-escaped, Unicode, or empty hosts.
        guard let authority = Self.serializedAuthority(in: absolute, scheme: rawScheme),
              !authority.isEmpty,
              !authority.contains("@"),
              !authority.contains("%"),
              authority.unicodeScalars.allSatisfy({ $0.isASCII && !$0.properties.isWhitespace && $0.properties.generalCategory != .control }) else {
            throw TargetError.ambiguousHost
        }

        let authorityHost = try Self.hostPart(from: authority)
        guard let componentHost = components.host,
              !componentHost.isEmpty,
              componentHost.unicodeScalars.allSatisfy(\.isASCII),
              componentHost.caseInsensitiveCompare(authorityHost) == .orderedSame,
              Self.isUnambiguousHost(componentHost) else {
            throw TargetError.ambiguousHost
        }

        if let port = components.port {
            let defaultPort = scheme == "https" ? 443 : 80
            guard port == defaultPort else { throw TargetError.nonDefaultPort }
            components.port = nil
        }

        let host = componentHost.lowercased()
        components.scheme = scheme
        components.host = host
        guard let canonicalURL = components.url,
              canonicalURL.scheme == scheme,
              canonicalURL.host == host,
              canonicalURL.user == nil,
              canonicalURL.password == nil else {
            throw TargetError.invalid
        }

        let serialized = canonicalURL.absoluteString
        guard !serialized.contains("\\"), serialized.utf8.count <= 4_096 else { throw TargetError.invalid }
        let originHost = host.contains(":") ? "[\(host)]" : host
        self.url = canonicalURL
        self.serializedURL = serialized
        self.origin = "\(scheme)://\(originHost)"
    }

    /// Resolves user navigation text once and returns the effective authority object.
    /// Callers must retain this result rather than re-resolving the original input.
    static func resolveNavigationInput(_ raw: String) throws -> CanonicalPageTarget {
        guard !raw.isEmpty,
              raw.utf8.count <= 4_096,
              raw.unicodeScalars.allSatisfy({ $0.properties.generalCategory != .control }) else {
            throw TargetError.invalid
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed == raw else { throw TargetError.invalid }

        let lower = trimmed.lowercased()
        let effective: String
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            effective = trimmed
        } else if trimmed.unicodeScalars.contains(where: { $0.properties.isWhitespace }) || (!trimmed.contains(".") && !trimmed.hasPrefix("[")) {
            var search = URLComponents()
            search.scheme = "https"
            search.host = "duckduckgo.com"
            search.path = "/"
            search.queryItems = [URLQueryItem(name: "q", value: trimmed)]
            guard let built = search.url?.absoluteString else { throw TargetError.invalid }
            effective = built
        } else {
            effective = "https://\(trimmed)"
        }
        return try CanonicalPageTarget(validating: effective)
    }

    /// Host + path only. This is presentation data, never authority data.
    var redactedDisplayHostAndPath: String {
        let path = url.path.isEmpty ? "/" : url.path
        return String((url.host ?? "validated-host") + path)
    }

    private static func serializedAuthority(in absolute: String, scheme: String) -> String? {
        let prefix = scheme + "://"
        guard absolute.count >= prefix.count,
              absolute.prefix(prefix.count).caseInsensitiveCompare(prefix) == .orderedSame else { return nil }
        let remainder = absolute.dropFirst(prefix.count)
        return String(remainder.prefix { $0 != "/" && $0 != "?" && $0 != "#" })
    }

    private static func hostPart(from authority: String) throws -> String {
        if authority.hasPrefix("[") {
            guard let close = authority.firstIndex(of: "]") else { throw TargetError.ambiguousHost }
            let host = String(authority[authority.index(after: authority.startIndex)..<close])
            let suffix = authority[authority.index(after: close)...]
            guard suffix.isEmpty || (suffix.first == ":" && suffix.dropFirst().allSatisfy(\.isNumber) && !suffix.dropFirst().isEmpty) else {
                throw TargetError.ambiguousHost
            }
            return host
        }
        let pieces = authority.split(separator: ":", omittingEmptySubsequences: false)
        guard pieces.count <= 2,
              let host = pieces.first,
              !host.isEmpty,
              pieces.count == 1 || (!pieces[1].isEmpty && pieces[1].allSatisfy(\.isNumber)) else {
            throw TargetError.ambiguousHost
        }
        return String(host)
    }

    private static func isUnambiguousHost(_ host: String) -> Bool {
        if host.contains(":") {
            var address = in6_addr()
            return host.withCString { inet_pton(AF_INET6, $0, &address) } == 1
        }
        guard !host.hasPrefix("."), !host.hasSuffix("."), host.utf8.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.isEmpty else { return false }
        return labels.allSatisfy { label in
            guard !label.isEmpty,
                  label.utf8.count <= 63,
                  label.first != "-",
                  label.last != "-" else { return false }
            return label.unicodeScalars.allSatisfy { scalar in
                scalar.isASCII && ((scalar.value >= 65 && scalar.value <= 90) ||
                    (scalar.value >= 97 && scalar.value <= 122) ||
                    (scalar.value >= 48 && scalar.value <= 57) || scalar.value == 45)
            }
        }
    }
}
