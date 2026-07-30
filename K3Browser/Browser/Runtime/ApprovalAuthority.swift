import Foundation

/// UI proposal only. Possession of this value grants no executable authority.
struct ApprovalRequest: Identifiable, Equatable {
    let id: UUID
    let runID: UUID
    let call: ValidatedToolCall
    let risk: ToolRisk
    let preview: String
    let reason: String
    let engagementProfileHash: String

    init(
        id: UUID = UUID(),
        runID: UUID,
        call: ValidatedToolCall,
        risk: ToolRisk,
        preview: String,
        reason: String,
        engagementProfileHash: String = "engagement:none"
    ) {
        self.id = id
        self.runID = runID
        self.call = call
        self.risk = risk
        self.preview = Self.boundedRedacted(preview)
        self.reason = Self.boundedRedacted(reason)
        self.engagementProfileHash = engagementProfileHash
    }

    private static func boundedRedacted(_ value: String) -> String {
        let redacted = Redactor.text(value)
        var result = ""
        for character in redacted {
            let next = String(character)
            guard result.utf8.count + next.utf8.count <= 240 else { break }
            result.append(character)
        }
        return result
    }
}

struct ApprovalTokenBinding: Equatable {
    let nonce: UUID
    let issuedAt: Date
    let expiresAt: Date
    let descriptorName: String
    let descriptorVersion: Int
    let runID: UUID
    let actionID: String
    let tool: ToolName
    let canonicalArgumentDigest: String
    let pageGeneration: UInt64?
    let origin: String?
    let snapshotID: UUID?
    let targetFingerprint: String?
    let engagementProfileHash: String

    static func expected(
        for request: ApprovalRequest,
        nonce: UUID,
        issuedAt: Date,
        expiresAt: Date
    ) -> ApprovalTokenBinding {
        let descriptor = ToolRegistry.descriptor(for: request.call.tool)
        return ApprovalTokenBinding(
            nonce: nonce,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            descriptorName: request.call.tool.rawValue,
            descriptorVersion: descriptor.descriptorVersion,
            runID: request.runID,
            actionID: request.call.id,
            tool: request.call.tool,
            canonicalArgumentDigest: request.call.canonicalArgumentDigest,
            pageGeneration: request.call.pageIdentity?.pageGeneration,
            origin: request.call.pageIdentity?.origin,
            snapshotID: request.call.pageIdentity?.snapshotID,
            targetFingerprint: request.call.target?.fingerprint,
            engagementProfileHash: request.engagementProfileHash
        )
    }
}

/// Opaque, immutable, single-use bearer value.
struct ApprovalToken: Equatable {
    fileprivate let tokenID: UUID
    fileprivate let binding: ApprovalTokenBinding
}

enum ApprovalCommitError: Error, Equatable {
    case missing
    case mismatch
    case expired
}

@MainActor
final class ApprovalAuthority {
    private var outstanding: (tokenID: UUID, binding: ApprovalTokenBinding)?
    let lifetime: TimeInterval

    init(lifetime: TimeInterval = 30) {
        self.lifetime = lifetime.isFinite ? max(0, min(lifetime, 300)) : 0
    }

    /// There is one global slot. Issuing always burns any previously staged token.
    func issue(
        for request: ApprovalRequest,
        now: Date = Date(),
        nonce: UUID = UUID(),
        tokenID: UUID = UUID()
    ) -> ApprovalToken {
        outstanding = nil
        let expiry = now.addingTimeInterval(lifetime)
        let binding = ApprovalTokenBinding.expected(
            for: request,
            nonce: nonce,
            issuedAt: now,
            expiresAt: expiry
        )
        outstanding = (tokenID, binding)
        return ApprovalToken(tokenID: tokenID, binding: binding)
    }

    /// Consume first. A mismatch or expiry permanently burns the global token slot.
    func consume(
        _ token: ApprovalToken,
        expected request: ApprovalRequest,
        now: Date = Date()
    ) -> Result<Void, ApprovalCommitError> {
        guard let stored = outstanding else { return .failure(.missing) }
        outstanding = nil

        let expectedBinding = ApprovalTokenBinding.expected(
            for: request,
            nonce: token.binding.nonce,
            issuedAt: token.binding.issuedAt,
            expiresAt: token.binding.expiresAt
        )
        guard stored.tokenID == token.tokenID,
              stored.binding == token.binding,
              token.binding == expectedBinding else {
            return .failure(.mismatch)
        }
        guard now < token.binding.expiresAt else { return .failure(.expired) }
        return .success(())
    }

    func invalidate() { outstanding = nil }
    func invalidateAll() { invalidate() }
}

enum CommitAuthority {
    case automatic
    case approved(token: ApprovalToken, proposal: ApprovalRequest)
}
