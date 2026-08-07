import SwiftUI

// MARK: - Explore v3 (Meta design + Indonesian)

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
            VStack(spacing: Meta.xl) {
                converterCard
                if hasConverted { resultsSection }
                cyclesSection
            }
            .padding(.horizontal, Meta.l)
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
    }

    private var converterCard: some View {
        VStack(alignment: .leading, spacing: Meta.n) {
            Text("KONVERSI TANGGAL")
                .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)
            Text("Konversi")
                .font(.metaTitle).foregroundStyle(Meta.ink)

            Picker("Sumber", selection: $sourceSystem) {
                ForEach(CalendarSystemID.allCases) { sys in
                    Text(Meta.systemTitle(sys)).tag(sys)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: Meta.n) {
                inputField(label: "Tahun", value: $inputYear)
                inputField(label: "Bulan", value: $inputMonth)
                inputField(label: "Hari", value: $inputDay)
            }

            Button { convert() } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Konversi ke Semua Kalender")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Meta.canvas)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Meta.jade)
                .clipShape(RoundedRectangle(cornerRadius: Meta.rMD))
            }
        }
        .padding(Meta.l)
        .background(Meta.surface)
        .clipShape(RoundedRectangle(cornerRadius: Meta.rLG))
    }

    private func inputField(label: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.metaCaption).foregroundStyle(Meta.inkMuted)
            TextField(label, value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
        }
    }

    private var resultsSection: some View {
        VStack(spacing: Meta.n) {
            MetaSection(title: "Hasil Konversi")
            ForEach(convertedProjections) { proj in
                MetaProjectionCard(projection: proj)
            }
        }
    }

    private var cyclesSection: some View {
        VStack(alignment: .leading, spacing: Meta.n) {
            MetaSection(title: "Referensi Siklus")
            cycleCard(title: "Pasaran (5 Hari)", entries: JavaneseAdapter.pasaranNames.enumerated().map { ($0.element, "Neptu: \(JavaneseAdapter.pasaranNeptu[$0.offset])") })
            cycleCard(title: "Saptawara (7 Hari)", entries: JavaneseAdapter.saptawaraNames.enumerated().map { ($0.element, "Neptu: \(JavaneseAdapter.saptawaraNeptu[$0.offset])") })
            cycleCard(title: "Wuku (210 Hari)", entries: JavaneseAdapter.wukuNames.enumerated().map { ($0.element, "Wuku \($0.offset + 1)/30") })
        }
    }

    private func cycleCard(title: String, entries: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: Meta.s) {
            Text(title).font(.metaHeadline).foregroundStyle(Meta.ink)
            ForEach(entries, id: \.0) { name, value in
                HStack {
                    Text(name).font(.metaBody).foregroundStyle(Meta.inkMuted)
                    Spacer()
                    Text(value).font(.metaMono).foregroundStyle(Meta.ink)
                }
                Divider().overlay(Meta.hairline)
            }
        }
        .padding(Meta.l)
        .background(Meta.surface)
        .clipShape(RoundedRectangle(cornerRadius: Meta.rLG))
    }

    private func convert() {
        convertedProjections = CalendarEngine.resolve(
            sourceSystem: sourceSystem, year: inputYear, month: inputMonth, day: inputDay,
            timeZone: appState.displayTimeZone, ruleset: appState.ruleset
        )
        hasConverted = true
    }
}
