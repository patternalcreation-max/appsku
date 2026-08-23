import SwiftUI
import PhotosUI

// MARK: - App entry

@main
struct XMockChatApp: App {
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            ChatListView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Session list (continue past chats / new chat)

struct ChatListView: View {
    @EnvironmentObject var store: ChatStore
    @State private var showIconSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    VStack(spacing: 12) {
                        Text("No chats")
                            .foregroundColor(Theme.secondaryText)
                        Button("Create first chat") {
                            store.sessions.append(ChatSession())
                        }
                        .foregroundColor(Theme.blue)
                    }
                } else {
                    List {
                        ForEach(store.sessions) { session in
                            NavigationLink {
                                ChatDetailView(sessionID: session.id)
                            } label: {
                                row(session)
                            }
                            .listRowBackground(Theme.black)
                        }
                        .onDelete { indexSet in
                            store.sessions.remove(atOffsets: indexSet)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Mock Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.sessions.insert(ChatSession(createdAt: Date(),
                                                          elements: ChatSeed.blankElements()), at: 0)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(Theme.blue)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showIconSettings = true
                    } label: {
                        Image(systemName: "shield.checkered")
                    }
                    .foregroundColor(Theme.blue)
                }
            }
            .sheet(isPresented: $showIconSettings) {
                IconSettingsView()
            }
        }
    }

    private func row(_ session: ChatSession) -> some View {
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
                        VerifiedBadge(icons: store.icons, size: 13)
                    }
                }
                Text(session.title)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(session.createdAt, style: .date)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.secondaryText)
                Text("\(session.elements.count) items")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.secondaryText)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Detail (the editor + live preview)

