import SwiftUI

// Magnetic Capsule contract: the Ball is the agent, capsules are temporary speech,
// the browser page never yields layout, and this leaf owns presentation only.
private enum AgentSurfaceMode: Equatable {
    case collapsed
    case compose
    case activePeek
    case resultPeek
}

struct AdaptiveAgentOverlay: View {
    @ObservedObject var dockPreferences: DockPreferences
    @Binding var commandText: String

    let phase: AgentPhase
    let resultText: String
    let isConfigured: Bool
    let pendingApprovalCount: Int
    let statusText: String?
    let hasPresentationConflict: Bool
    let onRun: () -> Void
    let onStop: () -> Void
    let onOpenMissionControl: () -> Void
    let onExpandApproval: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var composerIsFocused: Bool
    @Namespace private var agentGeometry
    @State private var surfaceMode: AgentSurfaceMode = .collapsed
    @State private var dragOrigin: CGPoint?
    @State private var dragPosition: CGPoint?
    @State private var dragDistance: CGFloat = 0

    private let ballDiameter: CGFloat = 56
    private let minimumTapSize: CGFloat = 44
    private let dragThreshold: CGFloat = 8
    private let capsuleInset: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if surfaceMode == .collapsed {
                    collapsedBall(in: geometry)
                        .transition(surfaceTransition)
                } else {
                    capsuleForCurrentMode(availableWidth: max(0, geometry.size.width - (capsuleInset * 2)))
                        .padding(.horizontal, capsuleInset)
                        .safeAreaPadding(.bottom, K3VisualSystem.Space.compact)
                        .transition(surfaceTransition)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .coordinateSpace(name: "AgentOverlaySpace")
        .onChange(of: phase) { newPhase in
            if newPhase.isBusy {
                composerIsFocused = false
                if surfaceMode == .compose { setSurface(.collapsed) }
                return
            }
            revealTerminalResultIfEligible()
        }
        .onChange(of: pendingApprovalCount) { count in
            if count > 0 {
                composerIsFocused = false
                setSurface(.collapsed)
            } else if count == 0 {
                revealTerminalResultIfEligible()
            }
        }
        .onChange(of: hasPresentationConflict) { hasConflict in
            if hasConflict, surfaceMode != .collapsed {
                composerIsFocused = false
                setSurface(.collapsed)
            } else if !hasConflict {
                revealTerminalResultIfEligible()
            }
        }
    }

    @ViewBuilder
    private func capsuleForCurrentMode(availableWidth: CGFloat) -> some View {
        switch surfaceMode {
        case .compose:
            composeCapsule(availableWidth: availableWidth)
        case .activePeek:
            activeCapsule(availableWidth: availableWidth)
        case .resultPeek:
            resultCapsule(availableWidth: availableWidth)
        case .collapsed:
            EmptyView()
        }
    }

    private func composeCapsule(availableWidth: CGFloat) -> some View {
        adaptiveCapsuleLayout(availableWidth: availableWidth) {
            missionControlButton
            composerField
            Button(action: runIfAllowed) {
                Label("Run", systemImage: "play.fill")
                    .labelStyle(.titleOnly)
                    .frame(minWidth: minimumTapSize, minHeight: minimumTapSize)
            }
            .buttonStyle(.borderedProminent)
            .tint(K3VisualSystem.Palette.interaction)
            .disabled(!isConfigured || isCommandBlank || phase.isBusy)
            .accessibilityLabel("Run agent command")
            .accessibilityHint(runAccessibilityHint)

            collapseButton
        }
        .capsuleMaterial(namespace: agentGeometry, reduceMotion: reduceMotion)
        .onAppear {
            guard !phase.isBusy else { return }
            DispatchQueue.main.async { composerIsFocused = true }
        }
    }

