import SwiftUI

// MARK: - Today Screen v2

struct TodayView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedProjection: CalendarProjection? = nil
    
    var body: some View {
        ScrollView {
            VStack(spacing: DS.space20) {
                contextHero
                astronomyStrip
                calendarCardsSection
                upcomingEventsSection
                quoteFooter
            }
            .padding(.horizontal, DS.space16)
            .padding(.bottom, 40)
        }
        .background(DS.bgBase.ignoresSafeArea())
        .refreshable { appState.refreshToday() }
        .task { appState.refreshToday() }
    }
    
    // MARK: - Context Hero
    private var contextHero: some View {
        VStack(alignment: .leading, spacing: DS.space12) {
            // Time display
            HStack(alignment: .firstTextBaseline, spacing: DS.space8) {
                Text(timeString)
                    .font(.system(size: 42, design: .rounded).weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                Text(gmtOffsetString)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(DS.primary)
            }
            
            // Date display
            Text(fullDateString)
                .font(.system(size: 15))
                .foregroundStyle(DS.textSecondary)
            
            // Timezone + mode
            HStack(spacing: DS.space8) {
                Label {
                    Text(appState.displayTimeZone.identifier)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(DS.textTertiary)
                } icon: {
                    Image(systemName: appState.timeZoneMode == .followSystem ? "location.fill" : "lock.fill")
                        .foregroundStyle(DS.primary)
                        .font(.system(size: 11))
                }
                
                if let astro = appState.todayBundle?.astronomy, astro.sunrise != nil {
                    Divider().frame(height: 12)
                    Label {
                        Text(appState.locationEnabled ? "Jakarta" : "Location off")
                            .font(.system(size: 12))
                            .foregroundStyle(DS.textTertiary)
                    } icon: {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(DS.accent)
                            .font(.system(size: 11))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.space20)
        .background(
            LinearGradient(
                colors: [DS.primary.opacity(0.12), DS.bgCard],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusXL, style: .continuous))
    }
    
    // MARK: - Astronomy Strip
    @ViewBuilder
    private var astronomyStrip: some View {
        if let astro = appState.todayBundle?.astronomy {
            GlassCard(padding: DS.space12) {
                HStack(spacing: 0) {
                    AstroStripItem(icon: "\(astro.moonPhaseEmoji)", iconColor: .white, value: "\(Int(astro.moonIllumination * 100))%", label: astro.moonPhaseName)
                    Divider().frame(height: 44)
                    AstroStripItem(icon: "sun.max.fill", iconColor: DS.accent, value: String(format: "%.0f°", astro.solarLongitude), label: "Solar λ")
                    Divider().frame(height: 44)
                    AstroStripItem(icon: "leaf.fill", iconColor: DS.success, value: astro.solarTerm.split(separator: " ").first.map(String.init) ?? "", label: "Solar Term")
                    if astro.sunrise != nil {
                        Divider().frame(height: 44)
                        AstroStripItem(icon: "sunrise.fill", iconColor: .orange, value: timeOnly(astro.sunrise), label: "Sunrise")
                    }
                }
            }
        }
    }
    
    // MARK: - Calendar Cards
    private var calendarCardsSection: some View {
        VStack(alignment: .leading, spacing: DS.space8) {
            SectionTitle(title: "Today Across Calendars", icon: "calendar.badge.clock")
            
            if let bundle = appState.todayBundle {
                ForEach(Array(bundle.projections.enumerated()), id: \.element.id) { idx, proj in
                    Button {
                        selectedProjection = proj
                    } label: {
                        CalendarCardV2(projection: proj, rank: idx)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selectedProjection) { proj in
            ProvenanceSheetV2(projection: proj)
                .presentationDetents([.medium, .large])
        }
    }
    
    // MARK: - Upcoming Events
    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: DS.space8) {
            SectionTitle(title: "Upcoming Events", icon: "sparkles")
            
            if appState.upcomingEvents.isEmpty {
                GlassCard {
                    Text("No major events in the next 90 days")
                        .font(DS.fontBody)
                        .foregroundStyle(DS.textTertiary)
                }
            } else {
                ForEach(Array(appState.upcomingEvents.prefix(8))) { event in
                    EventRow(event: event, daysUntil: event.daysFromToday)
                        .background(DS.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSM))
                }
            }
        }
    }
    
    // MARK: - Footer
    private var quoteFooter: some View {
        VStack(spacing: 4) {
            Text("One moment, several calendar views.")
                .font(.system(size: 12, design: .serif).italic())
                .foregroundStyle(DS.textTertiary)
        }
        .padding(.top, DS.space8)
    }
    
    // MARK: - Helpers
    private var gmtOffsetString: String {
        let offset = appState.displayTimeZone.secondsFromGMT()
        let hours = abs(offset) / 3600
        let mins = (abs(offset) % 3600) / 60
        let sign = offset >= 0 ? "+" : "-"
        return String(format: "GMT%@%d:%02d", sign, hours, mins)
    }
    
    private var timeString: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.timeZone = appState.displayTimeZone
        return fmt.string(from: Date())
    }
    
    private var fullDateString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeZone = appState.displayTimeZone
        return fmt.string(from: Date())
    }
    
    private func timeOnly(_ date: Date?) -> String {
        guard let date else { return "—" }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.timeZone = appState.displayTimeZone
        return fmt.string(from: date)
    }
}
