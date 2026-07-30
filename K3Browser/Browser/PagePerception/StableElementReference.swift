import Foundation
import CryptoKit

/// Public/model-safe target metadata. It contains no executable locator and no form value.
struct StableElementMetadata: Codable, Equatable, Hashable {
    let tag: String
    let type: String
    let role: String
    let name: String
    let accessibleLabel: String
    let textDigest: String
    let isVisible: Bool
    let sensitiveDataClass: String
    let formMethod: String
    let formAction: String

    // Required for synchronous live comparison. Explicit CodingKeys keep raw text
    // out of every encoded/model-facing representation.
    private let normalizedExpectedText: String
    private let executableBinding: Bool

    private enum CodingKeys: String, CodingKey {
        case tag, type, role, name, accessibleLabel, textDigest, isVisible
        case sensitiveDataClass, formMethod, formAction
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tag = try values.decode(String.self, forKey: .tag)
        type = try values.decode(String.self, forKey: .type)
        role = try values.decode(String.self, forKey: .role)
        name = try values.decode(String.self, forKey: .name)
        accessibleLabel = try values.decode(String.self, forKey: .accessibleLabel)
        textDigest = try values.decode(String.self, forKey: .textDigest)
        isVisible = try values.decode(Bool.self, forKey: .isVisible)
        sensitiveDataClass = try values.decode(String.self, forKey: .sensitiveDataClass)
        formMethod = try values.decode(String.self, forKey: .formMethod)
        formAction = try values.decode(String.self, forKey: .formAction)
        // Decoded metadata is evidence only and can never create executable authority.
        normalizedExpectedText = ""
        executableBinding = false
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(tag, forKey: .tag)
        try values.encode(type, forKey: .type)
        try values.encode(role, forKey: .role)
        try values.encode(name, forKey: .name)
        try values.encode(accessibleLabel, forKey: .accessibleLabel)
        try values.encode(textDigest, forKey: .textDigest)
        try values.encode(isVisible, forKey: .isVisible)
        try values.encode(sensitiveDataClass, forKey: .sensitiveDataClass)
        try values.encode(formMethod, forKey: .formMethod)
        try values.encode(formAction, forKey: .formAction)
    }

    var canonicalFingerprintPayload: String {
        [
            tag, type, role, name, accessibleLabel, textDigest,
            isVisible ? "visible" : "hidden", sensitiveDataClass, formMethod, formAction,
        ].joined(separator: "\u{1f}")
    }

    var fingerprint: String { SHA256Digest.hex(Data(canonicalFingerprintPayload.utf8)) }

    static func classify(
        tag: String,
        type: String,
        role: String,
        name: String,
        label: String,
        text: String,
        placeholder: String,
        autocomplete: String,
        visible: Bool,
        formMethod: String,
        formAction: String
    ) -> StableElementMetadata {
        // Match JavaScript String.prototype.slice(0, 160), including replacement
        // of a trailing unmatched UTF-16 surrogate before UTF-8 normalization.
        let boundedText = String(decoding: text.utf16.prefix(160), as: UTF16.self)
        let normalizedText = normalize(boundedText, maximumBytes: 2_048)
        let normalizedType = asciiLowercase(normalize(type, maximumBytes: 64))
        let normalizedRole = asciiLowercase(normalize(role, maximumBytes: 128))
        let normalizedName = normalize(name, maximumBytes: 256)
        let normalizedLabel = normalize(label, maximumBytes: 512)
        let normalizedPlaceholder = asciiLowercase(normalize(placeholder, maximumBytes: 512))
        let normalizedAutocomplete = asciiLowercase(normalize(autocomplete, maximumBytes: 256))
        let classificationInput = [
            normalizedType, normalizedRole, asciiLowercase(normalizedName),
            asciiLowercase(normalizedLabel), normalizedPlaceholder, normalizedAutocomplete,
        ].joined(separator: " ")
        return StableElementMetadata(
            tag: asciiLowercase(normalize(tag, maximumBytes: 64)),
            type: normalizedType,
            role: normalizedRole,
            name: normalizedName,
            accessibleLabel: normalizedLabel,
            textDigest: SHA256Digest.hex(Data(normalizedText.utf8)),
            isVisible: visible,
            sensitiveDataClass: classifySensitive(haystack: classificationInput, autocomplete: normalizedAutocomplete),
            formMethod: asciiLowercase(normalize(formMethod, maximumBytes: 16)),
            formAction: normalize(formAction, maximumBytes: 4_096),
            normalizedExpectedText: normalizedText,
            executableBinding: true
        )
    }

