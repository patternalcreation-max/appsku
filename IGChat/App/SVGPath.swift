import SwiftUI

// Minimal SVG path ("d" attribute) parser covering the IG icon set:
// M/m L/l H/h V/v C/c S/s Q/q T/t A/a Z/z with implicit repeats.
// Arcs are converted to cubic beziers (endpoint → center parameterization).

struct SVGPathParser {
    private let chars: [Character]
    private var pos = 0
    private var current = CGPoint.zero
    private var subpathStart = CGPoint.zero
    private var lastCubicControl: CGPoint?
    private var lastQuadControl: CGPoint?

    init(d: String) { chars = Array(d) }

    static func path(from d: String) -> Path {
        var parser = SVGPathParser(d: d)
        return parser.run()
    }

    // MARK: Entry

    private mutating func run() -> Path {
        var path = Path()
        skipIgnorable()
        while pos < chars.count {
            let c = chars[pos]
            if c.isLetter {
                pos += 1
                execute(c, into: &path)
                skipIgnorable()
            } else {
                pos += 1
                skipIgnorable()
            }
        }
        return path
    }

    private mutating func execute(_ cmd: Character, into path: inout Path) {
        switch cmd {
        case "M": moveGroups(into: &path, relative: false)
        case "m": moveGroups(into: &path, relative: true)
        case "L": lineGroups(into: &path, relative: false)
        case "l": lineGroups(into: &path, relative: true)
        case "H": hGroups(into: &path, relative: false)
        case "h": hGroups(into: &path, relative: true)
        case "V": vGroups(into: &path, relative: false)
        case "v": vGroups(into: &path, relative: true)
        case "C": cubicGroups(into: &path, relative: false)
        case "c": cubicGroups(into: &path, relative: true)
        case "S": smoothCubicGroups(into: &path, relative: false)
        case "s": smoothCubicGroups(into: &path, relative: true)
        case "Q": quadGroups(into: &path, relative: false)
        case "q": quadGroups(into: &path, relative: true)
        case "T": smoothQuadGroups(into: &path, relative: false)
        case "t": smoothQuadGroups(into: &path, relative: true)
        case "A": arcGroups(into: &path, relative: false)
        case "a": arcGroups(into: &path, relative: true)
        case "Z", "z": closeGroup(path: &path)
        default: break
        }
    }

    // MARK: Command groups

    private mutating func moveGroups(into path: inout Path, relative: Bool) {
        var first = true
        while let x = readNumber(), let y = readNumber() {
            let target = relative
                ? CGPoint(x: current.x + x, y: current.y + y)
                : CGPoint(x: x, y: y)
            if first {
                path.move(to: target)
                subpathStart = target
                first = false
            } else {
                path.addLine(to: target)
            }
            current = target
            lastCubicControl = nil
            lastQuadControl = nil
        }
    }

    private mutating func lineGroups(into path: inout Path, relative: Bool) {
        while let x = readNumber(), let y = readNumber() {
            let target = relative
                ? CGPoint(x: current.x + x, y: current.y + y)
                : CGPoint(x: x, y: y)
            path.addLine(to: target)
            current = target
            lastCubicControl = nil
            lastQuadControl = nil
        }
    }

    private mutating func hGroups(into path: inout Path, relative: Bool) {
        while let x = readNumber() {
            let target = relative
                ? CGPoint(x: current.x + x, y: current.y)
                : CGPoint(x: x, y: current.y)
            path.addLine(to: target)
            current = target
            lastCubicControl = nil
            lastQuadControl = nil
        }
    }

    private mutating func vGroups(into path: inout Path, relative: Bool) {
        while let y = readNumber() {
            let target = relative
                ? CGPoint(x: current.x, y: current.y + y)
                : CGPoint(x: current.x, y: y)
            path.addLine(to: target)
            current = target
            lastCubicControl = nil
            lastQuadControl = nil
        }
    }

    private mutating func cubicGroups(into path: inout Path, relative: Bool) {
        while let c1x = readNumber(), let c1y = readNumber(),
              let c2x = readNumber(), let c2y = readNumber(),
              let x = readNumber(), let y = readNumber() {
            let c1 = relative
                ? CGPoint(x: current.x + c1x, y: current.y + c1y)
                : CGPoint(x: c1x, y: c1y)
            let c2 = relative
                ? CGPoint(x: current.x + c2x, y: current.y + c2y)
                : CGPoint(x: c2x, y: c2y)
            let target = relative
                ? CGPoint(x: current.x + x, y: current.y + y)
                : CGPoint(x: x, y: y)
            path.addCurve(to: target, control1: c1, control2: c2)
            current = target
            lastCubicControl = c2
            lastQuadControl = nil
        }
    }

