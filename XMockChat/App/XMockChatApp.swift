import SwiftUI

@main
struct XMockChatApp: App {
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ChatListScreen()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Chat list (continue past chats / create new)

struct ChatListScreen: View {
    @EnvironmentObject var store: ChatStore
    @State private var openSessionID: UUID? = nil

    var body: some View {
        ZStack {
            Theme.black.ignoresSafeArea()

            List {
                ForEach(store.sessions) { session in
                    Button {
                        openSessionID = session.id
                    } label: {
                        ChatRow(session: session)
                    }
                    .listRowBackground(Theme.black)
                    .swipeActions {
                        Button(role: .destructive) {
                            store.sessions.removeAll { $0.id == session.id }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .overlay(alignment: .bottomTrailing) {
            Menu {
                Button {
                    store.sessions.insert(ChatSession(elements: ChatSeed.blankElements()), at: 0)
                } label: {
                    Label("New chat", systemImage: "plus.message")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Theme.blue))
            }
            .padding(24)
        }
        .fullScreenCover(item: $openSessionID) { id in
            if let idx = store.sessions.firstIndex(where: { $0.id == id }) {
                ChatView(session: $store.sessions[idx], onBack: {
                    openSessionID = nil
                })
                .preferredColorScheme(.dark)
            }
        }
    }
}

extension UUID: Identifiable {
    public var id: UUID { self }
}

struct ChatRow: View {
    let session: ChatSession

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let png = session.avatarPNG, let img = UIImage(data: png) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Theme.avatarGray
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(session.displayName.isEmpty ? "(no name)" : session.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    if session.isVerified {
                        VerifiedBadge(size: 13)
                            .alignmentGuide(.firstTextBaseline) { d in
                                d[.bottom] - 2
                            }
                    }
                }
                Text(session.title)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(session.createdAt, style: .date)
                .font(.system(size: 11))
                .foregroundColor(Theme.secondaryText)
        }
        .contentShape(Rectangle())
    }
}
