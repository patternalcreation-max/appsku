#!/usr/bin/env python3
"""
Agent UX Polish validator — markdown rendering, conversation, haptics, symbolEffect.
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BROWSER = REPO / "Browser"

failures = []

def check(condition, message):
    if condition:
        print(f"PASS {message}")
    else:
        print(f"FAIL {message}")
        failures.append(message)

def read(path):
    return path.read_text() if path.exists() else ""

md_view = read(BROWSER / "UI" / "AgentMarkdownView.swift")
conv_view = read(BROWSER / "UI" / "ConversationTimelineView.swift")
conv_entry = read(BROWSER / "Runtime" / "ConversationEntry.swift")
dock = read(BROWSER / "UI" / "AgentDock.swift")
visual = read(BROWSER / "Design" / "K3VisualSystem.swift")
browser = read(BROWSER / "BrowserView.swift")
mission = read(BROWSER / "UI" / "MissionControlView.swift")

# === Markdown Renderer ===
check(bool(md_view), "AgentMarkdownView.swift exists")
check("enum MarkdownBlock" in md_view, "MarkdownBlock enum exists")
check("struct MarkdownInlineRun" in md_view, "MarkdownInlineRun exists")
check("enum MarkdownParser" in md_view, "MarkdownParser exists")
check("static func parse(" in md_view, "Parser has parse() method")
check("static func parseInline(" in md_view, "Inline parser exists")
check("case .header" in md_view and "case .codeBlock" in md_view, "Block types: header + codeBlock")
check("case .bulletList" in md_view and "case .numberList" in md_view, "Block types: lists")
check("case .blockquote" in md_view and "case .rule" in md_view, "Block types: blockquote + rule")
check("case .plain" in md_view and "case .bold" in md_view, "Inline styles: plain + bold")
check("case .code" in md_view and "case .link(" in md_view, "Inline styles: code + link")
check("struct AgentMarkdownView: View" in md_view, "AgentMarkdownView is SwiftUI View")
check("var body: some View" in md_view, "AgentMarkdownView has body")

# === Conversation Model ===
check("struct ConversationEntry" in conv_entry, "ConversationEntry model exists")
check("enum Role: String, Codable" in conv_entry, "ConversationEntry has Role enum")
check("case user" in conv_entry and "case agent" in conv_entry, "Roles: user + agent")
check("let content: String" in conv_entry, "ConversationEntry stores content")
check("Identifiable, Codable, Equatable" in conv_entry, "ConversationEntry is Codable")

# === BrowserState Conversation Integration ===
check("@Published var conversation: [ConversationEntry]" in browser, "BrowserState publishes conversation")
check("ConversationEntry(role: .user" in browser, "User commands recorded in conversation")
check("ConversationEntry(role: .agent" in browser, "Agent responses recorded in conversation")

# === Conversation Timeline UI ===
check("struct ConversationTimelineView: View" in conv_view, "ConversationTimelineView exists")
check("@ObservedObject var state: BrowserState" in conv_view, "TimelineView observes BrowserState")
check("ScrollViewReader" in conv_view, "Timeline uses ScrollViewReader for auto-scroll")
check("LazyVStack" in conv_view, "Timeline uses LazyVStack for performance")
check("struct MessageBubble" in conv_view, "MessageBubble component exists")
check("struct ThinkingBubble" in conv_view, "ThinkingBubble component exists")
check("entry.role == .user" in conv_view, "Messages differentiated by role")
check("AgentMarkdownView(text:" in conv_view, "Agent messages render as markdown")
check("RoundedRectangle(cornerRadius: 18" in conv_view, "Bubbles use rounded corners")
check("K3VisualSystem.Palette.interaction" in conv_view, "User bubbles use brand color")
check("auto-scroll" in conv_view.lower() or "scrollTo" in conv_view, "Timeline auto-scrolls")

# === Mission Control wiring ===
check("ConversationTimelineView" in mission, "Mission Control links to ConversationTimelineView")

# === Result capsule markdown ===
check("AgentMarkdownView(text: resultExcerpt" in dock, "Result capsule renders markdown")
check("hasMarkdownInResult" in dock, "Result capsule detects markdown in result")

# === Haptics ===
check("enum Haptics" in visual, "Haptics enum in visual system")
check("static func light()" in visual and "static func medium()" in visual, "Impact haptics: light + medium")
check("static func success()" in visual and "static func error()" in visual, "Notification haptics: success + error")
check("static func selection()" in visual, "Selection haptic exists")
check("K3VisualSystem.Haptics.light()" in dock, "Ball tap has haptic")
check("K3VisualSystem.Haptics.medium()" in dock, "Edge snap has haptic")
check("K3VisualSystem.Haptics.success()" in dock, "Terminal success has haptic")
check("K3VisualSystem.Haptics.error()" in dock, "Terminal error has haptic")

# === symbolEffect + shadow ===
check("contentTransition(.symbolEffect(.replace))" in dock, "Ball symbol has transition effect")
check(".shadow(color: .black.opacity(0.12)" in dock, "Ball has drop shadow")

# === Swift syntax sanity ===
for name, src in [("AgentMarkdownView", md_view), ("ConversationTimelineView", conv_view),
                   ("ConversationEntry", conv_entry)]:
    check(src.count("{") == src.count("}"), f"{name} balanced braces")

print(f"\n{'='*60}")
if failures:
    print(f"RESULT: FAIL — {len(failures)} check(s) failed")
    sys.exit(1)
else:
    print("RESULT: PASS — all agent UX polish invariants verified")
    sys.exit(0)
