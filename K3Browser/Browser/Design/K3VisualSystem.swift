import SwiftUI
import UIKit

// THESIS page-first Magnetic Capsule; OWN-WORLD semantic indigo interaction, neutral material, amber approval, red error, SF typography/symbols; STORY browse quietly → tap the Ball → compose/watch/read a bounded result; FIRST VIEWPORT page dominates; the page never yields layout to agent chrome; FORM the Ball is the agent and capsules are temporary speech; FINISH independent review and CI compile remain required.
enum K3VisualSystem {
    enum Space {
        static let hairline: CGFloat = 1
        static let progress: CGFloat = 2
        static let compact: CGFloat = 6
        static let standard: CGFloat = 12
        static let generous: CGFloat = 16
        static let control: CGFloat = 44
        static let ball: CGFloat = 56
        static let dragThreshold: CGFloat = 8
    }

    enum Motion {
        static let quick = 0.18
        static let standard = 0.22

        static func animation(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeInOut(duration: standard)
        }

        static func snapAnimation(reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeOut(duration: quick)
        }
    }

    enum Palette {
        static let interaction = Color(uiColor: .systemIndigo)
        static let approval = Color(uiColor: .systemOrange)
        static let error = Color(uiColor: .systemRed)
        static let success = Color(uiColor: .systemGreen)
        static let rail = Color(uiColor: .systemBackground)
        static let capsule = Color(uiColor: .secondarySystemBackground)
        static let separator = Color(uiColor: .separator)
        static let dim = Color(uiColor: .black).opacity(0.42)
    }

    struct PhasePresentation {
        let title: String
        let symbol: String
        let color: Color
    }

    static func presentation(for phase: AgentPhase) -> PhasePresentation {
        switch phase {
        case .idle:
            return PhasePresentation(title: phase.label, symbol: "circle", color: .secondary)
        case .observing:
            return PhasePresentation(title: phase.label, symbol: "eye.fill", color: Palette.interaction)
        case .thinking:
            return PhasePresentation(title: phase.label, symbol: "brain.head.profile", color: Palette.interaction)
        case .awaitingApproval:
            return PhasePresentation(title: phase.label, symbol: "hand.raised.fill", color: Palette.approval)
        case .acting:
            return PhasePresentation(title: phase.label, symbol: "bolt.fill", color: Palette.interaction)
        case .done:
            return PhasePresentation(title: phase.label, symbol: "checkmark.circle.fill", color: Palette.success)
        case .stopped:
            return PhasePresentation(title: phase.label, symbol: "stop.circle", color: .secondary)
        case .error:
            return PhasePresentation(title: phase.label, symbol: "exclamationmark.triangle.fill", color: Palette.error)
        }
    }
}
