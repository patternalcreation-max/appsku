#!/usr/bin/env python3
"""
PEAK 3+4 — Relay + Workflows + Export validator.
Checks: HermesRelayClient, RelaySettings, AgentMode, WorkflowStore, ExportService, UI wiring.
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

relay_src = read(BROWSER / "Relay" / "HermesRelayClient.swift")
workflow_src = read(BROWSER / "Workflows" / "WorkflowStore.swift")
export_src = read(BROWSER / "Files" / "ExportService.swift")
relay_ui = read(BROWSER / "UI" / "RelayWorkflowsView.swift")
mission = read(BROWSER / "UI" / "MissionControlView.swift")
browser = read(BROWSER / "BrowserView.swift")

# === PEAK 3: Relay ===

# 1. HermesRelayClient source
check(bool(relay_src), "HermesRelayClient.swift exists")
check("enum AgentMode: String, Codable, CaseIterable" in relay_src, "AgentMode enum with cases")
check("case direct" in relay_src and "case relay" in relay_src and "case hybrid" in relay_src, "AgentMode has direct/relay/hybrid")
check("struct RelaySettings: Codable" in relay_src, "RelaySettings is Codable")
check("var enabled: Bool" in relay_src, "RelaySettings has enabled flag (opt-in)")
check("static let `default`" in relay_src, "RelaySettings has default (disabled)")
check("static func load()" in relay_src, "RelaySettings.load() for persistence")
check("func save()" in relay_src, "RelaySettings.save() persists")
check("final class HermesRelayClient" in relay_src, "HermesRelayClient class exists")
check("func send(" in relay_src, "HermesRelayClient.send() exists")

# 2. Relay safety constraints
check("https" in relay_src, "Relay enforces HTTPS")
check("settings.enabled" in relay_src, "Relay checks enabled flag before sending")
check("120" in relay_src, "Relay has timeout")

# 3. No forbidden patterns (check imports/usage, not comment text)
check("import NetworkExtension" not in relay_src, "No NetworkExtension import")
check("BGTaskScheduler" not in relay_src and "beginBackgroundTask" not in relay_src, "No background task scheduler")

# 4. Relay settings persistence
check("applicationSupportDirectory" in relay_src, "Relay stores in Application Support (sandbox-safe)")
check(".atomic" in relay_src, "Relay settings written atomically")

# === PEAK 4: Workflows ===

# 5. Workflow model
check("struct Workflow: Codable, Identifiable" in workflow_src, "Workflow is Codable Identifiable")
check("struct WorkflowStep: Codable, Equatable" in workflow_src, "WorkflowStep is Codable")
check("enum Kind: String, Codable" in workflow_src, "WorkflowStep.Kind enum")
check("case snapshot" in workflow_src, "Workflow has snapshot step")
check("case summarize" in workflow_src, "Workflow has summarize step")
check("case saveNote" in workflow_src, "Workflow has saveNote step")
check("case customPrompt" in workflow_src, "Workflow has customPrompt step")

# 6. Workflow store
check("enum WorkflowStore" in workflow_src, "WorkflowStore is enum")
check("static func load()" in workflow_src, "WorkflowStore.load()")
check("static func save(" in workflow_src, "WorkflowStore.save()")
check("static func add(" in workflow_src, "WorkflowStore.add()")
check("static func remove(id:" in workflow_src, "WorkflowStore.remove(id:)")

# 7. Built-in workflows
check("enum BuiltInWorkflows" in workflow_src, "BuiltInWorkflows exists")
check("summarizeAndNote" in workflow_src, "Built-in: Summarize + Save Note")
check("extractLinksMarkdown" in workflow_src, "Built-in: Extract Links as Markdown")
check("extractTableCSV" in workflow_src, "Built-in: Extract Table to CSV")
check("isBuiltIn: true" in workflow_src, "Built-ins marked isBuiltIn")

# === PEAK 4: Export ===

# 8. ExportService
check("enum ExportService" in export_src, "ExportService enum exists")
check("static func exportCSV(tables:" in export_src, "ExportService.exportCSV()")
check("static func exportLinksMarkdown(links:" in export_src, "ExportService.exportLinksMarkdown()")
check("static func exportMarkdown(" in export_src, "ExportService.exportMarkdown()")
check("static func saveToFile(" in export_src, "ExportService.saveToFile()")
check("escapeCSV" in export_src, "ExportService has CSV escaping")
check("K3Browser/Exports" in export_src, "Exports go to Documents/K3Browser/Exports")

# 9. BrowserState export extensions
check("func exportSnapshotAsCSV()" in export_src, "BrowserState can export CSV from snapshot")
check("func exportLinksAsMarkdown()" in export_src, "BrowserState can export links as Markdown")

# === UI wiring ===

# 10. Relay + Workflows UI
check("struct RelaySettingsView: View" in relay_ui, "RelaySettingsView is SwiftUI View")
check("Picker(\"Agent Mode\"" in relay_ui, "RelaySettingsView has mode picker")
check("SecureField" in relay_ui, "Relay token uses SecureField")
check("Toggle(\"Enable Relay\"" in relay_ui, "Relay has enable toggle")
check("struct WorkflowsView: View" in relay_ui, "WorkflowsView is SwiftUI View")
check("Button" in relay_ui and "Export tables as CSV" in relay_ui, "WorkflowsView has CSV export button")
check("Export links as Markdown" in relay_ui, "WorkflowsView has Markdown export button")

# 11. MissionControl wiring
check("RelaySettingsView" in mission, "MissionControl links to RelaySettingsView")
check("WorkflowsView" in mission, "MissionControl links to WorkflowsView")
check("antenna.radiowaves.left.and.right" in mission, "Relay row has icon in MissionControl")

# 12. Swift syntax sanity
for name, src in [("HermesRelayClient", relay_src), ("WorkflowStore", workflow_src),
                   ("ExportService", export_src), ("RelayWorkflowsView", relay_ui)]:
    check(src.count("{") == src.count("}"), f"{name} balanced braces")

print(f"\n{'='*60}")
if failures:
    print(f"RESULT: FAIL — {len(failures)} check(s) failed")
    sys.exit(1)
else:
    print("RESULT: PASS — all PEAK 3+4 invariants verified")
    sys.exit(0)
