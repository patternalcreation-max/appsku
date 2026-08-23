import SwiftUI

// MARK: - SVG path parser
// Subset: M m L l H h V v C c S s Z z + compact number syntax (.828.672 = two numbers)
// Tokenizer verified against regex reference: numbers match 1:1 for all built-in icons.

struct SVGPathShape: Shape {
    let d: String
    let viewBox: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x: CGFloat = 0, y: CGFloat = 0
        var sx: CGFloat = 0, sy: CGFloat = 0
        var lastCX: CGFloat? = nil
        var lastCY: CGFloat? = nil

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
                    number.append(ch)
                    hasNumber = true
                } else {
                    tokens.append((String(ch), 0))
                }
            } else if ch.isNumber || ch == "." {
                if ch == "." && hasNumber && number.contains(".") && !number.lowercased().hasSuffix("e") {
                    // Compact SVG: ".828.672" = two numbers
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

// MARK: - Slot-rendered icon views (respect overrides)

struct SlotIcon: View {
    let preset: IconSlot?
    let fallbackPath: String
    let fallbackVB: CGRect
    var size: CGFloat
    var color: Color

    var body: some View {
        Group {
            if let preset = preset {
                SVGPathShape(d: preset.path, viewBox: CGRect(x: 0, y: 0, width: preset.viewBoxWidth, height: preset.viewBoxHeight))
                    .fill(color)
                    .frame(width: size, height: size * preset.viewBoxHeight / max(preset.viewBoxWidth, 0.001))
            } else {
                SVGPathShape(d: fallbackPath, viewBox: fallbackVB)
                    .fill(color)
                    .frame(width: size, height: size * fallbackVB.height / fallbackVB.width)
            }
        }
    }
}

struct VerifiedBadge: View {
    let icons: IconOverrides
    var size: CGFloat = 14

    var body: some View {
        SlotIcon(preset: icons.verified,
                 fallbackPath: XIconPaths.verifiedPath,
                 fallbackVB: XIconPaths.verifiedViewBox,
                 size: size,
                 color: Theme.blue)
    }
}

struct BackArrowIcon: View {
    let icons: IconOverrides
    var size: CGFloat = 20

    var body: some View {
        SlotIcon(preset: icons.backArrow,
                 fallbackPath: XIconPaths.backArrowPath,
                 fallbackVB: XIconPaths.backArrowViewBox,
                 size: size,
                 color: Theme.primaryText)
    }
}

// MARK: - Tab bar

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
    var badgeNotifications: Int
    var badgeMessages: Int

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home, badge: 0)
            tabButton(.search, badge: 0)
            tabButton(.grok, badge: 0)
            tabButton(.notifications, badge: badgeNotifications)
            tabButton(.messages, badge: badgeMessages)
        }
    }

    @ViewBuilder
    private func tabButton(_ tab: XTab, badge: Int) -> some View {
        let (pathData, viewBox) = tab.pathData
        ZStack {
            SVGPathShape(d: pathData, viewBox: viewBox)
                .fill(tab.color)
                .frame(width: 24, height: 24 * viewBox.height / viewBox.width)
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
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
        .frame(maxWidth: .infinity)
        .frame(height: 49)
    }
}
