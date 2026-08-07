import SwiftUI

// MARK: - Calendar Grid v3 (Meta design system)

struct CalendarGridView: View {
    @Environment(AppState.self) private var appState
    @State private var gridData: [DayCellData] = []
    @State private var bridgeData: [DayCellData] = []
    @State private var selectedCell: DayCellData? = nil
    @State private var cellEvents: [Int64: [CalendarEvent]] = [:]

    private let weekdaysFull = ["Min", "Sen", "Sel", "Rab", "Kam", "Jum", "Sab"]

    var body: some View {
        ScrollView {
            VStack(spacing: Meta.n) {
                monthHeaderBar
                weekdayLabels
                calendarGrid
                bridgeSection
                yearInfoBar
            }
            .padding(.horizontal, Meta.l)
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
        .onAppear { loadGrid() }
        .onChange(of: appState.selectedMetaSolarMonth) { _, _ in loadGrid() }
        .onChange(of: appState.selectedMetaSolarYear) { _, _ in loadGrid() }
        .sheet(item: $selectedCell) { cell in
            DayDetailSheetV2(cell: cell).presentationDetents([.large])
        }
    }

    private var monthHeaderBar: some View {
        HStack {
            Button { prevMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Meta.inkMuted)
                    .frame(width: 36, height: 36)
                    .background(Meta.surface)
                    .clipShape(Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(monthName)
                    .font(.system(size: 22, design: .rounded).weight(.bold))
                    .foregroundStyle(Meta.coral)
                Text("Bulan \(appState.selectedMetaSolarMonth) / 13 · \(appState.selectedMetaSolarYear)")
                    .font(.metaCaption).foregroundStyle(Meta.inkMuted)
            }
            Spacer()
            Button { nextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Meta.inkMuted)
                    .frame(width: 36, height: 36)
                    .background(Meta.surface)
                    .clipShape(Circle())
            }
        }
        .padding(.top, Meta.n)
    }

    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(weekdaysFull, id: \.self) { day in
                Text(day)
                    .font(.metaEyebrow)
                    .foregroundStyle(Meta.inkMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
            ForEach(gridData) { cell in
                DayCellV3(cell: cell, isToday: isToday(cell), hasEvent: cellEvents[cell.fixedDay] != nil)
                    .onTapGesture { selectedCell = cell }
            }
        }
    }

