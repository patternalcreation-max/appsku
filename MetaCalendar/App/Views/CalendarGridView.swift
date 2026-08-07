import SwiftUI

// MARK: - Calendar Grid v2

struct CalendarGridView: View {
    @Environment(AppState.self) private var appState
    @State private var gridData: [DayCellData] = []
    @State private var bridgeData: [DayCellData] = []
    @State private var selectedCell: DayCellData? = nil
    @State private var cellEvents: [Int64: [CalendarEvent]] = [:]
    
    private let weekdays = ["S", "S", "R", "K", "J", "S", "S"]
    private let weekdaysFull = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: DS.space16) {
                monthHeaderBar
                weekdayLabels
                calendarGrid
                bridgeSection
                yearInfoBar
            }
            .padding(.horizontal, DS.space16)
            .padding(.bottom, 40)
        }
        .background(DS.bgBase.ignoresSafeArea())
        .onAppear { loadGrid() }
        .onChange(of: appState.selectedMetaSolarMonth) { _, _ in loadGrid() }
        .onChange(of: appState.selectedMetaSolarYear) { _, _ in loadGrid() }
        .sheet(item: $selectedCell) { cell in
            DayDetailSheetV2(cell: cell)
                .presentationDetents([.large])
        }
    }
    
    // Month nav bar
    private var monthHeaderBar: some View {
        HStack {
            Button { prevMonth() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(DS.bgCard)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(monthName)
                    .font(.system(size: 22, design: .rounded).weight(.bold))
                    .foregroundStyle(DS.systemColor(.metaSolar))
                Text("Month \(appState.selectedMetaSolarMonth) / 13 · \(appState.selectedMetaSolarYear)")
                    .font(DS.fontCaption)
                    .foregroundStyle(DS.textSecondary)
            }
            
            Spacer()
            
            Button { nextMonth() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(DS.bgCard)
                    .clipShape(Circle())
            }
        }
        .padding(.top, DS.space8)
    }
    
    // Weekday labels
    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(weekdaysFull, id: \.self) { day in
                Text(day)
                    .font(DS.fontMicro)
                    .foregroundStyle(DS.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // Grid
    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 3) {
            ForEach(gridData) { cell in
                DayCellV2(cell: cell, isToday: isToday(cell), hasEvent: cellEvents[cell.fixedDay] != nil)
                    .onTapGesture { selectedCell = cell }
            }
        }
    }
    
    // Bridge section
    @ViewBuilder
    private var bridgeSection: some View {
        if !bridgeData.isEmpty {
            VStack(alignment: .leading, spacing: DS.space8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DS.warning)
                    Text("Intercalary Bridge Days")
                        .font(.system(size: 13, design: .rounded).weight(.semibold))
                        .foregroundStyle(DS.textPrimary)
                }
                
                HStack(spacing: DS.space12) {
                    ForEach(bridgeData) { cell in
                        BridgeDayPill(cell: cell)
                            .onTapGesture { selectedCell = cell }
                    }
                }
            }
            .padding(DS.space12)
            .background(DS.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.radiusMD))
            .padding(.top, DS.space4)
        }
    }
    
    // Year info
    private var yearInfoBar: some View {
        HStack(spacing: DS.space16) {
            YearStat(label: "Days", value: "\(MetaSolarEngine.daysInYear(appState.selectedMetaSolarYear))")
            Divider().frame(height: 32)
            YearStat(label: "Leap", value: MetaSolarEngine.isLeapYear(appState.selectedMetaSolarYear) ? "Yes" : "No")
            Divider().frame(height: 32)
            YearStat(label: "Structure", value: "13×28")
        }
        .padding(DS.space12)
        .background(DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusMD))
    }
    
    private var monthName: String {
        let names = MetaSolarEngine.monthNames
        let idx = appState.selectedMetaSolarMonth - 1
        return idx < names.count ? names[idx] : "M\(appState.selectedMetaSolarMonth)"
    }
    
    // MARK: - Data
    private func loadGrid() {
        let year = appState.selectedMetaSolarYear
        let month = appState.selectedMetaSolarMonth
        
        var cells: [DayCellData] = []
        for day in 1...28 {
            let coord = MetaSolarDayCoordinate.monthDay(year: year, month: month, day: day)
            let fd = MetaSolarEngine.fixedDay(for: coord) ?? 0
            let weekday = FixedDay.weekday(fd)
            let (gy, gm, gd) = FixedDay.toGregorian(fd)
            let pasaran = JavaneseAdapter.pasaranIndex(fixedDay: fd)
            
            cells.append(DayCellData(
                coordinate: coord, dayNumber: day, weekday: weekday,
                gregorianDay: gd, gregorianMonth: gm, gregorianYear: gy,
                pasaranName: String(JavaneseAdapter.pasaranNames[pasaran].prefix(3)),
                fixedDay: fd
            ))
        }
        gridData = cells
        
        let bridges = MetaSolarEngine.bridgeDays(year: year)
        bridgeData = bridges.compactMap { coord in
            guard let fd = MetaSolarEngine.fixedDay(for: coord) else { return nil }
            let (gy, gm, gd) = FixedDay.toGregorian(fd)
            return DayCellData(
                coordinate: coord, dayNumber: 0, weekday: FixedDay.weekday(fd),
                gregorianDay: gd, gregorianMonth: gm, gregorianYear: gy,
                pasaranName: String(JavaneseAdapter.pasaranNames[JavaneseAdapter.pasaranIndex(fixedDay: fd)].prefix(3)),
                fixedDay: fd
            )
        }
        
        // Load events for this month
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
        let today = cal.dateComponents([.year, .month, .day], from: Date())
        return today.year == cell.gregorianYear && today.month == cell.gregorianMonth && today.day == cell.gregorianDay
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

struct DayCellV2: View {
    let cell: DayCellData
    let isToday: Bool
    let hasEvent: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(cell.dayNumber)")
                .font(.system(size: 17, design: .rounded).weight(.bold))
                .foregroundStyle(isToday ? DS.primary : DS.textPrimary)
            
            Text("\(cell.gregorianDay)")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(DS.textTertiary)
            
            Text(cell.pasaranName)
                .font(.system(size: 7))
                .foregroundStyle(DS.systemColor(.javanese).opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(isToday ? DS.primary.opacity(0.10) : DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .topTrailing) {
            if hasEvent {
                Circle()
                    .fill(DS.accent)
                    .frame(width: 5, height: 5)
                    .padding(3)
            }
        }
    }
}

struct BridgeDayPill: View {
    let cell: DayCellData
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(DS.warning)
            Text(cell.coordinate.isBridge ? "Bridge" : "★")
                .font(.system(size: 9, design: .rounded).weight(.semibold))
                .foregroundStyle(DS.warning)
            Text("\(cell.gregorianDay)")
                .font(.system(size: 9))
                .foregroundStyle(DS.textTertiary)
        }
        .frame(width: 72, height: 60)
        .background(DS.warning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusSM))
    }
}

