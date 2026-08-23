import SwiftUI

// MARK: - Phone canvas (fixed 400x800, used for both interactive editor and export)

struct PhoneCanvas: View {
    @Binding var session: ChatSession
    let icons: IconOverrides

    var onTapName: (() -> Void)? = nil
    var onTapPlaceholder: (() -> Void)? = nil
    var onTapElement: ((UUID) -> Void)? = nil
    var onLongPressElement: ((UUID) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            header
            chatArea
            inputBar
            XTabBar(badgeNotifications: session.badgeNotifications,
                    badgeMessages: session.badgeMessages)
        }
        .frame(width: 400, height: 800)
        .background(Theme.black)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            BackArrowIcon(icons: icons, size: 20)

            Group {
                if let png = session.avatarPNG, let img = UIImage(data: png) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Theme.avatarGray
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .contentShape(Rectangle())
            .onTapGesture { onTapName?() }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(session.displayName.isEmpty ? " " : session.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if session.isVerified {
                    VerifiedBadge(icons: icons, size: 14)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTapName?() }

            Spacer()

            SlotIcon(preset: icons.audioCall,
                     fallbackPath: XIconPaths.audioCallPath,
                     fallbackVB: XIconPaths.audioCallViewBox,
                     size: 17,
                     color: Theme.secondaryText)
                .padding(.trailing, 8)
            SlotIcon(preset: icons.videoCall,
                     fallbackPath: XIconPaths.videoCallPath,
                     fallbackVB: XIconPaths.videoCallViewBox,
                     size: 17,
                     color: Theme.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Chat area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($session.elements) { $element in
                        elementView(element)
                            .id(element.id)
                            .contentShape(Rectangle())
                            .onTapGesture { onTapElement?(element.id) }
                    }
                }
                .padding(16)
            }
            .frame(height: 800 - 57 - 64 - 49)
            .onAppear {
                if let last = session.elements.last {
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

    // MARK: Input bar

    private var inputBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Theme.secondaryText)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.bubbleGray))
            HStack(spacing: 12) {
                Text(session.inputPlaceholder)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { onTapPlaceholder?() }
                SlotIcon(preset: icons.voice,
                         fallbackPath: XIconPaths.voicePath,
                         fallbackVB: XIconPaths.voiceViewBox,
                         size: 20,
                         color: Theme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Theme.bubbleGray))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
