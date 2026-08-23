import SwiftUI

// MARK: - X.com icon paths (extracted from x.com SVG assets, verified via IoU > 0.99)

enum XIconPaths {
    static let homePath = "M20 9.838c0-.502-.25-.97-.668-1.248l-6.5-4.333c-.504-.336-1.16-.336-1.664 0l-6.5 4.333C4.251 8.868 4 9.336 4 9.838V18.5c0 .828.672 1.5 1.5 1.5h3v-3.5c0-1.933 1.567-3.5 3.5-3.5s3.5 1.567 3.5 3.5V20h3c.828 0 1.5-.672 1.5-1.5V9.838zm2 8.662c0 1.933-1.567 3.5-3.5 3.5h-5v-5.5c0-.829-.672-1.5-1.5-1.5s-1.5.671-1.5 1.5V22h-5C3.567 22 2 20.433 2 18.5V9.838c0-1.17.585-2.263 1.559-2.912l6.5-4.333c1.175-.784 2.707-.784 3.882 0l6.5 4.333C21.415 7.575 22 8.668 22 9.838V18.5z"
    static let homeViewBox = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)

    static let searchPath = "M10.25 3.75c-3.59 0-6.5 2.91-6.5 6.5s2.91 6.5 6.5 6.5c1.795 0 3.419-.726 4.596-1.904 1.178-1.177 1.904-2.801 1.904-4.596 0-3.59-2.91-6.5-6.5-6.5zm-8.5 6.5c0-4.694 3.806-8.5 8.5-8.5s8.5 3.806 8.5 8.5c0 1.986-.682 3.815-1.824 5.262l4.781 4.781-1.414 1.414-4.781-4.781c-1.447 1.142-3.276 1.824-5.262 1.824-4.694 0-8.5-3.806-8.5-8.5z"
    static let searchViewBox = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)

    static let grokPath = "M12.745 20.54l10.97-8.19c.539-.4 1.307-.244 1.564.38 1.349 3.288.746 7.241-1.938 9.955-2.683 2.714-6.417 3.31-9.83 1.954l-3.728 1.745c5.347 3.697 11.84 2.782 15.898-1.324 3.219-3.255 4.216-7.692 3.284-11.693l.008.009c-1.351-5.878.332-8.227 3.782-13.031L33 0l-4.54 4.59v-.014L12.743 20.544m-2.263 1.987c-3.837-3.707-3.175-9.446.1-12.755 2.42-2.449 6.388-3.448 9.852-1.979l3.72-1.737c-.67-.49-1.53-1.017-2.515-1.387-4.455-1.854-9.789-.931-13.41 2.728-3.483 3.523-4.579 8.94-2.697 13.561 1.405 3.454-.899 5.898-3.22 8.364C1.49 30.2.666 31.074 0 32l10.478-9.466"
    static let grokViewBox = CGRect(x: 0.0, y: 0.0, width: 33.0, height: 32.0)

    static let bellPath = "M19.993 9.042C19.48 5.017 16.054 2 11.996 2s-7.49 3.021-7.999 7.051L2.866 18H7.1c.463 2.282 2.481 4 4.9 4s4.437-1.718 4.9-4h4.236l-1.143-8.958zM12 20c-1.306 0-2.417-.835-2.829-2h5.658c-.412 1.165-1.523 2-2.829 2zm-6.866-4l.847-6.698C6.364 6.272 8.941 4 11.996 4s5.627 2.268 6.013 5.295L18.864 16H5.134z"
    static let bellViewBox = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)

    static let mailPath = "M12.001 1.5c5.858 0 10.7 4.518 10.7 10.2-.001 5.683-4.842 10.2-10.7 10.2-1.785 0-2.96-.555-3.95-1.095-1.876.768-4.02 1.2-6.245-.075l-.885-.505.523-.875c.54-.904.77-1.581.849-2.118.077-.526.02-.98-.11-1.463-.066-.25-.15-.502-.247-.788-.095-.277-.204-.59-.301-.92-.2-.674-.36-1.449-.332-2.39C1.319 6.002 6.153 1.5 12 1.5z"
    static let mailViewBox = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)

    // Verified badge — operator svg-image-19 (x.com icon-verified, scalloped circle + check)
    static let verifiedPath = "M20.396 11c-.018-.646-.215-1.275-.57-1.816-.354-.54-.852-.972-1.438-1.246.223-.607.27-1.264.14-1.897-.131-.634-.437-1.218-.882-1.687-.47-.445-1.053-.75-1.687-.882-.633-.13-1.29-.083-1.897.14-.273-.587-.704-1.086-1.245-1.44S11.647 1.62 11 1.604c-.646.017-1.273.213-1.813.568s-.969.854-1.24 1.44c-.608-.223-1.267-.272-1.902-.14-.635.13-1.22.436-1.69.882-.445.47-.749 1.055-.878 1.688-.13.633-.08 1.29.144 1.896-.587.274-1.087.705-1.443 1.245-.356.54-.555 1.17-.574 1.817.02.647.218 1.276.574 1.817.356.54.856.972 1.443 1.245-.224.606-.274 1.263-.144 1.896.13.634.433 1.218.877 1.688.47.443 1.054.747 1.687.878.633.132 1.29.084 1.897-.136.274.586.705 1.084 1.246 1.439.54.354 1.17.551 1.816.569.647-.016 1.276-.213 1.817-.567s.972-.854 1.245-1.44c.604.239 1.266.296 1.903.164.636-.132 1.22-.447 1.68-.907.46-.46.776-1.044.908-1.681s.075-1.299-.165-1.903c.586-.274 1.084-.705 1.439-1.246.354-.54.551-1.17.569-1.816zM9.662 14.85l-3.429-3.428 1.293-1.302 2.072 2.072 4.4-4.794 1.347 1.246z"
    static let verifiedViewBox = CGRect(x: 0, y: 0, width: 22, height: 22)

    // Audio call — operator svg-image-24 (x.com icon-phone-stroke)
    static let phoneStrokePath = "M3 6.42383C3.00022 4.533 4.533 3.00022 6.42383 3H9.61816L12.2168 8.19727L10.6885 9.72461C11.4852 11.4181 12.5812 12.5137 14.2744 13.3105L15.8027 11.7832L21 14.3818V17.5762C20.9998 19.467 19.467 20.9998 17.5762 21C9.5262 21 3 14.4738 3 6.42383ZM5 6.42383C5 13.3692 10.6308 19 17.5762 19C18.3624 18.9998 18.9998 18.3624 19 17.5762V15.6182L16.1973 14.2168L15.207 15.207L14.7412 15.6738L14.1289 15.4287C11.3748 14.3271 9.67293 12.6252 8.57129 9.87109L8.32617 9.25879L8.79297 8.79297L9.7832 7.80273L8.38184 5H6.42383C5.63757 5.00022 5.00022 5.63757 5 6.42383Z"
    static let phoneStrokeViewBox = CGRect(x: 0, y: 0, width: 24, height: 24)

    // Video call — operator svg-image-25 (x.com icon-camera-video-stroke)
    static let videoStrokePath = "M13.7314 4.00586C15.773 4.10929 17.4537 5.57379 17.8887 7.50977L22.5 5.46094V18.5391L17.8887 16.4893C17.4377 18.4984 15.6452 20 13.5 20H6C3.51472 20 1.5 17.9853 1.5 15.5V8.5C1.5 6.01472 3.51472 4 6 4H13.5L13.7314 4.00586ZM6 6C4.61929 6 3.5 7.11929 3.5 8.5V15.5C3.5 16.8807 4.61929 18 6 18H13.5C14.8807 18 16 16.8807 16 15.5V8.5C16 7.20566 15.0164 6.14082 13.7559 6.0127L13.5 6H6ZM18 9.64941V14.3496L20.5 15.4609V8.53906L18 9.64941Z"
    static let videoStrokeViewBox = CGRect(x: 0, y: 0, width: 24, height: 24)

    // Back arrow with full stem (X-style), Material arrow_back geometry
    static let backArrowPath = "M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"
    static let backArrowViewBox = CGRect(x: 0, y: 0, width: 24, height: 24)
}

