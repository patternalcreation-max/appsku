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

struct ContentView: View {
    @State private var elements: [ChatElement] = ChatSeed.defaultElements()
    @State private var displayName: String = "lauren"
    @State private var isVerified: Bool = true
    @State private var avatarImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?

    @State private var showEditor = false
    @State private var editorText: String = ""
    @State private var editorTarget: EditTarget?

    @State private var showExport = false
    @State private var showSaved = false
    @State private var highRes = true

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
                XTabBar()
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
            Image(systemName: "chevron.backward")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.primaryText)

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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.blue)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { beginEdit(.name, text: displayName) }
            .contextMenu {
                Button {
                    isVerified.toggle()
                } label: {
                    Label(isVerified ? "Hide verified badge" : "Show verified badge",
                          systemImage: "checkmark.circle")
                }
            }

            Spacer()

            Image(systemName: "phone")
                .font(.system(size: 18))
                .foregroundColor(Theme.primaryText)
            Image(systemName: "video")
                .font(.system(size: 18))
                .foregroundColor(Theme.primaryText)
            Button {
                showExport = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                    .foregroundColor(Theme.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: photoPickerItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { avatarImage = image }
                }
            }
        }
    }

    // MARK: Chat area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($elements) { $element in
                        elementView(element)
                            .id(element.id)
                            .contentShape(Rectangle())
                            .onTapGesture { beginEdit(.element(element.id), text: element.text) }
                            .contextMenu { elementMenu(for: element) }
                    }
                }
                .padding(16)
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
                elements.removeAll { $0.id == element.id }
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
        guard let idx = elements.firstIndex(where: { $0.id == element.id }) else { return }
        elements.insert(ChatElement(style: style, text: text), at: elements.index(after: idx))
    }

    // MARK: Input bar

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
                    .foregroundColor(Theme.secondaryText)
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
            displayName = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .element(let id):
            if let idx = elements.firstIndex(where: { $0.id == id }) {
                elements[idx].text = editorText
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
            avatarImage: avatarImage
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
            XTabBar()
        }
        .frame(width: 400, alignment: .top)
        .frame(minHeight: 800, alignment: .top)
        .background(Theme.black)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Theme.primaryText)
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
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.blue)
                }
            }
            Spacer()
            Image(systemName: "phone")
                .font(.system(size: 18))
                .foregroundColor(Theme.primaryText)
            Image(systemName: "video")
                .font(.system(size: 18))
                .foregroundColor(Theme.primaryText)
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
                    .foregroundColor(Theme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.bubbleGray))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
