import SwiftUI
import PhotosUI

// MARK: - Shapes

struct IGBubbleShape: Shape {
    let isSent: Bool

    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 20
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

// MARK: - Avatar

enum AvatarContent {
    case placeholder(String)
    case image(UIImage)
}

struct AvatarView: View {
    let content: AvatarContent
    var size: CGFloat

    var body: some View {
        Group {
            switch content {
            case .placeholder(let initials):
                ZStack {
                    Circle().fill(Color.white)
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundColor(.black)
                }
            case .image(let img):
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Status bar

// MARK: - Verified badge (defined in IGIcons.swift — real IG starburst SVG)

// MARK: - Chat header

struct ChatHeaderView: View {
    let username: String
    let isVerified: Bool
    let avatarContent: AvatarContent
    var avatarTap: (() -> Void)?
    var nameTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            BackButtonArt(height: 22)

            AvatarView(content: avatarContent, size: 32)
                .onTapGesture { avatarTap?() }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(username.isEmpty ? " " : username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if isVerified {
                        VerifiedBadge(size: 13)
                    }
                }
                Text("Business chat")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)
            }
            .contentShape(Rectangle())
            .onTapGesture { nameTap?() }

            Spacer()

            HeaderGlassStatic()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Profile context block

struct ProfileContextView: View {
    let profile: IGProfile
    let avatarContent: AvatarContent
    var statTap: (() -> Void)?
    var statusTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            AvatarView(content: avatarContent, size: 96)

            HStack(spacing: 5) {
                Text(profile.username.isEmpty ? " " : profile.username)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                if profile.isVerified {
                    VerifiedBadge(size: 15)
                }
            }
            .padding(.top, 12)

            (Text("\(profile.followers) followers")
                + Text(" · ")
                + Text("\(profile.posts) posts"))
                .font(.system(size: 14))
                .foregroundColor(Theme.secondaryText)
                .padding(.top, 4)
                .contentShape(Rectangle())
                .onTapGesture { statTap?() }

            Text(profile.statusLine)
                .font(.system(size: 14))
                .foregroundColor(Theme.secondaryText)
                .padding(.top, 4)
                .contentShape(Rectangle())
                .onTapGesture { statusTap?() }

            Text("Learn about business chats")
                .font(.system(size: 14))
                .foregroundColor(Theme.linkPale)
                .padding(.top, 8)

            HStack(spacing: 8) {
                profileButton("View profile")
                profileButton("Delete")
            }
            .padding(.top, 12)
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private func profileButton(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.profileButton))
    }
}

// MARK: - Messages

struct DateSeparatorView: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(Theme.dateText)
            .frame(maxWidth: .infinity)
    }
}

struct MessageTextView: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 15))
            .lineSpacing(15 * 0.4)
            .foregroundColor(.white)
    }
}

struct SentBubbleView: View {
    let text: String
    /// 0 = near the very top of the screen, 1 = near the bottom. nil = static (export uses default gradient).
    var screenProgress: Double?