    @ViewBuilder
    private var bridgeSection: some View {
        if !bridgeData.isEmpty {
            VStack(alignment: .leading, spacing: Meta.s) {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(Meta.gold)
                    Text("Hari Jembatan")
                        .font(.system(size: 13, design: .rounded).weight(.semibold))
                        .foregroundStyle(Meta.ink)
                }
                HStack(spacing: Meta.n) {
                    ForEach(bridgeData) { cell in
                        BridgeDayPill(cell: cell).onTapGesture { selectedCell = cell }
                    }
                }
            }
            .padding(Meta.n)
            .background(Meta.surface)
            .clipShape(RoundedRectangle(cornerRadius: Meta.rMD))
            .padding(.top, Meta.s)
        }
    }

    private var yearInfoBar: some View {
        HStack(spacing: Meta.xl) {
            yearStat("Hari", "\(MetaSolarEngine.daysInYear(appState.selectedMetaSolarYear))")
            Divider().frame(height: 32)
            yearStat("Kabisat", MetaSolarEngine.isLeapYear(appState.selectedMetaSolarYear) ? "Ya" : "Tidak")
            Divider().frame(height: 32)
            yearStat("Struktur", "13×28")
        }
        .padding(Meta.n)
        .background(Meta.surface)
        .clipShape(RoundedRectangle(cornerRadius: Meta.rMD))
    }

    private func yearStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 16, design: .rounded).weight(.bold)).foregroundStyle(Meta.ink)
            Text(label).font(.system(size: 10)).foregroundStyle(Meta.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var monthName: String {
        let names = MetaSolarEngine.monthNames
        let idx = appState.selectedMetaSolarMonth - 1
        return idx < names.count ? names[idx] : "B\(appState.selectedMetaSolarMonth)"
    }

    // MARK: - Data
    private func loadGrid() {
        let year = appState.selectedMetaSolarYear
        let month = appState.selectedMetaSolarMonth
        var cells: [DayCellData] = []
        for day in 1...28 {
            let coord = MetaSolarDayCoordinate.monthDay(year: year, month: month, day: day)
            let fd = MetaSolarEngine.fixedDay(for: coord) ?? 0
            cells.append(DayCellData(
                coordinate: coord, dayNumber: day, weekday: FixedDay.weekday(fd),
                gregorianDay: FixedDay.toGregorian(fd).day,
                gregorianMonth: FixedDay.toGregorian(fd).month,
                gregorianYear: FixedDay.toGregorian(fd).year,
                pasaranName: String(JavaneseAdapter.pasaranNames[JavaneseAdapter.pasaranIndex(fixedDay: fd)].prefix(4)),
                fixedDay: fd
            ))
        }
        gridData = cells
        let bridges = MetaSolarEngine.bridgeDays(year: year)
        bridgeData = bridges.compactMap { coord in
            guard let fd = MetaSolarEngine.fixedDay(for: coord) else { return nil }
            return DayCellData(
                coordinate: coord, dayNumber: 0, weekday: FixedDay.weekday(fd),
                gregorianDay: FixedDay.toGregorian(fd).day,
                gregorianMonth: FixedDay.toGregorian(fd).month,
                gregorianYear: FixedDay.toGregorian(fd).year,
                pasaranName: "", fixedDay: fd
            )
        }
        cellEvents = CalendarEvents.eventsForMonth(year: year, month: month, calendar: .metaSolar)
    }

    private func prevMonth() {
        if appState.selectedMetaSolarMonth > 1 { appState.selectedMetaSolarMonth -= 1 }
        else { appState.selectedMetaSolarMonth = 13; appState.selectedMetaSolarYear -= 1 }
    }
    private func nextMonth() {
        if appState.selectedMetaSolarMonth < 13 { appState.selectedMetaSolarMonth += 1 }
        else { appState.selectedMetaSolarMonth = 1; appState.selectedMetaSolarYear += 1 }
    }
    private func isToday(_ cell: DayCellData) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        let t = cal.dateComponents([.year, .month, .day], from: Date())
        return t.year == cell.gregorianYear && t.month == cell.gregorianMonth && t.day == cell.gregorianDay
    }
}

// MARK: - Cell Models & Views

struct DayCellData: Identifiable {
    let id = UUID()
    let coordinate: MetaSolarDayCoordinate
    let dayNumber: Int
    let weekday: Int
    let gregorianDay: Int
    let gregorianMonth: Int
    let gregorianYear: Int
    let pasaranName: String
    let fixedDay: Int64
}

struct DayCellV3: View {
    let cell: DayCellData
    let isToday: Bool
    let hasEvent: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("\(cell.dayNumber)")
                .font(.system(size: 17, design: .rounded).weight(.bold))
                .foregroundStyle(isToday ? Meta.jade : Meta.ink)
            Text("\(cell.gregorianDay)")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(Meta.inkMuted)
            Text(cell.pasaranName)
                .font(.system(size: 7))
                .foregroundStyle(Meta.violet.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(isToday ? Meta.jade.opacity(0.10) : Meta.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .topTrailing) {
            if hasEvent {
                Circle().fill(Meta.coral).frame(width: 5, height: 5).padding(3)
            }
        }
    }
}

