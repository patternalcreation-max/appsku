import SwiftUI

// MARK: - Today Screen

struct TodayView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedProjection: CalendarProjection? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                contextHeader
                astronomyStrip
                calendarCards
                provenanceFooter
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(AppTheme.bgPrimary.ignoresSafeArea())
        .refreshable {
            appState.refreshToday()
        }
        .task {
            appState.refreshToday()
        }
    }
    
    // Context Header
    private var contextHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.displayTimeZone.identifier)
                        .font(.system(size: 15, design: .monospaced).weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(gmtOffsetString)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Text(timeString)
                    .font(.system(size: 28, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.accent)
            }
            
            HStack(spacing: 6) {
                Image(systemName: appState.timeZoneMode == .followSystem ? "location.fill" : "lock.fill")
                    .font(.system(size: 11))
                Text(appState.timeZoneMode.displayName)
                    .font(.system(size: 12))
            }
            .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // Astronomy Strip
    @ViewBuilder
    private var astronomyStrip: some View {
        if let astro = appState.todayBundle?.astronomy {
            HStack(spacing: 12) {
                // Moon phase
                VStack(spacing: 4) {
                    Text(astro.moonPhaseEmoji)
                        .font(.system(size: 28))
                    Text("\(Int(astro.moonIllumination * 100))%")
                        .font(.system(size: 11, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Moon")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 40)
                
                // Solar longitude
                VStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.accentWarm)
                    Text(String(format: "%.0f°", astro.solarLongitude))
                        .font(.system(size: 11, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("Sun λ")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 40)
                
                // Solar term
                VStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.green)
                    Text(astro.solarTerm.split(separator: " ").first.map(String.init) ?? "")
                        .font(.system(size: 11, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    Text("Term")
                        .font(.system(size: 9))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                
                if astro.sunrise != nil {
                    Divider().frame(height: 40)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.orange)
                        if let sr = astro.sunrise {
                            Text(timeFormatter.string(from: sr))
                                .font(.system(size: 11, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Text("Sunrise")
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(14)
            .background(AppTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    // Calendar Cards
    private var calendarCards: some View {
        LazyVStack(spacing: 10) {
            if let bundle = appState.todayBundle {
                ForEach(bundle.projections) { proj in
                    CalendarCard(projection: proj)
                        .onTapGesture {
                            selectedProjection = proj
                        }
                        .accessibilityLabel("\(proj.calendarSystemID.displayName): \(proj.displayString). \(proj.subtitle)")
                }
            }
        }
        .sheet(item: $selectedProjection) { proj in
            ProvenanceSheet(projection: proj)
                .presentationDetents([.medium, .large])
        }
    }
    
    // Provenance Footer
    private var provenanceFooter: some View {
        VStack(spacing: 6) {
            Text("One moment, several calendar views.")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundStyle(AppTheme.textTertiary)
            Text("Method and source always visible.")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .padding(.top, 8)
    }
    
    // Helpers
    private var gmtOffsetString: String {
        let offset = appState.displayTimeZone.secondsFromGMT() / 3600
        let hours = abs(offset)
        let sign = offset >= 0 ? "+" : "-"
        return String(format: "GMT%@%.1f", sign, Double(hours))
    }
    
    private var timeString: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.timeZone = appState.displayTimeZone
        return fmt.string(from: Date())
    }
    
    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.timeStyle = .short
        f.timeZone = appState.displayTimeZone
        return f
    }
}
