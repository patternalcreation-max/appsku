import SwiftUI

// PEAK 2 Slice B — Compact tab strip for mobile.
// Horizontal scroll of tab pills. Active tab highlighted. Swipe not needed.

struct TabStripView: View {
    @ObservedObject var state: BrowserState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: K3VisualSystem.Space.compact) {
                    ForEach(Array(state._tabs.enumerated()), id: \.element.id) { index, tab in
                        tabPill(index: index, tab: tab)
                            .id(tab.id)
                    }
                    Button {
                        state.openNewTab()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: K3VisualSystem.Space.control, height: K3VisualSystem.Space.control)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New tab")
                }
                .padding(.horizontal, K3VisualSystem.Space.compact)
                .padding(.vertical, K3VisualSystem.Space.compact / 2)
            }
            .onChange(of: state._activeTabIndex) { newIndex in
                guard state._tabs.indices.contains(newIndex) else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(state._tabs[newIndex].id, anchor: .center)
                }
            }
        }
        .background(K3VisualSystem.Palette.rail)
    }

    private func tabPill(index: Int, tab: TabItem) -> some View {
        let isActive = index == state._activeTabIndex
        let displayTitle = tab.title.isEmpty ? URL(string: tab.url)?.host ?? tab.url : tab.title

        return Button {
            state.switchTab(to: index)
        } label: {
            HStack(spacing: K3VisualSystem.Space.compact) {
                Text(displayTitle)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(isActive ? .white : .primary)
                if state._tabs.count > 1 {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(isActive ? Color.white.opacity(0.7) : .secondary)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            state.closeTab(at: index)
                        }
                        .accessibilityLabel("Close tab")
                }
            }
            .padding(.horizontal, K3VisualSystem.Space.standard)
            .frame(minHeight: K3VisualSystem.Space.control)
            .background(isActive ? K3VisualSystem.Palette.interaction : Color(uiColor: .secondarySystemBackground))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tab: \(displayTitle)\(isActive ? ", active" : "")")
    }
}
