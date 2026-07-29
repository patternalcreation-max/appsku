import SwiftUI

struct MissionControlView: View {
    @ObservedObject var state: BrowserState
    @ObservedObject var settings: AgentSettings
    @Environment(\.presentationMode) private var presentationMode
    @State private var selector = ""
    @State private var value = ""

    var body: some View {
        NavigationView {
            List {
                Section("Current Run") {
                    NavigationLink(destination: CurrentRunView(state: state)) {
                        missionRow(symbol: K3VisualSystem.presentation(for: state.phase).symbol, title: state.phase.label, detail: "Status and result")
                    }
                }

                Section("Inspect") {
                    NavigationLink(destination: ActivityView(state: state)) {
                        missionRow(symbol: "list.bullet.rectangle", title: "Activity", detail: "Run timeline and export")
                    }
                    NavigationLink(destination: PageSnapshotView(state: state)) {
                        missionRow(symbol: "doc.text.magnifyingglass", title: "Page Snapshot", detail: state.snapshot == nil ? "No snapshot yet" : "Latest sanitized snapshot")
                    }
                }

                Section("Operate") {
                    NavigationLink(destination: ManualToolsView(state: state, selector: $selector, value: $value)) {
                        missionRow(symbol: "wrench.and.screwdriver", title: "Manual Tools", detail: "Actions are staged for approval")
                    }
                    NavigationLink(destination: AgentSettingsView(settings: settings)) {
                        missionRow(symbol: "gearshape", title: "Agent Settings", detail: settings.status)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Mission Control")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { presentationMode.wrappedValue.dismiss() }
                        .accessibilityLabel("Close Mission Control")
                }
            }
        }
        .navigationViewStyle(.stack)
        .disabled(state.pendingApproval != nil)
        .accessibilityHidden(state.pendingApproval != nil)
    }

    private func missionRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: K3VisualSystem.Space.standard) {
            Image(systemName: symbol)
                .foregroundColor(K3VisualSystem.Palette.interaction)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundColor(.secondary).lineLimit(2)
            }
        }
        .frame(minHeight: K3VisualSystem.Space.control)
        .accessibilityElement(children: .combine)
    }
}

private struct CurrentRunView: View {
    @ObservedObject var state: BrowserState

    var body: some View {
        List {
            Section("Status") {
                Label(state.phase.label, systemImage: K3VisualSystem.presentation(for: state.phase).symbol)
                    .foregroundColor(K3VisualSystem.presentation(for: state.phase).color)
                if state.phase.isBusy {
                    Button(role: .destructive, action: state.stopAgent) {
                        Label("Stop active run", systemImage: "stop.fill")
                    }
                    .frame(minHeight: K3VisualSystem.Space.control)
                }
            }
            if !state.agentAnswer.isEmpty {
                Section("Result") {
                    Text(state.agentAnswer).textSelection(.enabled)
                    Button(action: state.saveCurrentAnswerNote) {
                        Label("Save result as note", systemImage: "square.and.arrow.down")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Current Run")
    }
}

private struct ActivityView: View {
    @ObservedObject var state: BrowserState

    var body: some View {
        List {
            if state.steps.isEmpty {
                Label("No activity yet", systemImage: "clock")
                    .foregroundColor(.secondary)
            } else {
                ForEach(state.steps) { step in
                    HStack(alignment: .top, spacing: K3VisualSystem.Space.standard) {
                        Image(systemName: symbol(for: step.title))
                            .foregroundColor(.secondary)
                            .frame(width: 22)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title).font(.body.weight(.semibold))
                            if !step.detail.isEmpty {
                                Text(step.detail).font(.caption).foregroundColor(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            Section("Log") {
                Button(action: state.copyLog) { Label("Copy log", systemImage: "doc.on.doc") }
                Button(action: state.exportLog) { Label("Export Markdown", systemImage: "square.and.arrow.up") }
                Button(role: .destructive) { state.steps.removeAll() } label: { Label("Clear activity", systemImage: "trash") }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Activity")
    }

    private func symbol(for title: String) -> String {
        let value = title.lowercased()
        if value.contains("error") || value.contains("failed") { return "exclamationmark.triangle.fill" }
        if value.contains("approval") || value.contains("denied") { return "hand.raised.fill" }
        if value.contains("saved") || value.contains("export") { return "square.and.arrow.down" }
        if value.contains("observ") { return "eye.fill" }
        if value.contains("think") { return "brain.head.profile" }
        if value.contains("stop") { return "stop.circle.fill" }
        if value.contains("final") || value.contains("complete") { return "checkmark.circle.fill" }
        return "circle.fill"
    }
}

private struct PageSnapshotView: View {
    @ObservedObject var state: BrowserState

    var body: some View {
        List {
            Button { state.extractSnapshot() } label: {
                Label("Capture sanitized snapshot", systemImage: "camera.viewfinder")
                    .frame(minHeight: K3VisualSystem.Space.control)
            }
            if let snapshot = state.snapshot {
                Section("Snapshot") {
                    Text(snapshot.summaryText)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            } else {
                Label("No snapshot yet", systemImage: "doc")
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Page Snapshot")
    }
}

private struct ManualToolsView: View {
    @ObservedObject var state: BrowserState
    @Binding var selector: String
    @Binding var value: String

    var body: some View {
        Form {
            Section("Selector") {
                TextField("CSS selector", text: $selector)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                TextField("Value", text: $value)
            }
            Section("Stage for review") {
                Button("Fill once") {
                    state.stageManualApproval(call: ToolCall(id: UUID().uuidString, tool: "fill_selector", arguments: ["selector": selector, "value": value], reason: "Manual tool"))
                }
                Button("Click once") {
                    state.stageManualApproval(call: ToolCall(id: UUID().uuidString, tool: "click_selector", arguments: ["selector": selector], reason: "Manual tool"))
                }
            }
            Section("Memory") {
                Button("Read recent notes") { state.addStep("", "Recent notes", MemoryStore.recent()) }
                Button("Save result as note", action: state.saveCurrentAnswerNote)
            }
        }
        .navigationTitle("Manual Tools")
    }
}

private struct AgentSettingsView: View {
    @ObservedObject var settings: AgentSettings

    var body: some View {
        Form {
            Section("Model") {
                Button("Use GLM 5.2 / Z.AI preset", action: settings.useGLM52Preset)
                SecureField("API Key", text: $settings.apiKey)
                    .textContentType(.password)
                TextField("Base URL", text: $settings.baseURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                TextField("Model", text: $settings.model)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            Section("Operator") {
                TextField("Operator name", text: $settings.operatorSoul.displayName)
                TextField("Persona", text: $settings.operatorSoul.persona)
                TextField("Communication style", text: $settings.operatorSoul.communicationStyle)
                Text("Additional persona instructions cannot override the immutable core safety policy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $settings.operatorSoul.additionalInstructions)
                    .frame(minHeight: 120)
                    .accessibilityLabel("Additional persona instructions")
            }
            Section("Connection") {
                Button("Save", action: settings.save)
                Button(settings.isTesting ? "Testing" : "Test connection", action: settings.testConnection)
                    .disabled(settings.isTesting)
                Text(settings.status).font(.caption).textSelection(.enabled)
            }
        }
        .navigationTitle("Agent Settings")
    }
}