    fileprivate var synchronousExpectedText: String { normalizedExpectedText }
    fileprivate var hasExecutableBinding: Bool { executableBinding }

    fileprivate static func normalize(_ raw: String, maximumBytes: Int) -> String {
        var collapsed = ""
        var pendingSpace = false
        for scalar in raw.unicodeScalars {
            if isECMAScriptWhitespace(scalar.value) {
                pendingSpace = !collapsed.isEmpty
            } else {
                if pendingSpace { collapsed.append(" ") }
                collapsed.unicodeScalars.append(scalar)
                pendingSpace = false
            }
        }
        return utf8Prefix(collapsed, maximumBytes: maximumBytes)
    }

    fileprivate static func classifySensitive(haystack: String, autocomplete: String) -> String {
        let foldedHaystack = asciiLowercase(haystack)
        let foldedAutocomplete = asciiLowercase(autocomplete)
        let autocompleteTokens = Set(foldedAutocomplete.split(separator: " ").map(String.init))
        let credentialAutocomplete: Set<String> = [
            "current-password", "new-password", "one-time-code", "webauthn",
        ]
        let paymentAutocomplete: Set<String> = [
            "cc-name", "cc-given-name", "cc-additional-name", "cc-family-name",
            "cc-number", "cc-exp", "cc-exp-month", "cc-exp-year", "cc-csc", "cc-type",
            "transaction-amount", "transaction-currency",
        ]
        if !credentialAutocomplete.isDisjoint(with: autocompleteTokens) { return "credential" }
        if !paymentAutocomplete.isDisjoint(with: autocompleteTokens) { return "payment" }

        let words = Set(wordTokens(foldedHaystack))
        let credentialWords: Set<String> = [
            "credential", "credentials", "password", "passwd", "passcode", "otp", "2fa", "totp", "recovery", "pin",
        ]
        let paymentWords: Set<String> = [
            "payment", "card", "creditcard", "cvv", "cvc", "csc", "pan",
        ]
        let keyWords: Set<String> = [
            "apikey", "api-key", "session", "cookie", "privatekey", "private-key",
            "mnemonic", "seed", "secretkey", "signing", "wallet", "walletseed",
        ]
        let compact = foldedHaystack.unicodeScalars.reduce(into: "") { result, scalar in
            if isASCIIAlphanumeric(scalar.value) { result.unicodeScalars.append(scalar) }
        }
        if !credentialWords.isDisjoint(with: words) || ["onetimecode", "recoverycode"].contains(where: compact.contains) {
            return "credential"
        }
        if !paymentWords.isDisjoint(with: words) || ["cardnumber", "creditcard", "securitycode"].contains(where: compact.contains) {
            return "payment"
        }
        if !keyWords.isDisjoint(with: words) || [
            "apikey", "sessiontoken", "sessionid", "privatekey", "secretkey", "walletseed", "seedphrase", "signingkey",
        ].contains(where: compact.contains) {
            return "keyMaterial"
        }
        return "none"
    }

    private static func utf8Prefix(_ value: String, maximumBytes: Int) -> String {
        guard maximumBytes > 0, value.utf8.count > maximumBytes else { return maximumBytes > 0 ? value : "" }
        var output = ""
        output.reserveCapacity(maximumBytes)
        var byteCount = 0
        for scalar in value.unicodeScalars {
            let width = String(scalar).utf8.count
            guard byteCount + width <= maximumBytes else { break }
            output.unicodeScalars.append(scalar)
            byteCount += width
        }
        return output
    }

