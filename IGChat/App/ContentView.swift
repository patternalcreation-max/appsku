import SwiftUI
import UIKit
import PhotosUI

// MARK: - Shapes (IGBubbleShape lives in BubbleKit.swift)

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
    var showStatusAlways: Bool = true

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
    var showStatusAlways: Bool = true

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

            if showStatusAlways || !following {
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

/// Screen-locked Me wash (IG DM style). Pure math — no giant offset gradient.
enum MeWash {
    /// Color at viewport t (0 = top of chat, 1 = bottom).
    static func color(at t: Double, a: Color, b: Color, purpleUntil: Double, blueFrom: Double) -> Color {
        let top = min(max(purpleUntil, 0), 0.98)
        let bot = max(min(blueFrom, 1), top + 0.01)
        let x = min(max(t, 0), 1)
        if x <= top { return a }
        if x >= bot { return b }
        let u = (x - top) / (bot - top)
        return mix(a, b, u)
    }

    static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let u = min(max(t, 0), 1)
        let ua = UIColor(a)
        let ub = UIColor(b)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        ua.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        ub.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            red: Double(ar + (br - ar) * u),
            green: Double(ag + (bg - ag) * u),
            blue: Double(ab + (bb - ab) * u),
            opacity: Double(aa + (ba - aa) * u)
        )
    }

    /// Local vertical gradient for a bubble spanning viewport t0…t1.
    static func stops(t0: Double, t1: Double, a: Color, b: Color, purpleUntil: Double, blueFrom: Double) -> [Gradient.Stop] {
        let lo = min(t0, t1)
        let hi = max(t0, t1)
        let span = max(hi - lo, 0.0001)
        let top = min(max(purpleUntil, 0), 0.98)
        let bot = max(min(blueFrom, 1), top + 0.01)

        // Key viewport positions that affect this bubble
        var keys: [Double] = [lo, hi]
        if top > lo && top < hi { keys.append(top) }
        if bot > lo && bot < hi { keys.append(bot) }
        // a couple mid samples in the fade for smoothness
        if bot > top {
            for i in 1..<4 {
                let k = top + (bot - top) * Double(i) / 4.0
                if k > lo && k < hi { keys.append(k) }
            }
        }
        let uniq = Array(Set(keys.map { (round($0 * 10000) / 10000) })).sorted()

        return uniq.map { t in
            let local = (t - lo) / span
            return Gradient.Stop(
                color: color(at: t, a: a, b: b, purpleUntil: purpleUntil, blueFrom: blueFrom),
                location: min(max(local, 0), 1)
            )
        }
    }
}

struct SentBubbleView: View {
    let text: String
    var replyText: String? = nil
    var replyFromMe: Bool = false
    var replyName: String = "You"
    var replyKind: ReplyKind = .chat
    var replyImage: UIImage? = nil
    var photo: UIImage? = nil
    var position: BubbleGroupPos = .single
    var photoFrame: PhotoFrame = .default
    var photoMaxWidth: CGFloat = 280
    /// Chat viewport size — gradient is locked to the visible chat band (below header).
    var viewportSize: CGSize = .zero
    /// Y where chat content starts (header chrome). Wash t=0 begins here, not at the notch.
    var washTopInset: CGFloat = 0
    /// Bottom chrome (input bar) excluded from wash band.
    var washBottomInset: CGFloat = 0
    var gradA: Color = Color(red: 0xD9/255, green: 0x46/255, blue: 0xEF/255)
    var gradB: Color = Color(red: 0x3B/255, green: 0x5B/255, blue: 0xDB/255)
    var gradTop: Double = 35
    var gradBottom: Double = 60

