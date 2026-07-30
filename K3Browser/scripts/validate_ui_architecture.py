#!/usr/bin/env python3
"""Deterministic source and mutation gates for the latest-iOS native UI."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
BROWSER = ROOT / "Browser"
UI = BROWSER / "UI"
FILES = {
    "root": BROWSER / "BrowserView.swift", "visual": BROWSER / "Design" / "K3VisualSystem.swift",
    "chrome": UI / "BrowserChromeView.swift", "dock": UI / "AgentDock.swift",
    "approval": UI / "ApprovalReviewOverlay.swift", "mission": UI / "MissionControlView.swift",
    "project": ROOT / "project.yml", "workflow": REPO / ".github" / "workflows" / "build-k3browser.yml",
}
failures: list[str] = []


def check(name: str, condition: bool) -> None:
    print(("PASS " if condition else "FAIL ") + name)
    if not condition:
        failures.append(name)


def no_leaf_runtime_dependency(source: str) -> bool:
    return all(token not in source for token in ("BrowserState", "AgentSettings", "WKWebView", "evaluateJavaScript"))


def approval_is_narrow(source: str) -> bool:
    return all(token in source for token in ("let request: ApprovalRequest", "let onApprove: () -> Void", "let onDeny: () -> Void", "request.preview", "request.reason")) and "request.call.arguments" not in source


def no_forbidden_visuals(source: str) -> bool:
    return not re.search(r"\b(?:LinearGradient|RadialGradient|AngularGradient|MeshGradient)\b|\b(?:glow|pulse|particle|cardStack)\b", source, re.I)


def between(text: str, start: str, end: str) -> str:
    return text.partition(start)[2].partition(end)[0]


def terminal_result_plumbing(root: str, dock: str) -> bool:
    fallback = between(root, "private var agentResultText: String", "private var agentOverlay")
    ordered = ["if case .error(let message)", "state.agentAnswer", "state.steps.last", "state.phase.label"]
    positions = [fallback.find(token) for token in ordered]
    reveal = between(dock, "private func revealTerminalResultIfEligible()", "private func setSurface")
    approval_change = between(dock, ".onChange(of: pendingApprovalCount)", ".onChange(of: hasPresentationConflict)")
    conflict_change = between(dock, ".onChange(of: hasPresentationConflict)", "@ViewBuilder")
    return all((
        "state.agentAnswer" in fallback,
        "if case .error(let message)" in fallback,
        "state.steps.last" in fallback,
        all(position >= 0 for position in positions) and positions == sorted(positions),
        "case .done, .error:" in fallback,
        fallback.count("Redactor.text(") >= 4,
        "return Redactor.text(state.phase.label)" in fallback,
        "resultText: agentResultText" in root,
        all(token in reveal for token in ("isTerminal(phase)", "pendingApprovalCount == 0", "!hasPresentationConflict", "setSurface(.resultPeek)")),
        "else if count == 0" in approval_change and "revealTerminalResultIfEligible()" in approval_change,
        "else if !hasConflict" in conflict_change and "revealTerminalResultIfEligible()" in conflict_change,
    ))


def compact_capsule_adaptation(dock: str) -> bool:
    layout = between(dock, "private func adaptiveCapsuleLayout", "private var missionControlButton")
    return all((
        "@Environment(\\.dynamicTypeSize)" in dock,
        "availableWidth < 420 || dynamicTypeSize.isAccessibilitySize" in layout,
        "AnyLayout(VStackLayout" in layout and "AnyLayout(HStackLayout" in layout,
        dock.count("adaptiveCapsuleLayout(availableWidth: availableWidth)") == 3,
        "geometry.size.width" in dock,
        len(re.findall(r"\b(?:TextField|SecureField|TextEditor)\s*\(", dock)) == 1,
        "private var composerField" in dock,
    ))


def reduce_motion_crossfade(dock: str) -> bool:
    set_surface = between(dock, "private func setSurface", "private func isTerminal")
    modifier = between(dock, "func agentMatchedGeometry", "private struct BallBounds")
    return all((
        "? .easeInOut(duration: 0.18)" in set_surface,
        ": .easeInOut(duration: 0.20)" in set_surface,
        "withAnimation(animation)" in set_surface,
        "reduceMotion ? .opacity" in dock,
        "if enabled" in modifier and "matchedGeometryEffect" in modifier and "else" in modifier,
        dock.count("matchedGeometryEffect(") == 1,
        "isSource: true, enabled: !reduceMotion" in dock,
        "isSource: false, enabled: !reduceMotion" in dock,
    ))


def named_actions_and_control_sizes(dock: str) -> bool:
    actions = between(dock, ".accessibilityActions {", "private func ballDragGesture")
    return all((
        'minimumTapSize: CGFloat = 44' in dock,
        'if hasPendingApproval {\n                Button("Review")' in actions,
        '} else if phase.isBusy {\n                Button("Open status")' in actions,
        '} else {\n                Button("Compose")' in actions,
        'if phase.isBusy {\n                Button("Stop", role: .destructive)' in actions,
        'Button("Move left")' in actions and 'Button("Move right")' in actions,
        'Button("Mission Control")' in actions,
        dock.count("minHeight: minimumTapSize") >= 4,
        dock.count("width: minimumTapSize") >= 3,
    ))


sources = {name: path.read_text(encoding="utf-8") if path.is_file() else "" for name, path in FILES.items()}
all_ui = "\n".join(sources[name] for name in ("root", "visual", "chrome", "dock", "approval", "mission"))

check("all UI and configuration files exist", all(path.is_file() for path in FILES.values()))
check("Magnetic Capsule visual contract and semantic palette", all(token in sources["visual"] for token in ("THESIS page-first Magnetic Capsule", "Ball is the agent", "page never yields layout", "systemIndigo", "systemOrange", "systemRed", "systemGreen", "static let control: CGFloat = 44", "static let ball: CGFloat = 56", "static let dragThreshold: CGFloat = 8")))
check("browser chrome leaf has no runtime authority", no_leaf_runtime_dependency(sources["chrome"]))
check("browser chrome leaf mutation self-test", not no_leaf_runtime_dependency(sources["chrome"] + "\nlet state: BrowserState"))
check("chrome search URL and stable progress", all(token in sources["chrome"] for token in (".keyboardType(.webSearch)", ".textContentType(.URL)", "estimatedProgress", ".frame(height: K3VisualSystem.Space.progress)", ".opacity(isLoading ? 1 : 0)")))
check("chrome 44-point navigation targets", sources["chrome"].count("K3VisualSystem.Space.control") >= 2 and all(label in sources["chrome"] for label in ('label: "Back"', 'label: "Forward"', 'label: "Reload"', 'label: "Stop loading"')))
check("Mission Control absent from chrome", "Mission Control" not in sources["chrome"])
check("exactly one command composer and field", all_ui.count('accessibilityLabel("Agent command")') == 1 and len(re.findall(r"\b(?:TextField|SecureField|TextEditor)\s*\(", sources["dock"])) == 1)
check("Mission Control has no command composer", "Agent command" not in sources["mission"] and "commandText" not in sources["mission"])
check("single composer detector mutation self-test", (all_ui + '\n.accessibilityLabel("Agent command")').count('accessibilityLabel("Agent command")') != 1)
check("exclusive local surface modes and busy composer removal", all(token in sources["dock"] for token in ("enum AgentSurfaceMode", "case collapsed", "case compose", "case activePeek", "case resultPeek", "if phase.isBusy", "setSurface(.collapsed)")))
check("readable result peek and root redacted result plumbing", all(token in sources["dock"] for token in ("private func resultCapsule", "Text(resultExcerpt)", ".lineLimit(2)", 'Text("Details")', 'accessibilityLabel("Dismiss result")')) and terminal_result_plumbing(sources["root"], sources["dock"]))
check("terminal result recovery mutation self-test", not terminal_result_plumbing(sources["root"], sources["dock"].replace("else if !hasConflict", "else if hasConflict", 1)))
check("terminal result fallback mutation self-test", not terminal_result_plumbing(sources["root"].replace("state.steps.last", "nil as AgentStep?", 1), sources["dock"]))
check("terminal error precedence mutation self-test", not terminal_result_plumbing(sources["root"].replace("if case .error(let message)", "if case .done", 1), sources["dock"]))

check("approval API and preview are narrow", approval_is_narrow(sources["approval"]))
check("approval argument mutation self-test", not approval_is_narrow(sources["approval"] + "\nText(request.call.arguments.description)"))
check("approval blocks with explicit decisions", all(token in sources["approval"] for token in (".ignoresSafeArea()", ".allowsHitTesting(true)", "Button(action: onDeny)", "Button(action: onApprove)", ".accessibilityElement(children: .contain)", "UIAccessibility.post(notification: .announcement")))
check("approval context scrolls with pinned actions", "ScrollView(.vertical" in sources["approval"] and sources["approval"].index("ScrollView(.vertical") < sources["approval"].index("Button(action: onDeny)"))
check("approval is VoiceOver-modal and escape denies", all(token in sources["approval"] for token in ("@AccessibilityFocusState", ".accessibilityFocused($denyIsFocused)", ".accessibilityAction(.escape, onDeny)")) and ".accessibilityHidden(state.pendingApproval != nil)" in sources["root"])
check("approval exact action labels retained", all(label in sources["approval"] for label in ("Click once", "Fill once", "Select once", "Submit once", "Open once", "Go back once", "Go forward once", "Reload once", "Scroll once", "Export once", "Run once")))
check("approval craft uses exact action first and one-point risk accent", "Text(approveLabel)" in sources["approval"] and "Text(request.call.tool.rawValue)" in sources["approval"] and ".frame(height: K3VisualSystem.Space.hairline)" in sources["approval"])
check("approval has no outside dismissal", "onDismiss" not in sources["approval"] and "presentationMode" not in sources["approval"])

check("Mission Control uses NavigationStack", "NavigationStack {" in sources["mission"] and "NavigationView" not in sources["mission"] and ".navigationViewStyle" not in sources["mission"])
check("Mission Control root destinations", all(label in sources["mission"] for label in ("Current Run", "Activity", "Page Snapshot", "Manual Tools", "Agent Settings")))
check("Mission Control modern input modifiers", ".textInputAutocapitalization(.never)" in sources["mission"] and ".autocorrectionDisabled()" in sources["mission"] and ".autocapitalization(" not in sources["mission"] and ".disableAutocorrection(" not in sources["mission"])
check("Mission sheet detents and drag indicator only on mission route", sources["root"].count(".presentationDetents([.medium, .large])") == 1 and sources["root"].count(".presentationDragIndicator(.visible)") == 1 and "presentationBackgroundInteraction" not in all_ui)
check("API key uses SecureField", 'SecureField("API Key", text: $settings.apiKey)' in sources["mission"])
check("timeline uses SF Symbols", "Image(systemName: symbol(for: step.title))" in sources["mission"] and "step.icon" not in sources["mission"])

check("no forbidden visual effects", no_forbidden_visuals(all_ui))
check("visual detector mutation self-test", not no_forbidden_visuals(all_ui + "\nLinearGradient()\n.shadow(radius: 4)\npulse"))
check("icon-only controls carry accessibility labels", sources["chrome"].count("chromeButton(") == 6 and ".accessibilityLabel(label)" in sources["chrome"] and sources["dock"].count(".accessibilityLabel(") >= 8)
check("Reduce Motion uses opacity animation and conditional shared geometry", reduce_motion_crossfade(sources["dock"]))
check("Reduce Motion mutation self-test", not reduce_motion_crossfade(sources["dock"].replace("? .easeInOut(duration: 0.18)", "? nil", 1)))
check("compact and AX capsule adaptation with one field", compact_capsule_adaptation(sources["dock"]))
check("compact adaptation mutation self-test", not compact_capsule_adaptation(sources["dock"].replace(" || dynamicTypeSize.isAccessibilitySize", "", 1)))
check("ball geometry VoiceOver and final persistence", named_actions_and_control_sizes(sources["dock"]) and "dragThreshold: CGFloat = 8" in sources["dock"] and "Persist only the final snapped result" in sources["dock"] and "dockPreferences.edge" not in sources["dock"].partition(".onChanged")[2].partition(".onEnded")[0])
check("VoiceOver action-condition mutation self-test", not named_actions_and_control_sizes(sources["dock"].replace("else if phase.isBusy", "else if !phase.isBusy", 1)))
check("minimum-control-size mutation self-test", not named_actions_and_control_sizes(sources["dock"].replace("minimumTapSize: CGFloat = 44", "minimumTapSize: CGFloat = 43", 1)))
check("no page-resizing agent safe-area inset", ".safeAreaInset(edge: .bottom" not in sources["root"] and ".ignoresSafeArea(.keyboard, edges: .bottom)" in sources["root"] and sources["root"].count("WebViewContainer(webView: state.webView)") == 1 and sources["root"].count("AdaptiveAgentOverlay(") == 1)
check("single owners", all(sources["root"].count(token) == 1 for token in ("@StateObject private var state = BrowserState()", "@StateObject private var settings = AgentSettings()", "@StateObject private var dockPreferences = DockPreferences()")))
check("single mutually exclusive presentation router", sources["root"].count(".sheet(") == 1 and ".sheet(item: $activePresentation" in sources["root"] and "queuedPresentation" in sources["root"] and "revealApprovalAfterDismiss" in sources["root"])
check("approval presentation supremacy", all(token in sources["root"] for token in ("if activePresentation != nil", "activePresentation = nil", "presentationDidDismiss", "guard state.pendingApproval == nil else { return }", ".zIndex(100)", ".disabled(state.pendingApproval != nil)", ".accessibilityHidden(state.pendingApproval != nil)")))
check("latest iOS deployment target only", 'iOS: "26.0"' in sources["project"] and 'iOS: "15.0"' not in sources["project"])
check("macOS 26 and Xcode 26 workflow", all(token in sources["workflow"] for token in ("runs-on: macos-26", "Xcode_26.6.app", "Xcode_26.5.app", "Xcode_26.4.1.app", "Xcode_26.4.app", "Xcode_26.3.app", "/Applications/Xcode.app", "xcodebuild -version")) and "Xcode_27" not in sources["workflow"])
check("no legacy shell fake controls gradient glow pulse", all(token not in all_ui for token in ("expandedShelf", "AgentCockpitView", "ApprovalTray", ".pickerStyle(.segmented)")) and not re.search(r'Button\s*\(\s*"(?:Tabs|Library)|systemName:\s*"lock', all_ui))

if failures:
    print(f"FAILED {len(failures)} UI architecture invariant(s)")
    sys.exit(1)
print("PASS latest-iOS Magnetic Capsule architecture and mutation self-tests (Swift compile pending CI)")
