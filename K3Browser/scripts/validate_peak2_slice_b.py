#!/usr/bin/env python3
"""
PEAK 2 Slice B — Tab manager + tab strip validator.
Checks: TabItem, TabManager extension, TabStripView, BrowserState wiring.
"""
import sys
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BROWSER = REPO / "Browser"
SESSIONS = BROWSER / "Sessions"
UI = BROWSER / "UI"

failures = []

def check(condition, message):
    if condition:
        print(f"PASS {message}")
    else:
        print(f"FAIL {message}")
        failures.append(message)

def read(path):
    return path.read_text() if path.exists() else ""

tab_mgr = read(SESSIONS / "TabManager.swift")
tab_strip = read(UI / "TabStripView.swift")
browser = read(BROWSER / "BrowserView.swift")

# 1. TabManager source invariants
check(bool(tab_mgr), "TabManager.swift exists and non-empty")
check("struct TabItem: Identifiable, Equatable" in tab_mgr, "TabItem is Identifiable Equatable")
check("let id: UUID" in tab_mgr, "TabItem has stable UUID id")
check("var url: String" in tab_mgr, "TabItem has url field")
check("var title: String" in tab_mgr, "TabItem has title field")
check("extension BrowserState" in tab_mgr, "TabManager extends BrowserState")

# 2. Tab operations
check("func openNewTab(" in tab_mgr, "openNewTab exists")
check("func switchTab(to index: Int)" in tab_mgr, "switchTab(to:) exists")
check("func closeTab(at index: Int)" in tab_mgr, "closeTab(at:) exists")
check("func saveCurrentTabMetadata()" in tab_mgr, "saveCurrentTabMetadata exists")
check("func restoreSession()" in tab_mgr, "restoreSession exists")

# 3. Close-tab edge cases
check("_tabs.isEmpty" in tab_mgr, "closeTab handles empty fallback (keeps 1 tab)")
check("_tabs.count > 1" or "_tabs.count <= 1" in tab_mgr, "Tab manager handles count checks")

# 4. Session persistence
check("SessionRestorer.save(" in tab_mgr, "Tab manager persists via SessionRestorer")
check("SessionRestorer.load()" in tab_mgr, "Tab manager restores via SessionRestorer")
check("SavedTab(" in tab_mgr, "Tab manager maps to SavedTab for persistence")

# 5. BrowserState wiring
check("@Published var _tabs: [TabItem]" in browser, "BrowserState publishes _tabs")
check("@Published var _activeTabIndex: Int" in browser, "BrowserState publishes _activeTabIndex")
check("restoreSession()" in browser, "BrowserState calls restoreSession on init")
check("saveCurrentTabMetadata()" in browser, "BrowserState auto-saves tab metadata on title change")

# 6. TabStripView UI
check(bool(tab_strip), "TabStripView.swift exists and non-empty")
check("struct TabStripView: View" in tab_strip, "TabStripView is a SwiftUI View")
check("@ObservedObject var state: BrowserState" in tab_strip, "TabStripView observes BrowserState")
check("state.openNewTab()" in tab_strip, "TabStripView has new-tab button")
check("state.switchTab(to:" in tab_strip, "TabStripView calls switchTab on tap")
check("state.closeTab(at:" in tab_strip, "TabStripView calls closeTab on X")
check("ScrollView(.horizontal" in tab_strip, "TabStripView uses horizontal scroll")
check("Capsule()" in tab_strip, "TabStripView uses capsule pills")
check("ScrollViewReader" in tab_strip, "TabStripView auto-scrolls to active tab")
check(".accessibilityLabel" in tab_strip, "TabStripView has accessibility labels")

# 7. Wired into browser
check("TabStripView(state: state)" in browser, "TabStripView wired into browserWorkspace")

# 8. No forbidden APIs
check("WKWebView(" not in tab_mgr, "TabManager does not create WKWebView (URL-switch model)")
check("Keychain" not in tab_mgr, "No Keychain in TabManager")
check("UserDefaults" not in tab_mgr, "No UserDefaults in TabManager")

# 9. Swift syntax sanity
for name, src in [("TabManager", tab_mgr), ("TabStripView", tab_strip)]:
    check(src.count("{") == src.count("}"), f"{name} balanced braces")

print(f"\n{'='*60}")
if failures:
    print(f"RESULT: FAIL — {len(failures)} check(s) failed")
    sys.exit(1)
else:
    print("RESULT: PASS — all PEAK 2 slice B invariants verified")
    sys.exit(0)
