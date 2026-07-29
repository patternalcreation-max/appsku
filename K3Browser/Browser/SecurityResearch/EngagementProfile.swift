import Foundation
import CryptoKit

struct EngagementAsset: Codable, Equatable {
    enum Scheme: String, Codable, Equatable {
        case any
        case http
        case https
    }

    let scheme: Scheme
    let domain: String
    let path: String

    init(scheme: Scheme = .any, domain: String, path: String = "/*") {
        self.scheme = scheme
        self.domain = domain
        self.path = path
    }
}

struct EngagementTestingWindow: Codable, Equatable {
    let startsAt: Date
    let endsAt: Date
}

struct EngagementBudgets: Codable, Equatable {
    let maxRequestsPerMinute: Int
    let maxTotalRequests: Int
    let maxConcurrentRequests: Int
}

struct EngagementProfile: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let maximumProfileBytes = 1_048_576
    static let maximumPathBytes = 2_048
    static let maximumAssetsPerList = 256
    static let maximumListEntries = 128
    static let maximumMetadataBytes = 4_096

    let schemaVersion: Int
    let engagementID: UUID
    let importedAt: Date
    let platformRef: String?
    let programLabel: String
    let programType: String
    let policyDocumentHash: String
    let inScopeAssets: [EngagementAsset]
    let outOfScopeAssets: [EngagementAsset]
    let forbiddenActions: [String]
    let allowedCategories: [String]
    let testingWindow: EngagementTestingWindow?
    let budgets: EngagementBudgets
    let operatorDeclaration: String
    let declaredAt: Date
    var profileHash: String

    enum ValidationError: Error, Equatable {
        case unsupportedSchema
        case missingMetadata
        case missingDeclaration
        case missingScope
        case invalidAsset
        case invalidPolicyDocumentHash
        case profileHashMismatch
        case invalidTestingWindow
        case testingWindowNotYetActive
        case testingWindowExpired
        case invalidBudgets
        case profileTooLarge
    }

    func canonicalHash() throws -> String {
        let canonical = CanonicalProfile(profile: self)
        let digest = SHA256.hash(data: try Self.canonicalEncoder().encode(canonical))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func validate(now: Date = Date()) throws {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw ValidationError.unsupportedSchema
        }
        guard programLabel.utf8.count <= 256,
              programType.utf8.count <= 256,
              policyDocumentHash.utf8.count <= 64,
              operatorDeclaration.utf8.count <= Self.maximumMetadataBytes,
              (platformRef?.utf8.count ?? 0) <= 1_024,
              inScopeAssets.count <= Self.maximumAssetsPerList,
              outOfScopeAssets.count <= Self.maximumAssetsPerList,
              forbiddenActions.count <= Self.maximumListEntries,
              allowedCategories.count <= Self.maximumListEntries,
              forbiddenActions.allSatisfy({ $0.utf8.count <= 512 }),
              allowedCategories.allSatisfy({ $0.utf8.count <= 512 }) else {
            throw ValidationError.profileTooLarge
        }
        guard !programLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !programType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingMetadata
        }
        guard !operatorDeclaration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingDeclaration
        }
        guard !inScopeAssets.isEmpty else {
            throw ValidationError.missingScope
        }
        guard inScopeAssets.allSatisfy({ $0.isWellFormed }),
              outOfScopeAssets.allSatisfy({ $0.isWellFormed }) else {
            throw ValidationError.invalidAsset
        }
        guard Self.isSHA256Hex(policyDocumentHash) else {
            throw ValidationError.invalidPolicyDocumentHash
        }
        let canonicalData = try Self.canonicalEncoder().encode(CanonicalProfile(profile: self))
        guard canonicalData.count <= Self.maximumProfileBytes else {
            throw ValidationError.profileTooLarge
        }
        let expectedHash = SHA256.hash(data: canonicalData).map { String(format: "%02x", $0) }.joined()
        guard profileHash == expectedHash else {
            throw ValidationError.profileHashMismatch
        }
        if let window = testingWindow {
            guard window.startsAt < window.endsAt else {
                throw ValidationError.invalidTestingWindow
            }
            guard now >= window.startsAt else {
                throw ValidationError.testingWindowNotYetActive
            }
            guard now < window.endsAt else {
                throw ValidationError.testingWindowExpired
            }
        }
        guard budgets.maxRequestsPerMinute > 0,
              budgets.maxTotalRequests > 0,
              budgets.maxConcurrentRequests > 0 else {
            throw ValidationError.invalidBudgets
        }
    }

    private static func isSHA256Hex(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy {
            (48...57).contains($0.value) || (97...102).contains($0.value)
        }
    }

    static func canonicalEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.dateFormatter.string(from: date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = Self.dateFormatter.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid canonical date")
            }
            return date
        }
        return decoder
    }

    private static var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    private struct CanonicalProfile: Encodable {
        let schemaVersion: Int
        let engagementID: UUID
        let importedAt: Date
        let platformRef: String?
        let programLabel: String
        let programType: String
        let policyDocumentHash: String
        let inScopeAssets: [EngagementAsset]
        let outOfScopeAssets: [EngagementAsset]
        let forbiddenActions: [String]
        let allowedCategories: [String]
        let testingWindow: EngagementTestingWindow?
        let budgets: EngagementBudgets
        let operatorDeclaration: String
        let declaredAt: Date

        init(profile: EngagementProfile) {
            schemaVersion = profile.schemaVersion
            engagementID = profile.engagementID
            importedAt = profile.importedAt
            platformRef = profile.platformRef
            programLabel = profile.programLabel
            programType = profile.programType
            policyDocumentHash = profile.policyDocumentHash
            inScopeAssets = profile.inScopeAssets
            outOfScopeAssets = profile.outOfScopeAssets
            forbiddenActions = profile.forbiddenActions
            allowedCategories = profile.allowedCategories
            testingWindow = profile.testingWindow
            budgets = profile.budgets
            operatorDeclaration = profile.operatorDeclaration
            declaredAt = profile.declaredAt
        }
    }
}
