import SwiftUI

// Design contract: the page remains the workspace; this shelf is the command/state
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var composerIsFocused: Bool
    @State private var dragOrigin: CGPoint?
    @State private var dragPosition: CGPoint?
    @State private var dragDistance: CGFloat = 0

    private let ballDiameter: CGFloat = 56
    private let minimumTapSize: CGFloat = 44
    private let dragThreshold: CGFloat = 8

    var body: some View {
        Group {
            if dockPreferences.collapsed {
                GeometryReader { geometry in
                    collapsedBall(in: geometry)
                }
                .coordinateSpace(name: "AgentOverlaySpace")
            } else {
                expandedShelf
            }
        }
    }

    private var expandedShelf: some View {
        ScrollView(.vertical, showsIndicators: sizeCategory.isAccessibilityCategory) {
            VStack(alignment: .leading, spacing: K3VisualSystem.Space.standard) {
                statusHeader
                composer
                actionRow
            }
            .padding(.horizontal, K3VisualSystem.Space.generous)
            .padding(.vertical, K3VisualSystem.Space.standard)
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: sizeCategory.isAccessibilityCategory ? 270 : 190)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            K3VisualSystem.Palette.separator.frame(height: K3VisualSystem.Space.hairline)
        }
    }

    private var statusHeader: some View {
        let presentation = K3VisualSystem.presentation(for: phase)
        return HStack(spacing: K3VisualSystem.Space.standard) {
            Image(systemName: presentation.symbol)
                .foregroundColor(presentation.color)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(statusText ?? presentation.title)
                    .font(.headline)
                    .lineLimit(2)
                if let engagementLabel = engagementLabel, !engagementLabel.isEmpty {
                    Text(engagementLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: K3VisualSystem.Space.compact)

            Button(action: collapse) {
                Image(systemName: "chevron.down")
                    .frame(width: minimumTapSize, height: minimumTapSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Collapse agent shelf")
            .accessibilityHint("Shows the movable agent ball and restores more page space")
        }
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
            VStack(spacing: K3VisualSystem.Space.compact) { actionButtons }
        } else {
            HStack(spacing: K3VisualSystem.Space.compact) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: onOpenMissionControl) {
            Label("Mission Control", systemImage: "scope")
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: minimumTapSize)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Open Mission Control")
        .accessibilityHint("Opens run details, page tools, and agent settings")

        if hasPendingApproval {
            Button(action: onExpandApproval) {
                Label(approvalTitle, systemImage: "hand.raised.fill")
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: minimumTapSize)
            }
            .buttonStyle(.bordered)
            .tint(K3VisualSystem.Palette.approval)
            .accessibilityLabel(approvalAccessibilityLabel)
            .accessibilityHint("Opens the pending approval for review")
        }

        if phase.isBusy {
            Button(action: onStop) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity, minHeight: minimumTapSize)
            }
            .buttonStyle(.borderedProminent)
            .tint(K3VisualSystem.Palette.error)
            .accessibilityLabel("Stop agent")
            .accessibilityHint("Requests that the current operation stop")
        } else {
            Button(action: onRun) {
                Label("Run", systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: minimumTapSize)
            }
            .buttonStyle(.borderedProminent)
            .tint(K3VisualSystem.Palette.interaction)
            .disabled(!isConfigured || isCommandBlank || phase.isBusy)
            .accessibilityLabel("Run agent command")
            .accessibilityHint(runAccessibilityHint)
        }
    }

    private func collapsedBall(in geometry: GeometryProxy) -> some View {
        let bounds = safeBallBounds(in: geometry)
        let persistedPosition = ballPosition(in: bounds)
        let visiblePosition = dragPosition.map { clamp($0, to: bounds) } ?? persistedPosition
        let presentation = K3VisualSystem.presentation(for: phase)

        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(.regularMaterial)
                .overlay(Circle().stroke(presentation.color, lineWidth: 2))
                .overlay(
                    Image(systemName: presentation.symbol)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundColor(presentation.color)
                        .accessibilityHidden(true)
                )
                .frame(width: ballDiameter, height: ballDiameter)

            if hasPendingApproval {
                Text(badgeText)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Color(uiColor: .black))
                    .padding(.horizontal, 5)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Capsule().fill(K3VisualSystem.Palette.approval))
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
        .accessibilityAction(named: Text("Move left")) { moveBall(to: .left) }
        .accessibilityAction(named: Text("Move right")) { moveBall(to: .right) }
    }

    private func ballDragGesture(bounds: BallBounds, persistedPosition: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("AgentOverlaySpace"))
            .onChanged { value in
                let origin = dragOrigin ?? persistedPosition
                if dragOrigin == nil { dragOrigin = persistedPosition }
                dragDistance = dragMagnitude(value.translation)
                dragPosition = clamp(
                    CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height),
                    to: bounds
                )
            }
            .onEnded { value in
                let origin = dragOrigin ?? persistedPosition
                let finalDistance = dragMagnitude(value.translation)
                let finalPoint = clamp(
                    CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height),
                    to: bounds
                )
                if max(dragDistance, finalDistance) < dragThreshold {
                    expand()
                    dragPosition = nil
                } else {
                    withAnimation(K3VisualSystem.Motion.snapAnimation(reduceMotion: reduceMotion)) {
                        snapAndPersist(finalPoint, in: bounds)
                        dragPosition = nil
                    }
                }
                dragOrigin = nil
                dragDistance = 0
            }
    }

    private func safeBallBounds(in geometry: GeometryProxy) -> BallBounds {
        let radius = ballDiameter / 2
        let sideMargin: CGFloat = K3VisualSystem.Space.standard
        let topMargin: CGFloat = K3VisualSystem.Space.standard
        let practicalBottomMargin: CGFloat = K3VisualSystem.Space.generous
        let safeInsets = geometry.safeAreaInsets
        let minX = safeInsets.leading + sideMargin + radius
        let maxX = max(minX, geometry.size.width - safeInsets.trailing - sideMargin - radius)
        let minY = safeInsets.top + topMargin + radius
        let maxY = max(minY, geometry.size.height - safeInsets.bottom - practicalBottomMargin - radius)
        return BallBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }

    private func ballPosition(in bounds: BallBounds) -> CGPoint {
        let x = dockPreferences.edge == .left ? bounds.minX : bounds.maxX
        let normalizedY = CGFloat(min(max(dockPreferences.normalizedY, 0), 1))
        return CGPoint(x: x, y: bounds.minY + normalizedY * bounds.height)
    }

    private func clamp(_ point: CGPoint, to bounds: BallBounds) -> CGPoint {
        CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX), y: min(max(point.y, bounds.minY), bounds.maxY))
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

    private func moveBall(to edge: DockEdge) {
        dockPreferences.edge = edge
    }

    private func collapse() {
        composerIsFocused = false
        withAnimation(K3VisualSystem.Motion.animation(reduceMotion: reduceMotion)) {
            dockPreferences.collapsed = true
        }
    }

    private func expand() {
        withAnimation(K3VisualSystem.Motion.animation(reduceMotion: reduceMotion)) {
            dockPreferences.collapsed = false
        }
    }

    private func runIfAllowed() {
        guard isConfigured, !phase.isBusy, !isCommandBlank else { return }
        onRun()
    }

    private var hasPendingApproval: Bool { pendingApprovalCount > 0 }
    private var isCommandBlank: Bool { commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var approvalTitle: String { pendingApprovalCount == 1 ? "Review" : "Review \(pendingApprovalCount)" }
    private var approvalAccessibilityLabel: String {
        pendingApprovalCount == 1 ? "Review one pending approval" : "Review \(pendingApprovalCount) pending approvals"
    }
    private var badgeText: String { pendingApprovalCount > 99 ? "99+" : String(pendingApprovalCount) }
    private var ballAccessibilityLabel: String {
        var label = "Agent, \(statusText ?? phase.label)"
        if hasPendingApproval { label += ", \(approvalAccessibilityLabel)" }
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
}

private struct BallBounds {
    let minX: CGFloat
    let maxX: CGFloat
    let minY: CGFloat
    let maxY: CGFloat
    var height: CGFloat { maxY - minY }
}
