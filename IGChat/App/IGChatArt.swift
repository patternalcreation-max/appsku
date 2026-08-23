import SwiftUI

// Operator-supplied Affinity SVG art (Archive.zip 2026-08-23), transforms baked to viewBox space.

enum IGChatArt {
    // Untitled.svg — full chat bar, viewBox 1151 × 133
    static let barSize = CGSize(width: 1151, height: 133)

    // White icons inside the bar (camera, voice clip, photo, gif, plus) — baked d strings
    static let barCameraD = "M 79.52 41.11 L 81.5 41.11 C 84.93 41.11 88.22 42.47 90.64 44.9 C 93.06 47.32 94.43 50.61 94.43 54.04 L 94.43 75.63 C 94.43 79.06 93.06 82.35 90.64 84.78 C 88.22 87.2 84.93 88.56 81.5 88.56 L 51.38 88.56 C 47.95 88.56 44.66 87.2 42.23 84.78 C 39.81 82.35 38.45 79.06 38.45 75.63 L 38.45 54.04 C 38.45 50.61 39.81 47.32 42.23 44.9 C 44.66 42.47 47.95 41.11 51.38 41.11 L 53.37 41.11 C 53.63 39.59 54.35 38.18 55.45 37.07 C 56.87 35.66 58.77 34.87 60.77 34.87 L 72.12 34.87 C 74.11 34.87 76.02 35.66 77.43 37.07 C 78.53 38.18 79.25 39.59 79.52 41.11 Z M 66.44 50.29 C 58.56 50.29 52.17 56.69 52.17 64.57 C 52.17 72.45 58.56 78.84 66.44 78.84 C 74.31 78.84 80.71 72.45 80.71 64.57 C 80.71 56.69 74.31 50.29 66.44 50.29 Z M 66.44 55.37 C 71.51 55.37 75.64 59.49 75.64 64.57 C 75.64 69.65 71.51 73.77 66.44 73.77 C 61.36 73.77 57.24 69.65 57.24 64.57 C 57.24 59.49 61.36 55.37 66.44 55.37 Z"

    static let barVoiceD = "M 699.65 90.91 C 687.22 89.42 677.44 78.72 677.44 65.91 L 677.44 63.26 C 677.44 61.62 678.77 60.3 680.41 60.3 C 682.04 60.3 683.37 61.62 683.37 63.26 L 683.37 65.91 C 683.37 76.47 692.05 85.16 702.61 85.16 C 713.17 85.16 721.86 76.47 721.86 65.91 L 721.86 63.26 C 721.86 61.62 723.19 60.3 724.82 60.3 C 726.46 60.3 727.78 61.62 727.78 63.26 L 727.78 65.91 C 727.78 78.72 718.01 89.42 705.57 90.91 L 705.57 93.84 L 711.8 93.84 C 713.44 93.84 714.77 95.17 714.77 96.8 C 714.77 98.44 713.44 99.77 711.8 99.77 L 692.86 99.77 C 691.22 99.77 689.9 98.44 689.9 96.8 C 689.9 95.17 691.22 93.84 692.86 93.84 L 699.65 93.84 L 699.65 90.91 Z M 702.61 81.24 C 694.49 81.24 687.81 74.56 687.81 66.44 L 687.81 49.43 C 687.81 41.3 694.49 34.62 702.61 34.62 C 710.74 34.62 717.42 41.3 717.42 49.43 L 717.42 66.44 C 717.42 74.56 710.74 81.24 702.61 81.24 Z M 702.61 75.32 C 707.49 75.32 711.5 71.31 711.5 66.44 L 711.5 49.43 C 711.5 44.55 707.49 40.54 702.61 40.54 C 697.74 40.54 693.73 44.55 693.73 49.43 L 693.73 66.44 C 693.73 71.31 697.74 75.32 702.61 75.32 Z"

