import SwiftUI
import PhotosUI

// MARK: - Shapes

struct BubbleShape: Shape {
    let isSent: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 24
        let tailR: CGFloat = 4
        let bottomRight: CGFloat = isSent ? tailR : r
        let bottomLeft: CGFloat = isSent ? r : tailR
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bottomLeft), control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Element views

struct TimestampView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(Theme.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

struct NoticeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(Theme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
    }
}

struct MessageBubble: View {
    let text: String
    let isSent: Bool

    var body: some View {
        HStack {
            if isSent { Spacer(minLength: 48) }
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(isSent ? .white : Theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(BubbleShape(isSent: isSent).fill(isSent ? Theme.blue : Theme.bubbleGray))
                .fixedSize(horizontal: false, vertical: true)
            if !isSent { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Main view

struct ChatView: View {
    @Binding var session: ChatSession
    let onBack: () -> Void

    private var elements: [ChatElement] { session.elements }
    private var displayName: String { session.displayName }
    private var isVerified: Bool { session.isVerified }
    private var avatarImage: UIImage? {
        session.avatarPNG.flatMap { UIImage(data: $0) }
    }

    @State private var photoPickerItem: PhotosPickerItem?

    @State private var showEditor = false
    @State private var editorText: String = ""
    @State private var editorTarget: EditTarget?

    @State private var showExport = false
    @State private var showSaved = false
    @State private var highRes = true

    private func setAvatar(_ image: UIImage?) {
        session.avatarPNG = image?.pngData()
    }

    enum EditTarget: Hashable {
        case name
        case element(UUID)
    }

    var body: some View {
        ZStack {
            Theme.black.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                chatArea
                inputBar
                XTabBar(badgeNotifications: session.badgeNotifications, badgeMessages: session.badgeMessages)
            }
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

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
Button(action: onBack) {
                BackArrow(size: 20)
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                Group {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Theme.avatarGray
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayName.isEmpty ? " " : displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if isVerified {
                    VerifiedBadge(size: 14)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { beginEdit(.name, text: displayName) }
            .contextMenu {
                Button {
                    session.isVerified.toggle()
                } label: {
                    Label(isVerified ? "Hide verified badge" : "Show verified badge",
                          systemImage: "checkmark.circle")
                }
            }

            Spacer()

            PhoneCallIcon(size: 20)
                .padding(.trailing, 16)
            VideoCallIcon(size: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: photoPickerItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { setAvatar(image) }
                }
            }
        }
    }

    // MARK: Chat area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(session.elements) { element in
                        elementView(element)
                            .id(element.id)
                            .contentShape(Rectangle())
                            .onTapGesture { beginEdit(.element(element.id), text: element.text) }
                            .contextMenu { elementMenu(for: element) }
                    }
                }
                .padding(16)
            }
            .contextMenu {
                Button {
                    showExport = true
                } label: {
                    Label("Export screenshot", systemImage: "square.and.arrow.down")
                }
            }
            .onAppear {
                if let last = elements.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func elementView(_ element: ChatElement) -> some View {
        switch element.style {
        case .timestamp: TimestampView(text: element.text)
        case .notice: NoticeView(text: element.text)
        case .sent: MessageBubble(text: element.text, isSent: true)
        case .received: MessageBubble(text: element.text, isSent: false)
        }
    }

    private func elementMenu(for element: ChatElement) -> some View {
        Group {
            Button(role: .destructive) {
                session.elements.removeAll { $0.id == element.id }
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
        }
    }

    private func insertAfter(_ element: ChatElement, style: ChatElement.Style, text: String) {
        guard let idx = session.elements.firstIndex(where: { $0.id == element.id }) else { return }
        session.elements.insert(ChatElement(style: style, text: text), at: session.elements.index(after: idx))
    }

    // MARK: Input bar

    private var inputBar: some View {
        HStack(spacing: 12) {
Menu {
                Button {
                    session.elements.append(ChatElement(style: .sent, text: "New message"))
                } label: {
                    Label("Add chat me (blue)", systemImage: "arrow.up.circle")
                }
                Button {
                    session.elements.append(ChatElement(style: .received, text: "New message"))
                } label: {
                    Label("Add chat user (gray)", systemImage: "arrow.down.circle")
                }
                Button {
                    session.elements.append(ChatElement(style: .timestamp, text: "Today"))
                } label: {
                    Label("Add timestamp", systemImage: "clock")
                }
                Button {
                    session.elements.append(ChatElement(style: .notice, text: "🔒 Notice"))
                } label: {
                    Label("Add notice", systemImage: "lock.shield")
                }
                Divider()
                Button {
                    session.isVerified.toggle()
                } label: {
                    Label(session.isVerified ? "Hide verified badge" : "Show verified badge",
                          systemImage: "checkmark.circle")
                }
                Divider()
                Button {
                    session.badgeNotifications = max(0, session.badgeNotifications - 1)
                } label: {
                    Label("Bell badge minus", systemImage: "bell")
                }
                Button {
                    session.badgeNotifications += 1
                } label: {
                    Label("Bell badge plus", systemImage: "bell")
                }
                Button {
                    session.badgeMessages = max(0, session.badgeMessages - 1)
                } label: {
                    Label("Messages badge minus", systemImage: "envelope")
                }
                Button {
                    session.badgeMessages += 1
                } label: {
                    Label("Messages badge plus", systemImage: "envelope")
                }
                Divider()
                Button {
                    showExport = true
                } label: {
                    Label("Export screenshot", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Theme.secondaryText)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.bubbleGray))
            }
            HStack(spacing: 12) {
                Text("Message")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "waveform")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.bubbleGray))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
        case .element(let id):
            if let el = elements.first(where: { $0.id == id }) {
                switch el.style {
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
            session.displayName = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .element(let id):
            if let idx = session.elements.firstIndex(where: { $0.id == id }) {
                session.elements[idx].text = editorText
            }
        case nil:
            break
        }
        showEditor = false
    }

    // MARK: Export sheet

    private var exportSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Toggle(isOn: $highRes) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("High resolution (3×)")
                        Text("1200 × 2400 px PNG")
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
        let canvas = PhoneCanvas(
            elements: elements,
            displayName: displayName,
            isVerified: isVerified,
            avatarImage: avatarImage,
            badgeNotifications: session.badgeNotifications,
            badgeMessages: session.badgeMessages
        )
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = highRes ? 3.0 : 1.0
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSaved = true
    }
}

// MARK: - Static export canvas (400 × 800 phone frame)

struct PhoneCanvas: View {
    let elements: [ChatElement]
    let displayName: String
    let isVerified: Bool
    let avatarImage: UIImage?
    var badgeNotifications: Int = 4
    var badgeMessages: Int = 7

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 12) {
                ForEach(elements) { element in
                    switch element.style {
                    case .timestamp: TimestampView(text: element.text)
                    case .notice: NoticeView(text: element.text)
                    case .sent: MessageBubble(text: element.text, isSent: true)
                    case .received: MessageBubble(text: element.text, isSent: false)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            inputBar
            XTabBar(badgeNotifications: badgeNotifications, badgeMessages: badgeMessages)
        }
        .frame(width: 400, alignment: .top)
        .frame(minHeight: 800, alignment: .top)
        .background(Theme.black)
    }

    private var header: some View {
        HStack(spacing: 12) {
            BackArrow(size: 20)
            Group {
                if let avatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Theme.avatarGray
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayName.isEmpty ? " " : displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                if isVerified {
                    VerifiedBadge(size: 14)
                }
            }
            Spacer()
            PhoneCallIcon(size: 20)
                .padding(.trailing, 16)
            VideoCallIcon(size: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.bubbleGray))
            HStack(spacing: 12) {
                Text("Message")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "waveform")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.bubbleGray))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
