import SwiftUI
import Foundation
import Observation

// MARK: - Meta Design System v3 (ported from RN version by AI lo)
// Gold/Jade/Coral palette · dark-first · glassmorphism · Indonesian-first

enum Meta {
    // Dark palette (primary — dark-first)
    static let canvas = Color(red: 0.027, green: 0.075, blue: 0.063)      // #071310
    static let canvasEnd = Color(red: 0.043, green: 0.110, blue: 0.094)   // #0B1C18
    static let ink = Color(red: 0.961, green: 0.941, blue: 0.890)         // #F5F0E3
    static let inkMuted = Color(red: 0.624, green: 0.690, blue: 0.665)    // #9FB0AA
    static let hairline = Color.white.opacity(0.06)
    static let surface = Color(red: 0.07, green: 0.15, blue: 0.13).opacity(0.78)
    static let surfaceRaised = Color(red: 0.078, green: 0.165, blue: 0.137) // #142A24
    static let surfacePressed = Color(red: 0.110, green: 0.216, blue: 0.188) // #1C3730

    // Accents
    static let gold = Color(red: 0.906, green: 0.710, blue: 0.365)        // #E7B55D
    static let goldSoft = Color(red: 0.227, green: 0.188, blue: 0.125)    // #3A3020
    static let jade = Color(red: 0.337, green: 0.780, blue: 0.702)        // #56C7B3
    static let coral = Color(red: 0.910, green: 0.541, blue: 0.459)       // #E88A75
    static let violet = Color(red: 0.706, green: 0.639, blue: 0.937)      // #B4A3EF
    static let danger = Color(red: 0.941, green: 0.541, blue: 0.541)      // #F08A8A
    static let shadow = Color.black

    // Calendar system accents
    static func systemAccent(_ id: CalendarSystemID) -> Color {
        switch id {
        case .gregorian:  return gold
        case .metaSolar:  return coral
        case .chinese:    return Color(red: 0.906, green: 0.510, blue: 0.482) // warm red
        case .hijri:      return jade
        case .javanese:   return violet
        }
    }

    static func systemEyebrow(_ id: CalendarSystemID) -> String {
        switch id {
        case .gregorian:  return "SIPIL · GREGORIAN"
        case .metaSolar:  return "13 × 28 · METASOLAR"
        case .chinese:    return "BULAN BARU · CHINESE"
        case .hijri:      return "HISAB · HIJRI"
        case .javanese:   return "PASARAN · JAWA"
        }
    }

    static func systemTitle(_ id: CalendarSystemID) -> String {
        switch id {
        case .gregorian:  return "Gregorian"
        case .metaSolar:  return "MetaSolar 13"
        case .chinese:    return "China"
        case .hijri:      return "Hijriah"
        case .javanese:   return "Jawa"
        }
    }

    // Status label (Indonesian)
    static func statusLabel(_ status: ProjectionStatus) -> String {
        switch status {
        case .computed:               return "Dihitung"
        case .experimental:           return "Eksperimen"
        case .predicted:              return "Diperkirakan"
        case .observed:               return "Diamati"
        case .officiallyDeclared:     return "Resmi"
        case .historicalReconstruction: return "Rekonstruksi"
        }
    }

    // Spacing
    static let s: CGFloat = 4   // xs
    static let m: CGFloat = 8   // sm
    static let n: CGFloat = 12  // md
    static let l: CGFloat = 16  // lg
    static let xl: CGFloat = 24 // xl
    static let xxl: CGFloat = 32

    // Radius
    static let rSM: CGFloat = 10
    static let rMD: CGFloat = 16
    static let rLG: CGFloat = 24
    static let rXL: CGFloat = 32
    static let rPill: CGFloat = 999
}

// MARK: - Typography Helpers

extension Font {
    static let metaDisplay = Font.system(size: 52, design: .rounded).weight(.bold)
    static let metaTitle = Font.system(size: 30, design: .rounded).weight(.bold)
    static let metaHeadline = Font.system(size: 18, design: .rounded).weight(.semibold)
    static let metaBody = Font.system(size: 15)
    static let metaCaption = Font.system(size: 12).weight(.medium)
    static let metaEyebrow = Font.system(size: 10).weight(.heavy)
    static let metaMono = Font.system(size: 12, design: .monospaced).weight(.semibold)
}

// MARK: - App State

