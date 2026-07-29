#!/usr/bin/env python3
"""Deterministic stdlib validator for the isolated adaptive agent dock."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UI_FILE = ROOT / "Browser" / "UI" / "AgentDock.swift"
PREFERENCES_FILE = ROOT / "Browser" / "AppModel" / "DockPreferences.swift"
PHASE_FILE = ROOT / "Browser" / "Runtime" / "RuntimePhase.swift"
BROWSER_VIEW_FILE = ROOT / "Browser" / "BrowserView.swift"
FAILURES: list[str] = []


def require(name: str, condition: bool) -> None:
    if not condition:
        FAILURES.append(name)


def contains_all(source: str, tokens: tuple[str, ...]) -> bool:
    return all(token in source for token in tokens)


require("AgentDock.swift exists", UI_FILE.is_file())
source = UI_FILE.read_text(encoding="utf-8") if UI_FILE.is_file() else ""
preferences = PREFERENCES_FILE.read_text(encoding="utf-8") if PREFERENCES_FILE.is_file() else ""
phase = PHASE_FILE.read_text(encoding="utf-8") if PHASE_FILE.is_file() else ""
browser_view = BROWSER_VIEW_FILE.read_text(encoding="utf-8") if BROWSER_VIEW_FILE.is_file() else ""
require("supporting source files exist", PREFERENCES_FILE.is_file() and PHASE_FILE.is_file() and BROWSER_VIEW_FILE.is_file())

require(
    "adaptive overlay type and input-only API",
    contains_all(
        source,
        (
            "struct AdaptiveAgentOverlay: View",
            "@ObservedObject var dockPreferences: DockPreferences",
            "@Binding var commandText: String",
            "let phase: AgentPhase",
            "let isConfigured: Bool",
            "let pendingApprovalCount: Int",
            "let engagementLabel: String?",
            "let statusText: String?",
            "let onRun: () -> Void",
            "let onStop: () -> Void",
            "let onOpenMissionControl: () -> Void",
            "let onExpandApproval: () -> Void",
        ),
    ),
)
require(
    "design contract",
    contains_all(
        source.lower(),
        (
            "page remains the workspace",
            "dock is the command/state",
            "ball preserves page area",
            "one composer",
            "no authority decisions",
        ),
    ),
)
require(
    "geometry and safe-area layout",
    contains_all(source, ("GeometryReader", "geometry.safeAreaInsets", "safeBallBounds", "practicalBottomMargin")),
)
require(
    "clamped edge snap",
    contains_all(source, ("func clamp(", "snapAndPersist", "point.x <= midpoint ? .left : .right")),
)
require(
    "final edge and normalized-Y persistence",
    contains_all(
        source,
        (
            "dockPreferences.edge = snappedEdge",
            "dockPreferences.normalizedY = Double(min(max(normalizedY, 0), 1))",
            "Persist only the final snapped result",
        ),
    ),
)
require(
    "collapsed state persists by product contract",
    'static let collapsed = "dock.collapsed"' in preferences
    and "defaults.set(collapsed, forKey: Key.collapsed)" in preferences,
)
require(
    "normalized-Y is finite and clamped",
    preferences.count("isFinite") >= 2
    and "defaults.set(clamped, forKey: Key.normalizedY)" in preferences,
)
on_changed = source.partition(".onChanged")[2].partition(".onEnded")[0]
require(
    "no persistence during drag frames",
    "dockPreferences.edge" not in on_changed and "dockPreferences.normalizedY" not in on_changed,
)
require(
    "rotation-safe derived position",
    contains_all(source, ("dockPreferences.normalizedY", "bounds.minY + normalizedY * bounds.height"))
    and "@State private var absolute" not in source,
)
require(
    "56-point ball and 44-point controls",
    contains_all(source, ("ballDiameter: CGFloat = 56", "minimumTapSize: CGFloat = 44")),
)
require(
    "drag threshold prevents accidental expansion",
    contains_all(
        source,
        (
            "dragThreshold: CGFloat = 8",
            "max(dragDistance, finalDistance) < dragThreshold",
            "DragGesture(minimumDistance: 0",
        ),
    ),
)
composer_count = len(re.findall(r"\b(?:TextField|SecureField|TextEditor)\s*\(", source))
require("exactly one composer", composer_count == 1)
require(
    "configured/busy command disabling",
    ".disabled(!isConfigured || phase.isBusy)" in source,
)
require(
    "configured/busy/blank run disabling",
    ".disabled(!isConfigured || isCommandBlank || phase.isBusy)" in source
    and "trimmingCharacters(in: .whitespacesAndNewlines).isEmpty" in source,
)
require(
    "run-or-stop phase switch",
    "if phase.isBusy" in source and 'Label("Stop"' in source and 'Label("Run"' in source,
)
require(
    "approval badge and action",
    contains_all(
        source,
        (
            "if hasPendingApproval",
            "Button(action: onExpandApproval)",
            "private var badgeText: String",
            "pendingApprovalCount > 0",
        ),
    ),
)
require(
    "status and mission control always in dock",
    contains_all(source, ("statusText ?? phase.label", "Button(action: onOpenMissionControl)")),
)
require(
    "accessibility labels and hints",
    source.count(".accessibilityLabel(") >= 7 and source.count(".accessibilityHint(") >= 7
    and ".accessibilityAction { expand() }" in source,
)
require(
    "keyboard-safe composition",
    contains_all(source, ("@FocusState", ".focused($composerIsFocused)", ".submitLabel(.go)"))
    and ".ignoresSafeArea(.keyboard" not in source,
)
require(
    "bounded scrollable dock for keyboard and Dynamic Type",
    contains_all(
        source,
        (
            "expandedDock(in: geometry)",
            "let maximumDockHeight",
            "let maximumDockHeight = max(\n            0,",
            "geometry.size.height - geometry.safeAreaInsets.top",
            "ScrollView(.vertical",
            ".frame(maxHeight: maximumDockHeight)",
        ),
    ),
)
require(
    "animated edge snap",
    "withAnimation(.easeOut(duration: animationDuration))" in source
    and source.find("withAnimation(.easeOut(duration: animationDuration))")
    < source.find("snapAndPersist(finalPoint"),
)
require(
    "phase support",
    "enum AgentPhase" in phase and "var isBusy: Bool" in phase,
)
require(
    "single adaptive overlay integration",
    browser_view.count("AdaptiveAgentOverlay(") == 1
    and "commandText: $state.commandText" in browser_view
    and "@StateObject private var dockPreferences = DockPreferences()" in browser_view,
)
require(
    "legacy command shell removed",
    "var bottomCommandBar" not in browser_view
    and "AgentCockpitView" not in browser_view
    and "showCockpit" not in browser_view
    and 'TextField("Tell K3 what to do' not in browser_view,
)
require(
    "Mission Control and approval checkpoint integration",
    "struct MissionControlView: View" in browser_view
    and "showMissionControl" in browser_view
    and "ApprovalTray(" in browser_view
    and "onExpandApproval:" in browser_view,
)
durations = [float(value) for value in re.findall(r"(?:animationDuration\s*=|duration:)\s*([0-9]+(?:\.[0-9]+)?)", source)]
require("150-250ms animations", bool(durations) and all(0.15 <= value <= 0.25 for value in durations))
imports = re.findall(r"^import\s+([^\s]+)", source, flags=re.MULTILINE)
require("SwiftUI-only import", imports == ["SwiftUI"])
require(
    "no gradient decoration",
    not re.search(r"\b(?:LinearGradient|RadialGradient|AngularGradient|MeshGradient)\b", source),
)
require(
    "no hardcoded platform product names",
    not re.search(r"\b(?:iPhone|iPad|macOS|watchOS|visionOS)\b", source, flags=re.IGNORECASE),
)
require(
    "no BrowserState or AgentSettings dependency",
    "BrowserState" not in source and "AgentSettings" not in source,
)

if FAILURES:
    for failure in FAILURES:
        print(f"FAIL {failure}")
    print(f"FAILED {len(FAILURES)} agent-dock invariant(s)")
    sys.exit(1)

print("PASS adaptive agent dock source invariants (Swift compile/layout tests pending)")
