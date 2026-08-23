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
            let c = tokens[i].0
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

// MARK: - Tab bar icons

struct XTabIcon: View {
    let icon: XTab
    let size: CGFloat

    var body: some View {
        let (pathData, viewBox) = icon.pathData
        return SVGPathShape(d: pathData, viewBox: viewBox)
            .fill(icon.color)
            .frame(width: size, height: size * (viewBox.height / viewBox.width))
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

    var color: Color { Theme.secondaryText }
}

struct XTabBar: View {
    var onSelect: ((XTab) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.border).frame(height: 1)
            HStack(spacing: 0) {
                ForEach(XTab.allCases) { tab in
                    Button {
                        onSelect?(tab)
                    } label: {
                        XTabIcon(icon: tab, size: 24)
                            .frame(maxWidth: .infinity)
                            .frame(height: 49)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Theme.black)
    }
}