    private static func asciiLowercase(_ value: String) -> String {
        var result = ""
        for scalar in value.unicodeScalars {
            result.unicodeScalars.append(
                (65...90).contains(scalar.value) ? Unicode.Scalar(scalar.value + 32)! : scalar
            )
        }
        return result
    }

    private static func wordTokens(_ value: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        for scalar in value.unicodeScalars {
            if isASCIIAlphanumeric(scalar.value) {
                current.unicodeScalars.append(scalar)
            } else if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    private static func isECMAScriptWhitespace(_ value: UInt32) -> Bool {
        switch value {
        case 0x0009...0x000D, 0x0020, 0x00A0, 0x1680, 0x2000...0x200A,
             0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
            return true
        default:
            return false
        }
    }

    private static func isASCIIAlphanumeric(_ value: UInt32) -> Bool {
        (48...57).contains(value) || (97...122).contains(value)
    }

    private init(
        tag: String,
        type: String,
        role: String,
        name: String,
        accessibleLabel: String,
        textDigest: String,
        isVisible: Bool,
        sensitiveDataClass: String,
        formMethod: String,
        formAction: String,
        normalizedExpectedText: String,
        executableBinding: Bool
    ) {
        self.tag = tag
        self.type = type
        self.role = role
        self.name = name
        self.accessibleLabel = accessibleLabel
        self.textDigest = textDigest
        self.isVisible = isVisible
        self.sensitiveDataClass = sensitiveDataClass
        self.formMethod = formMethod
        self.formAction = formAction
        self.normalizedExpectedText = normalizedExpectedText
        self.executableBinding = executableBinding
    }
}

/// Device-created opaque authority binding. It is deliberately not Codable.
struct StableElementReference: Equatable {
    let ref: String
    private let privateSelector: String
    let snapshotID: UUID
    let pageGeneration: UInt64
    let origin: String
    let metadata: StableElementMetadata
    let fingerprint: String
    private let snapshotMarker: String
    private let canonicalPageURL: String
    private let pageBindingExecutable: Bool
    private let normalizedExpectedText: String

    fileprivate var hasExecutablePrivateBinding: Bool {
        let selectorBytes = privateSelector.utf8.count
        return selectorBytes > 0 && selectorBytes <= 4_096 &&
            metadata.hasExecutableBinding &&
            pageBindingExecutable &&
            normalizedExpectedText == metadata.synchronousExpectedText &&
            fingerprint == metadata.fingerprint &&
            fingerprint.utf8.count == 64 &&
            fingerprint.unicodeScalars.allSatisfy { scalar in
                (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
            }
    }

    /// Read-only issuance gate used by snapshot decoding. A reference is only
    /// model-visible when the private map would accept the exact same binding.
    var isExecutableBinding: Bool {
        StableElementReference.isValidOpaqueRef(ref) &&
            hasExecutablePrivateBinding &&
            metadata.isVisible &&
            metadata.sensitiveDataClass == "none"
    }

    init(
        ref: String? = nil,
        privateSelector: String,
        snapshotMarker: String,
        pageURL: String,
        identity: SnapshotIdentity,
        metadata: StableElementMetadata
    ) {
        let supplied = ref ?? ""
        self.ref = Self.isValidOpaqueRef(supplied) ? supplied : Self.makeOpaqueRef()
        self.privateSelector = privateSelector
        self.snapshotID = identity.snapshotID
        self.pageGeneration = identity.pageGeneration
        self.origin = identity.origin
        self.metadata = metadata
        self.fingerprint = metadata.fingerprint
        let expectedMarker = identity.snapshotID.uuidString.lowercased()
        let canonicalTarget = try? CanonicalPageTarget(validating: pageURL)
        self.snapshotMarker = snapshotMarker
        self.canonicalPageURL = canonicalTarget?.serializedURL ?? ""
        self.pageBindingExecutable = Self.isValidSnapshotMarker(snapshotMarker) &&
            snapshotMarker == expectedMarker &&
            canonicalTarget?.origin == identity.origin
        self.normalizedExpectedText = metadata.synchronousExpectedText
    }

    func isBound(to identity: SnapshotIdentity) -> Bool {
        snapshotID == identity.snapshotID && pageGeneration == identity.pageGeneration && origin == identity.origin
    }

    static func makeOpaqueRef(id: UUID = UUID()) -> String {
        "element_" + id.uuidString.lowercased()
    }

    static func isValidOpaqueRef(_ value: String) -> Bool {
        guard value.utf8.count == 44, value.hasPrefix("element_") else { return false }
        let uuid = String(value.dropFirst(8))
        guard uuid.count == 36 else { return false }
        for (index, character) in uuid.enumerated() {
            if [8, 13, 18, 23].contains(index) {
                guard character == "-" else { return false }
            } else {
                guard character.isNumber || (character >= "a" && character <= "f") else { return false }
            }
        }
        return UUID(uuidString: uuid) != nil
    }

    private static func isValidSnapshotMarker(_ value: String) -> Bool {
        guard value.count == 36, value == value.lowercased() else { return false }
        for (index, character) in value.enumerated() {
            if [8, 13, 18, 23].contains(index) {
                guard character == "-" else { return false }
            } else {
                guard character.isNumber || (character >= "a" && character <= "f") else { return false }
            }
        }
        return UUID(uuidString: value) != nil
    }

    /// The only bridge that releases private binding material, directly to the
    /// atomic WebKit executor's argument dictionary.
    func atomicExecutorArguments(operation: String, value: String?) -> [String: Any] {
        let expected: [String: Any] = [
            "tag": metadata.tag,
            "type": metadata.type,
            "role": metadata.role,
            "name": metadata.name,
            "label": metadata.accessibleLabel,
            "textDigest": metadata.textDigest,
            "visible": metadata.isVisible,
            "sensitiveClass": metadata.sensitiveDataClass,
            "formMethod": metadata.formMethod,
            "formAction": metadata.formAction,
            "fingerprint": fingerprint,
            "normalizedText": normalizedExpectedText,
            "bindingExecutable": hasExecutablePrivateBinding,
        ]
        return [
            "privateSelector": privateSelector,
            "expected": expected,
            "operation": operation,
            "operationValue": value ?? "",
            "hasOperationValue": value != nil,
            "boundOrigin": origin,
            "snapshotMarker": snapshotMarker,
            "boundPageURL": canonicalPageURL,
        ]
    }
}

struct PrivateTargetResolution {
    let reference: StableElementReference
}

final class PrivateElementReferenceMap {
    private var storage: [String: StableElementReference] = [:]

    func replace(with references: [StableElementReference], identity: SnapshotIdentity) {
        var replacement: [String: StableElementReference] = [:]
        for reference in references where reference.isBound(to: identity) && Self.validForStorage(reference) {
            guard replacement[reference.ref] == nil else {
                storage.removeAll(keepingCapacity: false)
                return
            }
            replacement[reference.ref] = reference
        }
        storage = replacement
    }

    func invalidate() { storage.removeAll(keepingCapacity: false) }

    func resolve(ref: String, identity: SnapshotIdentity) -> PrivateTargetResolution? {
        guard StableElementReference.isValidOpaqueRef(ref),
              let reference = storage[ref],
              reference.isBound(to: identity),
              Self.validForStorage(reference) else { return nil }
        return PrivateTargetResolution(reference: reference)
    }

    private static func validForStorage(_ reference: StableElementReference) -> Bool {
        reference.isExecutableBinding
    }
}

enum SHA256Digest {
    static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