struct BridgeDayPill: View {
    let cell: DayCellData
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "sparkles").font(.system(size: 14)).foregroundStyle(Meta.gold)
            Text(cell.coordinate.isBridge ? "Jembatan" : "★")
                .font(.system(size: 9, design: .rounded).weight(.semibold)).foregroundStyle(Meta.gold)
            Text("\(cell.gregorianDay)").font(.system(size: 9)).foregroundStyle(Meta.inkMuted)
        }
        .frame(width: 72, height: 60)
        .background(Meta.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Meta.rSM))
    }
}

// MARK: - Day Detail Sheet v3

struct DayDetailSheetV2: View {
    let cell: DayCellData
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Meta.xl) {
                    MetaCard {
                        VStack(alignment: .leading, spacing: Meta.s) {
                            Text(MetaSolarEngine.displayString(for: cell.coordinate))
                                .font(.metaTitle)
                                .foregroundStyle(Meta.coral)
                            Text(MetaSolarEngine.subtitle(for: cell.coordinate))
                                .font(.metaBody).foregroundStyle(Meta.inkMuted)
                        }
                    }

                    MetaSection(title: "Semua Kalender")
                    ForEach(getProjections()) { proj in
                        MetaProjectionCard(projection: proj)
                    }

                    MetaSection(title: "Siklus Jawa")
                    MetaCard {
                        let sapta = JavaneseAdapter.saptawaraIndex(fixedDay: cell.fixedDay)
                        let pasaran = JavaneseAdapter.pasaranIndex(fixedDay: cell.fixedDay)
                        let weton = JavaneseAdapter.wetonDay(fixedDay: cell.fixedDay)
                        let (wuku, _) = JavaneseAdapter.wukuIndex(fixedDay: cell.fixedDay)
                        let neptu = JavaneseAdapter.totalNeptu(fixedDay: cell.fixedDay)
                        VStack(spacing: Meta.s) {
                            MetaInfoRow(label: "Saptawara", value: JavaneseAdapter.saptawaraNames[sapta])
                            MetaInfoRow(label: "Pasaran", value: JavaneseAdapter.pasaranNames[pasaran])
                            MetaInfoRow(label: "Weton", value: "\(JavaneseAdapter.wetonName(saptawara: sapta, pasaran: pasaran)) (\(weton + 1)/35)")
                            MetaInfoRow(label: "Wuku", value: JavaneseAdapter.wukuNames[wuku])
                            MetaInfoRow(label: "Neptu", value: "\(neptu)")
                        }
                    }

                    let dayEvents = CalendarEvents.eventsOnFixedDay(cell.fixedDay)
                    if !dayEvents.isEmpty {
                        MetaSection(title: "Peristiwa di Hari Ini")
                        ForEach(dayEvents) { ev in
                            HStack {
                                Text(ev.emoji)
                                Text(ev.name).font(.metaBody).foregroundStyle(Meta.ink)
                                Spacer()
                                Text(ev.category.displayName)
                                    .font(.metaCaption).foregroundStyle(Meta.inkMuted)
                            }
                            .padding(Meta.n)
                            .background(Meta.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Meta.rSM))
                        }
                    }
                }
                .padding(.horizontal, Meta.l)
            }
            .navigationTitle(MetaSolarEngine.displayString(for: cell.coordinate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Selesai") { dismiss() } }
            }
            .background(MetaBackground())
        }
    }

    private func getProjections() -> [CalendarProjection] {
        var gCal = Calendar(identifier: .gregorian)
        gCal.timeZone = appState.displayTimeZone
        let dc = DateComponents(year: cell.gregorianYear, month: cell.gregorianMonth, day: cell.gregorianDay, hour: 12)
        let date = gCal.date(from: dc) ?? Date()
        return CalendarEngine.project(
            instant: Instant(date), timeZone: appState.displayTimeZone,
            location: nil, ruleset: appState.ruleset
        ).projections
    }
}

extension MetaSolarDayCoordinate {
    var isBridge: Bool {
        switch self { case .yearBridge, .leapBridge: return true; case .monthDay: return false }
    }
}
