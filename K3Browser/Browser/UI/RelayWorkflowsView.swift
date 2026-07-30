import SwiftUI

// PEAK 3+4 — Relay settings view + Workflows view + Export buttons.

struct RelaySettingsView: View {
    @State private var settings = RelaySettings.load()
    @State private var agentMode: AgentMode = .direct
    @State private var saved = false

    var body: some View {
        Form {
            Section("Mode") {
                Picker("Agent Mode", selection: $agentMode) {
                    ForEach(AgentMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(agentMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if agentMode != .direct {
                Section("Hermes Relay Endpoint") {
                    TextField("https://your-hermes.example.com/v1/chat/completions",
                              text: $settings.endpoint)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Relay Token", text: $settings.token)
                        .textContentType(.password)

                    Toggle("Enable Relay", isOn: $settings.enabled)

                    Text("Relay is optional. The app works fully offline in Direct mode. No background daemon, no VPN.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Button("Save Relay Settings") {
                    settings.save()
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                }
                if saved {
                    Text("Saved ✓")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Relay Settings")
    }
}

struct WorkflowsView: View {
    @ObservedObject var state: BrowserState
    @State private var workflows: [Workflow] = []

    var body: some View {
        List {
            if workflows.isEmpty {
                Label("No workflows yet", systemImage: "list.bullet.rectangle")
                    .foregroundColor(.secondary)
                Text("Workflows let you chain page actions: snapshot, summarize, extract, save.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(workflows) { workflow in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(workflow.name)
                                .font(.body.weight(.semibold))
                            if workflow.isBuiltIn {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                    .accessibilityLabel("Built-in")
                            }
                        }
                        Text(workflow.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        Text("\(workflow.steps.count) steps")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(minHeight: K3VisualSystem.Space.control)
                    .accessibilityElement(children: .combine)
                }
                .onDelete { offsets in
                    for index in offsets {
                        let wf = workflows[index]
                        if !wf.isBuiltIn {
                            WorkflowStore.remove(id: wf.id)
                        }
                    }
                    workflows = WorkflowStore.load()
                }
            }

            Section("Export Current Page") {
                Button {
                    if let url = state.exportSnapshotAsCSV() {
                        state.shareItems = [url]
                        state.showShare = true
                    }
                } label: {
                    Label("Export tables as CSV", systemImage: "tablecells")
                }
                .disabled(state.snapshot?.tables.isEmpty ?? true)

                Button {
                    if let url = state.exportLinksAsMarkdown() {
                        state.shareItems = [url]
                        state.showShare = true
                    }
                } label: {
                    Label("Export links as Markdown", systemImage: "link")
                }
                .disabled(state.snapshot?.links.isEmpty ?? true)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workflows")
        .onAppear { workflows = WorkflowStore.load() }
    }
}