@MainActor
@Observable
final class AppState {
    var timeZoneMode: TimeZoneMode = .followSystem
    var timeZone: TimeZone = .autoupdatingCurrent
    var ruleset: RulesetSelection = .default
    var location: GeoPoint? = GeoPoint(latitude: -6.2088, longitude: 106.8456, elevationMeters: 8, horizontalAccuracyMeters: nil)
    var locationEnabled: Bool = false
    var selectedMetaSolarYear: Int = MetaSolarEngine.currentYear()
    var selectedMetaSolarMonth: Int = MetaSolarEngine.currentMonth()
    var selectedGregDay: Date = Date()  // for DayStepper
    var todayBundle: ProjectionBundle? = nil
    var selectedDayBundle: ProjectionBundle? = nil  // for DayStepper projections
    var upcomingEvents: [CalendarEvent] = []
    var isLoading: Bool = false

    var displayTimeZone: TimeZone {
        switch timeZoneMode {
        case .followSystem: return .autoupdatingCurrent
        case .locked(let id): return TimeZone(identifier: id) ?? .autoupdatingCurrent
        }
    }

    func refreshToday() {
        isLoading = true
        let bundle = CalendarEngine.project(
            instant: Instant(), timeZone: displayTimeZone,
            location: locationEnabled ? location : nil, ruleset: ruleset
        )
        todayBundle = bundle
        selectedDayBundle = CalendarEngine.project(
            instant: Instant(selectedGregDay), timeZone: displayTimeZone,
            location: locationEnabled ? location : nil, ruleset: ruleset
        )
        upcomingEvents = CalendarEvents.upcoming(days: 90, hijriProfile: ruleset.hijriProfile)
        isLoading = false
    }

    var isOnSelectedDay: Bool {
        let cal = Calendar(identifier: .gregorian)
        return cal.isDateInToday(selectedGregDay)
    }

    func goToToday() { selectedGregDay = Date(); refreshToday() }
    func shiftDay(_ amount: Int) {
        selectedGregDay = Calendar(identifier: .gregorian).date(byAdding: .day, value: amount, to: selectedGregDay) ?? Date()
        refreshToday()
    }
}

extension RulesetSelection {
    static let `default` = RulesetSelection(
        hijriProfile: .tabular,
        javaneseProfile: .sultanAgungan,
        displayOrder: [.gregorian, .metaSolar, .hijri, .javanese, .chinese]
    )
}

// MARK: - Components

/// Background gradient canvas (like AppScreen in RN)
struct MetaBackground: View {
    var body: some View {
        LinearGradient(colors: [Meta.canvas, Meta.canvasEnd], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Meta.gold.opacity(0.06))
                    .frame(width: 280, height: 280)
                    .offset(x: 100, y: -190)
                    .blur(radius: 40)
            }
    }
}

/// Glass card with border + subtle shadow
struct MetaCard<Content: View>: View {
    var padding: CGFloat = Meta.l
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(Meta.surface)
            .clipShape(RoundedRectangle(cornerRadius: Meta.rLG, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Meta.rLG, style: .continuous)
                    .stroke(Meta.hairline, lineWidth: 0.5)
            )
    }
}

/// OrbitHero — 13 dots melingkar dengan highlighted month + sun halo center
struct OrbitHero: View {
    let date: Date
    let timeZone: TimeZone

    private var gregorianDay: Int {
        let cal = Calendar(identifier: .gregorian)
        var c = cal; c.timeZone = timeZone
        return c.component(.day, from: date)
    }

