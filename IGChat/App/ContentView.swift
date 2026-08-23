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
    var subtitle: String = "Business chat"
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
                Text(subtitle.isEmpty ? " " : subtitle)
                    .font(.system(size: 10))
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
    var following: Bool = false
    var showFollow: Bool = false
    var learnLinkEnabled: Bool = true
    var seenEnabled: Bool = false
    var seenText: String = "Seen"

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

            ForEach(profile.infoLines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.top, 2)
            }

            (Text("\(profile.followers) followers")
                + Text(" · ")
                + Text("\(profile.posts) posts"))
                .font(.system(size: 14))
                .foregroundColor(Theme.secondaryText)
                .padding(.top, 4)
                .contentShape(Rectangle())
                .onTapGesture { statTap?() }

            if !following {
                Text(profile.statusLine)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.top, 2)
                    .contentShape(Rectangle())
                    .onTapGesture { statusTap?() }
            }

            if learnLinkEnabled {
                Text("Learn about business chats")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.learnBlue)
                    .padding(.top, 8)
            }

            HStack(spacing: 8) {
                profileButton("View profile")
                if showFollow && !following {
                    profileButton("Follow")
                }
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
        Text(verbatim: normalized)
            .font(.system(size: 13))
            .lineSpacing(13 * 0.28)          // tight leading (IG ~1.32)
            .foregroundColor(.white)
    }

    /// Collapse blank lines between paragraphs to single tight breaks —
    /// long chats read as one dense block, exactly like the HTML tool.
    private var normalized: String {
        text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

struct SentBubbleView: View {
    let text: String
    /// Viewport position of the bubble's top & bottom edges (0 = top of viewport, 1 = bottom).
    /// The bubble acts as a window into a gradient FIXED to the viewport.
    var screenTop: Double?
    var screenBottom: Double?
    /// v1.18: dynamic gradient endpoints (Look & feel controls)
    var gradA: Color = Color(red: 0x6B/255, green: 0x3F/255, blue: 0xC7/255)
    var gradB: Color = Color(red: 0x51/255, green: 0x58/255, blue: 0xDF/255)
    var gradTop: Double = 15
    var gradBottom: Double = 30

    private func rgb(_ c: Color) -> (Double, Double, Double) {
        let cg = c.cgColor ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        let k = cg.components ?? [0, 0, 0, 1]
        return (Double(k[0]), Double(k[1]), Double(k[2]))
    }

    /// v1.19: gradient zone now user-controllable — gradA fills above gradTop% of screen,
    /// transitions to gradB by gradBottom%, gradB below. Bubble samples its screen-space edges.
    private func viewportColor(_ p: Double) -> Color {
        let t = min(max(p, 0), 1)
        let top = gradTop / 100, bot = gradBottom / 100
        let k = bot > top ? min(max((bot - t) / (bot - top), 0), 1) : (t <= bot ? 1 : 0)
        let (ar, ag, ab) = rgb(gradA)
        let (br, bg, bb) = rgb(gradB)
        return Color(red: br + (ar - br) * k,
                     green: bg + (ag - bg) * k,
                     blue: bb + (ab - bb) * k)
    }

    private var fill: LinearGradient {
        guard let top = screenTop, let bottom = screenBottom else {
            return LinearGradient(colors: [gradA, gradB], startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [viewportColor(top), viewportColor(max(bottom, top))],
                              startPoint: .top, endPoint: .bottom)
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
                // align avatar bottom with the BUBBLE bottom (not the hint below it)
                .alignmentGuide(.bottom) { d in
                    d[.bottom] + (heartHint ? 25 : 0)
                }
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
    @Binding var placeholder: String

    var body: some View {
        ChatBarView(placeholder: $placeholder)
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
            .onTapGesture { tap?() }
    }
}

// MARK: - Position gradient + top fade mask helpers

struct BubbleEdges: Equatable {
    var top: Double
    var bottom: Double
}

struct BubbleProgressKey: PreferenceKey {
    static var defaultValue: [ChatElement.ID: BubbleEdges] = [:]
    static func reduce(value: inout [ChatElement.ID: BubbleEdges], nextValue: () -> [ChatElement.ID: BubbleEdges]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

// MARK: - Static export canvas (400 × 800)

/// Top frost band — isolated so the main body stays type-checkable.
struct FrostBand: View {
    var bandPct: Double
    var frostBlur: Double

    var body: some View {
        GeometryReader { geo in
            let bandH = geo.size.height * (bandPct / 100.0)
            ZStack {
                Rectangle().fill(.thickMaterial)
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(.regularMaterial)
            }
            .frame(height: bandH)
            .blur(radius: CGFloat(max(frostBlur - 20, 0) / 2))
            .frame(maxHeight: .infinity, alignment: .top)
            .mask(alignment: .top) {
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.5),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .frame(height: bandH)
            }
            .overlay(alignment: .top) {
                LinearGradient(stops: [
                    .init(color: Theme.black.opacity(0.9), location: 0),
                    .init(color: Theme.black.opacity(0.9), location: 0.5),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
                .frame(height: bandH)
                .allowsHitTesting(false)
            }
            .allowsHitTesting(false)
        }
    }
}

struct PhoneCanvas: View {
    let elements: [ChatElement]
    let profile: IGProfile
    let avatarContent: AvatarContent
    var following: Bool = false
    var showFollow: Bool = false
    var learnLinkEnabled: Bool = true
    var seenEnabled: Bool = false
    var seenText: String = "Seen"
    var gradA: Color = Color(red: 0x6B/255, green: 0x3F/255, blue: 0xC7/255)
    var gradB: Color = Color(red: 0x51/255, green: 0x58/255, blue: 0xDF/255)
    var gradTop: Double = 15
    var gradBottom: Double = 30

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(
                username: profile.username,
                isVerified: profile.isVerified,
                subtitle: profile.subtitle,
                avatarContent: avatarContent
            )

            VStack(spacing: 20) {
                ProfileContextView(
                    profile: profile,
                    avatarContent: avatarContent,
                    following: following,
                    showFollow: showFollow,
                    learnLinkEnabled: learnLinkEnabled,
                    seenEnabled: seenEnabled,
                    seenText: seenText
                )
                ForEach(Array(elements.enumerated()), id: \.element.id) { idx, element in
                    elementView(element)
                    if seenEnabled, idx == (elements.lastIndex(where: { $0.style == .sent }) ?? -1) {
                        HStack {
                            Spacer()
                            Text(seenText)
                                .font(.system(size: 11))
                                .foregroundColor(Color(white: 0.56))
                                .padding(.trailing, 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))

            Spacer(minLength: 0)
            InputBarView(placeholder: .constant(profile.barPlaceholder.isEmpty ? "Message…" : profile.barPlaceholder))
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
            SentBubbleView(text: element.text, screenTop: nil, screenBottom: nil, gradA: gradA, gradB: gradB, gradTop: gradTop, gradBottom: gradBottom)
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

    @State private var rowProgress: [ChatElement.ID: BubbleEdges] = [:]
    @State private var showEditor = false
    @State private var editorText: String = ""
    @State private var editorTarget: EditTarget?

    @State private var showExport = false
    @State private var showSaved = false
    @State private var highRes = true

    // v1.16: settings sheet + seen + follow + info lines + toggles
    @State private var showSettings = false
    @State private var showFollow = true             // true = Follow button visible
    @State private var following = false
    @State private var seenEnabled = true
    @State private var seenHoursAgo = 0              // 0 = plain "Seen", 1-23 = "Seen Xh ago"
    @State private var learnLinkEnabled = true
    @State private var heartHintsEnabled = true

    // v1.17: date separator bucket picker
    @State private var pickerRef: UUID? = nil      // element to insert relative to
    @State private var pickerAbove = false
    @State private var pickedBucket = 0
    @State private var pickedIdx = 0

    // v1.18: multi-chat + look & feel
    @StateObject private var chatStore = ChatStore()
    @State private var showChatList = false

    // Look & feel (gradient colors, band %, frost blur)
    @State private var gradA = Color(red: 0x6B/255, green: 0x3F/255, blue: 0xC7/255)
    @State private var gradB = Color(red: 0x51/255, green: 0x58/255, blue: 0xDF/255)
    @State private var bandPct: Double = 15
    @State private var frostBlur: Double = 14
    @State private var gradTop: Double = 15    // top of transition zone (% of viewport)
    @State private var gradBottom: Double = 30 // bottom of transition zone (% of viewport)

    enum EditTarget: Hashable {
        case username
        case followers
        case posts
        case statusLine
        case placeholder
        case subtitle
        case infoLine(Int)
        case seenHours
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
                InputBarView(tap: { showSettings = true }, placeholder: $profile.barPlaceholder)
            }
            // Progressive frost across the TOP 15% of the screen: content crossing it
            // gaussian-blurs and fades toward black as it approaches the very top,
            // behind the floating glass toolbar.
            FrostBand(bandPct: bandPct, frostBlur: frostBlur)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)

            // Floating toolbar — no header container
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
        .sheet(isPresented: $showSettings) { settingsSheet }
        .sheet(isPresented: Binding(get: { pickerRef != nil }, set: { if !$0 { pickerRef = nil } })) { dateBucketSheet }
        .sheet(isPresented: $showChatList) { chatListSheet }
        .onAppear {
            chatStore.openDefault(elements: elements, title: profile.username)
            if let saved = chatStore.current, !saved.elements.isEmpty, saved.elements != elements {
                elements = saved.elements
            }
            if let p = IGPersistence.loadProfile() { profile = p }
            if let l = IGPersistence.loadLook() {
                gradA = Color(igHex: l.gradAHex)
                gradB = Color(igHex: l.gradBHex)
                bandPct = l.bandPct
                frostBlur = l.frostBlur
                gradTop = l.gradTop
                gradBottom = l.gradBottom
            }
        }
        .onChange(of: profile, perform: { IGPersistence.saveProfile($0) })
        .onChange(of: elements, perform: { chatStore.snapshotCurrent($0) })
        .onChange(of: gradA, perform: { _ in saveLook() })
        .onChange(of: gradB, perform: { _ in saveLook() })
        .onChange(of: bandPct, perform: { _ in saveLook() })
        .onChange(of: frostBlur, perform: { _ in saveLook() })
        .onChange(of: gradTop, perform: { _ in saveLook() })
        .onChange(of: gradBottom, perform: { _ in saveLook() })
        .alert("Saved to Photos", isPresented: $showSaved) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Chat mockup exported to your photo library.")
        }
    }

    @ViewBuilder
    private func elementView(_ element: ChatElement) -> some View {
        Group {
            switch element.style {
            case .date:
                DateSeparatorView(text: element.text)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEdit(.element(element.id), text: element.text) }
                    .contextMenu { dateMenu(element) }
            case .sent:
                SentBubbleView(text: element.text,
                              screenTop: rowProgress[element.id]?.top,
                              screenBottom: rowProgress[element.id]?.bottom,
                              gradA: gradA, gradB: gradB)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEdit(.element(element.id), text: element.text) }
                    .contextMenu { sentMenu(element) }
            case .received:
                ReceivedRowView(
                    text: element.text,
                    heartHint: element.heartHint && heartHintsEnabled,
                    avatarContent: avatarContent
                )
                    .contentShape(Rectangle())
                    .onTapGesture { beginEdit(.element(element.id), text: element.text) }
                    .contextMenu { receivedMenu(element) }
            }
        }
    }

    // MARK: Strict hold-add menus (Me adds only Me, Them only Them)

    /// insert index for "below my chat": right after held row
    /// insert index for "after their chat": after the next different-sender block
    private func strictMenu(_ element: ChatElement, isMe: Bool) -> some View {
        let heldIdx = elements.firstIndex(where: { $0.id == element.id }) ?? 0
        let style: ChatElement.Style = isMe ? .sent : .received
        let label = isMe ? "Me" : "Them"

        return Group {
            Button {
                withAnimation { elements.insert(ChatElement(style: style, text: "New message"), at: heldIdx) }
            } label: {
                Label("Add \(label) above", systemImage: "arrow.up")
            }

            // different sender right below?
            let next = heldIdx + 1 < elements.count ? elements[heldIdx + 1] : nil
            if let n = next, n.style != style {
                Button {
                    withAnimation { elements.insert(ChatElement(style: style, text: "New message"), at: heldIdx + 1) }
                } label: {
                    Label("Add \(label) below my chat", systemImage: "arrow.down.to.line")
                }
                // after their block: skip consecutive different-sender rows
                Button {
                    var i = heldIdx + 1
                    while i < elements.count && elements[i].style != style { i += 1 }
                    withAnimation { elements.insert(ChatElement(style: style, text: "New message"), at: i) }
                } label: {
                    Label("Add \(label) after their chat", systemImage: "arrow.down.below.line")
                }
            } else {
                Button {
                    withAnimation { elements.insert(ChatElement(style: style, text: "New message"), at: heldIdx + 1) }
                } label: {
                    Label("Add \(label) below", systemImage: "arrow.down")
                }
            }
        }
    }

    private func sentMenu(_ element: ChatElement) -> some View {
        Group {
            strictMenu(element, isMe: true)
            Divider()
            Button {
                pickerRef = element.id; pickerAbove = true
            } label: { Label("Add date separator above", systemImage: "clock.arrow.circlepath") }
            Button {
                pickerRef = element.id; pickerAbove = false
            } label: { Label("Add date separator below", systemImage: "clock") }
            Toggle(isOn: $seenEnabled) {
                Text("Show \"Seen\" under my chats")
            }
            Divider()
            deleteButton(element)
        }
    }
    private func receivedMenu(_ element: ChatElement) -> some View {
        Group {
            strictMenu(element, isMe: false)
            Divider()
            Toggle(isOn: $heartHintsEnabled) {
                Text("Show \"Double tap to ❤️\"")
            }
            Divider()
            deleteButton(element)
        }
    }

    private func deleteButton(_ element: ChatElement) -> some View {
        Button(role: .destructive) {
            withAnimation { elements.removeAll { $0.id == element.id } }
        } label: {
            Label("Delete this message", systemImage: "trash")
        }
    }

    private func dateMenu(_ element: ChatElement) -> some View {
        let idx = elements.firstIndex(where: { $0.id == element.id }) ?? 0
        return Group {
            Button {
                withAnimation { elements.insert(ChatElement(style: .sent, text: "New message"), at: idx) }
            } label: { Label("Add Me above", systemImage: "arrow.up") }
            Button {
                withAnimation { elements.insert(ChatElement(style: .sent, text: "New message"), at: idx + 1) }
            } label: { Label("Add Me below", systemImage: "arrow.down") }
            Button {
                withAnimation { elements.insert(ChatElement(style: .received, text: "New message"), at: idx) }
            } label: { Label("Add Them above", systemImage: "arrow.up") }
            Button {
                withAnimation { elements.insert(ChatElement(style: .received, text: "New message"), at: idx + 1) }
            } label: { Label("Add Them below", systemImage: "arrow.down") }
            Divider()
            deleteButton(element)
        }
    }

    // MARK: Live header (interactive)

    private var liveHeader: some View {
        HStack(spacing: 12) {
            GlassCircle(size: 46) {
                BackButtonArt(height: 19)
            }
            .onTapGesture { chatStore.snapshotCurrent(elements); showChatList = true }

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
                Text(profile.subtitle.isEmpty ? " " : profile.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEdit(.subtitle, text: profile.subtitle) }
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
                        Toggle("Show Follow button", isOn: $showFollow)
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
                        ForEach(Array(elements.enumerated()), id: \.element.id) { idx, element in
                            elementView(element)
                                .background(
                                    // per-row viewport tracking for the fixed-gradient window
                                    GeometryReader { row in
                                        let f = row.frame(in: .named("viewport"))
                                        let h = max(outer.size.height, 1)
                                        Color.clear.preference(
                                            key: BubbleProgressKey.self,
                                            value: [element.id: BubbleEdges(top: Double(f.minY / h), bottom: Double(f.maxY / h))]
                                        )
                                    }
                                )

                            // "Seen" under the last Me bubble (right-aligned, grayed)
                            if seenEnabled,
                               let lastMe = elements.lastIndex(where: { $0.style == .sent }),
                               idx == lastMe {
                                seenMarker
                            }
                        }
                    }
                    .padding(EdgeInsets(top: 108, leading: 16, bottom: 4, trailing: 16))
                }
                .coordinateSpace(name: "viewport")
                .onPreferenceChange(BubbleProgressKey.self) { dict in
                    rowProgress = dict
                }
                .onChange(of: elements.count) { _ in
                    if let last = elements.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
    }

    private var seenMarker: some View {
        HStack {
            Spacer()
            Text(seenText)
                .font(.system(size: 11))
                .foregroundColor(Color(white: 0.56))
                .padding(.trailing, 4)
                .contentShape(Rectangle())
                .onTapGesture { beginEdit(.seenHours, text: String(seenHoursAgo)) }
        }
        .frame(maxWidth: .infinity)
    }

    private var seenText: String {
        if seenHoursAgo > 0 && seenHoursAgo < 24 {
            return "Seen \(seenHoursAgo)h ago"
        }
        return "Seen"
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
            .onTapGesture { beginEdit(.username, text: profile.username) }
            .onLongPressGesture {
                withAnimation { profile.infoLines.insert("Full name", at: 0) }
            }

            // info lines (fullname etc.) — tight stack, same style as status
            ForEach(profile.infoLines.indices, id: \.self) { i in
                Text(profile.infoLines[i])
                    .font(.system(size: 14))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.top, 2)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEdit(.infoLine(i), text: profile.infoLines[i]) }
                    .onLongPressGesture {
                        withAnimation { profile.infoLines.insert("New line", at: i + 1) }
                    }
            }

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

            if !following {
                Text(profile.statusLine)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.secondaryText)
                    .padding(.top, 2)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEdit(.statusLine, text: profile.statusLine) }
                    .onLongPressGesture {
                        withAnimation { profile.statusLine = profile.statusLine + "\nNew line" }
                    }
            }

            if learnLinkEnabled {
                Text("Learn about business chats")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.learnBlue)
                    .padding(.top, 8)
            }

            HStack(spacing: 8) {
                Text("View profile")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.profileButton))

                if showFollow && !following {
                    Text("Follow")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.profileButton))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                following = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                withAnimation { showFollow = false }
                            }
                        }
                }
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
        case .placeholder: return "Message placeholder"
        case .subtitle: return "Subtitle (Business chat)"
        case .infoLine: return "Text line"
        case .seenHours: return "Seen — hours ago (0 = plain, 24+ = plain)"
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
        case .placeholder:
            profile.barPlaceholder = editorText
        case .subtitle:
            profile.subtitle = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .infoLine(let i):
            if profile.infoLines.indices.contains(i) {
                profile.infoLines[i] = editorText
            }
        case .seenHours:
            let n = Int(editorText.trimmingCharacters(in: .whitespaces)) ?? 0
            seenHoursAgo = max(0, min(n, 48))
        case .element(let id):
            if let idx = elements.firstIndex(where: { $0.id == id }) {
                elements[idx].text = editorText
            }
        case nil:
            break
        }
        showEditor = false
    }

    // MARK: Chat list (v1.18) — back button opens this

    private var chatListSheet: some View {
        NavigationStack {
            List {
                ForEach(chatStore.chats) { chat in
                    Button {
                        chatStore.snapshotCurrent(elements)
                        chatStore.currentId = chat.id
                        elements = chat.elements
                        showChatList = false
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [gradA, gradB], startPoint: .topLeading, endPoint: .bottomTrailing))
                                Text(String(chat.title.prefix(1)).uppercased())
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 56, height: 56)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(chat.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(lastMessage(in: chat))
                                    .font(.system(size: 13))
                                    .foregroundColor(Theme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            chatStore.deleteChat(chat.id)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }

                Button {
                    let chat = chatStore.createChat()
                    elements = chat.elements
                    showChatList = false
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.barPurple)
                        Text("New chat")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.black.ignoresSafeArea())
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showChatList = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func saveLook() {
        IGPersistence.saveLook(.init(gradAHex: gradA.igHex, gradBHex: gradB.igHex,
                                     bandPct: bandPct, frostBlur: frostBlur,
                                     gradTop: gradTop, gradBottom: gradBottom))
    }

    private func lastMessage(in chat: ChatSession) -> String {
        chat.elements.last(where: { $0.style != .date })?.text ?? "No messages"
    }

    // MARK: Date separator bucket picker (4 cards, tap = select, tap again = shuffle, Add = insert)

    private var dateBucketSheet: some View {
        let buckets = DateBuckets.buckets()
        return NavigationStack {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(buckets.enumerated()), id: \.1.id) { bi, bk in
                        let isPicked = bi == pickedBucket
                        Button {
                            if pickedBucket == bi {
                                pickedIdx = (pickedIdx + 1) % max(bk.options.count, 1)
                            } else {
                                pickedBucket = bi
                                pickedIdx = Int.random(in: 0..<max(bk.options.count, 1))
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(bk.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text(bk.options.indices.contains(pickedIdx) && isPicked
                                     ? bk.options[pickedIdx].label
                                     : (bk.options.first?.label ?? ""))
                                    .font(.system(size: 12.5))
                                    .foregroundColor(Theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.17, green: 0.17, blue: 0.18))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(isPicked ? Theme.barPurple : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)

                Text("Tap the card again to shuffle the time")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.secondaryText)

                Button {
                    insertPickedSeparator(buckets: buckets)
                } label: {
                    Text("Add separator")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.barPurple))
                        .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.top, 18)
            .navigationTitle("When?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { pickerRef = nil }
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.height(340)])
    }

    private func insertPickedSeparator(buckets: [DateBuckets.Bucket]) {
        guard let ref = pickerRef,
              let idx = elements.firstIndex(where: { $0.id == ref }) else { return }
        guard buckets.indices.contains(pickedBucket) else { return }
        let bucket = buckets[pickedBucket]
        guard bucket.options.indices.contains(pickedIdx) else { return }
        let label = bucket.options[pickedIdx].label
        withAnimation {
            elements.insert(ChatElement(style: .date, text: label), at: pickerAbove ? idx : idx + 1)
        }
        pickerRef = nil
    }

    // MARK: Settings sheet (triggered by chat bar — its only job)

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("Target profile") {
                    TextField("Username", text: $profile.username)
                    TextField("Followers", text: $profile.followers)
                    TextField("Posts", text: $profile.posts)
                    Toggle("Verified badge", isOn: $profile.isVerified)
                    TextField("Message placeholder", text: $profile.barPlaceholder)
                }
                Section("Display") {
                    Toggle("Show Follow button", isOn: $showFollow)
                    Toggle("Show \"Learn about business chats\"", isOn: $learnLinkEnabled)
                    Toggle("Show \"Double tap to ❤️\" hints", isOn: $heartHintsEnabled)
                }
                Section("Look & feel") {
                    ColorPicker("Gradient start", selection: Binding(
                        get: { gradA },
                        set: { gradA = $0.opacity(1) }), supportsOpacity: false)
                    ColorPicker("Gradient end", selection: Binding(
                        get: { gradB },
                        set: { gradB = $0.opacity(1) }), supportsOpacity: false)
                    VStack(alignment: .leading) {
                        Text("Gradient zone: \(Int(gradTop))% \u{2192} \(Int(gradBottom))% of screen")
                        Slider(value: $gradTop, in: 0...60, step: 1)
                        Slider(value: $gradBottom, in: 10...90, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Frost band height: \(Int(bandPct))%")
                        Slider(value: $bandPct, in: 5...40, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Frost blur: \(Int(frostBlur))px")
                        Slider(value: $frostBlur, in: 0...30, step: 1)
                    }
                }
                Section("Seen") {
                    Toggle("\"Seen\" under last Me message", isOn: $seenEnabled)
                    if seenEnabled {
                        Stepper("Hours ago: \(seenHoursAgo == 0 ? "plain" : "\(seenHoursAgo)h")", value: $seenHoursAgo, in: 0...48)
                    }
                }
                Section("Messages") {
                    Button {
                        elements.append(ChatElement(style: .sent, text: "New message"))
                    } label: {
                        Label("Add Me bubble", systemImage: "arrow.up.circle")
                    }
                    Button {
                        elements.append(ChatElement(style: .received, text: "New message"))
                    } label: {
                        Label("Add Them bubble", systemImage: "arrow.down.circle")
                    }
                    Button {
                        elements.append(ChatElement(style: .date, text: IGSeed.smartDate()))
                    } label: {
                        Label("Add date separator", systemImage: "clock")
                    }
                    Button(role: .destructive) {
                        elements.removeAll()
                    } label: {
                        Label("Clear all messages", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Chat settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSettings = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
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
            avatarContent: avatarContent,
            following: following,
            showFollow: showFollow,
            learnLinkEnabled: learnLinkEnabled,
            seenEnabled: seenEnabled,
            seenText: seenText
        )
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = highRes ? 3.0 : 1.0
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showSaved = true
    }
}
