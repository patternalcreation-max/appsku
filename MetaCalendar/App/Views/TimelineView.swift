import SwiftUI

// MARK: - Unified Timeline (World + Astronomy + Religious + Cultural)

struct TimelineView: View {
    @Environment(AppState.self) private var appState
    @State private var events: [CalendarEvent] = []
    @State private var selectedCategory: EventFilter = .all
    @State private var timeRange: TimeRange = .upcoming

    enum EventFilter: String, CaseIterable, Identifiable {
        case all = "Semua"
        case astronomical = "🪐 Astronomi"
        case cultural = "🎭 Budaya"
        case religious = "🕌 Agama"
        case sport = "⚽ Olahraga"
        case national = "🇮🇩 Nasional"
        case global = "🌍 Global"
        var id: String { rawValue }
    }

    enum TimeRange: String, CaseIterable, Identifiable {
        case past30 = "30 Hari Lalu"
        case upcoming = "Mendatang"
        case next90 = "90 Hari"
        case nextYear = "1 Tahun"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Meta.n) {
                // Time range picker
                Picker("Rentang", selection: $timeRange) {
                    ForEach(TimeRange.allCases) { r in Text(r.rawValue).tag(r) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Meta.l)

                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Meta.n) {
                        ForEach(EventFilter.allCases) { filter in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedCategory = filter
                                    loadEvents()
                                }
                            } label: {
                                Text(filter.rawValue)
                                    .font(.metaCaption.weight(.bold))
                                    .foregroundStyle(selectedCategory == filter ? Meta.canvas : Meta.inkMuted)
                                    .padding(.horizontal, Meta.n)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == filter ? categoryColor(filter) : Meta.surface)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Meta.hairline, lineWidth: 0.5))
                            }
                        }
                    }
                    .padding(.horizontal, Meta.l)
                }

                // Events grouped by month
                ForEach(groupedByMonth(), id: \.0) { monthLabel, monthEvents in
                    VStack(alignment: .leading, spacing: Meta.s) {
                        HStack {
                            Text(monthLabel)
                                .font(.metaHeadline)
                                .foregroundStyle(Meta.gold)
                            Spacer()
                            Text("\(monthEvents.count) peristiwa")
                                .font(.metaCaption)
                                .foregroundStyle(Meta.inkMuted)
                        }
                        .padding(.horizontal, Meta.l)

                        ForEach(monthEvents) { event in
                            TimelineEventCard(event: event, appState: appState)
                                .padding(.horizontal, Meta.l)
                        }
                    }
                }

                if events.isEmpty {
                    VStack(spacing: Meta.n) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(Meta.inkMuted)
                        Text("Tidak ada peristiwa dalam rentang ini")
                            .font(.metaBody).foregroundStyle(Meta.inkMuted)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
        .onAppear { loadEvents() }
        .onChange(of: timeRange) { _, _ in loadEvents() }
    }

    private func categoryColor(_ filter: EventFilter) -> Color {
        switch filter {
        case .all: return Meta.jade
        case .astronomical: return Meta.violet
        case .cultural: return Meta.gold
        case .religious: return Meta.jade
        case .sport: return Meta.coral
        case .national: return Meta.coral
        case .global: return Meta.gold
        }
    }

    // MARK: - Data

    private func loadEvents() {
        let cal = Calendar(identifier: .gregorian)
        let todayFD = FixedDay.fromGregorian(
            year: cal.component(.year, from: Date()),
            month: cal.component(.month, from: Date()),
            day: cal.component(.day, from: Date())
        )
        let year = cal.component(.year, from: Date())

        var all: [CalendarEvent] = []

        switch timeRange {
        case .past30:
            all = gatherEvents(year: year) + gatherEvents(year: year - 1)
            let floor = todayFD - 30
            all = all.filter { $0.fixedDay >= floor && $0.fixedDay < todayFD }
        case .upcoming:
            all = gatherEvents(year: year) + gatherEvents(year: year + 1)
            all = all.filter { $0.fixedDay >= todayFD }
            if all.count > 30 { all = Array(all.prefix(30)) }
        case .next90:
            all = gatherEvents(year: year) + gatherEvents(year: year + 1)
            let ceiling = todayFD + 90
            all = all.filter { $0.fixedDay >= todayFD && $0.fixedDay <= ceiling }
        case .nextYear:
            all = gatherEvents(year: year) + gatherEvents(year: year + 1)
            all = all.filter { $0.fixedDay >= todayFD }
        }

        // Category filter
        switch selectedCategory {
        case .all:
            break
        case .astronomical:
            all = all.filter { $0.category == .astronomical }
        case .cultural:
            all = all.filter { $0.category == .cultural }
        case .religious:
            all = all.filter { $0.category == .religious }
        case .sport:
            all = all.filter { $0.category == .sport }
        case .national:
            all = all.filter { $0.category == .national }
        case .global:
            all = all.filter { $0.category == .observance }
        }

        events = all.sorted { $0.fixedDay < $1.fixedDay }
    }

    /// Gather from ALL event sources
    private func gatherEvents(year: Int) -> [CalendarEvent] {
        var all: [CalendarEvent] = []
        all.append(contentsOf: CalendarEvents.generate(forGregorianYear: year))
        all.append(contentsOf: WorldEvents.generate(forGregorianYear: year))
        all.append(contentsOf: AstroEvents.generate(forGregorianYear: year))
        return all
    }

    private func groupedByMonth() -> [(String, [CalendarEvent])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: events) { event -> String in
            let (y, m, _) = FixedDay.toGregorian(event.fixedDay)
            let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: 1)) ?? Date()
            return formatter.string(from: date)
        }

        return grouped.sorted { a, b in
            let aDate = formatter.date(from: a.key) ?? Date.distantPast
            let bDate = formatter.date(from: b.key) ?? Date.distantPast
            return aDate < bDate
        }
    }
}