    static let barPhotoD = "M 835.82 34.62 C 843.23 34.62 849.32 40.72 849.32 48.13 L 849.32 86.26 C 849.32 93.67 843.23 99.77 835.82 99.77 L 797.69 99.77 C 790.28 99.77 784.19 93.67 784.19 86.26 L 784.19 48.13 C 784.19 40.72 790.28 34.62 797.69 34.62 L 835.82 34.62 Z M 843.4 71.55 L 843.4 48.13 C 843.4 43.97 839.98 40.55 835.82 40.55 L 797.69 40.54 C 793.53 40.54 790.11 43.97 790.11 48.13 L 790.11 79.58 L 796.58 73.11 L 797.47 72.39 L 798.46 71.87 L 799.51 71.56 L 800.58 71.46 L 801.65 71.56 L 802.7 71.87 L 803.69 72.39 L 804.58 73.11 L 812.69 81.23 L 828.89 65.03 L 828.9 65.03 L 829.78 64.31 L 830.77 63.79 L 831.82 63.49 L 832.89 63.38 L 833.96 63.49 L 835.01 63.79 L 835.99 64.31 L 836.88 65.03 L 843.4 71.55 Z M 790.27 87.8 C 790.99 91.23 794.06 93.84 797.69 93.84 L 835.82 93.84 C 839.98 93.84 843.4 90.42 843.4 86.26 L 843.4 79.93 L 832.89 69.41 L 816.69 85.61 L 816.69 85.61 L 815.8 86.33 L 814.81 86.85 L 813.77 87.16 L 812.69 87.26 L 811.62 87.16 L 810.58 86.85 L 809.59 86.33 L 808.7 85.61 L 800.58 77.49 L 790.27 87.8 Z M 800.6 46.5 C 803.13 46.5 805.21 48.58 805.21 51.11 C 805.21 53.64 803.13 55.72 800.6 55.72 C 798.07 55.72 795.99 53.64 795.99 51.11 C 795.99 48.58 798.07 46.5 800.6 46.5 Z"

    static let barGifD = "M 969.55 54.06 L 969.55 71.75 C 969.55 74.26 968.54 76.67 966.74 78.42 L 946.12 98.61 C 944.37 100.32 942.03 101.28 939.59 101.28 L 922.33 101.28 C 911.66 101.28 902.89 92.5 902.89 81.84 L 902.89 54.06 C 902.89 43.4 911.67 34.62 922.33 34.62 L 950.11 34.62 C 960.77 34.62 969.55 43.4 969.55 54.06 Z M 963.49 69.35 L 963.49 54.06 C 963.49 46.72 957.45 40.68 950.11 40.68 L 922.33 40.68 C 914.99 40.68 908.95 46.72 908.95 54.06 L 908.95 81.84 C 908.95 89.18 914.99 95.22 922.33 95.22 L 929.71 95.22 C 929.76 95.22 929.8 95.22 929.85 95.22 L 937.11 95.22 C 937.52 95.22 937.87 94.88 937.87 94.46 L 937.87 89.55 C 937.87 87.8 938.1 86.11 938.54 84.49 C 937.63 84.63 936.71 84.71 935.78 84.71 C 930.75 84.71 925.95 82.58 922.58 78.86 C 921.45 77.63 921.54 75.71 922.78 74.58 C 924.02 73.46 925.94 73.55 927.06 74.79 C 929.29 77.24 932.46 78.65 935.78 78.65 C 938.74 78.65 941.6 77.53 943.78 75.51 C 943.96 75.34 944.16 75.2 944.38 75.08 C 947.82 72 952.36 70.11 957.31 70.11 L 962.73 70.11 C 963.15 70.11 963.49 69.77 963.49 69.35 Z M 943.92 92.28 L 960.38 76.17 L 957.31 76.17 C 949.97 76.17 943.92 82.21 943.92 89.55 L 943.92 92.28 Z M 924.82 57.67 C 927.05 57.67 928.87 59.49 928.87 61.72 C 928.87 63.95 927.05 65.76 924.82 65.76 C 922.59 65.76 920.78 63.95 920.78 61.72 C 920.78 59.49 922.59 57.67 924.82 57.67 Z M 947.62 57.67 C 949.85 57.67 951.66 59.49 951.66 61.72 C 951.66 63.95 949.85 65.76 947.62 65.76 C 945.39 65.76 943.57 63.95 943.57 61.72 C 943.57 59.49 945.39 57.67 947.62 57.67 Z"