// MARK: - SVG path parser (subset: M m L l H h V v C c S s Z z — all commands used by the 5 X icons)

struct SVGPathShape: Shape {
    let d: String
    let viewBox: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x: CGFloat = 0, y: CGFloat = 0
        var sx: CGFloat = 0, sy: CGFloat = 0
        var lastCX: CGFloat? = nil
        var lastCY: CGFloat? = nil

        // scale from viewBox space to rect space
        let scale = min(rect.width / max(viewBox.width, 0.001),
                        rect.height / max(viewBox.height, 0.001))
        let tx = rect.minX + (rect.width - viewBox.width * scale) / 2 - viewBox.minX * scale
        let ty = rect.minY + (rect.height - viewBox.height * scale) / 2 - viewBox.minY * scale
        func tx2(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x * scale + tx, y: p.y * scale + ty)
        }

        let tokens = Self.tokenize(d)
        var i = 0
        var cur = [CGPoint]()

        func flushSub() {
            if cur.count >= 2 {
                path.addLines(cur.map(tx2))
            } else if cur.count == 1, let first = cur.first {
                path.move(to: tx2(first))
            }
            cur = []
        }

        while i < tokens.count {
            guard let c = tokens[i].0 else { i += 1; continue }
            let args = Array(tokens[(i + 1)...].prefix(while: { $0.0 == nil }).map { $0.1 })
            let argCount = args.count
            i += 1 + argCount

            let rel = c >= "a" && c <= "z"
            switch c.uppercased() {
            case "M":
                var j = 0
                while j + 1 < argCount {
                    let nx = args[j] + (rel ? x : 0)
                    let ny = args[j + 1] + (rel ? y : 0)
                    if j == 0 {
                        flushSub()
                        cur = [CGPoint(x: nx, y: ny)]
                        sx = nx; sy = ny
                    } else {
                        cur.append(CGPoint(x: nx, y: ny))
                    }
                    x = nx; y = ny
                    j += 2
                }
                lastCX = nil; lastCY = nil
            case "L":
                var j = 0
                while j + 1 < argCount {
                    let nx = args[j] + (rel ? x : 0)
                    let ny = args[j + 1] + (rel ? y : 0)
                    cur.append(CGPoint(x: nx, y: ny))
                    x = nx; y = ny
                    j += 2
                }
                lastCX = nil; lastCY = nil
            case "H":
                for v in args {
                    let nx = v + (rel ? x : 0)
                    cur.append(CGPoint(x: nx, y: y))
                    x = nx
                }
                lastCX = nil; lastCY = nil
            case "V":
                for v in args {
                    let ny = v + (rel ? y : 0)
                    cur.append(CGPoint(x: x, y: ny))
                    y = ny
                }
                lastCX = nil; lastCY = nil
            case "C", "S":
                let step = (c.uppercased() == "C") ? 6 : 4
                var j = 0
                while j + step <= argCount {
                    var x1: CGFloat, y1: CGFloat
                    if c.uppercased() == "C" {
                        x1 = args[j] + (rel ? x : 0)
                        y1 = args[j + 1] + (rel ? y : 0)
                    } else {
                        if let lcx = lastCX, let lcy = lastCY {
                            x1 = 2 * x - lcx
                            y1 = 2 * y - lcy
                        } else {
                            x1 = x; y1 = y
                        }
                    }
                    let x2: CGFloat, y2: CGFloat, xe: CGFloat, ye: CGFloat
                    if c.uppercased() == "C" {
                        x2 = args[j + 2] + (rel ? x : 0)
                        y2 = args[j + 3] + (rel ? y : 0)
                        xe = args[j + 4] + (rel ? x : 0)
                        ye = args[j + 5] + (rel ? y : 0)
                    } else {
                        x2 = args[j] + (rel ? x : 0)
                        y2 = args[j + 1] + (rel ? y : 0)
                        xe = args[j + 2] + (rel ? x : 0)
                        ye = args[j + 3] + (rel ? y : 0)
                    }
                    if cur.isEmpty {
                        cur.append(CGPoint(x: x, y: y))
                    }
                    let steps = 24
                    var s = 1
                    while s <= steps {
                        let t = CGFloat(s) / CGFloat(steps)
                        let mt = 1 - t
                        let bx = mt*mt*mt*x + 3*mt*mt*t*x1 + 3*mt*t*t*x2 + t*t*t*xe
                        let by = mt*mt*mt*y + 3*mt*mt*t*y1 + 3*mt*t*t*y2 + t*t*t*ye
                        cur.append(CGPoint(x: bx, y: by))
                        s += 1
                    }
                    lastCX = x2; lastCY = y2
                    x = xe; y = ye
                    j += step
                }
            case "Z":
                if !cur.isEmpty {
                    cur.append(CGPoint(x: sx, y: sy))
                    flushSub()
                    x = sx; y = sy
                }
                lastCX = nil; lastCY = nil
            default:
                break
            }
        }
        flushSub()
        return path
    }

    private static func tokenize(_ d: String) -> [(String?, CGFloat)] {
        var tokens: [(String?, CGFloat)] = []
        var number = ""
        var hasNumber = false
        var prevCommand: String? = nil

        func pushNumber() {
            if hasNumber, let v = Double(number) {
                tokens.append((nil, CGFloat(v)))
            }
            number = ""
            hasNumber = false
        }

        for ch in d {
            if ch.isLetter {
                pushNumber()
                if ch == "e" || ch == "E" {
                    // exponent — part of number
                    number.append(ch)
                    hasNumber = true
                } else {
                    prevCommand = String(ch)
                    tokens.append((String(ch), 0))
                }
            } else if ch.isNumber || ch == "." {
                if ch == "." && hasNumber && number.contains(".") && !number.lowercased().hasSuffix("e") {
                    // Compact SVG syntax: ".828.672" is TWO numbers (.828 and .672) —
                    // a second '.' terminates the current number and starts a new one.
                    pushNumber()
                }
                number.append(ch)
                hasNumber = true
            } else if ch == "-" || ch == "+" {
                if hasNumber && !number.lowercased().hasSuffix("e") {
                    pushNumber()
                }
                number.append(ch)
                hasNumber = true
            } else {
                pushNumber()
            }
        }
        pushNumber()
        return tokens
    }
}

