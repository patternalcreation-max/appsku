import SwiftUI

// Design contract: the page remains the workspace; this dock is the command/state
// boundary; the ball preserves page area; there is one composer; no authority decisions.
struct AdaptiveAgentOverlay: View {
    @ObservedObject var dockPreferences: DockPreferences
    @Binding var commandText: String

    let phase: AgentPhase
    let isConfigured: Bool
    let pendingApprovalCount: Int
    let engagementLabel: String?
    let statusText: String?
    let onRun: () -> Void
    let onStop: () -> Void
    let onOpenMissionControl: () -> Void
    let onExpandApproval: () -> Void

    @Environment(\.sizeCategory) private var sizeCategory
    @FocusState private var composerIsFocused: Bool
    @State private var dragOrigin: CGPoint?
    @State private var dragPosition: CGPoint?
    @State private var dragDistance: CGFloat = 0

    private let animationDuration = 0.20
    private let ballDiameter: CGFloat = 56
    private let minimumTapSize: CGFloat = 44
    private let dragThreshold: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if dockPreferences.collapsed {
                    collapsedBall(in: geometry)
                } else {
                    expandedDock(in: geometry)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "AgentOverlaySpace")
            .animation(.easeInOut(duration: animationDuration), value: dockPreferences.collapsed)
        }
    }

    private func expandedDock(in geometry: GeometryProxy) -> some View {
        let maximumDockHeight = max(
            0,
            geometry.size.height - geometry.safeAreaInsets.top - 8
        )

        return
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    statusHeader
                    composer
                    actionRow
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 8))
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: maximumDockHeight)
            .fixedSize(horizontal: false, vertical: true)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
    }

    private var statusHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: stateSymbol)
                .foregroundColor(stateColor)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText ?? phase.label)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                if let engagementLabel = engagementLabel, !engagementLabel.isEmpty {
                    Text(engagementLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Button(action: collapse) {
                Image(systemName: "chevron.down")
                    .frame(width: minimumTapSize, height: minimumTapSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Collapse agent dock")
            .accessibilityHint("Shows the movable agent ball and restores more page space")
        }
        .accessibilityElement(children: .contain)
    }

    private var composer: some View {
        TextField("Describe the next operation", text: $commandText, onCommit: runIfAllowed)
            .focused($composerIsFocused)
            .submitLabel(.go)
            .textFieldStyle(.roundedBorder)
            .frame(minHeight: minimumTapSize)
            .disabled(!isConfigured || phase.isBusy)
            .accessibilityLabel("Agent command")
            .accessibilityHint(composerAccessibilityHint)
    }

    @ViewBuilder
    private var actionRow: some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(spacing: 8) {
                actionButtons
            }
            .font(.subheadline.weight(.semibold))
        } else {
            HStack(spacing: 8) {
                actionButtons
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: onOpenMissionControl) {
            Label("Mission Control", systemImage: "slider.horizontal.3")
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: minimumTapSize)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Open Mission Control")
        .accessibilityHint("Opens agent settings and mission details")

        if hasPendingApproval {
            Button(action: onExpandApproval) {
                Label(approvalTitle, systemImage: "hand.raised.fill")
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: minimumTapSize)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .accessibilityLabel(approvalAccessibilityLabel)
            .accessibilityHint("Opens the pending approval for review")
        }

        if phase.isBusy {
            Button(action: onStop) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity, minHeight: minimumTapSize)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .accessibilityLabel("Stop agent")
            .accessibilityHint("Requests that the current operation stop")
        } else {
            Button(action: onRun) {
                Label("Run", systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: minimumTapSize)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isConfigured || isCommandBlank || phase.isBusy)
            .accessibilityLabel("Run agent command")
            .accessibilityHint(runAccessibilityHint)
        }
    }

    private func collapsedBall(in geometry: GeometryProxy) -> some View {
        let bounds = safeBallBounds(in: geometry)
        let persistedPosition = ballPosition(in: bounds)
        let visiblePosition = dragPosition.map { clamp($0, to: bounds) } ?? persistedPosition

        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    Circle().stroke(stateColor, lineWidth: 3)
                )
                .overlay(
                    Image(systemName: stateSymbol)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(stateColor)
                )
                .frame(width: ballDiameter, height: ballDiameter)
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)

            if hasPendingApproval {
                Text(badgeText)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Capsule().fill(Color.orange))
                    .offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: ballDiameter, height: ballDiameter)
        .contentShape(Circle())
        .position(visiblePosition)
        .gesture(ballDragGesture(bounds: bounds, persistedPosition: persistedPosition))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ballAccessibilityLabel)
        .accessibilityHint("Tap to expand, or drag to move and snap to an edge")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { expand() }
    }

    private func ballDragGesture(
        bounds: BallBounds,
        persistedPosition: CGPoint
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("AgentOverlaySpace"))
            .onChanged { value in
                let origin = dragOrigin ?? persistedPosition
                if dragOrigin == nil {
                    dragOrigin = persistedPosition
                }

                dragDistance = dragMagnitude(value.translation)
                dragPosition = clamp(
                    CGPoint(
                        x: origin.x + value.translation.width,
                        y: origin.y + value.translation.height
                    ),
                    to: bounds
                )
            }
            .onEnded { value in
                let origin = dragOrigin ?? persistedPosition
                let finalDistance = dragMagnitude(value.translation)
                let finalPoint = clamp(
                    CGPoint(
                        x: origin.x + value.translation.width,
                        y: origin.y + value.translation.height
                    ),
                    to: bounds
                )

                if max(dragDistance, finalDistance) < dragThreshold {
                    expand()
                } else {
                    withAnimation(.easeOut(duration: animationDuration)) {
                        snapAndPersist(finalPoint, in: bounds)
                        dragPosition = nil
                    }
                }

                dragOrigin = nil
                if max(dragDistance, finalDistance) < dragThreshold {
                    dragPosition = nil
                }
                dragDistance = 0
            }
    }

    private func safeBallBounds(in geometry: GeometryProxy) -> BallBounds {
        let radius = ballDiameter / 2
        let sideMargin: CGFloat = 12
        let topMargin: CGFloat = 12
        let practicalBottomMargin: CGFloat = 16
        let safeInsets = geometry.safeAreaInsets

        let minX = safeInsets.leading + sideMargin + radius
        let proposedMaxX = geometry.size.width - safeInsets.trailing - sideMargin - radius
        let maxX = max(minX, proposedMaxX)
        let minY = safeInsets.top + topMargin + radius
        let proposedMaxY = geometry.size.height - safeInsets.bottom - practicalBottomMargin - radius
        let maxY = max(minY, proposedMaxY)

        return BallBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    private func ballPosition(in bounds: BallBounds) -> CGPoint {
        let x = dockPreferences.edge == .left ? bounds.minX : bounds.maxX
        let normalizedY = CGFloat(min(max(dockPreferences.normalizedY, 0), 1))
        return CGPoint(x: x, y: bounds.minY + normalizedY * bounds.height)
    }

    private func clamp(_ point: CGPoint, to bounds: BallBounds) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    private func dragMagnitude(_ translation: CGSize) -> CGFloat {
        (translation.width * translation.width + translation.height * translation.height).squareRoot()
    }

    private func snapAndPersist(_ point: CGPoint, in bounds: BallBounds) {
        let midpoint = (bounds.minX + bounds.maxX) / 2
        let snappedEdge: DockEdge = point.x <= midpoint ? .left : .right
        let normalizedY = bounds.height > 0 ? (point.y - bounds.minY) / bounds.height : 0.5

        // Persist only the final snapped result, never transient drag frames.
        dockPreferences.edge = snappedEdge
        dockPreferences.normalizedY = Double(min(max(normalizedY, 0), 1))
    }

    private func collapse() {
        composerIsFocused = false
        withAnimation(.easeInOut(duration: animationDuration)) {
            dockPreferences.collapsed = true
        }
    }

    private func expand() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            dockPreferences.collapsed = false
        }
    }

    private func runIfAllowed() {
        guard isConfigured, !phase.isBusy, !isCommandBlank else { return }
        onRun()
    }

    private var hasPendingApproval: Bool {
        pendingApprovalCount > 0
    }

    private var isCommandBlank: Bool {
        commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var approvalTitle: String {
        pendingApprovalCount == 1 ? "Review" : "Review \(pendingApprovalCount)"
    }

    private var approvalAccessibilityLabel: String {
        pendingApprovalCount == 1
            ? "Review one pending approval"
            : "Review \(pendingApprovalCount) pending approvals"
    }

    private var badgeText: String {
        pendingApprovalCount > 99 ? "99+" : String(pendingApprovalCount)
    }

    private var ballAccessibilityLabel: String {
        var label = "Agent, \(statusText ?? phase.label)"
        if hasPendingApproval {
            label += ", \(approvalAccessibilityLabel)"
        }
        return label
    }

    private var composerAccessibilityHint: String {
        if !isConfigured { return "Configure the agent before entering a command" }
        if phase.isBusy { return "The command field is unavailable while the agent is busy" }
        return "Enter one command for the agent"
    }

    private var runAccessibilityHint: String {
        if !isConfigured { return "Configure the agent before running a command" }
        if isCommandBlank { return "Enter a command before running" }
        return "Starts the entered command"
    }

    private var stateColor: Color {
        switch phase {
        case .idle, .done:
            return .green
        case .observing, .thinking, .acting:
            return .accentColor
        case .awaitingApproval:
            return .orange
        case .stopped:
            return .secondary
        case .error:
            return .red
        }
    }

    private var stateSymbol: String {
        switch phase {
        case .idle:
            return "circle.fill"
        case .observing:
            return "eye.fill"
        case .thinking:
            return "brain.head.profile"
        case .awaitingApproval:
            return "hand.raised.fill"
        case .acting:
            return "bolt.fill"
        case .done:
            return "checkmark.circle.fill"
        case .stopped:
            return "stop.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
}

private struct BallBounds {
    let minX: CGFloat
    let maxX: CGFloat
    let minY: CGFloat
    let maxY: CGFloat

    var height: CGFloat {
        maxY - minY
    }
}
