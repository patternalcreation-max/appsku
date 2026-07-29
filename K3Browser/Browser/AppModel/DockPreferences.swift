import Combine
import Foundation

enum DockEdge: String, Codable, CaseIterable {
    case left
    case right
}

final class DockPreferences: ObservableObject {
    private enum Key {
        static let collapsed = "dock.collapsed"
        static let edge = "dock.edge"
        static let normalizedY = "dock.normalizedY"
    }

    private let defaults: UserDefaults

    @Published var collapsed: Bool {
        didSet { defaults.set(collapsed, forKey: Key.collapsed) }
    }

    @Published var edge: DockEdge {
        didSet { defaults.set(edge.rawValue, forKey: Key.edge) }
    }

    @Published var normalizedY: Double {
        didSet {
            guard normalizedY.isFinite else {
                normalizedY = 0.72
                return
            }
            let clamped = min(max(normalizedY, 0), 1)
            if normalizedY != clamped {
                normalizedY = clamped
                return
            }
            defaults.set(clamped, forKey: Key.normalizedY)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        collapsed = defaults.object(forKey: Key.collapsed) as? Bool ?? false
        edge = defaults.string(forKey: Key.edge).flatMap(DockEdge.init(rawValue:)) ?? .right
        let storedY = defaults.object(forKey: Key.normalizedY) as? Double ?? 0.72
        normalizedY = storedY.isFinite ? min(max(storedY, 0), 1) : 0.72
    }

    func reset() {
        collapsed = false
        edge = .right
        normalizedY = 0.72
    }
}