// MARK: - Timeline Event Card (with cross-calendar expansion)

struct TimelineEventCard: View {
    let event: CalendarEvent
    let appState: AppState
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Accent bar
                Rectangle()
                    .fill(accentColor)
                    .frame(height: 3)

                HStack(spacing: Meta.n) {
                    Text(event.emoji)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.name)
                            .font(.metaHeadline)
                            .foregroundStyle(Meta.ink)
                        Text(dateLine)
                            .font(.metaCaption)
                            .foregroundStyle(event.daysFromToday >= 0 && event.daysFromToday <= 7 ? Meta.coral : Meta.inkMuted)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Meta.inkMuted)
                }
                .padding(Meta.l)

                if expanded {
                    VStack(alignment: .leading, spacing: Meta.s) {
                        Divider().overlay(Meta.hairline)

                        if !event.description.isEmpty {
                            Text(event.description)
                                .font(.system(size: 13))
                                .foregroundStyle(Meta.inkMuted)
                        }

                        // Cross-calendar dates
                        Text("DI KALENDER LAIN")
                            .font(.metaEyebrow)
                            .foregroundStyle(Meta.gold)
                            .kerning(1.35)

                        ForEach(crossCalendarDates(), id: \.0) { system, dateStr in
                            HStack(spacing: 8) {
                                Image(systemName: system.iconName)
                                    .foregroundStyle(Meta.systemAccent(system))
                                    .font(.system(size: 12))
                                    .frame(width: 18)
                                Text(Meta.systemTitle(system))
                                    .font(.system(size: 13))
                                    .foregroundStyle(Meta.inkMuted)
                                Spacer()
                                Text(dateStr)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundStyle(Meta.ink)
                            }
                        }
                    }
                    .padding(Meta.l)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Meta.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Meta.rMD))
            .overlay(RoundedRectangle(cornerRadius: Meta.rMD).stroke(Meta.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var accentColor: Color {
        switch event.category {
        case .astronomical: return Meta.violet
        case .cultural:     return Meta.gold
        case .religious:    return Meta.jade
        case .national:     return Meta.coral
        case .seasonal:     return Meta.jade
        case .observance:   return Meta.gold
        case .sport:        return Meta.coral
        }
    }

    private var dateLine: String {
        let days = event.daysFromToday
        if days == 0 { return "\(event.dateString) · HARI INI" }
        if days > 0 { return "\(event.dateString) · \(days) hari lagi" }
        return "\(event.dateString) · \(-days) hari lalu"
    }

    private func crossCalendarDates() -> [(CalendarSystemID, String)] {
        let (y, m, d) = FixedDay.toGregorian(event.fixedDay)
        var gCal = Calendar(identifier: .gregorian)
        gCal.timeZone = appState.displayTimeZone
        let date = gCal.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()

        let bundle = CalendarEngine.project(
            instant: Instant(date), timeZone: appState.displayTimeZone,
            location: nil, ruleset: appState.ruleset
        )
        return bundle.projections.map { ($0.calendarSystemID, $0.displayString) }
    }
}
