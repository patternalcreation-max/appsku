import SwiftUI
import Foundation
import Observation

// MARK: - App Theme

enum AppTheme {
    static let bgPrimary = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let bgCard = Color(red: 0.10, green: 0.10, blue: 0.14)
    static let bgCardHover = Color(red: 0.14, green: 0.14, blue: 0.18)
    static let accent = Color(red: 0.55, green: 0.85, blue: 0.85)
    static let accentWarm = Color(red: 0.95, green: 0.75, blue: 0.45)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let textTertiary = Color(white: 0.40)
    static let divider = Color(white: 0.12)
    static let experimentalBadge = Color(red: 0.85, green: 0.65, blue: 0.25)
    static let computedBadge = Color(red: 0.30, green: 0.70, blue: 0.50)
    
    static func statusColor(_ status: ProjectionStatus) -> Color {
        switch status {
        case .computed: return computedBadge
        case .experimental: return experimentalBadge
        case .predicted: return Color(red: 0.75, green: 0.60, blue: 0.30)
        case .observed, .officiallyDeclared: return Color(red: 0.45, green: 0.75, blue: 0.90)
        case .historicalReconstruction: return Color(red: 0.60, green: 0.55, blue: 0.50)
        }
    }
    
    static func systemColor(_ id: CalendarSystemID) -> Color {
        switch id {
        case .metaSolar: return Color(red: 0.95, green: 0.70, blue: 0.30)
        case .gregorian: return Color(red: 0.40, green: 0.70, blue: 0.95)
        case .chinese: return Color(red: 0.85, green: 0.40, blue: 0.45)
        case .hijri: return Color(red: 0.50, green: 0.80, blue: 0.55)
        case .javanese: return Color(red: 0.75, green: 0.60, blue: 0.90)
        }
    }
}

// MARK: - App State (Observable)

@MainActor
@Observable
final class AppState {
    var timeZoneMode: TimeZoneMode = .followSystem
    var timeZone: TimeZone = .autoupdatingCurrent
    var ruleset: RulesetSelection = .default
    var location: GeoPoint? = nil
    var locationEnabled: Bool = false
    var selectedMetaSolarYear: Int = MetaSolarEngine.devEpochYear + Int((FixedDay.fromGregorian(year: Calendar(identifier: .gregorian).component(.year, from: Date()), month: 1, day: 1) - MetaSolarEngine.devEpochFixedDay) / 365)
    var selectedMetaSolarMonth: Int = 1
    var todayBundle: ProjectionBundle? = nil
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
        isLoading = false
    }
}

extension RulesetSelection {
    static let `default` = RulesetSelection(
        hijriProfile: .tabular,
        javaneseProfile: .cycles,
        displayOrder: [.metaSolar, .gregorian, .chinese, .hijri, .javanese]
    )
}

// MARK: - Reusable UI Components

struct CalendarCard: View {
    let projection: CalendarProjection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: projection.calendarSystemID.iconName)
                    .foregroundStyle(AppTheme.systemColor(projection.calendarSystemID))
                    .font(.system(size: 20))
                
                Text(projection.calendarSystemID.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(AppTheme.textSecondary)
                
                Spacer()
                
                Text(projection.status.rawValue.capitalized)
                    .font(.system(size: 10, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.statusColor(projection.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.statusColor(projection.status).opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Text(projection.displayString)
                .font(.system(size: 24, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            
            Text(projection.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
            
            if !projection.warnings.isEmpty {
                ForEach(projection.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct ProvenanceSheet: View {
    let projection: CalendarProjection
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Label("How was this calculated?", systemImage: "questionmark.circle")
                            .font(.title3.bold())
                        
                        InfoRow(label: "Calendar System", value: projection.calendarSystemID.displayName)
                        InfoRow(label: "Ruleset", value: projection.rulesetID)
                        InfoRow(label: "Status", value: projection.status.rawValue.capitalized)
                        InfoRow(label: "Provenance", value: projection.provenance)
                    }
                    
                    Group {
                        Label("Coordinate Details", systemImage: "scope")
                            .font(.title3.bold())
                        
                        InfoRow(label: "Year", value: "\(projection.coordinate.year)")
                        InfoRow(label: "Month", value: "\(projection.coordinate.month)\(projection.coordinate.isLeapMonth ? " (Leap)" : "")")
                        InfoRow(label: "Day", value: "\(projection.coordinate.day)")
                        
                        ForEach(projection.coordinate.extraFields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            InfoRow(label: key.replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression).capitalized, value: value)
                        }
                    }
                    
                    if !projection.warnings.isEmpty {
                        Group {
                            Label("Warnings", systemImage: "exclamationmark.triangle")
                                .font(.title3.bold())
                            
                            ForEach(projection.warnings, id: \.self) { w in
                                Text(w)
                                    .font(.callout)
                                    .foregroundStyle(.orange)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Calculation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.textPrimary)
            if let sub = subtitle {
                Text(sub)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