    private mutating func smoothCubicGroups(into path: inout Path, relative: Bool) {
        while let c2x = readNumber(), let c2y = readNumber(),
              let x = readNumber(), let y = readNumber() {
            let reflected: CGPoint
            if let lc = lastCubicControl {
                reflected = CGPoint(x: 2 * current.x - lc.x, y: 2 * current.y - lc.y)
            } else {
                reflected = current
            }
            let c1 = relative
                ? CGPoint(x: current.x + (reflected.x - current.x), y: current.y + (reflected.y - current.y))
                : reflected
            let c2 = relative
                ? CGPoint(x: current.x + c2x, y: current.y + c2y)
                : CGPoint(x: c2x, y: c2y)
            let target = relative
                ? CGPoint(x: current.x + x, y: current.y + y)
                : CGPoint(x: x, y: y)
            path.addCurve(to: target, control1: c1, control2: c2)
            current = target
            lastCubicControl = c2
            lastQuadControl = nil
        }
    }

    private mutating func quadGroups(into path: inout Path, relative: Bool) {
        while let cx = readNumber(), let cy = readNumber(),
              let x = readNumber(), let y = readNumber() {
            let c = relative
                ? CGPoint(x: current.x + cx, y: current.y + cy)
                : CGPoint(x: cx, y: cy)
            let target = relative
                ? CGPoint(x: current.x + x, y: current.y + y)
                : CGPoint(x: x, y: y)
            path.addQuadCurve(to: target, control: c)
            current = target
            lastQuadControl = c
            lastCubicControl = nil
        }
    }

    private mutating func smoothQuadGroups(into path: inout Path, relative: Bool) {
        while let x = readNumber(), let y = readNumber() {
            let c: CGPoint
            if let lq = lastQuadControl {
                c = CGPoint(x: 2 * current.x - lq.x, y: 2 * current.y - lq.y)
            } else {
                c = current
            }
            let target = relative
                ? CGPoint(x: current.x + x, y: current.y + y)
                : CGPoint(x: x, y: y)
            path.addQuadCurve(to: target, control: c)
            current = target
            lastQuadControl = c
            lastCubicControl = nil
        }
    }

    private mutating func closeGroup(path: inout Path) {
        path.closeSubpath()
        current = subpathStart
        lastCubicControl = nil
        lastQuadControl = nil
    }

    // MARK: Arc

    private mutating func arcGroups(into path: inout Path, relative: Bool) {
        while let rx = readNumber(), let ry = readNumber(),
              let rot = readNumber(), let large = readNumber(),
              let sweep = readNumber(), let x = readNumber(), let y = readNumber() {
            let target = relative
                ? CGPoint(x: current.x + x, y: current.y + y)
                : CGPoint(x: x, y: y)
            appendArc(to: target, rx: rx, ry: ry, rotationDeg: rot,
                      largeArc: large > 0.5, sweep: sweep > 0.5, into: &path)
        }
    }

