import SwiftUI

// Exact SVG path data lifted from instagram.com (operator-supplied 2026-08-23).
// Verified.svg viewBox 0 0 40 40, fill rgb(0,149,246). Others viewBox 24.

enum IGIcons {
    // Verified starburst + check, single path, evenodd fill.
    static let verifiedD = "M19.998 3.094 14.638 0l-2.972 5.15H5.432v6.354L0 14.64 3.094 20 0 25.359l5.432 3.137v5.905h5.975L14.638 40l5.36-3.094L25.358 40l3.232-5.6h6.162v-6.01L40 25.359 36.905 20 40 14.641l-5.248-3.03v-6.46h-6.419L25.358 0l-5.36 3.094Zm7.415 11.225 2.254 2.287-11.43 11.5-6.835-6.93 2.244-2.258 4.587 4.581 9.18-9.18Z"
    static let verifiedViewBox: CGFloat = 40

    // Header + input bar icons (stroke, currentColor → white).
    static let audioCallD = "M18.227 22.912c-4.913 0-9.286-3.627-11.486-5.828C4.486 14.83.731 10.291.921 5.231a3.289 3.289 0 0 1 .908-2.138 17.116 17.116 0 0 1 1.865-1.71 2.307 2.307 0 0 1 3.004.174 13.283 13.283 0 0 1 3.658 5.325 2.551 2.551 0 0 1-.19 1.941l-.455.853a.463.463 0 0 0-.024.387 7.57 7.57 0 0 0 4.077 4.075.455.455 0 0 0 .386-.024l.853-.455a2.548 2.548 0 0 1 1.94-.19 13.278 13.278 0 0 1 5.326 3.658 2.309 2.309 0 0 1 .174 3.003 17.319 17.319 0 0 1-1.71 1.866 3.29 3.29 0 0 1-2.138.91 10.27 10.27 0 0 1-.368.006Zm-13.144-20a.27.27 0 0 0-.167.054A15.121 15.121 0 0 0 3.28 4.47a1.289 1.289 0 0 0-.36.836c-.161 4.301 3.21 8.34 5.235 10.364s6.06 5.403 10.366 5.236a1.284 1.284 0 0 0 .835-.36 15.217 15.217 0 0 0 1.504-1.637.324.324 0 0 0-.047-.41 11.62 11.62 0 0 0-4.457-3.119.545.545 0 0 0-.411.044l-.854.455a2.452 2.452 0 0 1-2.071.116 9.571 9.571 0 0 1-5.189-5.188 2.457 2.457 0 0 1 .115-2.071l.456-.855a.544.544 0 0 0 .043-.41 11.629 11.629 0 0 0-3.118-4.458.36.36 0 0 0-.244-.1Z"
    static let videoCallRect = CGRect(x: 1, y: 3, width: 16.999, height: 18)
    static let videoCallD = "m17.999 9.146 2.495-2.256A1.5 1.5 0 0 1 23 8.003v7.994a1.5 1.5 0 0 1-2.506 1.113L18 14.854"

    // Input bar icons (stroke).
    static let voiceClipPaths: [(String, Bool)] = [
        ("M19.5 10.671v.897a7.5 7.5 0 0 1-15 0v-.897", true),   // arc
        ("M12 15.745a4 4 0 0 1-4-4V6a4 4 0 0 1 8 0v5.745a4 4 0 0 1-4 4Z", true),
    ]
    static let voiceClipLines: [(CGPoint, CGPoint)] = [
        (CGPoint(x: 12, y: 19.068), CGPoint(x: 12, y: 22)),
        (CGPoint(x: 8.706, y: 22), CGPoint(x: 15.104, y: 22)),
    ]

    static let addPhotoPaths: [String] = [
        "M6.549 5.013A1.557 1.557 0 1 0 8.106 6.57a1.557 1.557 0 0 0-1.557-1.557Z",  // filled dot
        "m2 18.605 3.901-3.9a.908.908 0 0 1 1.284 0l2.807 2.806a.908.908 0 0 0 1.283 0l5.534-5.534a.908.908 0 0 1 1.283 0l3.905 3.905",
        "M18.44 2.004A3.56 3.56 0 0 1 22 5.564h0v12.873a3.56 3.56 0 0 1-3.56 3.56H5.568a3.56 3.56 0 0 1-3.56-3.56V5.563a3.56 3.56 0 0 1 3.56-3.56Z",
    ]

