#!/usr/bin/env python3
"""Deterministic source and mutation gates for the modern native UI."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BROWSER = ROOT / "Browser"
UI = BROWSER / "UI"
FILES = {
    "root": BROWSER / "BrowserView.swift",
    "visual": BROWSER / "Design" / "K3VisualSystem.swift",
    "chrome": UI / "BrowserChromeView.swift",
    "dock": UI / "AgentDock.swift",
    "approval": UI / "ApprovalReviewOverlay.swift",
    "mission": UI / "MissionControlView.swift",
}
failures: list[str] = []


def check(name: str, condition: bool) -> None:
    if condition:
        print(f"PASS {name}")
    else:
        failures.append(name)
        print(f"FAIL {name}")


def no_leaf_runtime_dependency(source: str) -> bool:
    return all(token not in source for token in ("BrowserState", "AgentSettings", "WKWebView", "evaluateJavaScript"))


def approval_is_narrow(source: str) -> bool:
    return (
        "let request: ApprovalRequest" in source
        and "let onApprove: () -> Void" in source
        and "let onDeny: () -> Void" in source
        and "request.preview" in source
        and "request.reason" in source
        and "request.call.arguments" not in source
    )


def no_forbidden_color_or_gradient(source: str) -> bool:
    gradient = re.compile(r"\b(?:LinearGradient|RadialGradient|AngularGradient|MeshGradient)\b")
    rgb = re.compile(r"(?:Color|UIColor)\s*\([^\n]*(?:red\s*:|hue\s*:|white\s*:)|#[0-9A-Fa-f]{3,8}\b")
    return not gradient.search(source) and not rgb.search(source)


def ios15_only(source: str) -> bool:
    forbidden = (
        "NavigationStack", "NavigationSplitView", "presentationDetents", "toolbarBackground",
        "scrollContentBackground", "ViewThatFits", "AnyLayout", "Grid(", "GridRow(",
        "ContentUnavailableView", "sensoryFeedback", "symbolEffect", "containerRelativeFrame",
    )
    return all(token not in source for token in forbidden)


sources = {name: path.read_text(encoding="utf-8") if path.is_file() else "" for name, path in FILES.items()}
all_ui = "\n".join(sources.values())

check("all modern UI source files exist", all(path.is_file() for path in FILES.values()))
check("visual contract and semantic palette", all(token in sources["visual"] for token in ("THESIS page-first adaptive native instrument", "OWN-WORLD semantic indigo interaction", "STORY browse quietly", "FIRST VIEWPORT page dominates", "FORM native operator rail", "FINISH unreviewed", "UIColor.systemIndigo" if False else "systemIndigo")))
check("browser chrome leaf has no runtime authority", no_leaf_runtime_dependency(sources["chrome"]))
check("browser chrome leaf mutation self-test", not no_leaf_runtime_dependency(sources["chrome"] + "\nlet state: BrowserState"))
check("chrome search URL and stable progress", all(token in sources["chrome"] for token in (".keyboardType(.webSearch)", ".textContentType(.URL)", "estimatedProgress", ".frame(height: K3VisualSystem.Space.progress)", ".opacity(isLoading ? 1 : 0)")))
check("chrome 44-point navigation targets", sources["chrome"].count("K3VisualSystem.Space.control") >= 2 and all(label in sources["chrome"] for label in ('label: "Back"', 'label: "Forward"', 'label: "Reload"', 'label: "Stop loading"')))
check("Mission Control absent from chrome", "Mission Control" not in sources["chrome"])

composer_labels = all_ui.count('accessibilityLabel("Agent command")')
check("exactly one agent command composer label", composer_labels == 1)
check("dock has exactly one field", len(re.findall(r"\b(?:TextField|SecureField|TextEditor)\s*\(", sources["dock"])) == 1)
check("Mission Control has no command composer", "Agent command" not in sources["mission"] and "commandText" not in sources["mission"])
check("single composer detector mutation self-test", (all_ui + '\n.accessibilityLabel("Agent command")').count('accessibilityLabel("Agent command")') != 1)

check("approval API and preview are narrow", approval_is_narrow(sources["approval"]))
check("approval argument mutation self-test", not approval_is_narrow(sources["approval"] + "\nText(request.call.arguments.description)"))
check("approval blocks with explicit decisions", all(token in sources["approval"] for token in (".ignoresSafeArea()", ".allowsHitTesting(true)", "Button(action: onDeny)", "Button(action: onApprove)", ".accessibilityElement(children: .contain)", "UIAccessibility.post(notification: .announcement")))
check("approval context scrolls with pinned actions", "ScrollView(.vertical" in sources["approval"] and sources["approval"].index("ScrollView(.vertical") < sources["approval"].index("Button(action: onDeny)"))
check("approval is VoiceOver-modal and escape denies", all(token in sources["approval"] for token in ("@AccessibilityFocusState", ".accessibilityFocused($denyIsFocused)", ".accessibilityAction(.escape, onDeny)")) and ".accessibilityHidden(state.pendingApproval != nil)" in sources["root"])
check("approval has exact action-specific authority", all(label in sources["approval"] for label in ("Click once", "Fill once", "Select once", "Submit once", "Open once", "Go back once", "Go forward once", "Reload once", "Scroll once", "Export once", "Run once")))
check("approval CTA uses high contrast interaction tint", ".tint(K3VisualSystem.Palette.interaction)" in sources["approval"] and ".tint(K3VisualSystem.Palette.approval)" not in sources["approval"])
check("approval has no outside dismissal", "onDismiss" not in sources["approval"] and "presentationMode" not in sources["approval"])

check("Mission Control is hierarchical native list", all(token in sources["mission"] for token in ("NavigationView", "List {", "NavigationLink", ".listStyle(.insetGrouped)", 'Button("Done")')))
check("Mission Control root destinations", all(label in sources["mission"] for label in ("Current Run", "Activity", "Page Snapshot", "Manual Tools", "Agent Settings")))
check("Mission selector state durable at root", '@State private var selector = ""' in sources["mission"] and "selector: $selector" in sources["mission"])
check("API key uses SecureField", 'SecureField("API Key", text: $settings.apiKey)' in sources["mission"])
check("timeline uses SF Symbols, not model emoji primary icon", "Image(systemName: symbol(for: step.title))" in sources["mission"] and "step.icon" not in sources["mission"])

check("no gradients or hardcoded RGB/hex", no_forbidden_color_or_gradient(all_ui))
check("color detector mutation self-test", not no_forbidden_color_or_gradient(all_ui + "\nColor(red: 1, green: 0, blue: 0)\nLinearGradient()\n#fff"))
check("iOS 15 API surface", ios15_only(all_ui))
check("iOS API detector mutation self-test", not ios15_only(all_ui + "\nNavigationStack {}"))
check("icon-only controls carry accessibility labels", sources["chrome"].count("chromeButton(") == 5 and ".accessibilityLabel(label)" in sources["chrome"] and sources["dock"].count(".accessibilityLabel(") >= 6)
check("Reduce Motion controls transitions", "@Environment(\\.accessibilityReduceMotion)" in sources["dock"] and sources["dock"].count("reduceMotion: reduceMotion") >= 3)
check("ball and control geometry", all(token in sources["dock"] for token in ("ballDiameter: CGFloat = 56", "minimumTapSize: CGFloat = 44", "dragThreshold: CGFloat = 8")))
check("VoiceOver ball movement", all(token in sources["dock"] for token in ('Text("Move left")', 'Text("Move right")', "moveBall(to: .left)", "moveBall(to: .right)")))
check("final-only snap persistence", "Persist only the final snapped result" in sources["dock"] and "dockPreferences.edge" not in sources["dock"].partition(".onChanged")[2].partition(".onEnded")[0])
check("Run xor Stop", "if phase.isBusy" in sources["dock"] and sources["dock"].count('Label("Run"') == 1 and sources["dock"].count('Label("Stop"') == 1)

check("root uses safe-area shelf and one WKWebView", ".safeAreaInset(edge: .bottom" in sources["root"] and sources["root"].count("WebViewContainer(webView: state.webView)") == 1)
check("single mutually exclusive presentation router", sources["root"].count(".sheet(") == 1 and ".sheet(item: $activePresentation" in sources["root"] and "queuedPresentation" in sources["root"] and "revealApprovalAfterDismiss" in sources["root"])
check("approval dismisses active presentation before reveal", "if activePresentation != nil" in sources["root"] and "activePresentation = nil" in sources["root"] and "presentationDidDismiss" in sources["root"])
check("presentation is blocked during approval", "guard state.pendingApproval == nil else { return }" in sources["root"])
check("approval is top blocking layer", ".zIndex(100)" in sources["root"] and ".disabled(state.pendingApproval != nil)" in sources["root"] and ".accessibilityHidden(state.pendingApproval != nil)" in sources["root"])
check("legacy UI removed", all(token not in sources["root"] for token in ("var topBar", "ApprovalTray", ".pickerStyle(.segmented)", ".ignoresSafeArea(.keyboard")))
check("inline Mission Control removed", "struct MissionControlView" not in sources["root"])
check("no fake tabs library or lock", not re.search(r'Button\s*\(\s*"(?:Tabs|Library)|systemName:\s*"lock', all_ui))

if failures:
    print(f"FAILED {len(failures)} UI architecture invariant(s)")
    sys.exit(1)
print("PASS modern UI architecture invariants and mutation self-tests (Swift compile pending)")
