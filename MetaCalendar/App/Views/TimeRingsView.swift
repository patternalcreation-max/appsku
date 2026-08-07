import SwiftUI

// MARK: - Time Rings Screen (Killer Feature #2)
// Concentric rings showing 7+ cycles simultaneously.

struct TimeRingsView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedDate = Date()

    private var fixedDay: Int64 {
        let cal = Calendar(identifier: .gregorian)
        return FixedDay.fromGregorian(
            year: cal.component(.year, from: selectedDate),
            month: cal.component(.month, from: selectedDate),
            day: cal.component(.day, from: selectedDate)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Meta.xl) {
                // Rings canvas
                RingsCanvas(fixedDay: fixedDay)
                    .frame(height: 340)

                // Date picker
                DatePicker("Pilih Tanggal", selection: $selectedDate, displayedComponents: [.date])
                    .datePickerStyle(.compact)
                    .tint(Meta.jade)
                    .labelsHidden()
                    .frame(maxWidth: 200)

                // Date stepper
                HStack(spacing: Meta.n) {
                    Button { selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)! } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 40, height: 40)
                            .background(Meta.surface)
                            .clipShape(Circle())
                    }
                    Text(dateLabel)
                        .font(.metaCaption).foregroundStyle(Meta.inkMuted)
                    Button { selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)! } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 40, height: 40)
                            .background(Meta.surface)
                            .clipShape(Circle())
                    }
                }

                // Ring legend
                VStack(alignment: .leading, spacing: Meta.s) {
                    Text("SILAKTI TERLIHAT")
                        .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

                    ringLegendItem(color: Meta.coral, name: "Hari", cycle: 7, current: weekdayLabel)
                    ringLegendItem(color: Meta.gold, name: "Pasaran", cycle: 5, current: pasaranLabel)
                    ringLegendItem(color: Meta.violet, name: "Weton", cycle: 35, current: wetonLabel)
                    ringLegendItem(color: Meta.jade, name: "Bulan", cycle: 29.5, current: moonLabel)
                    ringLegendItem(color: Meta.coral.opacity(0.6), name: "MetaSolar", cycle: 28, current: metaSolarLabel)
                    ringLegendItem(color: Meta.gold.opacity(0.6), name: "Tahun", cycle: 365, current: "\(FixedDay.toGregorian(fixedDay).year)")
                }

                // Alignment info
                alignmentInfoCard
            }
            .padding(.horizontal, Meta.l)
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
    }

    private func ringLegendItem(color: Color, name: String, cycle: Double, current: String) -> some View {
        HStack(spacing: Meta.n) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name).font(.metaBody).foregroundStyle(Meta.ink)
            Text("(\(cycle == 29.5 ? "29,5" : String(format: "%.0f", cycle)) hari)").font(.metaCaption).foregroundStyle(Meta.inkMuted)
            Spacer()
            Text(current).font(.system(size: 13, design: .rounded).weight(.medium)).foregroundStyle(color)
        }
    }

    private var alignmentInfoCard: some View {
        MetaCard {
            VStack(alignment: .leading, spacing: Meta.s) {
                Text("STATISTIK SIKLUS")
                    .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

                // When do pasaran and weekday realign? LCM(5,7) = 35
                MetaInfoRow(label: "Pasaran × Hari", value: "Setiap 35 hari (weton)")
                MetaInfoRow(label: "Weton × Bulan", value: "Setiap \(AlignmentFinder.formatDuration(AlignmentFinder.cycleRealignment(days: [35, 30])))")
                MetaInfoRow(label: "Semua siklus", value: AlignmentFinder.formatDuration(AlignmentFinder.cycleRealignment(days: [5, 7, 28, 30])))

                Text("Ketika semua posisi kembali ke titik yang sama, momen tersebut disebut 'penyelarasan penuh'.")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundStyle(Meta.inkMuted)
                    .padding(.top, Meta.s)
            }
        }
    }

    private var dateLabel: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.locale = Locale(identifier: "id_ID")
        return fmt.string(from: selectedDate)
    }

    private var weekdayLabel: String {
        let names = ["Ahad","Senin","Selasa","Rabu","Kamis","Jumat","Sabtu"]
        return names[FixedDay.weekday(fixedDay)]
    }

    private var pasaranLabel: String {
        let names = ["Legi","Pahing","Pon","Wage","Kliwon"]
        return names[JavaneseAdapter.pasaranIndex(fixedDay: fixedDay)]
    }

    private var wetonLabel: String {
        return "\(JavaneseAdapter.wetonDay(fixedDay: fixedDay) + 1)/35"
    }

    private var moonLabel: String {
        let phase = AstronomyEngine.moonPhaseAngle(forFixedDay: fixedDay)
        let pct = Int((1 - cos(phase * .pi / 180)) / 2 * 100)
        return "\(pct)%"
    }

    private var metaSolarLabel: String {
        let coord = MetaSolarEngine.coordinate(forFixedDay: fixedDay)
        if case .monthDay(_, let m, let d) = coord {
            return "B\(m) H\(d)"
        }
        return "Jembatan"
    }
}

