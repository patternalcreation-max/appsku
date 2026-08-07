import SwiftUI
import Foundation
import Observation

// MARK: - Design System v2 (ui-ux-pro-max: teal primary, orange accent, dark-first)

enum DS {
    // Primary palette — Teal focus
    static let primary = Color(red: 0.05, green: 0.58, blue: 0.53)       // #0D9488
    static let primaryLight = Color(red: 0.20, green: 0.72, blue: 0.65)  // lighter teal
    static let onPrimary = Color.white
    
    // Accent — Action orange
    static let accent = Color(red: 0.918, green: 0.349, blue: 0.047)     // #EA580C
    static let accentLight = Color(red: 0.973, green: 0.580, blue: 0.114)
    
    // Backgrounds — dark-first
    static let bgBase = Color(red: 0.035, green: 0.035, blue: 0.043)     // near-black
    static let bgCard = Color(red: 0.075, green: 0.075, blue: 0.090)     // card surface
    static let bgCardHover = Color(red: 0.11, green: 0.11, blue: 0.13)   // elevated
    static let bgInput = Color(red: 0.055, green: 0.055, blue: 0.065)
    
    // Text hierarchy
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.68)
    static let textTertiary = Color(white: 0.42)
    static let textAccent = primary
    
    // Borders & dividers
    static let border = Color(white: 0.10)
    static let borderActive = primary
    static let divider = Color(white: 0.08)
    
    // Status colors
    static let success = Color(red: 0.16, green: 0.70, blue: 0.45)
    static let warning = Color(red: 0.90, green: 0.62, blue: 0.15)
    static let danger = Color(red: 0.85, green: 0.27, blue: 0.27)
    
    // Calendar system colors
    static func systemColor(_ id: CalendarSystemID) -> Color {
        switch id {
        case .metaSolar:  return Color(red: 0.95, green: 0.62, blue: 0.20)
        case .gregorian:  return Color(red: 0.25, green: 0.60, blue: 0.90)
        case .chinese:    return Color(red: 0.85, green: 0.35, blue: 0.38)
        case .hijri:      return Color(red: 0.30, green: 0.75, blue: 0.50)
        case .javanese:   return Color(red: 0.70, green: 0.50, blue: 0.88)
        }
    }
    
    static func statusColor(_ status: ProjectionStatus) -> Color {
        switch status {
        case .computed:               return success
        case .experimental:           return warning
        case .predicted:              return Color(red: 0.80, green: 0.60, blue: 0.25)
        case .observed, .officiallyDeclared: return Color(red: 0.30, green: 0.75, blue: 0.90)
        case .historicalReconstruction: return Color(red: 0.60, green: 0.55, blue: 0.50)
        }
    }
    
    // Typography
    static let fontDisplay = Font.system(size: 34, design: .rounded).weight(.bold)
    static let fontTitle = Font.system(size: 22, design: .rounded).weight(.semibold)
    static let fontBody = Font.system(size: 15)
    static let fontBodyMono = Font.system(size: 14, design: .monospaced)
    static let fontCaption = Font.system(size: 12)
    static let fontMicro = Font.system(size: 10, design: .rounded).weight(.semibold)
    
    // Spacing
    static let space4: CGFloat = 4
    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space20: CGFloat = 20
    static let space24: CGFloat = 24
    
    // Corner radius
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
}

// MARK: - App State

@MainActor
@Observable
final class AppState {
    var timeZoneMode: TimeZoneMode = .followSystem
    var timeZone: TimeZone = .autoupdatingCurrent
    var ruleset: RulesetSelection = .default
    var location: GeoPoint? = GeoPoint(latitude: -6.2088, longitude: 106.8456, elevationMeters: 8, horizontalAccuracyMeters: nil) // Jakarta default
    var locationEnabled: Bool = false
    var selectedMetaSolarYear: Int = MetaSolarEngine.currentYear()
    var selectedMetaSolarMonth: Int = MetaSolarEngine.currentMonth()
    var todayBundle: ProjectionBundle? = nil
    var upcomingEvents: [CalendarEvent] = []
    var isLoading: Bool = false
    
    var displayTimeZone: TimeZone {
        switch timeZoneMode {
        case .followSystem:
            return .autoupdatingCurrent
        case .locked(let id):
            return TimeZone(identifier: id) ?? .autoupdatingCurrent
        }
    }
    
    func refreshToday() {
        isLoading = true
        let bundle = CalendarEngine.project(
            instant: Instant(),
            timeZone: displayTimeZone,
            location: locationEnabled ? location : nil,
            ruleset: ruleset
        )
        todayBundle = bundle
        
        // Load upcoming events for next 90 days
        upcomingEvents = CalendarEvents.upcoming(days: 90, hijriProfile: ruleset.hijriProfile)
        
        isLoading = false
    }
}

