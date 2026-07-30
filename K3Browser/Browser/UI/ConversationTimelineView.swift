import SwiftUI

// ConversationTimelineView — Chat-style conversation display with rich markdown.
// User messages right-aligned with indigo bubble.
// Agent messages left-aligned with neutral material + markdown rendering.

struct ConversationTimelineView: View {
    @ObservedObject var state: BrowserState
    @ObservedObject var settings: AgentSettings

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if state.conversation.isEmpty {
                        emptyConversation
                    } else {
                        ForEach(state.conversation) { entry in
                            MessageBubble(entry: entry)
                                .id(entry.id)
                        }
                        if state.phase.isBusy {
                            ThinkingBubble()
                                .id("thinking")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: state.conversation.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) {
                    if let last = state.conversation.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: state.phase) { phase in
                if phase.isBusy {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var emptyConversation: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.quaternary)
                .symbolRenderingMode(.hierarchical)

            Text("No conversation yet")
                .font(.title3.weight(.semibold))

            Text("Tap the Agent Ball and describe what you want to do on this page.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let entry: ConversationEntry

    var body: some View {
        HStack {
            if entry.role == .user {
                Spacer(minLength: 40)
                userBubble
            } else {
                agentBubble
                Spacer(minLength: 40)
            }
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(entry.content)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(K3VisualSystem.Palette.interaction)
                )
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = entry.content
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            Text(entry.timestamp.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var agentBubble: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: entry.isError ? "exclamationmark.triangle.fill" : "sparkles")
                    .font(.caption)
                    .foregroundStyle(entry.isError ? K3VisualSystem.Palette.error : K3VisualSystem.Palette.interaction)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(entry.isError ? K3VisualSystem.Palette.error.opacity(0.1) : K3VisualSystem.Palette.interaction.opacity(0.1)))
                    .accessibilityHidden(true)

                if entry.isError || isPlainText(entry.content) {
                    Text(entry.content)
                        .font(.body)
                        .foregroundStyle(entry.isError ? K3VisualSystem.Palette.error : .primary)
                        .textSelection(.enabled)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                } else {
                    AgentMarkdownView(text: entry.content)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                        )
                }
            }

            Text(entry.timestamp.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 32)
        }
    }

    private func isPlainText(_ text: String) -> Bool {
        // If no markdown markers detected, render as plain Text for performance
        !text.contains("#") && !text.contains("**") && !text.contains("`") &&
        !text.contains("- ") && !text.contains("1. ") && !text.contains("[") &&
        !text.contains(">") && !text.contains("```")
    }
}

// MARK: - Thinking Indicator

private struct ThinkingBubble: View {
    @State private var animateOffset: CGFloat = 0

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(K3VisualSystem.Palette.interaction)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(K3VisualSystem.Palette.interaction.opacity(0.1)))
                    .accessibilityHidden(true)

                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 6, height: 6)
                            .offset(y: animateOffset)
                            .animation(
                                .easeInOut(duration: 0.4)
                                    .repeatForever()
                                    .delay(Double(index) * 0.15),
                                value: animateOffset
                            )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemBackground))
                )
            }
            Spacer(minLength: 60)
        }
        .onAppear {
            animateOffset = -4
        }
        .accessibilityLabel("Agent is thinking")
    }
}
