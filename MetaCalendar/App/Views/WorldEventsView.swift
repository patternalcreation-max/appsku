import SwiftUI

// MARK: - World Events Screen v1

struct WorldEventsView: View {
    @Environment(AppState.self) private var appState
    @State private var events: [CalendarEvent] = []
    @State private var selectedCategory: EventFilter = .all

    enum EventFilter: String, CaseIterable, Identifiable {
        case all = "Semua"
        case astronomical = "Astronomi"
        case cultural = "Budaya"
        case sport = "Olahraga"
        case observance = "Global"

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Meta.xl) {
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Meta.n) {
                        ForEach(EventFilter.allCases) { filter in
                            Button {
                                selectedCategory = filter
                                loadEvents()
                            } label: {
                                Text(filter.rawValue)
                                    .font(.metaCaption.weight(.bold))
                                    .foregroundStyle(selectedCategory == filter ? Meta.canvas : Meta.inkMuted)
                                    .padding(.horizontal, Meta.n)
                                    .padding(.vertical, 8)
                                    .background(selectedCategory == filter ? Meta.jade : Meta.surface)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Meta.hairline, lineWidth: 0.5))
                            }
                        }
                    }
                }

                // Events grouped by month
                ForEach(groupedByMonth(), id: \.0) { month, monthEvents in
                    VStack(alignment: .leading, spacing: Meta.s) {
                        // Month header
                        HStack {
                            Text(month)
                                .font(.metaHeadline)
                                .foregroundStyle(Meta.gold)
                            Spacer()
                            Text("\(monthEvents.count) peristiwa")
                                .font(.metaCaption)
                                .foregroundStyle(Meta.inkMuted)
                        }

                        // Event cards
                        ForEach(monthEvents) { event in
                            WorldEventCard(event: event, appState: appState)
                        }
                    }
                }

                if events.isEmpty {
                    VStack(spacing: Meta.n) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Meta.inkMuted)
                        Text("Tidak ada peristiwa ditemukan")
                            .font(.metaBody)
                            .foregroundStyle(Meta.inkMuted)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, Meta.l)
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
        .onAppear { loadEvents() }
    }

    private func loadEvents() {
        let now = Calendar(identifier: .gregorian).component(.year, from: Date())
        var all = WorldEvents.generate(forGregorianYear: now)
        let next = WorldEvents.generate(forGregorianYear: now + 1)
        all.append(contentsOf: next)

        // Merge with cultural/religious events too
        let cultural = CalendarEvents.upcoming(days: 365, hijriProfile: appState.ruleset.hijriProfile)
        all.append(contentsOf: cultural)

        // Filter
        switch selectedCategory {
        case .all:
            events = all.sorted { $0.fixedDay < $1.fixedDay }
        case .astronomical:
            events = all.filter { $0.category == .astronomical }.sorted { $0.fixedDay < $1.fixedDay }
        case .cultural:
            events = all.filter { $0.category == .cultural || $0.category == .religious }.sorted { $0.fixedDay < $1.fixedDay }
        case .sport:
            events = all.filter { $0.category == .sport }.sorted { $0.fixedDay < $1.fixedDay }
        case .observance:
            events = all.filter { $0.category == .observance || $0.category == .national }.sorted { $0.fixedDay < $1.fixedDay }
        }

        // Only future events
        let cal = Calendar(identifier: .gregorian)
        let todayFD = FixedDay.fromGregorian(
            year: cal.component(.year, from: Date()),
            month: cal.component(.month, from: Date()),
            day: cal.component(.day, from: Date())
        )
        events = events.filter { $0.fixedDay >= todayFD }
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

// MARK: - World Event Card

struct WorldEventCard: View {
    let event: CalendarEvent
    let appState: AppState
    @State private var showCalendars = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { showCalendars.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(categoryColor)
                    .frame(height: 3)

                VStack(alignment: .leading, spacing: Meta.s) {
                    HStack(spacing: Meta.n) {
                        Text(event.emoji)
                            .font(.system(size: 28))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.name)
                                .font(.metaHeadline)
                                .foregroundStyle(Meta.ink)
                            Text(event.dateString + " · \(event.daysFromToday == 0 ? "HARI INI" : "\(event.daysFromToday) hari lagi")")
                                .font(.metaCaption)
                                .foregroundStyle(event.daysFromToday <= 7 ? Meta.coral : Meta.inkMuted)
                        }

                        Spacer()

                        Text(event.category.displayName.uppercased())
                            .font(.metaEyebrow)
                            .foregroundStyle(categoryColor)
                    }

                    if !event.description.isEmpty {
                        Text(event.description)
                            .font(.system(size: 13))
                            .foregroundStyle(Meta.inkMuted)
                            .lineLimit(2)
                    }

                    // Cross-calendar alignment (expandable)
                    if showCalendars {
                        Divider().overlay(Meta.hairline).padding(.vertical, Meta.s)

                        Text("HARI INI DI KALENDER LAIN")
                            .font(.metaEyebrow)
                            .foregroundStyle(Meta.gold)
                            .kerning(1.35)

                        ForEach(crossCalendarDates(), id: \.0) { system, dateStr in
                            HStack {
                                Image(systemName: system.iconName)
                                    .foregroundStyle(Meta.systemAccent(system))
                                    .font(.system(size: 12))
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
                }
                .padding(Meta.l)
            }
            .background(Meta.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: Meta.rMD))
            .overlay(RoundedRectangle(cornerRadius: Meta.rMD).stroke(Meta.hairline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
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

    // Compute this event's date in all 5 calendars
    private func crossCalendarDates() -> [(CalendarSystemID, String)] {
        var gCal = Calendar(identifier: .gregorian)
        gCal.timeZone = appState.displayTimeZone
        let (y, m, d) = FixedDay.toGregorian(event.fixedDay)
        let date = gCal.date(from: DateComponents(year: y, month: m, day: d, hour: 12)) ?? Date()

        let bundle = CalendarEngine.project(
            instant: Instant(date), timeZone: appState.displayTimeZone,
            location: nil, ruleset: appState.ruleset
        )

        return bundle.projections.map { ($0.calendarSystemID, $0.displayString) }
    }
}
