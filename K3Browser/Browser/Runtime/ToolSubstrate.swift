import Foundation

// MARK: - Typed JSON substrate

indirect enum JSONValue: Codable, Equatable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .number(let value):
            guard value.isFinite else {
                throw EncodingError.invalidValue(
                    value,
                    EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "JSON numbers must be finite")
                )
            }
            try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var objectValue: [String: JSONValue]? {
        guard case .object(let value) = self else { return nil }
        return value
    }

    var arrayValue: [JSONValue]? {
        guard case .array(let value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case .number(let value) = self else { return nil }
        return value
    }

    var boolValue: Bool? {
        guard case .bool(let value) = self else { return nil }
        return value
    }

    var integerValue: Int? {
        guard case .number(let value) = self, value.isFinite, value.rounded() == value else { return nil }
        return Int(exactly: value)
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    subscript(key: String) -> JSONValue? { objectValue?[key] }
    subscript(index: Int) -> JSONValue? {
        guard let values = arrayValue, values.indices.contains(index) else { return nil }
        return values[index]
    }
}

// MARK: - Static typed tool registry

enum ToolName: String, Codable, CaseIterable, Equatable, Hashable {
    case snapshotPage = "snapshot_page"
    case extractText = "extract_text"
    case extractLinks = "extract_links"
    case extractForms = "extract_forms"
    case extractTables = "extract_tables"
    case saveMemoryNote = "save_memory_note"
    case readMemoryNotes = "read_memory_notes"
    case scroll = "scroll"
    case openURL = "open_url"
    case back = "back"
    case forward = "forward"
    case reload = "reload"
    case fillSelector = "fill_selector"
    case clickSelector = "click_selector"
    case selectOption = "select_option"
    case submitForm = "submit_form"
    case exportMarkdown = "export_markdown"
    case exportJSON = "export_json"
    case exportCSV = "export_csv"
}

extension ToolName: CustomStringConvertible {
    var description: String { rawValue }

    var isExport: Bool {
        switch self {
        case .exportMarkdown, .exportJSON, .exportCSV: return true
        default: return false
        }
    }
}

enum ToolEffectClass: String, Codable, Equatable {
    case pageRead
    case localRead
    case viewportMutation
    case navigation
    case domMutation
    case localPersistence
    case externalShare
}

enum ToolSettlementClass: String, Codable, Equatable {
    case snapshot
    case immediateJavaScript
    case webKitNavigation
    case possibleWebKitNavigation
    case localPersistence
    case presentation
}

enum ToolApprovalPolicy: String, Codable, Equatable {
    case automatic
    case requireApproval
    case alwaysRequireApproval
}

enum ToolScopeRequirement: String, Codable, Equatable {
    case none
    case currentPageWhenEngagementActive
    case targetURLWhenEngagementActive
}

enum ToolReplayPolicy: String, Codable, Equatable {
    case reobserveBeforeReplay
    case idempotentLocalRead
    case noReplay
}

enum ToolOutputSchema: String, Codable, Equatable {
    case sanitizedSnapshot
    case safeText
    case navigationSettlement
    case mutationSettlement
    case localReceipt
    case presentationReceipt
}

enum ToolRedactionPolicy: String, Codable, Equatable {
    case sanitizedPageEvidence
    case redactRuntimeText
    case receiptOnly
}

enum ToolEvidencePolicy: String, Codable, Equatable {
    case pageIdentityBound
    case localDevice
    case exactEffectReceipt
}

struct ToolBudgetMetadata: Codable, Equatable {
    let timeoutSeconds: Int
    let maximumInvocationsPerRun: Int
    let maximumArgumentBytes: Int
    let maximumResultBytes: Int
}

struct ToolDescriptor: Codable, Equatable {
    let effectClass: ToolEffectClass
    let settlementClass: ToolSettlementClass
    let defaultApprovalPolicy: ToolApprovalPolicy
    let isPageBound: Bool
    let scopeRequirement: ToolScopeRequirement
    let budget: ToolBudgetMetadata
    let replayPolicy: ToolReplayPolicy
    let outputSchema: ToolOutputSchema
    let redactionPolicy: ToolRedactionPolicy
    let evidencePolicy: ToolEvidencePolicy
    let descriptorVersion: Int

    init(effectClass: ToolEffectClass, settlementClass: ToolSettlementClass, defaultApprovalPolicy: ToolApprovalPolicy, isPageBound: Bool, scopeRequirement: ToolScopeRequirement, budget: ToolBudgetMetadata, replayPolicy: ToolReplayPolicy, descriptorVersion: Int) {
        self.effectClass = effectClass
        self.settlementClass = settlementClass
        self.defaultApprovalPolicy = defaultApprovalPolicy
        self.isPageBound = isPageBound
        self.scopeRequirement = scopeRequirement
        self.budget = budget
        self.replayPolicy = replayPolicy
        self.descriptorVersion = descriptorVersion
        switch settlementClass {
        case .snapshot: self.outputSchema = .sanitizedSnapshot
        case .webKitNavigation, .possibleWebKitNavigation: self.outputSchema = .navigationSettlement
        case .immediateJavaScript: self.outputSchema = .mutationSettlement
        case .localPersistence: self.outputSchema = effectClass == .localRead ? .safeText : .localReceipt
        case .presentation: self.outputSchema = .presentationReceipt
        }
        self.redactionPolicy = effectClass == .pageRead ? .sanitizedPageEvidence : (effectClass == .externalShare ? .receiptOnly : .redactRuntimeText)
        self.evidencePolicy = isPageBound ? .pageIdentityBound : (effectClass == .localRead || effectClass == .localPersistence ? .localDevice : .exactEffectReceipt)
    }
}

enum ToolRegistry {
    private static let readBudget = ToolBudgetMetadata(timeoutSeconds: 15, maximumInvocationsPerRun: 6, maximumArgumentBytes: 8_192, maximumResultBytes: 65_536)
    private static let actionBudget = ToolBudgetMetadata(timeoutSeconds: 30, maximumInvocationsPerRun: 6, maximumArgumentBytes: 16_384, maximumResultBytes: 16_384)
    private static let localBudget = ToolBudgetMetadata(timeoutSeconds: 10, maximumInvocationsPerRun: 6, maximumArgumentBytes: 65_536, maximumResultBytes: 65_536)

    static let descriptors: [ToolName: ToolDescriptor] = {
        let registry: [ToolName: ToolDescriptor] = [
            .snapshotPage: ToolDescriptor(effectClass: .pageRead, settlementClass: .snapshot, defaultApprovalPolicy: .automatic, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: readBudget, replayPolicy: .reobserveBeforeReplay, descriptorVersion: 1),
            .extractText: ToolDescriptor(effectClass: .pageRead, settlementClass: .snapshot, defaultApprovalPolicy: .automatic, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: readBudget, replayPolicy: .reobserveBeforeReplay, descriptorVersion: 1),
            .extractLinks: ToolDescriptor(effectClass: .pageRead, settlementClass: .snapshot, defaultApprovalPolicy: .automatic, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: readBudget, replayPolicy: .reobserveBeforeReplay, descriptorVersion: 1),
            .extractForms: ToolDescriptor(effectClass: .pageRead, settlementClass: .snapshot, defaultApprovalPolicy: .automatic, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: readBudget, replayPolicy: .reobserveBeforeReplay, descriptorVersion: 1),
            .extractTables: ToolDescriptor(effectClass: .pageRead, settlementClass: .snapshot, defaultApprovalPolicy: .automatic, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: readBudget, replayPolicy: .reobserveBeforeReplay, descriptorVersion: 1),
            .saveMemoryNote: ToolDescriptor(effectClass: .localPersistence, settlementClass: .localPersistence, defaultApprovalPolicy: .automatic, isPageBound: false, scopeRequirement: .none, budget: localBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .readMemoryNotes: ToolDescriptor(effectClass: .localRead, settlementClass: .localPersistence, defaultApprovalPolicy: .automatic, isPageBound: false, scopeRequirement: .none, budget: localBudget, replayPolicy: .idempotentLocalRead, descriptorVersion: 1),
            .scroll: ToolDescriptor(effectClass: .viewportMutation, settlementClass: .immediateJavaScript, defaultApprovalPolicy: .requireApproval, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: actionBudget, replayPolicy: .reobserveBeforeReplay, descriptorVersion: 1),
            .openURL: ToolDescriptor(effectClass: .navigation, settlementClass: .webKitNavigation, defaultApprovalPolicy: .requireApproval, isPageBound: true, scopeRequirement: .targetURLWhenEngagementActive, budget: actionBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .back: ToolDescriptor(effectClass: .navigation, settlementClass: .webKitNavigation, defaultApprovalPolicy: .requireApproval, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: actionBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .forward: ToolDescriptor(effectClass: .navigation, settlementClass: .webKitNavigation, defaultApprovalPolicy: .requireApproval, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: actionBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .reload: ToolDescriptor(effectClass: .navigation, settlementClass: .webKitNavigation, defaultApprovalPolicy: .requireApproval, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: actionBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .fillSelector: ToolDescriptor(effectClass: .domMutation, settlementClass: .immediateJavaScript, defaultApprovalPolicy: .requireApproval, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: actionBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .clickSelector: ToolDescriptor(effectClass: .domMutation, settlementClass: .possibleWebKitNavigation, defaultApprovalPolicy: .requireApproval, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: actionBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .selectOption: ToolDescriptor(effectClass: .domMutation, settlementClass: .immediateJavaScript, defaultApprovalPolicy: .requireApproval, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: actionBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .submitForm: ToolDescriptor(effectClass: .domMutation, settlementClass: .possibleWebKitNavigation, defaultApprovalPolicy: .alwaysRequireApproval, isPageBound: true, scopeRequirement: .currentPageWhenEngagementActive, budget: actionBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .exportMarkdown: ToolDescriptor(effectClass: .externalShare, settlementClass: .presentation, defaultApprovalPolicy: .requireApproval, isPageBound: false, scopeRequirement: .none, budget: localBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .exportJSON: ToolDescriptor(effectClass: .externalShare, settlementClass: .presentation, defaultApprovalPolicy: .requireApproval, isPageBound: false, scopeRequirement: .none, budget: localBudget, replayPolicy: .noReplay, descriptorVersion: 1),
            .exportCSV: ToolDescriptor(effectClass: .externalShare, settlementClass: .presentation, defaultApprovalPolicy: .requireApproval, isPageBound: false, scopeRequirement: .none, budget: localBudget, replayPolicy: .noReplay, descriptorVersion: 1),
        ]
        return registry
    }()

    private static let failClosedDescriptor = ToolDescriptor(
        effectClass: .externalShare,
        settlementClass: .presentation,
        defaultApprovalPolicy: .alwaysRequireApproval,
        isPageBound: true,
        scopeRequirement: .currentPageWhenEngagementActive,
        budget: ToolBudgetMetadata(
            timeoutSeconds: 1,
            maximumInvocationsPerRun: 0,
            maximumArgumentBytes: 0,
            maximumResultBytes: 0
        ),
        replayPolicy: .noReplay,
        descriptorVersion: 0
    )

    static func descriptor(for tool: ToolName) -> ToolDescriptor {
        descriptors[tool] ?? failClosedDescriptor
    }

    static var promptToolList: String {
        ToolName.allCases.map(\.rawValue).joined(separator: ", ")
    }

    static func approvalReason(for tool: ToolName) -> String {
        let descriptor = descriptor(for: tool)
        let policyReason: String
        switch descriptor.defaultApprovalPolicy {
        case .automatic:
            policyReason = "Manual review was requested."
        case .requireApproval:
            policyReason = "This tool requires approval before it runs."
        case .alwaysRequireApproval:
            policyReason = "This tool always requires approval before it runs."
        }

        let effectReason: String
        switch descriptor.effectClass {
        case .pageRead:
            effectReason = "It reads the current page."
        case .localRead:
            effectReason = "It reads local device data."
        case .viewportMutation:
            effectReason = "It changes the visible page position."
        case .navigation:
            effectReason = "It navigates the browser."
        case .domMutation:
            effectReason = "It changes or activates page content."
        case .localPersistence:
            effectReason = "It writes local device data."
        case .externalShare:
            effectReason = "It prepares data to leave the app."
        }
        return policyReason + " " + effectReason
    }
}

// This policy can only make a descriptor decision more restrictive. It never grants authority.
enum SensitiveToolPolicy {
    private static let blockedPhrases = [
        "password", "passcode", "otp", "2fa", "credit card", "cvv", "payment", "purchase",
        "checkout", "delete", "remove", "send money", "transfer", "swap", "wallet",
        "connect wallet", "sign transaction", "approve token", "confirm order"
    ]

    static func blockReason(for arguments: JSONValue) -> String? {
        guard containsBlockedData(arguments) else { return nil }
        return "Blocked by safety policy for sensitive/payment/login/crypto/delete pattern."
    }

    private static func containsBlockedData(_ value: JSONValue) -> Bool {
        switch value {
        case .object(let values):
            return values.contains { key, nested in
                containsBlockedPhrase(key) || containsBlockedData(nested)
            }
        case .array(let values):
            return values.contains(where: containsBlockedData)
        case .string(let value):
            return containsBlockedPhrase(value)
        case .number, .bool, .null:
            return false
        }
    }

    private static func containsBlockedPhrase(_ raw: String) -> Bool {
        let normalized = raw.lowercased().replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return blockedPhrases.contains { normalized.contains($0) }
    }
}

struct ToolCall: Identifiable, Codable, Equatable {
    let id: String
    let tool: ToolName
    let arguments: JSONValue

    init(id: String, tool: ToolName, arguments: JSONValue) {
        self.id = id
        self.tool = tool
        self.arguments = arguments
    }

    private enum CodingKeys: String, CodingKey { case id, tool, arguments }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        tool = try container.decode(ToolName.self, forKey: .tool)
        arguments = try container.decode(JSONValue.self, forKey: .arguments)
        guard case .object = arguments else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: container.codingPath + [CodingKeys.arguments], debugDescription: "Tool arguments must be a JSON object")
            )
        }
    }
}
