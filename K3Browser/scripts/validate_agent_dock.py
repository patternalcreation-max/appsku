#!/usr/bin/env python3
"""Deterministic stdlib validator for the adaptive agent shelf and ball."""
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
    if not condition:
        failures.append(name)
        print(f"FAIL {name}")
    else:
        print(f"PASS {name}")


source = DOCK.read_text(encoding="utf-8") if DOCK.is_file() else ""
preferences = PREFERENCES.read_text(encoding="utf-8") if PREFERENCES.is_file() else ""
phase = PHASE.read_text(encoding="utf-8") if PHASE.is_file() else ""
view = VIEW.read_text(encoding="utf-8") if VIEW.is_file() else ""

require("source files exist", all(path.is_file() for path in (DOCK, PREFERENCES, PHASE, VIEW)))
require("input-only adaptive overlay API", all(token in source for token in ("struct AdaptiveAgentOverlay: View", "@ObservedObject var dockPreferences: DockPreferences", "@Binding var commandText: String", "let phase: AgentPhase", "let onRun: () -> Void", "let onStop: () -> Void", "let onOpenMissionControl: () -> Void", "let onExpandApproval: () -> Void")))
require("no runtime owner dependency", "BrowserState" not in source and "AgentSettings" not in source and "WKWebView" not in source)
require("one command field", len(re.findall(r"\b(?:TextField|SecureField|TextEditor)\s*\(", source)) == 1 and source.count('accessibilityLabel("Agent command")') == 1)
require("expanded bottom shelf", "private var expandedShelf" in source and ".background(.regularMaterial)" in source and ".frame(maxHeight: sizeCategory.isAccessibilityCategory ? 270 : 190)" in source)
require("bounded Dynamic Type layout", "@Environment(\\.sizeCategory)" in source and "ScrollView(.vertical" in source and "sizeCategory.isAccessibilityCategory" in source)
require("keyboard focus is bounded", "@FocusState" in source and ".focused($composerIsFocused)" in source and ".ignoresSafeArea(.keyboard" not in source)
require("56 44 8 geometry", all(token in source for token in ("ballDiameter: CGFloat = 56", "minimumTapSize: CGFloat = 44", "dragThreshold: CGFloat = 8")))
require("clamped safe-area edge snap", all(token in source for token in ("geometry.safeAreaInsets", "safeBallBounds", "func clamp(", "point.x <= midpoint ? .left : .right")))
changed = source.partition(".onChanged")[2].partition(".onEnded")[0]
require("persist final snap only", "dockPreferences.edge" not in changed and "dockPreferences.normalizedY" not in changed and "Persist only the final snapped result" in source)
require("tap versus drag threshold", "DragGesture(minimumDistance: 0" in source and "max(dragDistance, finalDistance) < dragThreshold" in source)
require("collapsed preference persists", 'static let collapsed = "dock.collapsed"' in preferences and "defaults.set(collapsed, forKey: Key.collapsed)" in preferences)
require("normalized Y finite and clamped", preferences.count("isFinite") >= 2 and "defaults.set(clamped, forKey: Key.normalizedY)" in preferences)
require("Run xor Stop", "if phase.isBusy" in source and source.count('Label("Run"') == 1 and source.count('Label("Stop"') == 1)
require("approval badge and reopen", "if hasPendingApproval" in source and "Button(action: onExpandApproval)" in source and "badgeText" in source)
require("Mission Control available", "Button(action: onOpenMissionControl)" in source)
require("phase semantics", "K3VisualSystem.presentation(for: phase)" in source and "var isBusy: Bool" in phase)
require("Reduce Motion", "@Environment(\\.accessibilityReduceMotion)" in source and source.count("reduceMotion: reduceMotion") >= 3)
require("VoiceOver move actions", all(token in source for token in ('Text("Move left")', 'Text("Move right")', "moveBall(to: .left)", "moveBall(to: .right)")))
require("accessibility coverage", source.count(".accessibilityLabel(") >= 6 and source.count(".accessibilityHint(") >= 6)
require("single root integration", view.count("AdaptiveAgentOverlay(") == 1 and "commandText: $state.commandText" in view and "@StateObject private var dockPreferences = DockPreferences()" in view)
require("safe-area shelf integration", ".safeAreaInset(edge: .bottom" in view and "if !dockPreferences.collapsed" in view)
require("no legacy shell", all(token not in view for token in ("bottomCommandBar", "AgentCockpitView", "showCockpit", "ApprovalTray")))
require("SwiftUI-only import", re.findall(r"^import\s+([^\s]+)", source, re.MULTILINE) == ["SwiftUI"])
require("no gradients glow pulse or card stack", not re.search(r"Gradient|shadow\s*\(|pulse|card", source, re.IGNORECASE))

if failures:
    print(f"FAILED {len(failures)} agent-dock invariant(s)")
    sys.exit(1)
print("PASS adaptive agent shelf source invariants (Swift compile/layout tests pending)")