    private var monthLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        fmt.timeZone = timeZone
        return fmt.string(from: date)
    }

    private var weekdayLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE"
        fmt.timeZone = timeZone
        let label = fmt.string(from: date)
        return label.uppercased()
    }

    private var monthIndex: Int {
        let cal = Calendar(identifier: .gregorian)
        var c = cal; c.timeZone = timeZone
        return c.component(.month, from: date) // 1-12
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Outer orbit ring
                Circle()
                    .stroke(Meta.hairline, lineWidth: 0.5)
                    .frame(width: 236, height: 236)

                // Inner orbit ring
                Circle()
                    .stroke(Meta.hairline, lineWidth: 0.5)
                    .frame(width: 172, height: 172)

                // Sun halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Meta.gold.opacity(0.35), Meta.gold.opacity(0.06)],
                            center: .center, startRadius: 0, endRadius: 63
                        )
                    )
                    .frame(width: 126, height: 126)

                // 13 dots
                ForEach(0..<13, id: \.self) { i in
                    let angle = Double(i) / 13.0 * 2.0 * .pi - .pi / 2
                    let radius: CGFloat = 102
                    let isActive = i == (monthIndex - 1) % 13

                    Circle()
                        .fill(isActive ? Meta.gold : Meta.inkMuted)
                        .frame(width: isActive ? 10 : 7, height: isActive ? 10 : 7)
                        .opacity(isActive ? 1 : 0.36)
                        .offset(x: cos(angle) * radius, y: sin(angle) * radius)
                        .animation(.easeInOut(duration: 0.3), value: isActive)
                }

                // Center content
                VStack(spacing: Meta.s) {
                    Text(weekdayLabel)
                        .font(.metaEyebrow)
                        .foregroundStyle(Meta.gold)
                        .kerning(1.35)
                    Text("\(gregorianDay)")
                        .font(.metaDisplay)
                        .foregroundStyle(Meta.ink)
                    Text(monthLabel)
                        .font(.metaBody)
                        .foregroundStyle(Meta.inkMuted)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityLabel("\(weekdayLabel.lowercased()), \(gregorianDay) \(monthLabel)")
    }
}

/// Expandable projection card with accent bar
struct MetaProjectionCard: View {
    let projection: CalendarProjection
    @State private var expanded = false

    private var accentColor: Color { Meta.systemAccent(projection.calendarSystemID) }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Accent bar
                Rectangle()
                    .fill(accentColor)
                    .frame(height: 3)

                VStack(alignment: .leading, spacing: Meta.n) {
                    // Top row
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Meta.systemEyebrow(projection.calendarSystemID))
                                .font(.metaEyebrow)
                                .foregroundStyle(accentColor)
                                .kerning(1.35)
                            Text(Meta.systemTitle(projection.calendarSystemID))
                                .font(.metaHeadline)
                                .foregroundStyle(Meta.ink)
                        }
                        Spacer()
                        VStack(spacing: 4) {
                            Text(Meta.statusLabel(projection.status))
                                .font(.metaCaption.weight(.bold))
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, Meta.n)
                                .padding(.vertical, 6)
                                .background(accentColor.opacity(0.15))
                                .clipShape(Capsule())
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                                .foregroundStyle(Meta.inkMuted)
                        }
                    }

                    // Primary date
                    Text(projection.displayString)
                        .font(.metaHeadline)
                        .foregroundStyle(Meta.ink)

                    // Secondary
                    Text(projection.subtitle)
                        .font(.metaBody)
                        .foregroundStyle(Meta.inkMuted)
                        .lineLimit(expanded ? nil : 2)

                    // Expanded details
                    if expanded {
                        Divider().overlay(Meta.hairline).padding(.vertical, Meta.s)

                        // Epistemic class badge
                        HStack(spacing: Meta.s) {
                            Text(projection.status.epistemicClass.rawValue.uppercased())
                                .font(.metaEyebrow)
                                .foregroundStyle(accentColor)
                                .kerning(1.2)
                            Text("·")
                                .foregroundStyle(Meta.inkMuted)
                            Text(Meta.statusLabel(projection.status))
                                .font(.metaCaption)
                                .foregroundStyle(Meta.inkMuted)
                        }

                        MetaInfoRow(label: "Metode", value: projection.rulesetID)
                        MetaInfoRow(label: "Batas", value: "Tengah malam · \(projection.calendarSystemID.rawValue)")
                        MetaInfoRow(label: "Provenans", value: projection.provenance)
                        MetaInfoRow(label: "Status", value: detailLabel)
                    }
                }
                .padding(Meta.l)
            }
            .background(Meta.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Meta.rMD, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Meta.rMD, style: .continuous)
                    .stroke(Meta.hairline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Meta.systemTitle(projection.calendarSystemID)), \(projection.displayString)")
        .accessibilityHint(expanded ? "Ketuk untuk ciutkan" : "Ketuk untuk detail")
    }

    private var detailLabel: String {
        switch projection.status {
        case .experimental: return "Profil eksperimen; bukan klaim kalender universal."
        case .predicted: return "Perkiraan; mungkin berubah dengan deklarasi resmi."
        default: return "Hasil deterministik dari konteks dan profil aktif."
        }
    }
}

/// Day stepper — prev/next day with "KEMBALI KE HARI INI"
struct DayStepper: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: Meta.s) {
            Button {
                appState.shiftDay(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Meta.ink)
                    .frame(width: 40, height: 40)
                    .background(Meta.surfacePressed.opacity(0.5))
                    .clipShape(Circle())
            }