// MARK: - Rings Canvas (SwiftUI Canvas)

struct RingsCanvas: View {
    let fixedDay: Int64

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - 20

            // Draw 6 concentric rings
            let rings: [(radius: Double, segments: Int, currentIdx: Int, color: Color, label: String)] = [
                ringData(0, maxR: maxRadius),
                ringData(1, maxR: maxRadius),
                ringData(2, maxR: maxRadius),
                ringData(3, maxR: maxRadius),
                ringData(4, maxR: maxRadius),
                ringData(5, maxR: maxRadius),
            ]

            for ring in rings {
                drawRing(context: &context, center: center, radius: ring.radius,
                         segments: ring.segments, currentIdx: ring.currentIdx,
                         color: ring.color)
            }

            // Center sun
            let sunRect = CGRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30)
            context.fill(Path(ellipseIn: sunRect), with: .color(Meta.gold.opacity(0.3)))
            let innerRect = CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)
            context.fill(Path(ellipseIn: innerRect), with: .color(Meta.gold))
        }
    }

    private func ringData(_ index: Int, maxR: Double) -> (radius: Double, segments: Int, currentIdx: Int, color: Color, label: String) {
        let spacing: Double = 22
        let radius = maxR - Double(index) * spacing

        switch index {
        case 0: // Weekday (7)
            return (radius, 7, FixedDay.weekday(fixedDay), Meta.coral, "Hari")
        case 1: // Pasaran (5)
            return (radius, 5, JavaneseAdapter.pasaranIndex(fixedDay: fixedDay), Meta.gold, "Pasaran")
        case 2: // Weton (35)
            return (radius, 35, JavaneseAdapter.wetonDay(fixedDay: fixedDay), Meta.violet, "Weton")
        case 3: // Moon (29.5 ~ 30 segments)
            let moonPhase = Int(AstronomyEngine.moonPhaseAngle(forFixedDay: fixedDay) / 12) % 30
            return (radius, 30, moonPhase, Meta.jade, "Bulan")
        case 4: // MetaSolar day (28)
            let coord = MetaSolarEngine.coordinate(forFixedDay: fixedDay)
            let day = { if case .monthDay(_, _, let d) = coord { return d - 1 }; return 0 }()
            return (radius, 28, day, Meta.coral.opacity(0.6), "MetaSolar")
        case 5: // Year orbit (12 months)
            let month = FixedDay.toGregorian(fixedDay).month - 1
            return (radius, 12, month, Meta.gold.opacity(0.6), "Tahun")
        default:
            return (radius, 1, 0, Meta.inkMuted, "")
        }
    }

    private func drawRing(context: inout GraphicsContext, center: CGPoint, radius: Double,
                          segments: Int, currentIdx: Int, color: Color) {
        // Background ring
        var bgPath = Path()
        bgPath.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(bgPath, with: .color(Meta.hairline), lineWidth: 1)

        // Segment dots
        for i in 0..<segments {
            let angle = Double(i) / Double(segments) * 2 * .pi - .pi / 2
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            let isActive = i == currentIdx
            let dotSize: CGFloat = isActive ? 8 : 3

            let rect = CGRect(x: x - dotSize/2, y: y - dotSize/2, width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: rect), with: .color(isActive ? color : Meta.inkMuted.opacity(0.3)))
        }
    }
}