struct YearStat: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, design: .rounded).weight(.bold))
                .foregroundStyle(DS.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DS.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Detail Sheet v2

struct DayDetailSheetV2: View {
    let cell: DayCellData
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.space16) {
                    // MetaSolar title
                    GlassCard {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(MetaSolarEngine.displayString(for: cell.coordinate))
                                .font(DS.fontDisplay)
                                .foregroundStyle(DS.systemColor(.metaSolar))
                            Text(MetaSolarEngine.subtitle(for: cell.coordinate))
                                .font(DS.fontBody)
                                .foregroundStyle(DS.textSecondary)
                        }
                    }
                    
                    // All calendars
                    SectionTitle(title: "All Calendars", icon: "globe")
                    ForEach(getProjections()) { proj in
                        CalendarCardV2(projection: proj, rank: -1)
                    }
                    
                    // Javanese deep
                    SectionTitle(title: "Javanese Cycles", icon: "circle.grid.cross")
                    GlassCard {
                        let sapta = JavaneseAdapter.saptawaraIndex(fixedDay: cell.fixedDay)
                        let pasaran = JavaneseAdapter.pasaranIndex(fixedDay: cell.fixedDay)
                        let weton = JavaneseAdapter.wetonDay(fixedDay: cell.fixedDay)
                        let (wuku, _) = JavaneseAdapter.wukuIndex(fixedDay: cell.fixedDay)
                        let neptu = JavaneseAdapter.totalNeptu(fixedDay: cell.fixedDay)
                        
                        VStack(spacing: DS.space8) {
                            InfoRowV2(label: "Saptawara", value: JavaneseAdapter.saptawaraNames[sapta])
                            InfoRowV2(label: "Pasaran", value: JavaneseAdapter.pasaranNames[pasaran])
                            InfoRowV2(label: "Weton", value: "\(JavaneseAdapter.wetonName(saptawara: sapta, pasaran: pasaran)) (\(weton + 1)/35)")
                            InfoRowV2(label: "Wuku", value: JavaneseAdapter.wukuNames[wuku])
                            InfoRowV2(label: "Neptu", value: "\(neptu)")
                            InfoRowV2(label: "Day Detail", value: "S:\(JavaneseAdapter.saptawaraNeptu[sapta]) + P:\(JavaneseAdapter.pasaranNeptu[pasaran])")
                        }
                    }
                    
                    // Events on this day
                    let dayEvents = CalendarEvents.eventsOnFixedDay(cell.fixedDay)
                    if !dayEvents.isEmpty {
                        SectionTitle(title: "Events on This Day", icon: "calendar.badge.exclamationmark")
                        ForEach(dayEvents) { ev in
                            HStack {
                                Text(ev.emoji)
                                Text(ev.name)
                                    .font(DS.fontBody)
                                    .foregroundStyle(DS.textPrimary)
                                Spacer()
                                Text(ev.category.rawValue.capitalized)
                                    .font(DS.fontMicro)
                                    .foregroundStyle(DS.textTertiary)
                            }
                            .padding(DS.space12)
                            .background(DS.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: DS.radiusSM))
                        }
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle(MetaSolarEngine.displayString(for: cell.coordinate))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .background(DS.bgBase.ignoresSafeArea())
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
