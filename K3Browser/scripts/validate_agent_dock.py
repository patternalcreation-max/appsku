#!/usr/bin/env python3
"""Deterministic stdlib validator for the Magnetic Capsule agent surface."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCK = ROOT / "Browser" / "UI" / "AgentDock.swift"
PREFERENCES = ROOT / "Browser" / "AppModel" / "DockPreferences.swift"
PHASE = ROOT / "Browser" / "Runtime" / "RuntimePhase.swift"
VIEW = ROOT / "Browser" / "BrowserView.swift"
failures: list[str] = []


def require(name: str, condition: bool) -> None:
    print(("PASS " if condition else "FAIL ") + name)
    if not condition:
        failures.append(name)


def between(text: str, start: str, end: str) -> str:
    return text.partition(start)[2].partition(end)[0]


def centralized_terminal_result(root: str) -> bool:
    body = between(root, "private var agentResultText: String", "private var agentOverlay")
    ordered = ["state.agentAnswer", "if case .error(let message)", "state.steps.last", "state.phase.label"]
    positions = [body.find(token) for token in ordered]
    return (
        bool(body)
        and all(position >= 0 for position in positions)
        and positions == sorted(positions)
        and "case .done, .error:" in body
        and body.count("Redactor.text(") >= 4
        and "resultText: agentResultText" in root
        and "resultText: state.agentAnswer" not in root
    )


def terminal_conflict_recovery(dock: str) -> bool:
    reveal = between(dock, "private func revealTerminalResultIfEligible()", "private func setSurface")
    phase_change = between(dock, ".onChange(of: phase)", ".onChange(of: pendingApprovalCount)")
    approval_change = between(dock, ".onChange(of: pendingApprovalCount)", ".onChange(of: hasPresentationConflict)")
    conflict_change = between(dock, ".onChange(of: hasPresentationConflict)", "@ViewBuilder")
    return all((
        all(token in reveal for token in (
            "isTerminal(phase)", "!resultText.trimmingCharacters", "pendingApprovalCount == 0",
            "!hasPresentationConflict", "setSurface(.resultPeek)")),
        "revealTerminalResultIfEligible()" in phase_change,
        "count > 0" in approval_change and "else if count == 0" in approval_change
            and "revealTerminalResultIfEligible()" in approval_change,
        "if hasConflict" in conflict_change and "else if !hasConflict" in conflict_change
            and "revealTerminalResultIfEligible()" in conflict_change,
    ))


def compact_ax_adaptation(dock: str) -> bool:
    compose = between(dock, "private func composeCapsule", "private var composerField")
    active = between(dock, "private func activeCapsule", "private func resultCapsule")
    result = between(dock, "private func resultCapsule", "private func adaptiveCapsuleLayout")
    layout = between(dock, "private func adaptiveCapsuleLayout", "private var missionControlButton")
    return all((
        "@Environment(\\.dynamicTypeSize)" in dock,
        "geometry.size.width" in dock and "availableWidth:" in dock,
        "availableWidth < 420 || dynamicTypeSize.isAccessibilitySize" in layout,
        "AnyLayout(VStackLayout" in layout and "AnyLayout(HStackLayout" in layout,
        all("adaptiveCapsuleLayout(availableWidth: availableWidth)" in section for section in (compose, active, result)),
        len(re.findall(r"\b(?:TextField|SecureField|TextEditor)\s*\(", dock)) == 1,
        "private var composerField" in dock,
        all(token in compose for token in ("missionControlButton", "composerField", 'Label("Run"', "collapseButton")),
        dock.count("minimumTapSize") >= 10,
    ))


def reduce_motion_crossfade(dock: str) -> bool:
    set_surface = between(dock, "private func setSurface", "private func isTerminal")
    transition = between(dock, "private var surfaceTransition", "private var hasPendingApproval")
    modifier = between(dock, "func agentMatchedGeometry", "private struct BallBounds")
    return all((
        "@Environment(\\.accessibilityReduceMotion)" in dock,
        "? .easeInOut(duration: 0.18)" in set_surface,
        ": .easeInOut(duration: 0.20)" in set_surface,
        "withAnimation(animation)" in set_surface and "withAnimation(nil)" not in set_surface,
        "reduceMotion ? .opacity" in transition and ".scale(scale: 0.96" in transition,
        "if enabled" in modifier and "matchedGeometryEffect" in modifier and "else" in modifier,
        dock.count("matchedGeometryEffect(") == 1,
        '.agentMatchedGeometry(id: "agent-surface", in: agentGeometry, isSource: true, enabled: !reduceMotion)' in dock,
        '.agentMatchedGeometry(id: "agent-surface", in: namespace, isSource: false, enabled: !reduceMotion)' in dock,
    ))


source = DOCK.read_text(encoding="utf-8") if DOCK.is_file() else ""
preferences = PREFERENCES.read_text(encoding="utf-8") if PREFERENCES.is_file() else ""
phase = PHASE.read_text(encoding="utf-8") if PHASE.is_file() else ""
view = VIEW.read_text(encoding="utf-8") if VIEW.is_file() else ""

require("source files exist", all(path.is_file() for path in (DOCK, PREFERENCES, PHASE, VIEW)))
require("input-only adaptive overlay API", all(token in source for token in (
    "struct AdaptiveAgentOverlay: View", "@ObservedObject var dockPreferences: DockPreferences",
    "@Binding var commandText: String", "let phase: AgentPhase", "let resultText: String",
    "let hasPresentationConflict: Bool", "let onRun: () -> Void", "let onStop: () -> Void",
    "let onOpenMissionControl: () -> Void", "let onExpandApproval: () -> Void")))
require("no runtime owner dependency", all(token not in source for token in ("BrowserState", "AgentSettings", "WKWebView")))
require("exclusive local surface modes", all(token in source for token in (
    "enum AgentSurfaceMode", "case collapsed", "case compose", "case activePeek", "case resultPeek",
    "@State private var surfaceMode: AgentSurfaceMode = .collapsed")))
require("one command field and label", len(re.findall(r"\b(?:TextField|SecureField|TextEditor)\s*\(", source)) == 1 and source.count('accessibilityLabel("Agent command")') == 1)
require("compose-only modern input", all(token in source for token in ("private func composeCapsule", "private var composerField", "@FocusState", ".focused($composerIsFocused)", ".submitLabel(.go)", ".textInputAutocapitalization(.never)", ".autocorrectionDisabled()")))
require("busy removes composer", "if phase.isBusy" in source and "setSurface(.collapsed)" in source and "case .compose:" in source)
require("Magnetic Capsule has no shelf or scroll form", all(token not in source for token in ("expandedShelf", "statusHeader", "actionRow", "ScrollView(.vertical")))
require("capsule overlays bottom with 16 inset and keyboard safety", ".padding(.horizontal, capsuleInset)" in source and "capsuleInset: CGFloat = 16" in source and ".safeAreaPadding(.bottom" in source)
require("56 44 8 geometry", all(token in source for token in ("ballDiameter: CGFloat = 56", "minimumTapSize: CGFloat = 44", "dragThreshold: CGFloat = 8")))
require("clamped safe-area edge snap", all(token in source for token in ("geometry.safeAreaInsets", "safeBallBounds", "func clamp(", "point.x <= midpoint ? .left : .right")))
changed = source.partition(".onChanged")[2].partition(".onEnded")[0]
require("persist final snap only", "dockPreferences.edge" not in changed and "dockPreferences.normalizedY" not in changed and "Persist only the final snapped result" in source)
require("tap versus drag threshold", "DragGesture(minimumDistance: 0" in source and "max(dragDistance, finalDistance) < dragThreshold" in source)
require("launch and reset are collapsed without surface persistence", "collapsed" not in preferences and "edge = .right" in preferences and "normalizedY = 0.72" in preferences)
require("normalized Y finite and clamped", preferences.count("isFinite") >= 2 and "defaults.set(clamped, forKey: Key.normalizedY)" in preferences)
require("explicit Mission Stop Run collapse", all(token in source for token in ('Label("Mission Control"', 'Label("Stop"', 'Label("Run"', 'accessibilityLabel("Collapse agent capsule")')))
require("approval badge and explicit review", "if hasPendingApproval" in source and "onExpandApproval()" in source and 'Button("Review")' in source and "badgeText" in source)
require("result peek is readable and durable", all(token in source for token in ("private func resultCapsule", "Text(resultExcerpt)", ".lineLimit(2)", 'Text("Details")', 'accessibilityLabel("Dismiss result")')) and "asyncAfter" not in source)
require("centralized redacted terminal result fallback", centralized_terminal_result(view))
require("centralized result mutation self-test", not centralized_terminal_result(view.replace("state.steps.last", "nil as AgentStep?", 1)))
require("terminal result conflict recovery", terminal_conflict_recovery(source))
require("terminal conflict recovery mutation self-test", not terminal_conflict_recovery(source.replace("else if count == 0 {\n                revealTerminalResultIfEligible()", "else if count == 0 {", 1)))
require("result semantics distinguish error and success", "isErrorPhase" in source and "K3VisualSystem.Palette.error" in source and "K3VisualSystem.Palette.success" in source)
require("phase remains runtime truth", "K3VisualSystem.presentation(for: phase)" in source and "var isBusy: Bool" in phase)
require("Reduce Motion uses a real crossfade and conditional geometry", reduce_motion_crossfade(source))
require("Reduce Motion mutation self-test", not reduce_motion_crossfade(source.replace("? .easeInOut(duration: 0.18)", "? nil", 1)))
require("compact and AX layout adapts one composer", compact_ax_adaptation(source))
require("compact layout mutation self-test", not compact_ax_adaptation(source.replace(" || dynamicTypeSize.isAccessibilitySize", "", 1)))
require("VoiceOver named primary move and contextual actions", all(token in source for token in ('Button("Compose")', 'Button("Open status")', 'Button("Move left")', 'Button("Move right")', 'Button("Stop", role: .destructive)', 'Button("Review")', 'Button("Mission Control")', "moveBall(to: .left)", "moveBall(to: .right)", "if phase.isBusy", "if hasPendingApproval")))
require("single root overlay without page resize", view.count("AdaptiveAgentOverlay(") == 1 and view.count("WebViewContainer(webView: state.webView)") == 1 and ".safeAreaInset(edge: .bottom" not in view and ".ignoresSafeArea(.keyboard, edges: .bottom)" in view)
require("result and conflict passed from root", "resultText: agentResultText" in view and "hasPresentationConflict:" in view)
require("no legacy shell", all(token not in view + source for token in ("bottomCommandBar", "AgentCockpitView", "showCockpit", "ApprovalTray", "expandedShelf")))
require("SwiftUI-only import", re.findall(r"^import\s+([^\s]+)", source, re.MULTILINE) == ["SwiftUI"])
require("no gradients glow pulse fake controls or card stack", not re.search(r"Gradient|shadow\s*\(|glow|pulse|card(?:Stack)?|Button\s*\(\s*\"(?:Tabs|Library)", source, re.IGNORECASE))

if failures:
    print(f"FAILED {len(failures)} Magnetic Capsule invariant(s)")
    sys.exit(1)
print("PASS Magnetic Capsule source invariants and mutation self-tests (Swift compile/layout tests pending CI)")