extension RulesetSelection {
    static let `default` = RulesetSelection(
        hijriProfile: .tabular,
        javaneseProfile: .sultanAgungan,
        displayOrder: [.gregorian, .metaSolar, .hijri, .javanese, .chinese]
    )
}

// MARK: - Reusable Components

struct GlassCard<Content: View>: View {
    var padding: CGFloat = DS.space16
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .padding(padding)
            .background(DS.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG, style: .continuous))
    }
}

struct CalendarCardV2: View {
    let projection: CalendarProjection
    let rank: Int
    
    var body: some View {
        HStack(spacing: DS.space12) {
            // Left: system icon badge
            ZStack {
                Circle()
                    .fill(DS.systemColor(projection.calendarSystemID).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: projection.calendarSystemID.iconName)
                    .foregroundStyle(DS.systemColor(projection.calendarSystemID))
                    .font(.system(size: 18))
            }
            
            // Center: date info
            VStack(alignment: .leading, spacing: DS.space4) {
                Text(projection.displayString)
                    .font(.system(size: 18, design: .rounded).weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                
                Text(projection.subtitle)
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right: status badge
            VStack(spacing: 2) {
                Text(String(projection.status.rawValue.prefix(4)).uppercased())
                    .font(DS.fontMicro)
                    .foregroundStyle(DS.statusColor(projection.status))
                if rank == 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.success)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, DS.space16)
        .padding(.vertical, DS.space12)
        .background(DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMD, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(projection.calendarSystemID.displayName), \(projection.displayString), \(projection.subtitle)")
    }
}

struct EventRow: View {
    let event: CalendarEvent
    let daysUntil: Int
    
    var body: some View {
        HStack(spacing: DS.space12) {
            // Days until badge
            VStack(spacing: 0) {
                Text(daysUntil == 0 ? "NOW" : "\(daysUntil)")
                    .font(.system(size: daysUntil == 0 ? 10 : 20, design: .rounded).weight(.bold))
                    .foregroundStyle(daysUntil <= 3 ? DS.accent : DS.textPrimary)
                if daysUntil > 0 {
                    Text(daysUntil == 1 ? "day" : "days")
                        .font(.system(size: 9))
                        .foregroundStyle(DS.textTertiary)
                }
            }
            .frame(width: 52, height: 52)
            .background((daysUntil <= 3 ? DS.accent.opacity(0.12) : DS.bgCardHover))
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSM))
            
            // Event info
            VStack(alignment: .leading, spacing: 2) {
                Text(event.emoji + " " + event.name)
                    .font(.system(size: 14, design: .rounded).weight(.medium))
                    .foregroundStyle(DS.textPrimary)
                Text(event.dateString)
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Category badge
            Text(event.category.rawValue.uppercased())
                .font(DS.fontMicro)
                .foregroundStyle(DS.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(DS.bgCardHover)
                .clipShape(Capsule())
        }
        .padding(.horizontal, DS.space12)
        .padding(.vertical, 10)
    }
}

struct AstroStripItem: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 11, design: .rounded).weight(.semibold))
                .foregroundStyle(DS.textSecondary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SectionTitle: View {
    let title: String
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(DS.primary)
                    .font(.system(size: 14))
            }
            Text(title)
                .font(.system(size: 13, design: .rounded).weight(.semibold))
                .foregroundStyle(DS.textTertiary)
                .textCase(.uppercase)
            Spacer()
        }
    }
}

struct InfoRowV2: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(DS.fontCaption)
                .foregroundStyle(DS.textTertiary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(DS.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ProvenanceSheetV2: View {
    let projection: CalendarProjection
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.space20) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: DS.space12) {
                            HStack {
                                Image(systemName: projection.calendarSystemID.iconName)
                                    .foregroundStyle(DS.systemColor(projection.calendarSystemID))
                                    .font(.title2)
                                Text(projection.calendarSystemID.displayName)
                                    .font(DS.fontTitle)
                                    .foregroundStyle(DS.textPrimary)
                            }
                            InfoRowV2(label: "Ruleset", value: projection.rulesetID)
                            InfoRowV2(label: "Status", value: projection.status.rawValue.capitalized)
                            InfoRowV2(label: "Provenance", value: projection.provenance)
                        }
                    }
                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: DS.space8) {
                            Text("Coordinate")
                                .font(DS.fontTitle)
                                .foregroundStyle(DS.textPrimary)
                            InfoRowV2(label: "Year", value: "\(projection.coordinate.year)")
                            InfoRowV2(label: "Month", value: "\(projection.coordinate.month)\(projection.coordinate.isLeapMonth ? " (Leap)" : "")")
                            InfoRowV2(label: "Day", value: "\(projection.coordinate.day)")
                            ForEach(projection.coordinate.extraFields.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                                InfoRowV2(label: k.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized, value: v)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Calculation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .background(DS.bgBase.ignoresSafeArea())
        }
    }
}