    static let gifStickerPaths: [String] = [
        "M13.11 22H7.416A5.417 5.417 0 0 1 2 16.583V7.417A5.417 5.417 0 0 1 7.417 2h9.166A5.417 5.417 0 0 1 22 7.417v5.836a2.083 2.083 0 0 1-.626 1.488l-6.808 6.664A2.083 2.083 0 0 1 13.11 22Z",
    ]
    static let gifStickerDots: [CGPoint] = [
        CGPoint(x: 8.238, y: 9.943),
        CGPoint(x: 15.762, y: 9.943),
    ]
    static let gifStickerSmileD = "M15.174 15.23a4.887 4.887 0 0 1-6.937-.301"
    static let gifStickerFoldD = "M22 10.833v1.629a1.25 1.25 0 0 1-1.25 1.25h-1.79a5.417 5.417 0 0 0-5.417 5.417v1.62a1.25 1.25 0 0 1-1.25 1.25H9.897"
    static let gifStickerDotRadius: CGFloat = 1.335
}

// MARK: - Rendered icon views

/// The real Instagram verified starburst badge (exact path, #0095F6).
struct VerifiedBadge: View {
    var size: CGFloat = 12

    var body: some View {
        SVGFillIcon(
            base: SVGPathParser.path(from: IGIcons.verifiedD),
            viewBox: IGIcons.verifiedViewBox,
            size: size,
            color: Theme.igBlue,
            evenOdd: true
        )
    }
}

struct PhoneIcon: View {
    var size: CGFloat = 24

    var body: some View {
        SVGFillIcon(
            base: SVGPathParser.path(from: IGIcons.audioCallD),
            viewBox: 24,
            size: size,
            color: .white
        )
    }
}

struct VideoCallIcon: View {
    var size: CGFloat = 24

    private var base: Path {
        var p = SVGPathParser.path(from: IGIcons.videoCallD)
        p.addRoundedRect(
            in: IGIcons.videoCallRect,
            cornerSize: CGSize(width: 3, height: 3)
        )
        return p
    }

    var body: some View {
        SVGStrokeIcon(
            base: base,
            viewBox: 24,
            size: size,
            color: .white,
            width: 2
        )
    }
}

struct VoiceClipIcon: View {
    var size: CGFloat = 22

    private var base: Path {
        var p = Path()
        for (d, _) in IGIcons.voiceClipPaths {
            p.addPath(SVGPathParser.path(from: d))
        }
        for (a, b) in IGIcons.voiceClipLines {
            p.move(to: a)
            p.addLine(to: b)
        }
        return p
    }

    var body: some View {
        SVGStrokeIcon(base: base, viewBox: 24, size: size, color: .white, width: 2)
    }
}

struct AddPhotoIcon: View {
    var size: CGFloat = 22

    var body: some View {
        SVGStrokeIcon(
            base: SVGPathParser.path(from: IGIcons.addPhotoPaths[2]),
            viewBox: 24,
            size: size,
            color: .white,
            width: 2
        )
    }
}

struct GifStickerIcon: View {
    var size: CGFloat = 22

    private var base: Path {
        var p = SVGPathParser.path(from: IGIcons.gifStickerPaths[0])
        p.addPath(SVGPathParser.path(from: IGIcons.gifStickerSmileD))
        p.addPath(SVGPathParser.path(from: IGIcons.gifStickerFoldD))
        for c in IGIcons.gifStickerDots {
            let r = IGIcons.gifStickerDotRadius
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        }
        return p
    }

    var body: some View {
        SVGStrokeIcon(base: base, viewBox: 24, size: size, color: .white, width: 2)
    }
}

struct CameraRoundIcon: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(Theme.igBlue)
            Image(systemName: "camera.fill")
                .font(.system(size: size * 0.4, weight: .regular))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}