    /// Blue (top, <70%) -> purple (bottom, >80%), smooth transition between.
    private var fill: LinearGradient {
        let t = min(max(screenProgress ?? 0.85, 0), 1)
        // ramp 0.70...0.80
        let k = min(max((t - 0.70) / 0.10, 0), 1)
        // blue #5158DF -> purple #6B3FC7
        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * k }
        let end = Color(red: lerp(0x51, 0x6B) / 255.0,
                        green: lerp(0x58, 0x3F) / 255.0,
                        blue: lerp(0xDF, 0xC7) / 255.0)
        return LinearGradient(colors: [Theme.gradientStart, end],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        HStack {
            Spacer(minLength: 64)
            MessageTextView(text: text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(IGBubbleShape(isSent: true).fill(fill))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ReceivedRowView: View {
    let text: String
    let heartHint: Bool
    let avatarContent: AvatarContent

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            AvatarView(content: avatarContent, size: 28)
                .padding(.bottom, 24)
            VStack(alignment: .leading, spacing: 6) {
                MessageTextView(text: text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(IGBubbleShape(isSent: false).fill(Theme.bubbleGray))
                    .fixedSize(horizontal: false, vertical: true)
                if heartHint {
                    Text("Double tap to ❤️")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.secondaryText)
                        .padding(.leading, 4)
                }
            }
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Input bar

struct InputBarView: View {
    var tap: (() -> Void)?

    var body: some View {
        ChatBarView()
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { tap?() }
    }
}

// MARK: - Position gradient + top fade mask helpers

struct BubbleProgressKey: PreferenceKey {
    static var defaultValue: [ChatElement.ID: Double] = [:]
    static func reduce(value: inout [ChatElement.ID: Double], nextValue: () -> [ChatElement.ID: Double]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Blur+fade modifier applied to content scrolling under the floating header.
struct UnderHeaderFade: ViewModifier {
    var height: CGFloat
    func body(content: Content) -> some View {
        content
            .mask(
                VStack(spacing: 0) {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                        .frame(height: height)
                    Rectangle().fill(Color.black)
                }
                .frame(maxHeight: .infinity)
            )
    }
}

// MARK: - Static export canvas (400 × 800)

struct PhoneCanvas: View {
    let elements: [ChatElement]
    let profile: IGProfile
    let avatarContent: AvatarContent

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(
                username: profile.username,
                isVerified: profile.isVerified,
                avatarContent: avatarContent
            )
            Rectangle().fill(Theme.headerBorder).frame(height: 1)

            VStack(spacing: 20) {
                ProfileContextView(profile: profile, avatarContent: avatarContent)
                ForEach(elements) { element in
                    elementView(element)
                }
            }
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))

            Spacer(minLength: 0)
            InputBarView()
        }
        .frame(width: 400, alignment: .top)
        .frame(minHeight: 800, alignment: .top)
        .background(Theme.black)
    }

    @ViewBuilder
    private func elementView(_ element: ChatElement) -> some View {
        switch element.style {
        case .date:
            DateSeparatorView(text: element.text)
        case .sent:
            SentBubbleView(text: element.text, screenProgress: nil)
        case .received:
            ReceivedRowView(
                text: element.text,
                heartHint: element.heartHint,
                avatarContent: avatarContent
            )
        }
    }
}

// MARK: - Main view

struct ContentView: View {
    @State private var elements: [ChatElement] = IGSeed.defaultElements()
    @State private var profile = IGProfile()
    @State private var avatarImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?

    @State private var rowProgress: [ChatElement.ID: Double] = [:]
    @State private var showEditor = false
    @State private var editorText: String = ""
    @State private var editorTarget: EditTarget?

    @State private var showExport = false
    @State private var showSaved = false
    @State private var highRes = true

    enum EditTarget: Hashable {
        case username
        case followers
        case posts
        case statusLine
        case element(UUID)
    }

    private var avatarContent: AvatarContent {
        if let avatarImage {
            return .image(avatarImage)
        }
        return .placeholder(profile.initials)
    }

    var body: some View {
        ZStack {
            Theme.black.ignoresSafeArea()
            VStack(spacing: 0) {
                chatArea
                InputBarView(tap: { showEditor = true })
            }
            // Floating toolbar — no header container; messages scrolling under it
            // get gaussian-blurred + faded to black (see UnderHeaderFade on chatArea).
            VStack {
                liveHeader
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                Spacer(minLength: 0)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditor) { editorSheet }
        .sheet(isPresented: $showExport) { exportSheet }
        .alert("Saved to Photos", isPresented: $showSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Chat mockup exported to your photo library.")
        }
    }

    @ViewBuilder
    private func elementView(_ element: ChatElement) -> some View {
        switch element.style {
        case .date:
            DateSeparatorView(text: element.text)
        case .sent:
            SentBubbleView(text: element.text, screenProgress: rowProgress[element.id])
        case .received:
            ReceivedRowView(
                text: element.text,
                heartHint: element.heartHint,
                avatarContent: avatarContent
            )
        }
    }

    // MARK: Live header (interactive)

    private var liveHeader: some View {
        HStack(spacing: 12) {
            GlassCircle(size: 32) {
                BackButtonArt(height: 19)
            }

            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                AvatarView(content: avatarContent, size: 32)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(profile.username.isEmpty ? " " : profile.username)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if profile.isVerified {
                        VerifiedBadge(size: 13)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                profile.isVerified.toggle()
                            }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { beginEdit(.username, text: profile.username) }
                .contextMenu {
                    Button {
                        profile.isVerified.toggle()
                    } label: {
                        Label(
                            profile.isVerified ? "Hide verified badge" : "Show verified badge",
                            systemImage: "checkmark.seal"
                        )
                    }
                }
            }

            Spacer()

            HStack(spacing: 10) {
                GlassCircle(size: 46) {
                    Menu {
                        Button {
                            profile.isVerified.toggle()
                        } label: {
                            Label(
                                profile.isVerified ? "Hide verified badge" : "Show verified badge",
                                systemImage: profile.isVerified ? "checkmark.seal.fill" : "checkmark.seal"
                            )
                        }
                        Divider()
                        Button {
                            elements.append(ChatElement(style: .sent, text: "New message"))
                        } label: {
                            Label("Purple bubble (Me)", systemImage: "arrow.up.circle")
                        }
                        Button {
                            elements.append(ChatElement(style: .received, text: "New message"))
                        } label: {
                            Label("Gray bubble (Target)", systemImage: "arrow.down.circle")
                        }
                        Button {
                            elements.append(ChatElement(style: .date, text: "JUL 16 AT 1:11 PM"))
                        } label: {
                            Label("Date separator", systemImage: "clock")
                        }
                        Divider()
                        Button(role: .destructive) {
                            elements.removeAll()
                        } label: {
                            Label("Clear all messages", systemImage: "trash")
                        }
                    } label: {
                        PhonecallArt(height: 22)
                    }
                }
                GlassCircle(size: 46) {
                    Button {
                        showExport = true
                    } label: {
                        VcArt(height: 22)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        liveProfileContext
                        ForEach(elements) { element in
                            elementView(element)
                                .background(
                                    // per-row position tracking for the gradient strategy
                                    GeometryReader { row in
                                        Color.clear.preference(
                                            key: BubbleProgressKey.self,
                                            value: [element.id: Double(row.frame(in: .global).minY / max(outer.size.height, 1))]
                                        )
                                    }
                                )
                        }
                    }
                    .padding(EdgeInsets(top: 76, leading: 16, bottom: 4, trailing: 16))
                }
                .onPreferenceChange(BubbleProgressKey.self) { dict in
                    rowProgress = dict
                }
                .modifier(UnderHeaderFade(height: 86))
                .onChange(of: elements.count) { _ in
                    if let last = elements.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
    }

    private var liveProfileContext: some View {
        VStack(spacing: 0) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                AvatarView(content: avatarContent, size: 96)
            }
            .buttonStyle(.plain)

            HStack(spacing: 5) {
                Text(profile.username.isEmpty ? " " : profile.username)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                if profile.isVerified {
                    VerifiedBadge(size: 15)
                }
            }
            .padding(.top, 12)

            (Text("\(profile.followers) followers")
                + Text(" · ")
                + Text("\(profile.posts) posts"))
                .font(.system(size: 14))
                .foregroundColor(Theme.secondaryText)
                .padding(.top, 4)
                .contentShape(Rectangle())
                .onTapGesture { beginEdit(.followers, text: profile.followers) }
                .contextMenu {
                    Button {
                        beginEdit(.posts, text: profile.posts)
                    } label: {
                        Label("Edit posts count", systemImage: "square.grid.2x2")
                    }
                }

            Text(profile.statusLine)
                .font(.system(size: 14))
                .foregroundColor(Theme.secondaryText)
                .padding(.top, 4)
                .contentShape(Rectangle())
                .onTapGesture { beginEdit(.statusLine, text: profile.statusLine) }

            Text("Learn about business chats")
                .font(.system(size: 14))
                .foregroundColor(Theme.linkPale)
                .padding(.top, 8)

            HStack(spacing: 8) {
                Text("View profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.profileButton))
                Text("Delete")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.profileButton))
            }
            .padding(.top, 12)
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func liveElementView(_ element: ChatElement) -> some View {
        switch element.style {
        case .date:
            DateSeparatorView(text: element.text)
        case .sent:
            SentBubbleView(text: element.text)
        case .received:
            ReceivedRowView(
                text: element.text,
                heartHint: element.heartHint,
                avatarContent: avatarContent
            )
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
                Label("Add purple bubble below", systemImage: "arrow.up.circle")
            }
            Button {
                insertAfter(element, style: .received, text: "New message")
            } label: {
                Label("Add gray bubble below", systemImage: "arrow.down.circle")
            }
            Button {
                insertAfter(element, style: .date, text: "JUL 16 AT 1:11 PM")
            } label: {
                Label("Add date separator below", systemImage: "clock")
            }
            if element.style == .received {
                Divider()
                Button {
                    if let idx = elements.firstIndex(where: { $0.id == element.id }) {
                        elements[idx].heartHint.toggle()
                    }
                } label: {
                    Label(
                        element.heartHint ? "Hide \u{201C}Double tap\u{201D} hint" : "Show \u{201C}Double tap to ❤️\u{201D}",
                        systemImage: "heart"
                    )
                }
            }
        }
    }

    private func insertAfter(_ element: ChatElement, style: ChatElement.Style, text: String) {
        guard let idx = elements.firstIndex(where: { $0.id == element.id }) else { return }
        elements.insert(ChatElement(style: style, text: text), at: elements.index(after: idx))
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
        case .username: return "Username"
        case .followers: return "Followers"
        case .posts: return "Posts"
        case .statusLine: return "Status line"
        case .element(let id):
            if let el = elements.first(where: { $0.id == id }) {
                switch el.style {
                case .date: return "Date separator"
                case .sent: return "Purple message"
                case .received: return "Gray message"
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
        case .username:
            profile.username = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .followers:
            profile.followers = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .posts:
            profile.posts = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .statusLine:
            profile.statusLine = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
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
                .tint(Theme.igBlue)
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
                        .background(Capsule().fill(Theme.igBlue))
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
            profile: profile,
            avatarContent: avatarContent
        )
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = highRes ? 3.0 : 1.0
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSaved = true
    }
}
