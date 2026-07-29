import Foundation

enum EngagementScopeDisposition: String, Codable, Equatable {
    case neutral
    case inScope
    case outOfScope
    case invalid
}

struct EngagementStatus: Codable, Equatable {
    let disposition: EngagementScopeDisposition
    let reason: String
    let matchedAsset: EngagementAsset?

    static func neutral(_ reason: String) -> EngagementStatus {
        EngagementStatus(disposition: .neutral, reason: reason, matchedAsset: nil)
    }

    static func invalid(_ reason: String) -> EngagementStatus {
        EngagementStatus(disposition: .invalid, reason: reason, matchedAsset: nil)
    }
}