    private mutating func appendArc(to target: CGPoint, rx: Double, ry: Double,
                                    rotationDeg: Double, largeArc: Bool, sweep: Bool,
                                    into path: inout Path) {
        if abs(rx) < 1e-9 || abs(ry) < 1e-9 {
            path.addLine(to: target)
            current = target
            return
        }
        let x1 = Double(current.x), y1 = Double(current.y)
        let x2 = Double(target.x), y2 = Double(target.y)
        let phi = rotationDeg * Double.pi / 180
        let cosp = cos(phi), sinp = sin(phi)
        let dx2 = (x1 - x2) / 2, dy2 = (y1 - y2) / 2
        let x1p = cosp * dx2 + sinp * dy2
        let y1p = -sinp * dx2 + cosp * dy2
        var rxv = abs(rx), ryv = abs(ry)
        let lambda = (x1p * x1p) / (rxv * rxv) + (y1p * y1p) / (ryv * ryv)
        if lambda > 1 {
            let s = sqrt(lambda)
            rxv *= s
            ryv *= s
        }
        let num = rxv * rxv * ryv * ryv - rxv * rxv * y1p * y1p - ryv * ryv * x1p * x1p
        let den = rxv * rxv * y1p * y1p + ryv * ryv * x1p * x1p
        var co = sqrt(max(0, num / den))
        if largeArc == sweep { co = -co }
        let cxp = co * rxv * y1p / ryv
        let cyp = -co * ryv * x1p / rxv
        let cx = cosp * cxp - sinp * cyp + (x1 + x2) / 2
        let cy = sinp * cxp + cosp * cyp + (y1 + y2) / 2

        func angleBetween(_ ux: Double, _ uy: Double, _ vx: Double, _ vy: Double) -> Double {
            let dot = ux * vx + uy * vy
            let len = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
            var a = acos(max(-1, min(1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }

        let ux = (x1p - cxp) / rxv, uy = (y1p - cyp) / ryv
        let vx = (-x1p - cxp) / rxv, vy = (-y1p - cyp) / ryv
        let theta1 = angleBetween(1, 0, ux, uy)
        var dtheta = angleBetween(ux, uy, vx, vy)
        if !sweep && dtheta > 0 { dtheta -= 2 * Double.pi }
        if sweep && dtheta < 0 { dtheta += 2 * Double.pi }

        let segments = max(1, Int(ceil(abs(dtheta) / (Double.pi / 2))))
        let delta = dtheta / Double(segments)
        let k = 4.0 / 3.0 * tan(delta / 4)

        func arcPoint(_ t: Double) -> CGPoint {
            let ox = rxv * cos(t), oy = ryv * sin(t)
            return CGPoint(x: cx + cosp * ox - sinp * oy, y: cy + sinp * ox + cosp * oy)
        }
        func arcDeriv(_ t: Double) -> CGPoint {
            let dx = -rxv * sin(t), dy = ryv * cos(t)
            return CGPoint(x: cosp * dx - sinp * dy, y: sinp * dx + cosp * dy)
        }

        var th = theta1
        var p0 = arcPoint(th)
        for _ in 0..<segments {
            let th2 = th + delta
            let p3 = arcPoint(th2)
            let d0 = arcDeriv(th)
            let d3 = arcDeriv(th2)
            let p1 = CGPoint(x: p0.x + k * d0.x, y: p0.y + k * d0.y)
            let p2 = CGPoint(x: p3.x - k * d3.x, y: p3.y - k * d3.y)
            path.addCurve(to: p3, control1: p1, control2: p2)
            th = th2
            p0 = p3
        }
        current = target
        lastCubicControl = nil
        lastQuadControl = nil
    }

    // MARK: Number scanner

    private mutating func skipIgnorable() {
        while pos < chars.count {
            let c = chars[pos]
            if c == " " || c == "\t" || c == "\n" || c == "\r" || c == "," {
                pos += 1
            } else {
                break
            }
        }
    }

    private mutating func readNumber() -> Double? {
        skipIgnorable()
        guard pos < chars.count else { return nil }
        var s = ""
        if chars[pos] == "+" || chars[pos] == "-" {
            s.append(chars[pos])
            pos += 1
        }
        var sawDigit = false
        while pos < chars.count, chars[pos].isNumber {
            s.append(chars[pos])
            pos += 1
            sawDigit = true
        }
        if pos < chars.count, chars[pos] == "." {
            s.append(chars[pos])
            pos += 1
            while pos < chars.count, chars[pos].isNumber {
                s.append(chars[pos])
                pos += 1
                sawDigit = true
            }
        }
        if pos < chars.count, chars[pos] == "e" || chars[pos] == "E" {
            var lookahead = pos + 1
            var exp = "e"
            if lookahead < chars.count, chars[lookahead] == "+" || chars[lookahead] == "-" {
                exp.append(chars[lookahead])
                lookahead += 1
            }
            if lookahead < chars.count, chars[lookahead].isNumber {
                while lookahead < chars.count, chars[lookahead].isNumber {
                    exp.append(chars[lookahead])
                    lookahead += 1
                }
                s.append(exp)
                pos = lookahead
            }
        }
        guard sawDigit, let v = Double(s) else { return nil }
        return v
    }
}

// MARK: - Scaled shape

struct ScaledIconShape: Shape {
    let base: Path
    var viewBox: CGFloat

    func path(in rect: CGRect) -> Path {
        guard viewBox > 0, rect.width > 0, rect.height > 0 else { return base }
        let s = min(rect.width / viewBox, rect.height / viewBox)
        let ox = (rect.width - viewBox * s) / 2
        let oy = (rect.height - viewBox * s) / 2
        let t = CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: ox, ty: oy)
        return base.applying(t)
    }
}

// MARK: - Icon views

struct SVGFillIcon: View {
    let base: Path
    var viewBox: CGFloat = 24
    var size: CGFloat
    var color: Color
    var evenOdd: Bool = false

    var body: some View {
        ScaledIconShape(base: base, viewBox: viewBox)
            .fill(color, style: FillStyle(eoFill: evenOdd, antialiased: true))
            .frame(width: size, height: size)
    }
}

struct SVGStrokeIcon: View {
    let base: Path
    var viewBox: CGFloat = 24
    var size: CGFloat
    var color: Color
    var width: CGFloat = 2

    var body: some View {
        ScaledIconShape(base: base, viewBox: viewBox)
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