// MARK: - Back arrow (full stem)

struct BackArrow: View {
    var size: CGFloat = 20

    var body: some View {
        SVGPathShape(d: XIconPaths.backArrowPath, viewBox: XIconPaths.backArrowViewBox)
            .fill(Theme.primaryText)
            .frame(width: size, height: size)
    }
}

// MARK: - Verified badge (operator SVG)

struct VerifiedBadge: View {
    var size: CGFloat = 14

    var body: some View {
        SVGPathShape(d: XIconPaths.verifiedPath, viewBox: XIconPaths.verifiedViewBox)
            .fill(Theme.blue)
            .frame(width: size, height: size)
    }
}

// MARK: - Call icons (operator svg-image-24 / svg-image-25)

struct PhoneCallIcon: View {
    var size: CGFloat = 17

    var body: some View {
        SVGPathShape(d: XIconPaths.phoneStrokePath, viewBox: XIconPaths.phoneStrokeViewBox)
            .fill(Theme.secondaryText)
            .frame(width: size, height: size)
    }
}

struct VideoCallIcon: View {
    var size: CGFloat = 17

    var body: some View {
        SVGPathShape(d: XIconPaths.videoStrokePath, viewBox: XIconPaths.videoStrokeViewBox)
            .fill(Theme.secondaryText)
            .frame(width: size, height: size)
    }
}