struct ChatDetailView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID

    @State private var showEditor = false
    @State private var editorText: String = ""
    @State private var editorTarget: EditTarget?

    @State private var showExport = false
    @State private var showSaved = false
    @State private var highRes = true

    enum EditTarget: Hashable {
        case name
        case placeholder
        case element(UUID)
    }

    private var sessionIndex: Int? {
        store.sessions.firstIndex(where: { $0.id == sessionID })
    }

    private var binding: Binding<ChatSession> {
        guard let idx = sessionIndex else {
            return .constant(ChatSession())
        }
        return $store.sessions[idx]
    }

    var body: some View {
        ZStack {
            Theme.black.ignoresSafeArea()
            ChatScreen(session: binding,
                       icons: store.icons,
                       onBack: { dismiss() },
                       onTapName: { beginEdit(.name, text: binding.wrappedValue.displayName) },
                       onTapPlaceholder: { beginEdit(.placeholder, text: binding.wrappedValue.inputPlaceholder) },
                       onTapElement: { id in
                           if let el = binding.wrappedValue.elements.first(where: { $0.id == id }) {
                               beginEdit(.element(id), text: el.text)
                           }
                       },
                       elementMenu: { element in
                           AnyView(elementContextMenu(element))
                       },
                       chatMenu: {
                           AnyView(chatContextMenu)
                       },
                       onAvatarChange: { data in
                           binding.wrappedValue.avatarPNG = data
                       })
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditor) { editorSheet }
        .sheet(isPresented: $showExport) { exportSheet }
        .alert("Saved to Photos", isPresented: $showSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Screenshot exported to your photo library.")
        }
    }

    // MARK: Context menus

    private var chatContextMenu: some View {
        Group {
            Button {
                binding.wrappedValue.elements.append(ChatElement(style: .sent, text: "New message"))
            } label: {
                Label("Add chat me (blue)", systemImage: "arrow.up.circle")
            }
            Button {
                binding.wrappedValue.elements.append(ChatElement(style: .received, text: "New message"))
            } label: {
                Label("Add chat user (gray)", systemImage: "arrow.down.circle")
            }
            Button {
                binding.wrappedValue.elements.append(ChatElement(style: .timestamp, text: "Today"))
            } label: {
                Label("Add timestamp", systemImage: "clock")
            }
            Button {
                binding.wrappedValue.elements.append(ChatElement(style: .notice, text: "\u{1F512} Notice text"))
            } label: {
                Label("Add notice", systemImage: "lock.shield")
            }
            Divider()
            Button {
                binding.wrappedValue.isVerified.toggle()
            } label: {
                Label(binding.wrappedValue.isVerified ? "Hide verified badge" : "Show verified badge",
                      systemImage: "checkmark.circle")
            }
            Button {
                binding.wrappedValue.badgeNotifications = max(0, binding.wrappedValue.badgeNotifications - 1)
            } label: {
                Label("Bell badge: \(binding.wrappedValue.badgeNotifications) \u{2212}", systemImage: "bell")
            }
            Button {
                binding.wrappedValue.badgeNotifications += 1
            } label: {
                Label("Bell badge: \(binding.wrappedValue.badgeNotifications) +", systemImage: "bell")
            }
            Button {
                binding.wrappedValue.badgeMessages = max(0, binding.wrappedValue.badgeMessages - 1)
            } label: {
                Label("Messages badge: \(binding.wrappedValue.badgeMessages) \u{2212}", systemImage: "envelope")
            }
            Button {
                binding.wrappedValue.badgeMessages += 1
            } label: {
                Label("Messages badge: \(binding.wrappedValue.badgeMessages) +", systemImage: "envelope")
            }
            Divider()
            Button {
                showExport = true
            } label: {
                Label("Export screenshot", systemImage: "square.and.arrow.down")
            }
        }
    }

    @ViewBuilder
    private func elementContextMenu(_ element: ChatElement) -> some View {
        Button(role: .destructive) {
            binding.wrappedValue.elements.removeAll { $0.id == element.id }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        Divider()
        Button {
            insertAfter(element, style: .sent, text: "New message")
        } label: {
            Label("Add blue bubble below", systemImage: "arrow.up.circle")
        }
        Button {
            insertAfter(element, style: .received, text: "New message")
        } label: {
            Label("Add gray bubble below", systemImage: "arrow.down.circle")
        }
        Button {
            insertAfter(element, style: .timestamp, text: "Today")
        } label: {
            Label("Add timestamp below", systemImage: "clock")
        }
        Button {
            insertAfter(element, style: .notice, text: "Notice text")
        } label: {
            Label("Add notice below", systemImage: "lock.shield")
        }
    }

    private func insertAfter(_ element: ChatElement, style: ChatStyle, text: String) {
        guard let idx = binding.wrappedValue.elements.firstIndex(where: { $0.id == element.id }) else { return }
        binding.wrappedValue.elements.insert(ChatElement(style: style, text: text), at: binding.wrappedValue.elements.index(after: idx))
    }

    // MARK: Editor sheet

    private var editorSheet: some View {
        NavigationStack {
            TextEditor(text: $editorText)
                .font(.system(size: 16))
                .padding(12)
                .frame(maxHeight: 320)
                .background(Color(red: 0.11, green: 0.12, blue: 0.13))
                .navigationTitle(editorTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { commitEdit() }
                            .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.height(340)])
        .preferredColorScheme(.dark)
    }

    private var editorTitle: String {
        switch editorTarget {
        case .name: return "Display name"
        case .placeholder: return "Input placeholder"
        case .element(let id):
            if let idx = binding.wrappedValue.elements.firstIndex(where: { $0.id == id }) {
                switch binding.wrappedValue.elements[idx].style {
                case .timestamp: return "Timestamp"
                case .notice: return "Notice"
                case .sent, .received: return "Message"
                }
            }
            return "Edit"
        case nil: return "Edit"
        }
    }

    private func beginEdit(_ target: EditTarget, text: String) {
        editorTarget = target
        editorText = text
        showEditor = true
    }

    private func commitEdit() {
        switch editorTarget {
        case .name:
            binding.wrappedValue.displayName = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .placeholder:
            binding.wrappedValue.inputPlaceholder = editorText
        case .element(let id):
            if let idx = binding.wrappedValue.elements.firstIndex(where: { $0.id == id }) {
                binding.wrappedValue.elements[idx].text = editorText
            }
        case nil:
            break
        }
        showEditor = false
    }

    // MARK: Export

    private var exportSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Toggle(isOn: $highRes) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("High resolution (3\u{00d7})")
                        Text("1200 \u{00d7} 2400 px PNG")
                            .font(.footnote)
                            .foregroundColor(Theme.secondaryText)
                    }
                }
                .tint(Theme.blue)
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.bubbleGray))
                .padding(.horizontal)

                Button {
                    exportPNG()
                } label: {
                    Label("Save screenshot to Photos", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Capsule().fill(Theme.blue))
                        .foregroundColor(.white)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(300)])
        .preferredColorScheme(.dark)
    }

    private func exportPNG() {
        showExport = false
        let sessionCopy = binding.wrappedValue
        let canvas = ChatScreen(session: .constant(sessionCopy),
                                icons: store.icons,
                                exportFrame: true)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = highRes ? 3.0 : 1.0
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSaved = true
    }
}