    /// Screen-locked fill: sample wash across this bubble’s Y in the content band (below header).
    private func meBubbleBackground() -> some View {
        GeometryReader { geo in
            let f = geo.frame(in: .named("viewport"))
            let vh = max(viewportSize.height, 1)
            let top = max(washTopInset, 0)
            let bottom = max(washBottomInset, 0)
            let usable = max(vh - top - bottom, 1)
            // Remap: first bubble under header → t≈0 (full ungu). Bottom of chat → t≈1 (biru).
            let t0 = Double((f.minY - top) / usable)
            let t1 = Double((f.maxY - top) / usable)
            let stops = MeWash.stops(
                t0: t0, t1: t1,
                a: gradA, b: gradB,
                purpleUntil: gradTop / 100.0,
                blueFrom: gradBottom / 100.0
            )
            LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var hasReply: Bool {
        let t = (replyText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty || replyImage != nil || replyKind == .story
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if hasReply {
                ReplyChrome(
                    isSent: true,
                    kind: replyKind,
                    replyFromMe: replyFromMe,
                    peerName: replyName,
                    replyText: replyText,
                    replyImage: replyImage,
                    meQuoteFill: gradA
                )
            }
            if let photo {
                HStack {
                    Spacer(minLength: 48)
                    PhotoMessageView(image: photo, isSent: true, position: position, frame: photoFrame, maxWidth: photoMaxWidth)
                }
            }
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let link = LinkURLAnalyzer.analyze(text)
                if let link, link.isURLOnly {
                    LinkPreviewBlock(text: text, isSent: true)
                } else {
                    HStack {
                        Spacer(minLength: 64)
                        MessageTextView(text: text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(meBubbleBackground())
                            .clipShape(IGBubbleShape(isSent: true, position: position))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if link != nil {
                        LinkPreviewBlock(text: text, isSent: true)
                    }
                }
            }
        }
    }
}

struct ReceivedRowView: View {
    let text: String
    let heartHint: Bool
    let avatarContent: AvatarContent
    var showAvatar: Bool = true
    var replyText: String? = nil
    var replyFromMe: Bool = false
    var replyName: String = "You"
    var replyKind: ReplyKind = .chat
    var replyImage: UIImage? = nil
    var photo: UIImage? = nil
    var position: BubbleGroupPos = .single
    var photoFrame: PhotoFrame = .default
    var photoMaxWidth: CGFloat = 280
    var gradA: Color = Color(red: 0xD9/255, green: 0x46/255, blue: 0xEF/255)

    private var hasReply: Bool {
        let t = (replyText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty || replyImage != nil || replyKind == .story
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if showAvatar {
                AvatarView(content: avatarContent, size: 28)
                    .alignmentGuide(.bottom) { d in
                        d[.bottom] + (heartHint ? 25 : 0)
                    }
            } else {
                Color.clear.frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 6) {
                if hasReply {
                    ReplyChrome(
                        isSent: false,
                        kind: replyKind,
                        replyFromMe: replyFromMe,
                        peerName: replyName,
                        replyText: replyText,
                        replyImage: replyImage,
                        meQuoteFill: gradA
                    )
                }
                if let photo {
                    PhotoMessageView(image: photo, isSent: false, position: position, frame: photoFrame, maxWidth: photoMaxWidth)
                }
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let link = LinkURLAnalyzer.analyze(text)
                    if let link, link.isURLOnly {
                        LinkPreviewBlock(text: text, isSent: false)
                    } else {
                        MessageTextView(text: text)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(IGBubbleShape(isSent: false, position: position).fill(Theme.bubbleGray))
                            .fixedSize(horizontal: false, vertical: true)
                        if link != nil {
                            LinkPreviewBlock(text: text, isSent: false)
                        }
                    }
                }
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

/// Soft header frost — same canvas color as chat BG (#0E1217), soft bottom edge.
/// UIKit materials always lighten dark backgrounds into a grey “aura”; we skip them
/// so the band never shifts color. Content under the header dissolves into the canvas.
struct HeaderBlurBand: View {
    var safeTop: CGFloat
    var frostBlur: Double = 22
    var chromeHeight: CGFloat = 92

    private var bandH: CGFloat { safeTop + chromeHeight }

    var body: some View {
        GeometryReader { geo in
            let h = max(bandH, 1)
            let soft = 20 + CGFloat(max(frostBlur, 0)) * 0.6
            LinearGradient(stops: [
                .init(color: Theme.black.opacity(1.0), location: 0),
                .init(color: Theme.black.opacity(0.97), location: 0.42),
                .init(color: Theme.black.opacity(0.72), location: 0.68),
                .init(color: Theme.black.opacity(0.28), location: 0.88),
                .init(color: Theme.black.opacity(0.0), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: geo.size.width, height: h + soft)
            .mask(
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.55),
                    .init(color: .black.opacity(0.55), location: 0.78),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
    }
}

// MARK: - Main view

struct ContentView: View {
    @State private var elements: [ChatElement] = IGSeed.defaultElements()
    @State private var profile = IGProfile()
    @State private var avatarImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var messagePhotoPickerItem: PhotosPickerItem?
    @State private var messagePhotoTarget: UUID? = nil   // attach photo to this bubble
    @State private var cropPhotoTarget: UUID? = nil      // edit photo framing
    @State private var cropDraft = PhotoFrame.default
    @State private var replyPhotoPickerItem: PhotosPickerItem?
    @State private var replyPhotoTarget: UUID? = nil     // story/media quote image

    @State private var rowProgress: [ChatElement.ID: BubbleEdges] = [:]
    @State private var viewportSize: CGSize = .zero
    @State private var safeTop: CGFloat = 47
    /// Stable id so the profile / View profile block gets the same pass-under-header blur as bubbles.
    private let profilePassId = UUID(uuidString: "A11CE000-0000-4000-8000-000000000001")!
    @State private var showEditor = false
    @State private var editorText: String = ""
    @State private var editorTarget: EditTarget?

    // v1.16: settings sheet + seen + follow + info lines + toggles
    @State private var showSettings = false
    @State private var showFollow = true             // true = Follow button visible
    @State private var following = false
    @State private var seenEnabled = true
    @State private var seenHoursAgo = 0              // 0 = plain "Seen", 1-23 = "Seen Xh ago"
    @State private var learnLinkEnabled = true
    @State private var heartHintsEnabled = true
    @State private var showStatusAlways = true   // keep "You don't follow..." even when Following

    // v1.17: date separator bucket picker
    @State private var pickerRef: UUID? = nil      // element to insert relative to
    @State private var pickerAbove = false
    @State private var pickedBucket = 0
    @State private var pickedIdx = 0

    // v1.18: multi-chat + look & feel
    @StateObject private var chatStore = ChatStore()
    /// Launch always on list; thread only after explicit open.
    enum AppRoute: Equatable { case list, thread }
    @State private var route: AppRoute = .list
    @Environment(\.scenePhase) private var scenePhase

    // Look & feel
    @State private var gradA = Color(red: 0xD9/255, green: 0x46/255, blue: 0xEF/255)
    @State private var gradB = Color(red: 0x3B/255, green: 0x5B/255, blue: 0xDB/255)
    @State private var frostBlur: Double = 22
    @State private var gradTop: Double = 35
    @State private var gradBottom: Double = 60
    @State private var subtitleFontSize: Double = 10
    @State private var photoWindow: Double = 0.35
    @State private var photoFocusX: Double = 0.5
    @State private var photoFocusY: Double = 0.5
    @State private var photoZoom: Double = 1.0
    @State private var photoMaxWidth: Double = 280

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
        case reply(UUID)
    }

    private var meWashId: String {
        "\(gradA.igHex)-\(gradB.igHex)-\(Int(gradTop))-\(Int(gradBottom))"
    }

    private var defaultPhotoFrame: PhotoFrame {
        PhotoFrame(window: photoWindow, focusX: photoFocusX, focusY: photoFocusY, zoom: photoZoom).clamped()
    }

    private func resolvedFrame(for element: ChatElement) -> PhotoFrame {
        (element.photoFrame ?? defaultPhotoFrame).clamped()
    }

    private var avatarContent: AvatarContent {
        if let avatarImage {
            return .image(avatarImage)
        }
        return .placeholder(profile.initials)
    }

    var body: some View {
        Group {
            switch route {
            case .list:
                chatListRoot
            case .thread:
                threadRoot
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditor) { editorSheet }
        .sheet(isPresented: $showSettings) { settingsSheet }
        .sheet(isPresented: Binding(
            get: { messagePhotoTarget != nil },
            set: { if !$0 { messagePhotoTarget = nil } }
        )) {
            NavigationStack {
                PhotosPicker(selection: $messagePhotoPickerItem, matching: .images) {
                    Label("Choose photo", systemImage: "photo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .navigationTitle("Attach photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { messagePhotoTarget = nil }
                    }
                }
            }
            .presentationDetents([.height(180)])
            .preferredColorScheme(.dark)
        }
                .sheet(isPresented: Binding(
            get: { cropPhotoTarget != nil },
            set: { if !$0 { cropPhotoTarget = nil } }
        )) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Frame like IG")
                            .font(.headline)
                        Text("Window shortens the bubble. Focus pans what’s visible. Zoom punches in.")
                            .font(.caption)
                            .foregroundColor(Theme.secondaryText)

                        if let id = cropPhotoTarget,
                           let el = elements.first(where: { $0.id == id }),
                           let img = ChatImageCodec.image(from: el.imageJPEG) {
                            PhotoMessageView(
                                image: img,
                                isSent: el.style == .sent,
                                position: .single,
                                frame: cropDraft,
                                maxWidth: CGFloat(photoMaxWidth)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Window (height): \(Int(cropDraft.window * 100))%")
                            Slider(value: $cropDraft.window, in: 0...1, step: 0.05)
                            Text("0% full photo · 100% short IG window")
                                .font(.caption2).foregroundColor(Theme.secondaryText)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Focus X — left → right: \(Int(cropDraft.focusX * 100))%")
                            Slider(value: $cropDraft.focusX, in: 0...1, step: 0.05)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Focus Y — top → bottom: \(Int(cropDraft.focusY * 100))%")
                            Slider(value: $cropDraft.focusY, in: 0...1, step: 0.05)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(format: "Zoom: %.2f×", cropDraft.zoom))
                            Slider(value: $cropDraft.zoom, in: 1...2.5, step: 0.05)
                        }

                        Button("Reset to settings defaults") {
                            cropDraft = defaultPhotoFrame
                        }
                        .font(.subheadline)
                    }
                    .padding()
                }
                .navigationTitle("Crop photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { cropPhotoTarget = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            if let id = cropPhotoTarget,
                               let idx = elements.firstIndex(where: { $0.id == id }) {
                                elements[idx].photoFrame = cropDraft.clamped()
                            }
                            cropPhotoTarget = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .preferredColorScheme(.dark)
        }

        .sheet(isPresented: Binding(
            get: { replyPhotoTarget != nil },
            set: { if !$0 { replyPhotoTarget = nil } }
        )) {
            NavigationStack {
                PhotosPicker(selection: $replyPhotoPickerItem, matching: .images) {
                    Label("Choose story / media", systemImage: "circle.dashed")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .navigationTitle("Reply to story")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { replyPhotoTarget = nil }
                    }
                }
            }
            .presentationDetents([.height(180)])
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: Binding(get: { pickerRef != nil }, set: { if !$0 { pickerRef = nil } })) { dateBucketSheet }
        .onAppear {
            // List-first: restore sessions/profile/look/settings but do NOT open a thread.
            chatStore.openDefault(elements: elements, title: profile.username)
            if let p = IGPersistence.loadProfile() { profile = p }
            if let jpeg = IGPersistence.loadAvatarJPEG() {
                avatarImage = ChatImageCodec.image(from: jpeg)
            }
            if let s = IGPersistence.loadSettings() {
                showFollow = s.showFollow
                following = s.following
                seenEnabled = s.seenEnabled
                seenHoursAgo = s.seenHoursAgo
                learnLinkEnabled = s.learnLinkEnabled
                heartHintsEnabled = s.heartHintsEnabled
                showStatusAlways = s.showStatusAlways
            } else if UserDefaults.standard.object(forKey: "igchat.showStatusAlways") != nil {
                // migrate legacy single-key toggle
                showStatusAlways = UserDefaults.standard.bool(forKey: "igchat.showStatusAlways")
            }
            if let l = IGPersistence.loadLook() {
                // Upgrade muted v1 defaults → hot IG wash (old pair was nearly identical violet)
                let mutedOld = Set(["6B3FC7", "5158DF"])
                if mutedOld.contains(l.gradAHex.uppercased()) && mutedOld.contains(l.gradBHex.uppercased()) {
                    gradA = Color(red: 0xD9/255, green: 0x46/255, blue: 0xEF/255)
                    gradB = Color(red: 0x3B/255, green: 0x5B/255, blue: 0xDB/255)
                    gradTop = 35
                    gradBottom = 60
                } else {
                    gradA = Color(igHex: l.gradAHex)
                    gradB = Color(igHex: l.gradBHex)
                    gradTop = l.gradTop
                    gradBottom = l.gradBottom
                }
                frostBlur = l.frostBlur
                subtitleFontSize = l.subtitleFontSize
                photoWindow = l.photoWindow != 0 ? l.photoWindow : l.landscapeCrop
                photoFocusX = l.photoFocusX
                photoFocusY = l.photoFocusY
                photoZoom = max(l.photoZoom, 1)
                photoMaxWidth = l.photoMaxWidth > 0 ? l.photoMaxWidth : 280
            }
        }
        .onChange(of: profile, perform: { IGPersistence.saveProfile($0) })
        .onChange(of: elements, perform: { chatStore.snapshotCurrent($0) })
        .onChange(of: showFollow, perform: { _ in saveSettings() })
        .onChange(of: following, perform: { _ in saveSettings() })
        .onChange(of: seenEnabled, perform: { _ in saveSettings() })
        .onChange(of: seenHoursAgo, perform: { _ in saveSettings() })
        .onChange(of: learnLinkEnabled, perform: { _ in saveSettings() })
        .onChange(of: heartHintsEnabled, perform: { _ in saveSettings() })
        .onChange(of: showStatusAlways, perform: { _ in saveSettings() })
        .onChange(of: gradA, perform: { _ in saveLook() })
        .onChange(of: gradB, perform: { _ in saveLook() })
        .onChange(of: frostBlur, perform: { _ in saveLook() })
        .onChange(of: gradTop, perform: { _ in saveLook() })
        .onChange(of: gradBottom, perform: { _ in saveLook() })
        .onChange(of: subtitleFontSize, perform: { _ in saveLook() })
        .onChange(of: photoWindow, perform: { _ in saveLook() })
        .onChange(of: photoFocusX, perform: { _ in saveLook() })
        .onChange(of: photoFocusY, perform: { _ in saveLook() })
        .onChange(of: photoZoom, perform: { _ in saveLook() })
        .onChange(of: photoMaxWidth, perform: { _ in saveLook() })
        .onChange(of: scenePhase, perform: { phase in
            if phase == .background || phase == .inactive {
                chatStore.flush(elements)
                saveSettings()
                saveLook()
                IGPersistence.saveProfile(profile)
            }
        })
    }

    private var threadRoot: some View {
        ZStack {
            Theme.black.ignoresSafeArea()
            VStack(spacing: 0) {
                chatArea
                InputBarView(tap: { showSettings = true }, placeholder: $profile.barPlaceholder)
            }

            // Soft canvas-colored frost under header (no material grey aura)
            HeaderBlurBand(safeTop: safeTop, frostBlur: frostBlur)

            // Floating toolbar — transparent chrome
            VStack {
                liveHeader
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func elementView(_ element: ChatElement, at idx: Int) -> some View {
        Group {
            switch element.style {
            case .date:
                DateSeparatorView(text: element.text)
                    .contentShape(Rectangle())
                    .onTapGesture { beginEdit(.element(element.id), text: element.text) }
                    .contextMenu { dateMenu(element) }
            case .sent:
                SentBubbleView(text: element.text,
                              replyText: element.replyText,
                              replyFromMe: element.replyFromMe,
                              replyName: profile.username,
                              replyKind: element.replyKind,
                              replyImage: ChatImageCodec.image(from: element.replyImageJPEG),
                              photo: ChatImageCodec.image(from: element.imageJPEG),
                              position: BubbleGrouping.position(in: elements, at: idx),
                              photoFrame: resolvedFrame(for: element),
                              photoMaxWidth: CGFloat(photoMaxWidth),
                              viewportSize: viewportSize,
                              washTopInset: safeTop + 96,
                              washBottomInset: 70,
                              gradA: gradA, gradB: gradB,
                              gradTop: gradTop, gradBottom: gradBottom)
                    .id("\(element.id)-\(meWashId)")
                    .contentShape(Rectangle())
                    .onTapGesture { beginEdit(.element(element.id), text: element.text) }
                    .contextMenu { sentMenu(element) }
            case .received:
                ReceivedRowView(
                    text: element.text,
                    heartHint: element.heartHint && heartHintsEnabled,
                    avatarContent: avatarContent,
                    showAvatar: BubbleGrouping.position(in: elements, at: idx) == .single
                        || BubbleGrouping.position(in: elements, at: idx) == .last,
                    replyText: element.replyText,
                    replyFromMe: element.replyFromMe,
                    replyName: profile.username,
                    replyKind: element.replyKind,
                    replyImage: ChatImageCodec.image(from: element.replyImageJPEG),
                    photo: ChatImageCodec.image(from: element.imageJPEG),
                    position: BubbleGrouping.position(in: elements, at: idx),
                    photoFrame: resolvedFrame(for: element),
                    photoMaxWidth: CGFloat(photoMaxWidth),
                    gradA: gradA
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
            replyAsMenu(element)
            moveMenu(element)
            Divider()
            replyMenu(element)
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
            replyAsMenu(element)
            moveMenu(element)
            Divider()
            replyMenu(element)
            Divider()
            Toggle(isOn: $heartHintsEnabled) {
                Text("Show \"Double tap to ❤️\"")
            }
            Divider()
            deleteButton(element)
        }
    }

    @ViewBuilder
    private func replyMenu(_ element: ChatElement) -> some View {
        let has = element.hasReply
        Button {
            replyToMessageAbove(element)
        } label: {
            Label("Reply to message above", systemImage: "arrowshape.turn.up.left")
        }
        Button {
            beginEdit(.reply(element.id), text: element.replyText ?? "")
        } label: {
            Label(has ? "Edit reply quote text" : "Add reply quote text…", systemImage: "text.quote")
        }
        Button {
            if let idx = elements.firstIndex(where: { $0.id == element.id }) {
                elements[idx].replyKind = .story
            }
            replyPhotoTarget = element.id
        } label: {
            Label("Reply to story (pick photo)…", systemImage: "circle.dashed")
        }
        Button {
            messagePhotoTarget = element.id
        } label: {
            Label(element.hasImage ? "Replace photo…" : "Attach photo…", systemImage: "photo")
        }
        if element.hasImage {
            Button {
                cropDraft = resolvedFrame(for: element)
                cropPhotoTarget = element.id
            } label: {
                Label("Crop / frame photo…", systemImage: "crop")
            }
            Button(role: .destructive) {
                if let idx = elements.firstIndex(where: { $0.id == element.id }) {
                    elements[idx].imageJPEG = nil
                    elements[idx].photoFrame = nil
                }
            } label: {
                Label("Remove photo", systemImage: "photo.badge.minus")
            }
        }
        if has {
            Button(role: .destructive) {
                clearReply(element.id)
            } label: {
                Label("Remove reply", systemImage: "xmark.circle")
            }
        }
    }

    private func replyToMessageAbove(_ element: ChatElement) {
        guard let idx = elements.firstIndex(where: { $0.id == element.id }), idx > 0 else { return }
        var i = idx - 1
        while i >= 0 && elements[i].style == .date { i -= 1 }
        guard i >= 0 else { return }
        let src = elements[i]
        elements[idx].replyText = src.text
        elements[idx].replyFromMe = (src.style == .sent)
        elements[idx].replyKind = .chat
        elements[idx].replyImageJPEG = src.imageJPEG
    }

    private func clearReply(_ id: UUID) {
        guard let idx = elements.firstIndex(where: { $0.id == id }) else { return }
        elements[idx].replyText = nil
        elements[idx].replyFromMe = false
        elements[idx].replyKind = .chat
        elements[idx].replyImageJPEG = nil
    }

    /// Long-press target message → insert a reply bubble quoting it.
    private func replyAs(to target: ChatElement, asMe: Bool) {
        guard let idx = elements.firstIndex(where: { $0.id == target.id }) else { return }
        // Quote text: prefer message text; if photo-only, use a short label.
        let trimmed = target.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let quoteText: String? = {
            if !trimmed.isEmpty { return trimmed }
            if target.hasImage { return nil }
            return trimmed.isEmpty ? nil : trimmed
        }()
        var neu = ChatElement(
            style: asMe ? .sent : .received,
            text: "New message",
            replyText: quoteText,
            replyFromMe: (target.style == .sent),
            replyKind: .chat,
            replyImageJPEG: target.imageJPEG,
            imageJPEG: nil
        )
        // If target was photo-only, still show quote via image
        if neu.replyText == nil && neu.replyImageJPEG == nil {
            neu.replyText = "Message"
        }
        withAnimation {
            elements.insert(neu, at: idx + 1)
        }
        // Open editor so user can type the reply body
        beginEdit(.element(neu.id), text: neu.text)
    }


    @ViewBuilder
    private func moveMenu(_ element: ChatElement) -> some View {
        if let idx = elements.firstIndex(where: { $0.id == element.id }) {
            if idx > 0 {
                Button {
                    withAnimation { elements.swapAt(idx, idx - 1) }
                } label: { Label("Move up", systemImage: "arrow.up") }
            }
            if idx < elements.count - 1 {
                Button {
                    withAnimation { elements.swapAt(idx, idx + 1) }
                } label: { Label("Move down", systemImage: "arrow.down") }
            }
        }
    }

    @ViewBuilder
    private func replyAsMenu(_ element: ChatElement) -> some View {
        // Only for real chat bubbles (not date separators)
        if element.style == .sent || element.style == .received {
            Button {
                replyAs(to: element, asMe: true)
            } label: {
                Label("Reply as Me", systemImage: "arrowshape.turn.up.left.circle")
            }
            Button {
                replyAs(to: element, asMe: false)
            } label: {
                Label("Reply as Them", systemImage: "arrowshape.turn.up.left.circle.fill")
            }
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
            Menu("Set time") {
                ForEach(IGStamp.Preset.allCases) { preset in
                    Button(preset.rawValue) {
                        if let i = elements.firstIndex(where: { $0.id == element.id }) {
                            IGStamp.apply(preset, to: &elements[i])
                        }
                    }
                }
                Divider()
                Button("More… (buckets)") {
                    pickerRef = element.id; pickerAbove = false
                }
            }
            Button {
                if let i = elements.firstIndex(where: { $0.id == element.id }) {
                    IGStamp.nudge(&elements[i], minutes: -30)
                }
            } label: { Label("-30 min", systemImage: "minus.circle") }
            Button {
                if let i = elements.firstIndex(where: { $0.id == element.id }) {
                    IGStamp.nudge(&elements[i], minutes: 30)
                }
            } label: { Label("+30 min", systemImage: "plus.circle") }
            Divider()
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
            Button {
                chatStore.snapshotCurrent(elements)
                route = .list
            } label: {
                GlassCircle(size: 46) {
                    BackButtonArt(height: 19)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to chats")

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
                    .font(.system(size: CGFloat(subtitleFontSize)))
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
                    VcArt(height: 22)
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
                    await MainActor.run {
                        avatarImage = image
                        IGPersistence.saveAvatarJPEG(ChatImageCodec.jpeg(image))
                    }
                }
            }
        }
        .onChange(of: messagePhotoPickerItem) { newItem in
            guard let newItem, let target = messagePhotoTarget else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let jpeg = ChatImageCodec.jpeg(image) {
                    await MainActor.run {
                        if let idx = elements.firstIndex(where: { $0.id == target }) {
                            elements[idx].imageJPEG = jpeg
                        }
                        messagePhotoTarget = nil
                        messagePhotoPickerItem = nil
                    }
                }
            }
        }
        .onChange(of: replyPhotoPickerItem) { newItem in
            guard let newItem, let target = replyPhotoTarget else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let jpeg = ChatImageCodec.jpeg(image) {
                    await MainActor.run {
                        if let idx = elements.firstIndex(where: { $0.id == target }) {
                            elements[idx].replyImageJPEG = jpeg
                            elements[idx].replyKind = .story
                            if (elements[idx].replyText ?? "").isEmpty {
                                elements[idx].replyText = "Story"
                            }
                        }
                        replyPhotoTarget = nil
                        replyPhotoPickerItem = nil
                    }
                }
            }
        }
    }



    // MARK: Chat area

    private var chatArea: some View {
        GeometryReader { outer in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        liveProfileContext
                            .background(
                                GeometryReader { row in
                                    let f = row.frame(in: .named("viewport"))
                                    let h = max(outer.size.height, 1)
                                    Color.clear.preference(
                                        key: BubbleProgressKey.self,
                                        value: [profilePassId: BubbleEdges(top: Double(f.minY / h), bottom: Double(f.maxY / h))]
                                    )
                                }
                            )
                        ForEach(Array(elements.enumerated()), id: \.element.id) { idx, element in
                            elementView(element, at: idx)
                                .padding(.top, idx == 0 ? 8 : BubbleGrouping.spacing(before: idx, in: elements))
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
                    .padding(EdgeInsets(top: safeTop + 96, leading: 16, bottom: 4, trailing: 16))
                }
                .coordinateSpace(name: "viewport")
                // Draw under status bar so blur can run all the way to the notch
                .ignoresSafeArea(edges: .top)
                .onAppear {
                    viewportSize = outer.size
                    safeTop = outer.safeAreaInsets.top
                }
                .onChange(of: outer.size, perform: { viewportSize = $0 })
                .onChange(of: outer.safeAreaInsets.top, perform: { safeTop = $0 })
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

            if showStatusAlways || !following {
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
        case .reply: return "Reply quote"
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
        case .reply(let id):
            if let idx = elements.firstIndex(where: { $0.id == id }) {
                let trimmed = editorText.trimmingCharacters(in: .whitespacesAndNewlines)
                elements[idx].replyText = trimmed.isEmpty ? nil : trimmed
            }
        case nil:
            break
        }
        showEditor = false
    }

    // MARK: Chat list (root) — launch screen

    private var chatListRoot: some View {
        NavigationStack {
            ZStack {
                Theme.black.ignoresSafeArea()
                if chatStore.chats.isEmpty {
                    VStack(spacing: 18) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Theme.secondaryText)
                        Text("No chats yet")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Start a new conversation to mock an IG inbox thread.")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 36)
                        Button {
                            openNewBlankChat()
                        } label: {
                            Text("New Chat")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(Theme.barPurple))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    List {
                        ForEach(chatStore.chats) { chat in
                            Button {
                                openChat(chat)
                            } label: {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient(
                                                colors: [gradA, gradB],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                        Text(String(chat.title.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                                            .font(.system(size: 22, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 56, height: 56)

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(alignment: .firstTextBaseline) {
                                            Text(chat.title)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            Spacer(minLength: 8)
                                            Text(listTime(for: chat))
                                                .font(.system(size: 12))
                                                .foregroundColor(Theme.secondaryText)
                                        }
                                        Text(lastMessage(in: chat))
                                            .font(.system(size: 14))
                                            .foregroundColor(Theme.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Theme.black)
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    chatStore.deleteChat(chat.id)
                                    if chatStore.chats.isEmpty {
                                        elements = IGSeed.defaultElements()
                                    }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            openNewBlankChat()
                        } label: {
                            Label("New Chat", systemImage: "plus.bubble")
                        }
                        Button {
                            openPatriciaChat()
                        } label: {
                            Label("Patricia (Kimchi) script", systemImage: "text.bubble")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        openNewBlankChat()
                    } label: {
                        Text("New Chat")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Theme.barPurple)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func openChat(_ chat: ChatSession) {
        if route == .thread {
            chatStore.snapshotCurrent(elements)
        }
        chatStore.currentId = chat.id
        elements = chat.elements
        route = .thread
    }

    private func openNewBlankChat() {
        if route == .thread {
            chatStore.snapshotCurrent(elements)
        }
        let title = profile.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let chat = chatStore.createChat(
            title: title.isEmpty ? "New chat" : title,
            elements: IGSeed.defaultElements()
        )
        elements = chat.elements
        route = .thread
    }

    private func openPatriciaChat() {
        if route == .thread {
            chatStore.snapshotCurrent(elements)
        }
        let chat = chatStore.createChat(
            title: "patricia",
            elements: IGSeed.patriciaKimchiElements()
        )
        elements = chat.elements
        profile = IGSeed.patriciaProfile()
        route = .thread
    }

    private func listTime(for chat: ChatSession) -> String {
        if let stamp = chat.elements.last(where: { $0.style == .date })?.text, !stamp.isEmpty {
            return stamp
        }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: chat.updatedAt).uppercased()
    }

    private func saveSettings() {
        IGPersistence.saveSettings(.init(
            showFollow: showFollow,
            following: following,
            seenEnabled: seenEnabled,
            seenHoursAgo: seenHoursAgo,
            learnLinkEnabled: learnLinkEnabled,
            heartHintsEnabled: heartHintsEnabled,
            showStatusAlways: showStatusAlways
        ))
        UserDefaults.standard.set(showStatusAlways, forKey: "igchat.showStatusAlways")
    }

    private func saveLook() {
        IGPersistence.saveLook(.init(
            gradAHex: gradA.igHex,
            gradBHex: gradB.igHex,
            frostBlur: frostBlur,
            gradTop: gradTop,
            gradBottom: gradBottom,
            subtitleFontSize: subtitleFontSize,
            photoWindow: photoWindow,
            photoFocusX: photoFocusX,
            photoFocusY: photoFocusY,
            photoZoom: photoZoom,
            photoMaxWidth: photoMaxWidth,
            landscapeCrop: photoWindow
        ))
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
                    Toggle("Keep \"You don't follow each other\" when Following", isOn: $showStatusAlways)
                    Toggle("Show \"Learn about business chats\"", isOn: $learnLinkEnabled)
                    Toggle("Show \"Double tap to ❤️\" hints", isOn: $heartHintsEnabled)
                }
                                                Section("Me gradient") {
                    Text("Wash mulai dari bawah header (bukan notch). Ungu hot di atas chat → biru di bawah.")
                        .font(.caption)
                        .foregroundColor(Theme.secondaryText)

                    ColorPicker("Ungu", selection: Binding(
                        get: { gradA },
                        set: { gradA = $0.opacity(1) }), supportsOpacity: false)
                    ColorPicker("Biru", selection: Binding(
                        get: { gradB },
                        set: { gradB = $0.opacity(1) }), supportsOpacity: false)

                    // Preview = same MeWash math as live bubbles (full screen 0…1)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                stops: MeWash.stops(
                                    t0: 0, t1: 1,
                                    a: gradA, b: gradB,
                                    purpleUntil: gradTop / 100.0,
                                    blueFrom: gradBottom / 100.0
                                ),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 140)
                        .overlay(alignment: .topLeading) {
                            Text("ATAS").font(.caption2.bold()).foregroundColor(.white).padding(8)
                        }
                        .overlay(alignment: .bottomLeading) {
                            Text("BAWAH").font(.caption2.bold()).foregroundColor(.white).padding(8)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Zona ungu: \(Int(gradTop))% dari atas")
                        Slider(value: Binding(
                            get: { gradTop },
                            set: { v in
                                gradTop = v
                                if gradBottom < v + 5 { gradBottom = min(v + 5, 95) }
                            }
                        ), in: 0...70, step: 1)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fade length: \(Int(max(gradBottom - gradTop, 0)))%")
                        Slider(value: Binding(
                            get: { max(gradBottom - gradTop, 5) },
                            set: { gradBottom = min(gradTop + max($0, 5), 95) }
                        ), in: 5...50, step: 1)
                    }
                    Text("Biru solid mulai di \(Int(gradBottom))% layar")
                        .font(.caption2)
                        .foregroundColor(Theme.secondaryText)

                    Button("Reset pola IG (hot)") {
                        gradTop = 35
                        gradBottom = 60
                        gradA = Color(red: 0xD9/255, green: 0x46/255, blue: 0xEF/255)
                        gradB = Color(red: 0x3B/255, green: 0x5B/255, blue: 0xDB/255)
                    }
                }

                Section("Header fade") {
                    Text("Soft canvas fade under the chrome (no grey aura).")
                        .font(.caption).foregroundColor(Theme.secondaryText)
                    Text("Edge soft: \(Int(frostBlur))")
                    Slider(value: $frostBlur, in: 0...40, step: 1)
                }
                Section("Photo defaults") {
                    Text("Hold any photo → Crop / frame for per-bubble overrides.")
                        .font(.caption).foregroundColor(Theme.secondaryText)
                    Text("Window: \(Int(photoWindow * 100))%")
                    Slider(value: $photoWindow, in: 0...1, step: 0.05)
                    Text("Focus X (left → right): \(Int(photoFocusX * 100))%")
                    Slider(value: $photoFocusX, in: 0...1, step: 0.05)
                    Text("Focus Y (top → bottom): \(Int(photoFocusY * 100))%")
                    Slider(value: $photoFocusY, in: 0...1, step: 0.05)
                    Text(String(format: "Zoom: %.2f×", photoZoom))
                    Slider(value: $photoZoom, in: 1...2.5, step: 0.05)
                    Text("Max width: \(Int(photoMaxWidth))pt")
                    Slider(value: $photoMaxWidth, in: 180...320, step: 5)
                }
                Section("Type") {
                    Text("Subtitle size: \(Int(subtitleFontSize))pt")
                    Slider(value: $subtitleFontSize, in: 8...14, step: 0.5)
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
                        let id = UUID()
                        elements.append(ChatElement(id: id, style: .sent, text: ""))
                        messagePhotoTarget = id
                    } label: {
                        Label("Add Me photo…", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        let id = UUID()
                        elements.append(ChatElement(id: id, style: .received, text: ""))
                        messagePhotoTarget = id
                    } label: {
                        Label("Add Them photo…", systemImage: "photo")
                    }
                    Button {
                        elements.append(IGStamp.makeSeparator(.justNow))
                    } label: {
                        Label("Add date separator (now)", systemImage: "clock")
                    }
                    Menu {
                        ForEach(IGStamp.Preset.allCases) { preset in
                            Button(preset.rawValue) {
                                elements.append(IGStamp.makeSeparator(preset))
                            }
                        }
                    } label: {
                        Label("Add stamp…", systemImage: "clock.badge.questionmark")
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

}