            Button {
                appState.goToToday()
            } label: {
                Text(appState.isOnSelectedDay ? "HARI INI" : "KEMBALI KE HARI INI")
                    .font(.metaCaption.weight(.heavy))
                    .kerning(0.7)
                    .foregroundStyle(appState.isOnSelectedDay ? Meta.jade : Meta.inkMuted)
                    .padding(.horizontal, Meta.n)
            }

            Button {
                appState.shiftDay(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Meta.ink)
                    .frame(width: 40, height: 40)
                    .background(Meta.surfacePressed.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(Meta.s)
        .background(Meta.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Meta.hairline, lineWidth: 0.5))
    }
}

/// Section heading
struct MetaSection: View {
    let title: String
    var action: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.metaHeadline)
                .foregroundStyle(Meta.ink)
            Spacer()
            if let action {
                Text(action)
                    .font(.metaCaption)
                    .foregroundStyle(Meta.inkMuted)
            }
        }
    }
}

/// Info row
struct MetaInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.metaCaption)
                .foregroundStyle(Meta.inkMuted)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Meta.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Event row (Indonesian copy)
struct MetaEventRow: View {
    let event: CalendarEvent
    let daysUntil: Int

    var body: some View {
        HStack(spacing: Meta.n) {
            VStack(spacing: 0) {
                Text(daysUntil == 0 ? "KINI" : "\(daysUntil)")
                    .font(.system(size: daysUntil == 0 ? 9 : 20, design: .rounded).weight(.bold))
                    .foregroundStyle(daysUntil <= 3 ? Meta.coral : Meta.ink)
                if daysUntil > 0 {
                    Text(daysUntil == 1 ? "hari" : "hari")
                        .font(.system(size: 9))
                        .foregroundStyle(Meta.inkMuted)
                }
            }
            .frame(width: 52, height: 52)
            .background((daysUntil <= 3 ? Meta.coral.opacity(0.12) : Meta.surfaceRaised))
            .clipShape(RoundedRectangle(cornerRadius: Meta.rSM))

            VStack(alignment: .leading, spacing: 2) {
                Text(event.emoji + " " + event.name)
                    .font(.system(size: 14, design: .rounded).weight(.medium))
                    .foregroundStyle(Meta.ink)
                Text(event.dateString)
                    .font(.metaCaption)
                    .foregroundStyle(Meta.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(event.category.displayName.uppercased())
                .font(.metaEyebrow)
                .foregroundStyle(Meta.inkMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Meta.surfaceRaised)
                .clipShape(Capsule())
        }
        .padding(.horizontal, Meta.n)
        .padding(.vertical, 10)
    }
}

/// Provenance sheet (Indonesian)
struct MetaProvenanceSheet: View {
    let projection: CalendarProjection
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Meta.xl) {
                    MetaCard {
                        VStack(alignment: .leading, spacing: Meta.n) {
                            Text("BAGAIMANA DIHITUNG?")
                                .font(.metaEyebrow)
                                .foregroundStyle(Meta.gold)
                                .kerning(1.35)
                            Text(Meta.systemTitle(projection.calendarSystemID))
                                .font(.metaTitle)
                                .foregroundStyle(Meta.ink)
                            MetaInfoRow(label: "Ruleset", value: projection.rulesetID)
                            MetaInfoRow(label: "Kelas Epistemik", value: projection.status.epistemicClass.rawValue)
                            MetaInfoRow(label: "Status", value: Meta.statusLabel(projection.status))
                            MetaInfoRow(label: "Provenans", value: projection.provenance)
                        }
                    }

                    MetaCard {
                        VStack(alignment: .leading, spacing: Meta.s) {
                            Text("KOORDINAT")
                                .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)
                            MetaInfoRow(label: "Tahun", value: "\(projection.coordinate.year)")
                            MetaInfoRow(label: "Bulan", value: "\(projection.coordinate.month)\(projection.coordinate.isLeapMonth ? " (Kabisat)" : "")")
                            MetaInfoRow(label: "Hari", value: "\(projection.coordinate.day)")
                            ForEach(projection.coordinate.extraFields.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                                MetaInfoRow(label: k.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized, value: v)
                            }
                        }
                    }
                }
                .padding(.horizontal, Meta.l)
            }
            .navigationTitle("Perhitungan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Selesai") { dismiss() } }
            }
            .background(MetaBackground())
        }
    }
}