// MARK: - Session settings (badges, verified, placeholder)

struct SessionSettingsView: View {
    @Binding var session: ChatSession

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    Toggle(isOn: $session.isVerified) {
                        Label("Verified badge", systemImage: "checkmark.seal")
                    }
                    .tint(Theme.blue)
                    HStack {
                        Text("Display name")
                        Spacer()
                        Text(session.displayName.isEmpty ? "(empty)" : session.displayName)
                            .foregroundColor(Theme.secondaryText)
                    }
                }
                Section("Notification badges") {
                    Stepper(value: $session.badgeNotifications, in: 0...999) {
                        HStack {
                            Image(systemName: "bell.badge").foregroundColor(Theme.blue)
                            Text("Bell badge")
                            Spacer()
                            Text("\(session.badgeNotifications)").foregroundColor(Theme.secondaryText)
                        }
                    }
                    Stepper(value: $session.badgeMessages, in: 0...999) {
                        HStack {
                            Image(systemName: "envelope.badge").foregroundColor(Theme.blue)
                            Text("Messages badge")
                            Spacer()
                            Text("\(session.badgeMessages)").foregroundColor(Theme.secondaryText)
                        }
                    }
                    Text("Set to 0 to hide a badge.")
                        .font(.footnote)
                        .foregroundColor(Theme.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Icon settings (SVG overrides)

struct IconSettingsView: View {
    @EnvironmentObject var store: ChatStore
    @State private var pathInput: String = ""
    @State private var selectedSlot: IconSlotKey = .verified

    var body: some View {
        NavigationStack {
            List {
                Section("Slots") {
                    ForEach(IconSlotKey.allCases) { slot in
                        Button {
                            selectedSlot = slot
                            pathInput = store.icons[slot]?.path ?? ""
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(slot.displayName)
                                        .foregroundColor(.white)
                                    Text(store.icons[slot] == nil ? "Default" : "Custom")
                                        .font(.caption)
                                        .foregroundColor(store.icons[slot] == nil ? Theme.secondaryText : Theme.blue)
                                }
                                Spacer()
                                if selectedSlot == slot {
                                    Image(systemName: "checkmark").foregroundColor(Theme.blue)
                                }
                            }
                        }
                    }
                }

                Section("Custom SVG path for \(selectedSlot.displayName)") {
                    TextEditor(text: $pathInput)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        if pathInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            store.icons[selectedSlot] = nil
                        } else {
                            store.icons[selectedSlot] = IconSlot(
                                path: pathInput.trimmingCharacters(in: .whitespacesAndNewlines),
                                viewBoxWidth: 24, viewBoxHeight: 24)
                        }
                    } label: {
                        Label("Apply to \(selectedSlot.displayName)", systemImage: "checkmark.circle")
                    }
                    .foregroundColor(Theme.blue)

                    Button(role: .destructive) {
                        store.icons[selectedSlot] = nil
                        pathInput = ""
                    } label: {
                        Label("Reset to default", systemImage: "arrow.counterclockwise")
                    }

                    Text("Paste any SVG path data (d=\"…\"). Uses a 24×24 viewBox by default; path syntax M/L/H/V/C/S/Z relative+absolute.")
                        .font(.caption)
                        .foregroundColor(Theme.secondaryText)
                }

                Section("Presets") {
                    ForEach(IconPresets.all) { preset in
                        Button {
                            pathInput = preset.path
                            store.icons[selectedSlot] = IconSlot(path: preset.path,
                                                                viewBoxWidth: preset.vbW,
                                                                viewBoxHeight: preset.vbH)
                        } label: {
                            HStack(spacing: 12) {
                                SVGPathShape(d: preset.path,
                                             viewBox: CGRect(x: 0, y: 0, width: preset.vbW, height: preset.vbH))
                                    .fill(Theme.primaryText)
                                    .frame(width: 22, height: 22 * preset.vbH / preset.vbW)
                                Text(preset.name)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Icons")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}
