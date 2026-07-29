import Foundation

enum AgentPhase: Equatable {
    case idle
    case observing
    case thinking
    case awaitingApproval
    case acting(String)
    case done
    case stopped
    case error(String)

    var label: String {
        switch self {
        case .idle: return "Ready"
        case .observing: return "Observing…"
        case .thinking: return "Thinking…"
        case .awaitingApproval: return "Approval needed"
        case .acting(let tool): return "Acting: \(tool)"
        case .done: return "Done"
        case .stopped: return "Stopped"
        case .error: return "Error"
        }
    }

    var isBusy: Bool {
        switch self {
        case .observing, .thinking, .awaitingApproval, .acting:
            return true
        case .idle, .done, .stopped, .error:
            return false
        }
    }
}
