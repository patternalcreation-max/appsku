import SwiftUI

// MARK: - Explore / Convert Screen

struct ExploreView: View {
    @Environment(AppState.self) private var appState
    @State private var sourceSystem: CalendarSystemID = .gregorian
    @State private var inputYear: Int = 2026
    @State private var inputMonth: Int = 8
    @State private var inputDay: Int = 7
    @State private var convertedProjections: [CalendarProjection] = []
    @State private var hasConverted: Bool = false
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 3)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Source selector
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Convert", subtitle: "Resolve a calendar coordinate")
                    
                    // Calendar system picker
                    Picker("Source", selection: $sourceSystem) {
                        ForEach(CalendarSystemID.allCases) { sys in
                            Text(sys.displayName).tag(sys)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Date input
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Year")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                            TextField("Year", value: $inputYear, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Month")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                            TextField("Month", value: $inputMonth, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Day")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textTertiary)
                            TextField("Day", value: $inputDay, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                        }
                    }
                    
                    Button {
                        convert()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Convert to All Calendars")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.bgPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
                .background(AppTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                
                // Results
                if hasConverted {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Results", subtitle: "\(sourceSystem.displayName) → All")
                        
                        ForEach(convertedProjections) { proj in
                            CalendarCard(projection: proj)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(AppTheme.bgPrimary.ignoresSafeArea())
    }
    
    private func convert() {
        convertedProjections = CalendarEngine.resolve(
            sourceSystem: sourceSystem,
            year: inputYear, month: inputMonth, day: inputDay,
            timeZone: appState.displayTimeZone,
            ruleset: appState.ruleset
        )
        hasConverted = true
    }
}

// MARK: - Quick Reference: Cycle Tables

struct ExploreCyclesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Weton cycle
                cycleCard(
                    title: "Weton Cycle (35 days)",
                    icon: "circle.grid.cross.fill",
                    color: AppTheme.systemColor(.javanese),
                    entries: wetonEntries()
                )
                
                // Pasaran
                cycleCard(
                    title: "Pasaran (5 days)",
                    icon: "pentagon.fill",
                    color: .purple,
                    entries: pasaranEntries()
                )
                
                // Saptawara
                cycleCard(
                    title: "Saptawara (7 days)",
                    icon: "7.circle.fill",
                    color: .blue,
                    entries: saptawaraEntries()
                )
                
                // Wuku
                cycleCard(
                    title: "Wuku Cycle (210 days)",
                    icon: "square.grid.3x3.fill",
                    color: .indigo,
                    entries: wukuEntries()
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(AppTheme.bgPrimary.ignoresSafeArea())
    }
    
    private func cycleCard(title: String, icon: String, color: Color, entries: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            ForEach(entries, id: \.0) { name, value in
                HStack {
                    Text(name)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Text(value)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func pasaranEntries() -> [(String, String)] {
        JavaneseAdapter.pasaranNames.enumerated().map { i, name in
            (name, "Neptu: \(JavaneseAdapter.pasaranNeptu[i])")
        }
    }
    
    private func saptawaraEntries() -> [(String, String)] {
        JavaneseAdapter.saptawaraNames.enumerated().map { i, name in
            (name, "Neptu: \(JavaneseAdapter.saptawaraNeptu[i])")
        }
    }
    
    private func wetonEntries() -> [(String, String)] {
        (0..<5).map { p in
            (0..<7).map { s in
                let name = JavaneseAdapter.wetonName(saptawara: s, pasaran: p)
                let neptu = JavaneseAdapter.saptawaraNeptu[s] + JavaneseAdapter.pasaranNeptu[p]
                return (name, "Neptu: \(neptu)")
            }
        }.flatMap { $0 }.sorted { $0.1 > $1.1 }
    }
    
    private func wukuEntries() -> [(String, String)] {
        JavaneseAdapter.wukuNames.enumerated().map { i, name in
            (name, "Wuku \(i + 1)/30")
        }
    }
}