    static let barPlusD = "M 1056.18 31.59 C 1075.41 31.59 1091.02 47.2 1091.02 66.44 C 1091.02 85.67 1075.41 101.28 1056.18 101.28 C 1036.95 101.28 1021.33 85.67 1021.33 66.44 C 1021.33 47.2 1036.95 31.59 1056.18 31.59 Z M 1056.18 38.26 C 1040.63 38.26 1028.01 50.89 1028.01 66.44 C 1028.01 81.99 1040.63 94.61 1056.18 94.61 C 1071.73 94.61 1084.35 81.99 1084.35 66.44 C 1084.35 50.89 1071.73 38.26 1056.18 38.26 Z M 1052.84 69.77 L 1039.69 69.77 C 1037.85 69.77 1036.36 68.28 1036.36 66.44 C 1036.36 64.59 1037.85 63.1 1039.69 63.1 L 1052.84 63.1 L 1052.84 49.95 C 1052.84 48.11 1054.34 46.61 1056.18 46.61 C 1058.02 46.61 1059.52 48.11 1059.52 49.95 L 1059.52 63.1 L 1072.66 63.1 C 1074.5 63.1 1076 64.59 1076 66.44 C 1076 68.28 1074.5 69.77 1072.66 69.77 L 1059.52 69.77 L 1059.52 82.92 C 1059.52 84.76 1058.02 86.26 1056.18 86.26 C 1054.34 86.26 1052.84 84.76 1052.84 82.92 L 1052.84 69.77 Z"

    static var barWhiteIcons: Path {
        var p = Path()
        for d in [barCameraD, barVoiceD, barPhotoD, barGifD, barPlusD] {
            p.addPath(SVGPathParser.path(from: d))
        }
        return p
    }

    static var barPill: Path {
        Path(roundedRect: CGRect(x: 0, y: 0, width: 1151, height: 133), cornerRadius: 66.44)
    }

    static var barPurpleCircle: Path {
        Path(ellipseIn: CGRect(x: 66.44 - 51.51, y: 66.43 - 51.51, width: 103.02, height: 103.02))
    }

    // Backbutton.svg — viewBox 34 × 60, stroke 5.59
    static let backSize = CGSize(width: 34, height: 60)
    static let backD = "M 30.58 3.07 C 30.19 3.03 2.71 30.65 3.07 29.19 C 3.44 27.73 29.55 56.2 29.55 56.2"
    static let backStroke: CGFloat = 5.59

    // Liveduo.svg — viewBox 73 × 74
    static let liveduoSize = CGSize(width: 73, height: 74)
    static let liveduoBlob1 = "M 46.87 55.25 C 72.57 49.06 73.34 26.03 64.74 12.59 C 57.12 0.7 33.04 -1.56 27.04 16.77 C -1.09 24.04 0.81 49.7 7.58 60.31 C 15.63 72.91 36.16 75.98 46.87 55.25 Z"
    static let liveduoBlob2 = "M 45.61 57.26 C 48.97 30.79 21.6 39.95 27.04 16.77"
    static let liveduoSmile1 = "M 39.2 25.43 C 43.02 30.39 53.33 29.2 56.09 24.88"
    static let liveduoSmile2 = "M 15.95 55.34 C 19.78 60.3 30.08 59.11 32.85 54.79"
    static let liveduoDots: [CGPoint] = [
        CGPoint(x: 40.38, y: 16.91), CGPoint(x: 17.14, y: 46.82),
        CGPoint(x: 54.96, y: 16.76), CGPoint(x: 31.71, y: 46.67),
    ]
    static let liveduoDotR: CGFloat = 3.51
    static let liveduoStroke: CGFloat = 6.67

    static var liveduoPath: Path {
        var p = SVGPathParser.path(from: liveduoBlob1)
        p.addPath(SVGPathParser.path(from: liveduoBlob2))
        p.addPath(SVGPathParser.path(from: liveduoSmile1))
        p.addPath(SVGPathParser.path(from: liveduoSmile2))
        for c in liveduoDots {
            p.addEllipse(in: CGRect(x: c.x - liveduoDotR, y: c.y - liveduoDotR,
                                    width: liveduoDotR * 2, height: liveduoDotR * 2))
        }
        return p
    }

