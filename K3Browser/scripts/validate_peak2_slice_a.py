#!/usr/bin/env python3
"""
PEAK 2 Slice A — Sessions storage layer validator.
Checks: HistoryStore, BookmarkStore, SessionRestorer source invariants.
"""
import sys
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BROWSER = REPO / "Browser"
SESSIONS = BROWSER / "Sessions"

failures = []

def check(condition, message):
    if condition:
        print(f"PASS {message}")
    else:
        print(f"FAIL {message}")
        failures.append(message)

def read(path):
    return path.read_text() if path.exists() else ""

# 1. Session files exist
history_src = read(SESSIONS / "HistoryStore.swift")
bookmark_src = read(SESSIONS / "BookmarkStore.swift")
session_src = read(SESSIONS / "SessionRestorer.swift")

check(bool(history_src), "HistoryStore.swift exists and non-empty")
check(bool(bookmark_src), "BookmarkStore.swift exists and non-empty")
check(bool(session_src), "SessionRestorer.swift exists and non-empty")

# 2. HistoryStore invariants
check("struct HistoryEntry: Codable, Identifiable" in history_src, "HistoryEntry is Codable Identifiable")
check("enum HistoryStore" in history_src, "HistoryStore is enum (no instances)")
check("static func load()" in history_src, "HistoryStore.load() exists")
check("static func record(url: String, title: String)" in history_src, "HistoryStore.record() exists")
check("static func clear()" in history_src, "HistoryStore.clear() exists")
check("static func remove(id: UUID)" in history_src, "HistoryStore.remove(id:) exists")
check("maxEntries" in history_src, "HistoryStore has max entries cap")
check("applicationSupportDirectory" in history_src, "HistoryStore uses Application Support (sandbox-safe)")

# 3. BookmarkStore invariants
check("struct Bookmark: Codable, Identifiable" in bookmark_src, "Bookmark is Codable Identifiable")
check("static func add(url: String, title: String)" in bookmark_src, "BookmarkStore.add() exists")
check("static func remove(id: UUID)" in bookmark_src, "BookmarkStore.remove(id:) exists")
check("static func isBookmarked(url: String)" in bookmark_src, "BookmarkStore.isBookmarked() exists")
check("applicationSupportDirectory" in bookmark_src, "BookmarkStore uses Application Support (sandbox-safe)")

# 4. SessionRestorer invariants
check("struct SavedTab: Codable, Identifiable" in session_src, "SavedTab is Codable Identifiable")
check("struct Snapshot: Codable" in session_src, "SessionRestorer.Snapshot is Codable")
check("static func save(tabs: [SavedTab], activeIndex: Int)" in session_src, "SessionRestorer.save() exists")
check("static func load()" in session_src, "SessionRestorer.load() exists")

# 5. BrowserState integration
browser_src = read(BROWSER / "BrowserView.swift")
check("@Published var history: [HistoryEntry]" in browser_src, "BrowserState publishes history")
check("@Published var bookmarks: [Bookmark]" in browser_src, "BrowserState publishes bookmarks")
check("HistoryStore.record(" in browser_src, "BrowserState records history on navigation")
check("HistoryStore.load()" in browser_src, "BrowserState loads history on init")
check("BookmarkStore.load()" in browser_src, "BrowserState loads bookmarks on init")
check("func toggleBookmark()" in browser_src, "BrowserState has toggleBookmark()")
check("func clearHistory()" in browser_src, "BrowserState has clearHistory()")
check("func navigate(to url: String)" in browser_src, "BrowserState has navigate(to:)")

# 6. UI integration
mission_src = read(BROWSER / "UI" / "MissionControlView.swift")
history_ui_src = read(BROWSER / "UI" / "HistoryBookmarksView.swift")
chrome_src = read(BROWSER / "UI" / "BrowserChromeView.swift")

check("HistoryView" in mission_src, "MissionControl links to HistoryView")
check("BookmarksView" in mission_src, "MissionControl links to BookmarksView")
check("Section(\"Sessions\")" in mission_src, "MissionControl has Sessions section")
check("struct HistoryView: View" in history_ui_src, "HistoryView is a SwiftUI View")
check("struct BookmarksView: View" in history_ui_src, "BookmarksView is a SwiftUI View")
check("isBookmarked" in chrome_src, "BrowserChromeView has bookmark state")
check("onToggleBookmark" in chrome_src, "BrowserChromeView has bookmark toggle callback")
check("state.toggleBookmark" in browser_src, "BrowserView wires toggleBookmark to chrome")

# 7. No entitlements or forbidden APIs
all_session_src = history_src + bookmark_src + session_src
check("Keychain" not in all_session_src, "No Keychain dependency in sessions storage")
check("UserDefaults" not in all_session_src, "No UserDefaults in sessions storage (file-backed)")
check(".atomic" in history_src, "HistoryStore writes atomically")
check(".atomic" in bookmark_src, "BookmarkStore writes atomically")

# 8. Swift syntax sanity
for name, src in [("HistoryStore", history_src), ("BookmarkStore", bookmark_src), ("SessionRestorer", session_src)]:
    check(src.count("{") == src.count("}"), f"{name} balanced braces")
    check("import Foundation" in src, f"{name} imports Foundation")

print(f"\n{'='*60}")
if failures:
    print(f"RESULT: FAIL — {len(failures)} check(s) failed")
    sys.exit(1)
else:
    print("RESULT: PASS — all PEAK 2 slice A invariants verified")
    sys.exit(0)
