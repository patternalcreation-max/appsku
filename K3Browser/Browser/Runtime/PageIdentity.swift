import Foundation

struct PageIdentity: Codable, Equatable, Hashable {
    let generation: UInt64
    let target: CanonicalPageTarget?
    let isTopLevelLoading: Bool
    let generationExhausted: Bool

    var isCommitted: Bool { target != nil && !isTopLevelLoading && !generationExhausted }
}

/// Foundation-only reducer. WebKit delegates supply a stable navigation ID in B2.
struct PageIdentityReducer {
    private(set) var generation: UInt64
    private(set) var committedTarget: CanonicalPageTarget?
    private(set) var inFlightTopLevelNavigation = false
    private(set) var inFlightNavigationID: UUID?
    private(set) var expectedNavigationTarget: CanonicalPageTarget?
    private(set) var observedInFlightTarget: CanonicalPageTarget?
    private(set) var lastCommittedNavigationID: UUID?
    private(set) var generationExhausted: Bool

    init(generation: UInt64 = 0, committedTarget: CanonicalPageTarget? = nil) {
        self.generation = generation
        self.committedTarget = committedTarget
        self.generationExhausted = generation == UInt64.max
        if generationExhausted { self.committedTarget = nil }
    }

    var current: PageIdentity {
        PageIdentity(
            generation: generation,
            target: committedTarget,
            isTopLevelLoading: inFlightTopLevelNavigation,
            generationExhausted: generationExhausted
        )
    }

    /// Invalidates exactly once for a given top-level navigation ID.
    @discardableResult
    mutating func mainFrameProvisionalStart(
        navigationID: UUID = UUID(),
        expectedTarget: CanonicalPageTarget? = nil
    ) -> PageIdentity {
        guard !(inFlightTopLevelNavigation && inFlightNavigationID == navigationID) else { return current }
        invalidateAndAdvance()
        guard !generationExhausted else { return current }
        inFlightTopLevelNavigation = true
        inFlightNavigationID = navigationID
        expectedNavigationTarget = expectedTarget
        observedInFlightTarget = nil
        return current
    }

    /// Commit settles the generation created at provisional start; it never advances again.
    @discardableResult
    mutating func mainFrameCommit(
        _ target: CanonicalPageTarget,
        navigationID: UUID? = nil
    ) -> PageIdentity {
        guard !generationExhausted,
              inFlightTopLevelNavigation,
              navigationID == nil || navigationID == inFlightNavigationID else {
            return current
        }
        committedTarget = target
        inFlightTopLevelNavigation = false
        lastCommittedNavigationID = inFlightNavigationID
        inFlightNavigationID = nil
        expectedNavigationTarget = nil
        observedInFlightTarget = nil
        return current
    }

    /// Returns true only for a same-document transition. KVO associated with an
    /// in-flight navigation is remembered for B2 settlement and does not advance.
    @discardableResult
    mutating func observeTopLevelURL(_ target: CanonicalPageTarget) -> Bool {
        guard !generationExhausted else { return false }
        if inFlightTopLevelNavigation {
            observedInFlightTarget = target
            return false
        }
        // A URL KVO notification before the first main-frame commit is not a
        // same-document transition and must not manufacture page authority.
        guard committedTarget != nil else { return false }
        guard committedTarget != target else { return false }
        invalidateAndAdvance()
        guard !generationExhausted else { return false }
        committedTarget = target
        return true
    }

    @discardableResult
    mutating func webContentProcessTerminated() -> PageIdentity {
        invalidateAndAdvance()
        return current
    }

    /// Snapshot capture is a read of identity and never changes generation.
    func captureSnapshotIdentity(snapshotID: UUID = UUID()) -> SnapshotIdentity? {
        guard let target = committedTarget,
              !inFlightTopLevelNavigation,
              !generationExhausted else { return nil }
        return SnapshotIdentity(snapshotID: snapshotID, pageGeneration: generation, origin: target.origin)
    }

    /// Callback acceptance binds the snapshot to both generation and committed origin.
    func accepts(_ snapshot: SnapshotIdentity) -> Bool {
        guard let target = committedTarget,
              !inFlightTopLevelNavigation,
              !generationExhausted else { return false }
        return snapshot.pageGeneration == generation && snapshot.origin == target.origin
    }

    private mutating func invalidateAndAdvance() {
        committedTarget = nil
        inFlightTopLevelNavigation = false
        inFlightNavigationID = nil
        expectedNavigationTarget = nil
        observedInFlightTarget = nil
        lastCommittedNavigationID = nil
        guard !generationExhausted else { return }
        guard generation < UInt64.max else {
            generationExhausted = true
            return
        }
        generation += 1
        if generation == UInt64.max {
            // Reserve the terminal value as a permanent fail-closed state.
            generationExhausted = true
            committedTarget = nil
        }
    }
}

struct SnapshotIdentity: Codable, Equatable, Hashable {
    let snapshotID: UUID
    let pageGeneration: UInt64
    let origin: String
}