    private var composerField: some View {
        TextField("Describe the next operation", text: $commandText)
            .focused($composerIsFocused)
            .submitLabel(.go)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .textFieldStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: minimumTapSize)
            .onSubmit(runIfAllowed)
            .accessibilityLabel("Agent command")
            .accessibilityHint(composerAccessibilityHint)
    }

    private func activeCapsule(availableWidth: CGFloat) -> some View {
        adaptiveCapsuleLayout(availableWidth: availableWidth) {
            phaseIdentity

            Text(statusText ?? phase.label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: stopAndCollapse) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(minHeight: minimumTapSize)
            }
            .buttonStyle(.borderedProminent)
            .tint(K3VisualSystem.Palette.error)
            .accessibilityLabel("Stop agent")
            .accessibilityHint("Requests that the current operation stop")

            missionControlButton
            collapseButton
        }
        .capsuleMaterial(namespace: agentGeometry, reduceMotion: reduceMotion)
    }

    private func resultCapsule(availableWidth: CGFloat) -> some View {
        adaptiveCapsuleLayout(availableWidth: availableWidth) {
            Image(systemName: isErrorPhase ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isErrorPhase ? K3VisualSystem.Palette.error : K3VisualSystem.Palette.success)
                .frame(width: 24, height: minimumTapSize)
                .accessibilityHidden(true)

            if hasMarkdownInResult {
                AgentMarkdownView(text: resultExcerpt, fontSize: 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(resultExcerpt)
                    .font(.body)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel(isErrorPhase ? "Agent error: \(resultExcerpt)" : "Agent result: \(resultExcerpt)")
            }

            Button {
                setSurface(.collapsed)
                onOpenMissionControl()
            } label: {
                Text("Details")
                    .frame(minHeight: minimumTapSize)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Open result details")

            Button { setSurface(.collapsed) } label: {
                Image(systemName: "xmark")
                    .frame(width: minimumTapSize, height: minimumTapSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss result")
        }
        .capsuleMaterial(namespace: agentGeometry, reduceMotion: reduceMotion)
    }

    private func adaptiveCapsuleLayout<Content: View>(
        availableWidth: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let useVerticalLayout = availableWidth < 420 || dynamicTypeSize.isAccessibilitySize
        let layout = useVerticalLayout
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: K3VisualSystem.Space.compact))
            : AnyLayout(HStackLayout(spacing: K3VisualSystem.Space.compact))
        return layout {
            content()
        }
        .frame(maxWidth: .infinity)
    }

    private var missionControlButton: some View {
        Button {
            composerIsFocused = false
            setSurface(.collapsed)
            onOpenMissionControl()
        } label: {
            Label("Mission Control", systemImage: "scope")
                .labelStyle(.iconOnly)
                .frame(width: minimumTapSize, height: minimumTapSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Mission Control")
        .accessibilityHint("Opens run details, page tools, and agent settings")
    }

    private var collapseButton: some View {
        Button { collapse() } label: {
            Image(systemName: "chevron.down")
                .frame(width: minimumTapSize, height: minimumTapSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Collapse agent capsule")
        .accessibilityHint("Returns to the movable agent ball")
    }

    private var phaseIdentity: some View {
        let presentation = K3VisualSystem.presentation(for: phase)
        return Image(systemName: presentation.symbol)
            .foregroundStyle(presentation.color)
            .frame(width: 24, height: minimumTapSize)
            .accessibilityHidden(true)
    }

    private func collapsedBall(in geometry: GeometryProxy) -> some View {
        let bounds = safeBallBounds(in: geometry)
        let persistedPosition = ballPosition(in: bounds)
        let visiblePosition = dragPosition.map { clamp($0, to: bounds) } ?? persistedPosition
        let presentation = K3VisualSystem.presentation(for: phase)

        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(.regularMaterial)
                .overlay(Circle().stroke(presentation.color, lineWidth: K3VisualSystem.Space.hairline))
                .overlay(
                    Image(systemName: presentation.symbol)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(presentation.color)
                        .contentTransition(.symbolEffect(.replace))
                        .accessibilityHidden(true)
                )
                .frame(width: ballDiameter, height: ballDiameter)
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                .agentMatchedGeometry(id: "agent-surface", in: agentGeometry, isSource: true, enabled: !reduceMotion)

            if hasPendingApproval {
                Text(badgeText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color(uiColor: .black))
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
        .accessibilityHint(ballAccessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityActions {
            if hasPendingApproval {
                Button("Review") { onExpandApproval() }
            } else if phase.isBusy {
                Button("Open status") { setSurface(.activePeek) }
            } else {
                Button("Compose") { setSurface(.compose) }
            }
            Button("Move left") { moveBall(to: .left) }
            Button("Move right") { moveBall(to: .right) }
            if phase.isBusy {
                Button("Stop", role: .destructive) { onStop() }
            }
            Button("Mission Control") { onOpenMissionControl() }
        }
    }

    private func ballDragGesture(bounds: BallBounds, persistedPosition: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("AgentOverlaySpace"))
            .onChanged { value in
                let origin = dragOrigin ?? persistedPosition
                if dragOrigin == nil { dragOrigin = persistedPosition }
                dragDistance = dragMagnitude(value.translation)
                dragPosition = clamp(CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height), to: bounds)
            }
            .onEnded { value in
                let origin = dragOrigin ?? persistedPosition
                let finalDistance = dragMagnitude(value.translation)
                let finalPoint = clamp(CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height), to: bounds)
                if max(dragDistance, finalDistance) < dragThreshold {
                    handleBallTap()
                    K3VisualSystem.Haptics.light()
                    dragPosition = nil
                } else {
                    withAnimation(K3VisualSystem.Motion.snapAnimation(reduceMotion: reduceMotion)) {
                        snapAndPersist(finalPoint, in: bounds)
                        K3VisualSystem.Haptics.medium()
                        dragPosition = nil
                    }
                }
                dragOrigin = nil
                dragDistance = 0
            }
    }

    private func safeBallBounds(in geometry: GeometryProxy) -> BallBounds {
        let radius = ballDiameter / 2
        let safeInsets = geometry.safeAreaInsets
        let sideMargin = K3VisualSystem.Space.standard
        let topMargin = K3VisualSystem.Space.standard
        let bottomMargin = K3VisualSystem.Space.generous
        let minX = safeInsets.leading + sideMargin + radius
        let maxX = max(minX, geometry.size.width - safeInsets.trailing - sideMargin - radius)
        let minY = safeInsets.top + topMargin + radius
        let maxY = max(minY, geometry.size.height - safeInsets.bottom - bottomMargin - radius)
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

    private func handleBallTap() {
        if hasPendingApproval {
            onExpandApproval()
        } else if phase.isBusy {
            setSurface(.activePeek)
        } else {
            setSurface(.compose)
        }
    }

    private func collapse() {
        composerIsFocused = false
        setSurface(.collapsed)
    }

    private func stopAndCollapse() {
        setSurface(.collapsed)
        onStop()
    }

    private func runIfAllowed() {
        guard isConfigured, !phase.isBusy, !isCommandBlank else { return }
        composerIsFocused = false
        setSurface(.collapsed)
        onRun()
    }

    private func revealTerminalResultIfEligible() {
        guard isTerminal(phase),
              !resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              pendingApprovalCount == 0,
              !hasPresentationConflict else { return }
        composerIsFocused = false
        if isErrorPhase {
            K3VisualSystem.Haptics.error()
        } else {
            K3VisualSystem.Haptics.success()
        }
        setSurface(.resultPeek)
    }

    private func setSurface(_ mode: AgentSurfaceMode) {
        let animation: Animation = reduceMotion
            ? .easeInOut(duration: 0.18)
            : .easeInOut(duration: 0.20)
        withAnimation(animation) {
            surfaceMode = mode
        }
    }

    private func isTerminal(_ value: AgentPhase) -> Bool {
        switch value {
        case .done, .error: return true
        default: return false
        }
    }

    private var isErrorPhase: Bool {
        if case .error = phase { return true }
        return false
    }

    private var surfaceTransition: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
    }

    private var hasPendingApproval: Bool { pendingApprovalCount > 0 }
    private var isCommandBlank: Bool { commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var badgeText: String { pendingApprovalCount > 99 ? "99+" : String(pendingApprovalCount) }
    private var resultExcerpt: String { resultText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasMarkdownInResult: Bool {
        let r = resultExcerpt
        return r.contains("**") || r.contains("`") || r.contains("##") || r.contains("- ") || r.contains("```")
    }
    private var ballAccessibilityLabel: String {
        var label = "Agent, \(statusText ?? phase.label)"
        if hasPendingApproval { label += ", approval pending" }
        return label
    }
    private var ballAccessibilityHint: String {
        if hasPendingApproval { return "Tap to review the pending approval, or drag to move" }
        if phase.isBusy { return "Tap for current status and Stop, or drag to move" }
        return "Tap to compose a command, or drag to move and snap to an edge"
    }
    private var composerAccessibilityHint: String {
        isConfigured ? "Enter one command for the agent" : "Configure the agent in Mission Control before running a command"
    }
    private var runAccessibilityHint: String {
        if !isConfigured { return "Configure the agent before running a command" }
        if isCommandBlank { return "Enter a command before running" }
        return "Starts the entered command"
    }
}

private extension View {
    func capsuleMaterial(namespace: Namespace.ID, reduceMotion: Bool) -> some View {
        self
            .padding(K3VisualSystem.Space.compact)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(K3VisualSystem.Palette.separator, lineWidth: K3VisualSystem.Space.hairline))
            .agentMatchedGeometry(id: "agent-surface", in: namespace, isSource: false, enabled: !reduceMotion)
    }

    @ViewBuilder
    func agentMatchedGeometry(id: String, in namespace: Namespace.ID, isSource: Bool, enabled: Bool) -> some View {
        if enabled {
            matchedGeometryEffect(id: id, in: namespace, isSource: isSource)
        } else {
            self
        }
    }
}

private struct BallBounds {
    let minX: CGFloat
    let maxX: CGFloat
    let minY: CGFloat
    let maxY: CGFloat
    var height: CGFloat { maxY - minY }
}