    // Phonecall.svg — viewBox 71 × 71, fill evenodd
    static let phoneSize = CGSize(width: 71, height: 71)
    static let phoneD = "M 55.17 70.1 C 39.52 70.1 25.58 58.54 18.57 51.53 C 11.38 44.35 -0.58 29.88 0.02 13.76 C 0.13 11.21 1.16 8.79 2.92 6.95 C 4.76 4.99 6.75 3.16 8.86 1.5 C 11.74 -0.7 15.83 -0.46 18.43 2.05 C 23.66 6.66 27.66 12.49 30.09 19.02 C 30.71 21.08 30.5 23.31 29.48 25.21 L 28.03 27.92 C 27.83 28.3 27.8 28.75 27.96 29.16 C 30.41 35.03 35.08 39.7 40.95 42.14 C 41.35 42.3 41.8 42.27 42.18 42.07 L 44.9 40.62 C 46.8 39.6 49.02 39.39 51.08 40.01 C 57.61 42.44 63.44 46.44 68.05 51.67 C 70.56 54.27 70.8 58.36 68.61 61.24 C 66.94 63.35 65.12 65.34 63.16 67.18 C 61.32 68.94 58.89 69.98 56.34 70.08 C 55.95 70.09 55.56 70.1 55.17 70.1 Z M 13.29 6.37 C 13.1 6.37 12.91 6.43 12.76 6.54 C 10.9 8.01 9.16 9.61 7.54 11.33 C 6.85 12.05 6.44 13 6.39 14 C 5.88 27.7 16.62 40.57 23.08 47.02 C 29.53 53.47 42.39 64.24 56.11 63.71 C 57.11 63.66 58.05 63.26 58.77 62.56 C 60.49 60.94 62.09 59.2 63.56 57.34 C 63.83 56.93 63.77 56.38 63.41 56.04 C 59.53 51.65 54.66 48.24 49.21 46.1 C 48.77 45.97 48.3 46.02 47.9 46.24 L 45.18 47.69 C 43.14 48.78 40.72 48.92 38.58 48.06 C 31.09 44.96 25.14 39.01 22.04 31.53 C 21.19 29.38 21.32 26.96 22.41 24.93 L 23.86 22.2 C 24.08 21.8 24.13 21.33 24 20.9 C 21.86 15.44 18.45 10.58 14.06 6.69 C 13.85 6.49 13.58 6.38 13.29 6.37 L 13.29 6.37 Z"

    // Vc.svg — viewBox 72 × 60, fill evenodd
    static let vcSize = CGSize(width: 72, height: 60)
    static let vcD = "M 56.51 44.93 L 56.51 47.59 C 56.51 54.15 51.18 59.48 44.61 59.48 L 11.9 59.48 C 5.33 59.48 0 54.15 0 47.59 L 0 11.9 C 0 5.33 5.33 -0 11.9 -0 L 44.61 -0 C 51.18 -0 56.51 5.33 56.51 11.9 L 56.51 14.55 L 58.96 12.34 C 60.33 11.1 62.1 10.42 63.94 10.42 C 68.02 10.42 71.38 13.77 71.38 17.85 L 71.38 41.63 C 71.38 45.71 68.02 49.06 63.94 49.06 C 62.1 49.06 60.33 48.38 58.96 47.14 L 56.51 44.93 Z M 56.51 22.57 L 56.51 36.9 L 62.95 42.73 C 63.22 42.98 63.58 43.11 63.94 43.11 C 64.76 43.11 65.43 42.45 65.43 41.63 L 65.43 17.85 C 65.43 17.03 64.76 16.37 63.94 16.37 C 63.58 16.37 63.22 16.5 62.95 16.75 L 56.51 22.57 Z M 50.56 11.9 C 50.56 8.61 47.89 5.95 44.61 5.95 L 11.9 5.95 C 8.61 5.95 5.95 8.61 5.95 11.9 L 5.95 47.59 C 5.95 50.87 8.61 53.53 11.9 53.53 L 44.61 53.53 C 47.89 53.53 50.56 50.87 50.56 47.59 L 50.56 11.9 Z"
}

// MARK: - Art views

/// Wide (non-square) scaled shape for full-width art like the chat bar.
struct ScaledArtShape: Shape {
    let base: Path
    var artSize: CGSize

