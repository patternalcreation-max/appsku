import SwiftUI

// PEAK 2 Sessions — History and Bookmarks views.

struct HistoryView: View {
    @ObservedObject var state: BrowserState

    var body: some View {
        List {
            if state.history.isEmpty {
                Label("No history yet", systemImage: "clock")
                    .foregroundColor(.secondary)
            } else {
                ForEach(state.history) { entry in
                    Button {
                        state.navigate(to: entry.url)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title.isEmpty ? entry.url : entry.title)
                                .font(.body)
                                .lineLimit(2)
                            Text(entry.url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(entry.visitedAt.formatted(.relative(presentation: .named)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(minHeight: K3VisualSystem.Space.control)
                    }
                    .accessibilityElement(children: .combine)
                }
                .onDelete { offsets in
                    for index in offsets {
                        let entry = state.history[index]
                        HistoryStore.remove(id: entry.id)
                    }
                    state.history = HistoryStore.load()
                }
                Section {
                    Button(role: .destructive) {
                        state.clearHistory()
                    } label: {
                        Label("Clear all history", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("History")
    }
}

struct BookmarksView: View {
    @ObservedObject var state: BrowserState

    var body: some View {
        List {
            if state.bookmarks.isEmpty {
                Label("No bookmarks yet", systemImage: "bookmark")
                    .foregroundColor(.secondary)
                Text("Open a page and bookmark it from the address bar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(state.bookmarks) { bookmark in
                    Button {
                        state.navigate(to: bookmark.url)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bookmark.title.isEmpty ? bookmark.url : bookmark.title)
                                .font(.body)
                                .lineLimit(2)
                            Text(bookmark.url)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(minHeight: K3VisualSystem.Space.control)
                    }
                    .accessibilityElement(children: .combine)
                }
                .onDelete { offsets in
                    for index in offsets {
                        let bookmark = state.bookmarks[index]
                        BookmarkStore.remove(id: bookmark.id)
                    }
                    state.bookmarks = BookmarkStore.load()
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Bookmarks")
    }
}