// MARK: - Tab bar icons

struct XTabIcon: View {
    let icon: XTab
    let size: CGFloat
    var badge: Int? = nil

    var body: some View {
        let (pathData, viewBox) = icon.pathData
        return SVGPathShape(d: pathData, viewBox: viewBox)
            .fill(icon.color)
            .frame(width: size, height: size * (viewBox.height / viewBox.width))
            .overlay(alignment: .topTrailing) {
                if let badge = badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Circle().fill(Theme.blue))
                        .fixedSize()
                        .offset(x: 3, y: -2)
                }
            }
    }
}

enum XTab: Int, CaseIterable, Identifiable {
    case home = 0
    case search = 1
    case grok = 2
    case notifications = 3
    case messages = 4

    var id: Int { rawValue }

    var pathData: (String, CGRect) {
        switch self {
        case .home: return (XIconPaths.homePath, XIconPaths.homeViewBox)
        case .search: return (XIconPaths.searchPath, XIconPaths.searchViewBox)
        case .grok: return (XIconPaths.grokPath, XIconPaths.grokViewBox)
        case .notifications: return (XIconPaths.bellPath, XIconPaths.bellViewBox)
        case .messages: return (XIconPaths.mailPath, XIconPaths.mailViewBox)
        }
    }

    var color: Color { .white }
}

struct XTabBar: View {
    var onSelect: ((XTab) -> Void)? = nil
    var badgeNotifications: Int = 4
    var badgeMessages: Int = 7

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(XTab.allCases) { tab in
                    Button {
                        onSelect?(tab)
                    } label: {
                        XTabIcon(icon: tab, size: 24, badge: badge(for: tab))
                            .frame(maxWidth: .infinity)
                            .frame(height: 49)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Theme.black)
    }

    private func badge(for tab: XTab) -> Int? {
        switch tab {
        case .notifications: return badgeNotifications
        case .messages: return badgeMessages
        default: return nil
        }
    }
}
