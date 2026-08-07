import SwiftUI

// MARK: - MetaSolar Calendar Grid Screen

struct CalendarGridView: View {
    @Environment(AppState.self) private var appState
    @State private var gridData: [MetaSolarDayCell] = []
    @State private var bridgeData: [MetaSolarDayCell] = []
    @State private var selectedCell: MetaSolarDayCell? = nil
    
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month selector
                monthSelector
                
                // Month name header
                monthHeader
                
                // Weekday labels
                HStack(spacing: 0) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 11, design: .rounded).weight(.medium))
                            .foregroundStyle(AppTheme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar grid (28 days = exactly 4 rows × 7 columns)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    ForEach(gridData) { cell in
                        DayCellView(cell: cell, isToday: isToday(cell))
                            .onTapGesture { selectedCell = cell }
                    }
                }
                
                // Bridge days
                if !bridgeData.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AppTheme.experimentalBadge)
                            Text("Intercalary Bridge Days")
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        
                        HStack(spacing: 12) {
                            ForEach(bridgeData) { cell in
                                BridgeDayView(cell: cell)
                                    .onTapGesture { selectedCell = cell }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Year info
                yearInfoBar
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(AppTheme.bgPrimary.ignoresSafeArea())
        .onAppear { loadGrid() }
        .onChange(of: appState.selectedMetaSolarMonth) { _, _ in loadGrid() }
        .onChange(of: appState.selectedMetaSolarYear) { _, _ in loadGrid() }
        .sheet(item: $selectedCell) { cell in
            DayDetailSheet(cell: cell)
                .presentationDetents([.medium])
        }
    }
    
    // Month selector
    private var monthSelector: some View {
        HStack {
            Button {
                prevMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.bgCard)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Button {
                nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.bgCard)
                    .clipShape(Circle())
            }
        }
    }
    
    // Month header
    private var monthHeader: some View {
        VStack(spacing: 4) {
            Text(monthName)
                .font(.system(size: 28, design: .rounded).weight(.bold))
                .foregroundStyle(AppTheme.systemColor(.metaSolar))
            Text("Month \(appState.selectedMetaSolarMonth) of 13 · \(appState.selectedMetaSolarYear)")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // Year info bar
    private var yearInfoBar: some View {
        HStack(spacing: 16) {
            VStack {
                Text("\(MetaSolarEngine.daysInYear(appState.selectedMetaSolarYear))")
                    .font(.system(size: 18, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Days")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            Divider().frame(height: 30)
            
            VStack {
                Text(MetaSolarEngine.isLeapYear(appState.selectedMetaSolarYear) ? "Yes" : "No")
                    .font(.system(size: 18, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Leap Year")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
            
            Divider().frame(height: 30)
            
            VStack {
                Text("13 × 28")
                    .font(.system(size: 18, design: .rounded).weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Structure")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .padding(14)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var monthName: String {
        let names = MetaSolarEngine.monthNames
        let idx = appState.selectedMetaSolarMonth - 1
        return idx < names.count ? names[idx] : "Month \(appState.selectedMetaSolarMonth)"
    }
    
    // MARK: - Data Loading
    
    private func loadGrid() {
        let year = appState.selectedMetaSolarYear
        let month = appState.selectedMetaSolarMonth
        
        var cells: [MetaSolarDayCell] = []
        for day in 1...28 {
            let coord = MetaSolarDayCoordinate.monthDay(year: year, month: month, day: day)
            let fixedDay = MetaSolarEngine.fixedDay(for: coord) ?? 0
            let weekday = FixedDay.weekday(fixedDay)
            
            // Get Gregorian date for this day
            let (gy, gm, gd) = FixedDay.toGregorian(fixedDay)
            
            // Get Javanese info
            let pasaran = JavaneseAdapter.pasaranIndex(fixedDay: fixedDay)
            
            cells.append(MetaSolarDayCell(
                coordinate: coord,
                dayNumber: day,
                weekday: weekday,
                gregorianDate: "\(gd) \(gregorianMonthName(gm))",
                pasaranName: JavaneseAdapter.pasaranNames[pasaran].split(separator: " ").first.map(String.init) ?? "",
                fixedDay: fixedDay,
                gregorianYear: gy
            ))
        }
        gridData = cells
        
        // Bridge days
        let bridges = MetaSolarEngine.bridgeDays(year: year)
        bridgeData = bridges.compactMap { coord in
            guard let fd = MetaSolarEngine.fixedDay(for: coord) else { return nil }
            let (gy, gm, gd) = FixedDay.toGregorian(fd)
            return MetaSolarDayCell(
                coordinate: coord,
                dayNumber: 0,
                weekday: FixedDay.weekday(fd),
                gregorianDate: "\(gd) \(gregorianMonthName(gm))",
                pasaranName: JavaneseAdapter.pasaranNames[JavaneseAdapter.pasaranIndex(fixedDay: fd)].split(separator: " ").first.map(String.init) ?? "",
                fixedDay: fd,
                gregorianYear: gy
            )
        }
    }
    
    private func prevMonth() {
        if appState.selectedMetaSolarMonth > 1 {
            appState.selectedMetaSolarMonth -= 1
        } else {
            appState.selectedMetaSolarMonth = 13
            appState.selectedMetaSolarYear -= 1
        }
    }
    
    private func nextMonth() {
        if appState.selectedMetaSolarMonth < 13 {
            appState.selectedMetaSolarMonth += 1
        } else {
            appState.selectedMetaSolarMonth = 1
            appState.selectedMetaSolarYear += 1
        }
    }
    
    private func isToday(_ cell: MetaSolarDayCell) -> Bool {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.dateComponents([.year, .month, .day], from: Date())
        let cellDate = FixedDay.toGregorian(cell.fixedDay)
        return today.year == cellDate.year && today.month == cellDate.month && today.day == cellDate.day
    }
    
    private func gregorianMonthName(_ month: Int) -> String {
        let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return month > 0 && month <= 12 ? names[month - 1] : ""
    }
}

// MARK: - Day Cell Model

struct MetaSolarDayCell: Identifiable {
    let id = UUID()
    let coordinate: MetaSolarDayCoordinate
    let dayNumber: Int
    let weekday: Int
    let gregorianDate: String
    let pasaranName: String
    let fixedDay: Int64
    let gregorianYear: Int
}

// MARK: - Cell Views

struct DayCellView: View {
    let cell: MetaSolarDayCell
    let isToday: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(cell.dayNumber)")
                .font(.system(size: 18, design: .rounded).weight(.bold))
                .foregroundStyle(isToday ? AppTheme.accent : AppTheme.textPrimary)
            
            Text(cell.gregorianDate)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
                .lineLimit(1)
            
            Text(cell.pasaranName)
                .font(.system(size: 8))
                .foregroundStyle(AppTheme.systemColor(.javanese).opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(isToday ? AppTheme.accent.opacity(0.12) : AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? AppTheme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}

struct BridgeDayView: View {
    let cell: MetaSolarDayCell
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.experimentalBadge)
            Text(cell.coordinate.isBridge ? "Bridge" : "★")
                .font(.system(size: 10, design: .rounded).weight(.semibold))
                .foregroundStyle(AppTheme.experimentalBadge)
            Text(cell.gregorianDate)
                .font(.system(size: 9))
                .foregroundStyle(AppTheme.textTertiary)
        }
        .frame(width: 80, height: 64)
        .background(AppTheme.experimentalBadge.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Day Detail Sheet

struct DayDetailSheet: View {
    let cell: MetaSolarDayCell
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MetaSolar
                    Group {
                        SectionHeader(title: MetaSolarEngine.displayString(for: cell.coordinate))
                        Text(MetaSolarEngine.subtitle(for: cell.coordinate))
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Divider()
                    
                    // Full projection for this day
                    SectionHeader(title: "All Calendars", subtitle: "\(cell.gregorianDate) \(cell.gregorianYear)")
                    
                    let projections = getProjections()
                    ForEach(projections) { proj in
                        CalendarCard(projection: proj)
                    }
                    
                    // Javanese cycle details
                    SectionHeader(title: "Javanese Cycles")
                    let sapta = JavaneseAdapter.saptawaraIndex(fixedDay: cell.fixedDay)
                    let pasaran = JavaneseAdapter.pasaranIndex(fixedDay: cell.fixedDay)
                    let weton = JavaneseAdapter.wetonDay(fixedDay: cell.fixedDay)
                    let (wuku, _) = JavaneseAdapter.wukuIndex(fixedDay: cell.fixedDay)
                    let neptu = JavaneseAdapter.totalNeptu(fixedDay: cell.fixedDay)
                    
                    InfoRow(label: "Saptawara", value: JavaneseAdapter.saptawaraNames[sapta])
                    InfoRow(label: "Pasaran", value: JavaneseAdapter.pasaranNames[pasaran])
                    InfoRow(label: "Weton", value: "\(JavaneseAdapter.wetonName(saptawara: sapta, pasaran: pasaran)) (\(weton + 1)/35)")
                    InfoRow(label: "Wuku", value: JavaneseAdapter.wukuNames[wuku])
                    InfoRow(label: "Neptu", value: "\(neptu) (S:\(JavaneseAdapter.saptawaraNeptu[sapta]) + P:\(JavaneseAdapter.pasaranNeptu[pasaran]))")
                }
                .padding()
            }
            .navigationTitle("Day Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func getProjections() -> [CalendarProjection] {
        var gCal = Calendar(identifier: .gregorian)
        gCal.timeZone = appState.displayTimeZone
        let dateComponents = DateComponents(year: cell.gregorianYear, month: Int(FixedDay.toGregorian(cell.fixedDay).month), day: Int(FixedDay.toGregorian(cell.fixedDay).day), hour: 12)
        let date = gCal.date(from: dateComponents) ?? Date()
        
        let bundle = CalendarEngine.project(
            instant: Instant(date),
            timeZone: appState.displayTimeZone,
            location: nil,
            ruleset: appState.ruleset
        )
        return bundle.projections
    }
}

extension MetaSolarDayCoordinate {
    var isBridge: Bool {
        switch self {
        case .yearBridge, .leapBridge: return true
        case .monthDay: return false
        }
    }
}