    func path(in rect: CGRect) -> Path {
        guard artSize.width > 0, artSize.height > 0, rect.width > 0, rect.height > 0 else { return base }
        let s = min(rect.width / artSize.width, rect.height / artSize.height)
        let t = CGAffineTransform(a: s, b: 0, c: 0, d: s,
                                  tx: (rect.width - artSize.width * s) / 2,
                                  ty: (rect.height - artSize.height * s) / 2)
        return base.applying(t)
    }
}

/// The operator's complete chat bar art (pill + purple camera circle + icons + "Message…" text).
struct ChatBarView: View {
    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                ScaledArtShape(base: IGChatArt.barPill, artSize: IGChatArt.barSize)
                    .fill(Theme.barPill)
                ScaledArtShape(base: IGChatArt.barPurpleCircle, artSize: IGChatArt.barSize)
                    .fill(Theme.barPurple)
                ScaledArtShape(base: IGChatArt.barWhiteIcons, artSize: IGChatArt.barSize)
                    .fill(Color.white, style: FillStyle(eoFill: true, antialiased: true))
                Text("Message…")
                    .font(.system(size: h * 0.322, weight: .medium))
                    .foregroundColor(Theme.barMessageText)
                    .padding(.leading, w * 0.1195)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .offset(y: h * 0.026)
            }
        }
        .aspectRatio(IGChatArt.barSize.width / IGChatArt.barSize.height, contentMode: .fit)
    }
}

struct BackButtonArt: View {
    var height: CGFloat = 21

    var body: some View {
        ScaledArtShape(base: SVGPathParser.path(from: IGChatArt.backD), artSize: IGChatArt.backSize)
            .stroke(Color.white,
                    style: StrokeStyle(lineWidth: IGChatArt.backStroke * height / IGChatArt.backSize.height,
                                       lineCap: .round, lineJoin: .round))
            .frame(width: height * IGChatArt.backSize.width / IGChatArt.backSize.height, height: height)
            .offset(x: -3)   // optical centering: stroke weight sits heavy right
    }
}

/// One liquid-glass circular container per button (operator spec: separate containers).
struct GlassCircle<Content: View>: View {
    var size: CGFloat = 46
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(width: size, height: size)
            .background(
                Circle().fill(
                    RadialGradient(
                        colors: [.clear, Color.white.opacity(0.055)],
                        center: .center,
                        startRadius: size * 0.22,
                        endRadius: size * 0.52
                    )
                )
            )
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.white.opacity(0.04)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            )
            .overlay(
                Ellipse()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.05), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: size * 0.6, height: size * 0.38)
                    .offset(y: -size * 0.30)
                    .clipShape(Circle())
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
    }
}

struct LiveduoArt: View {
    var height: CGFloat = 24

    var body: some View {
        ScaledArtShape(base: IGChatArt.liveduoPath, artSize: IGChatArt.liveduoSize)
            .stroke(Color.white,
                    style: StrokeStyle(lineWidth: IGChatArt.liveduoStroke * height / IGChatArt.liveduoSize.height,
                                       lineCap: .round, lineJoin: .round))
            .frame(width: height * IGChatArt.liveduoSize.width / IGChatArt.liveduoSize.height, height: height)
    }
}

struct PhonecallArt: View {
    var height: CGFloat = 22

    var body: some View {
        ScaledArtShape(base: SVGPathParser.path(from: IGChatArt.phoneD), artSize: IGChatArt.phoneSize)
            .fill(Color.white, style: FillStyle(eoFill: true, antialiased: true))
            .frame(width: height, height: height)
    }
}

struct VcArt: View {
    var height: CGFloat = 22

    var body: some View {
        ScaledArtShape(base: SVGPathParser.path(from: IGChatArt.vcD), artSize: IGChatArt.vcSize)
            .fill(Color.white, style: FillStyle(eoFill: true, antialiased: true))
            .frame(width: height * IGChatArt.vcSize.width / IGChatArt.vcSize.height, height: height)
    }
}

/// Apple liquid-glass style container: frosted capsule + highlight border + shadow.
struct GlassCapsule<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 16) {
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, y: 4)
    }
}

/// Static (non-interactive) header glass buttons for the export canvas.
struct HeaderGlassStatic: View {
    var body: some View {
        HStack(spacing: 10) {
            GlassCircle(size: 46) { PhonecallArt(height: 22) }
            GlassCircle(size: 46) { VcArt(height: 22) }
        }
        .colorScheme(.dark)
    }
}
