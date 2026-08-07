import SwiftUI

// MARK: - Explore v2

struct ExploreView: View {
    @Environment(AppState.self) private var appState
    @State private var sourceSystem: CalendarSystemID = .gregorian
    @State private var inputYear: Int = Calendar(identifier: .gregorian).component(.year, from: Date())
    @State private var inputMonth: Int = Calendar(identifier: .gregorian).component(.month, from: Date())
    @State private var inputDay: Int = Calendar(identifier: .gregorian).component(.day, from: Date())
    @State private var convertedProjections: [CalendarProjection] = []
    @State private var hasConverted: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DS.space20) {
                converterCard
                if hasConverted { resultsSection }
                cyclesSection
            }
            .padding(.horizontal, DS.space16)
            .padding(.bottom, 40)
        }
        .background(DS.bgBase.ignoresSafeArea())
    }
    
    private var converterCard: some View {
        VStack(alignment: .leading, spacing: DS.space12) {
            SectionTitle(title: "Convert Date", icon: "arrow.triangle.swap")
            
            Picker("Source", selection: $sourceSystem) {
                ForEach(CalendarSystemID.allCases) { sys in
                    Text(sys.displayName).tag(sys)
                }
            }
            .pickerStyle(.segmented)
            
            HStack(spacing: DS.space12) {
                inputField(label: "Year", value: $inputYear)
                inputField(label: "Month", value: $inputMonth)
                inputField(label: "Day", value: $inputDay)
            }
            
            Button { convert() } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Convert to All Calendars")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(DS.primary)
                .clipShape(RoundedRectangle(cornerRadius: DS.radiusMD))
            }
        }
        .padding(DS.space16)
        .background(DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
    }
    
    private func inputField(label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(DS.fontCaption).foregroundStyle(DS.textTertiary)
            TextField(label, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
        }
    }
    
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: DS.space8) {
            SectionTitle(title: "Results", icon: "checkmark.seal")
            ForEach(convertedProjections) { proj in
                CalendarCardV2(projection: proj, rank: -1)
            }
        }
    }
    
    private var cyclesSection: some View {
        VStack(alignment: .leading, spacing: DS.space8) {
            SectionTitle(title: "Quick Reference", icon: "book")
            
            cycleCard(title: "Pasaran (5-Day)", entries: JavaneseAdapter.pasaranNames.enumerated().map { ($0.element, "Neptu: \(JavaneseAdapter.pasaranNeptu[$0.offset])") })
            cycleCard(title: "Saptawara (7-Day)", entries: JavaneseAdapter.saptawaraNames.enumerated().map { ($0.element, "Neptu: \(JavaneseAdapter.saptawaraNeptu[$0.offset])") })
            cycleCard(title: "Wuku (210-Day)", entries: JavaneseAdapter.wukuNames.enumerated().map { ($0.element, "Wuku \($0.offset + 1)/30") })
        }
    }
    
    private func cycleCard(title: String, entries: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: DS.space8) {
            Text(title)
                .font(.system(size: 13, design: .rounded).weight(.semibold))
                .foregroundStyle(DS.textPrimary)
            
            ForEach(entries, id: \.0) { name, value in
                HStack {
                    Text(name).font(DS.fontBody).foregroundStyle(DS.textSecondary)
                    Spacer()
                    Text(value).font(DS.fontBodyMono).foregroundStyle(DS.textPrimary)
                }
                Divider()
            }
        }
        .padding(DS.space16)
        .background(DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
    }
    
    private func convert() {
        convertedProjections = CalendarEngine.resolve(
            sourceSystem: sourceSystem, year: inputYear, month: inputMonth, day: inputDay,
            timeZone: appState.displayTimeZone, ruleset: appState.ruleset
        )
        hasConverted = true
    }
}
