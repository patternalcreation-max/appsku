import SwiftUI

// MARK: - Cosmic Signature (Killer Feature #3)
// Every moment has a "time fingerprint" — all calendars, moon, weton, astronomy.
// Can be saved and shared as a visual card.

struct CosmicSignatureView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedDate = Date()
    @State private var showShareSheet = false

    private var fixedDay: Int64 {
        let cal = Calendar(identifier: .gregorian)
        return FixedDay.fromGregorian(
            year: cal.component(.year, from: selectedDate),
            month: cal.component(.month, from: selectedDate),
            day: cal.component(.day, from: selectedDate)
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Meta.xl) {
                // Date selector
                DatePicker("Pilih Momen", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .tint(Meta.jade)
                    .labelsHidden()
                    .padding(.horizontal, Meta.l)

                // Signature card
                SignatureCard(date: selectedDate, fixedDay: fixedDay, appState: appState)
                    .padding(.horizontal, Meta.l)

                // Action buttons
                HStack(spacing: Meta.n) {
                    Button { showShareSheet = true } label: {
                        Label("Bagikan", systemImage: "square.and.arrow.up")
                            .font(.metaCaption.weight(.bold))
                            .foregroundStyle(Meta.canvas)
                            .padding(.horizontal, Meta.l)
                            .padding(.vertical, 12)
                            .background(Meta.jade)
                            .clipShape(RoundedRectangle(cornerRadius: Meta.rMD))
                    }

                    Button {
                        // Save to journal (placeholder)
                    } label: {
                        Label("Simpan", systemImage: "bookmark.fill")
                            .font(.metaCaption.weight(.bold))
                            .foregroundStyle(Meta.ink)
                            .padding(.horizontal, Meta.l)
                            .padding(.vertical, 12)
                            .background(Meta.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Meta.rMD))
                            .overlay(RoundedRectangle(cornerRadius: Meta.rMD).stroke(Meta.hairline, lineWidth: 0.5))
                    }
                }
            }
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
        .sheet(isPresented: $showShareSheet) {
            ShareSignatureCard(date: selectedDate, fixedDay: fixedDay, appState: appState)
        }
    }
}

// MARK: - Signature Card

struct SignatureCard: View {
    let date: Date
    let fixedDay: Int64
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: Meta.s) {
                Text("SIDIK WAKTU")
                    .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(2)

                // Big date
                let cal = Calendar(identifier: .gregorian)
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 64, design: .rounded).weight(.bold))
                    .foregroundStyle(Meta.ink)

                let fmt = DateFormatter()
                Text(monthYearLabel)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Meta.inkMuted)
            }
            .padding(.top, Meta.xl)
            .padding(.bottom, Meta.l)

            // Divider
            Rectangle().fill(Meta.gold.opacity(0.2)).frame(height: 1)
                .padding(.horizontal, Meta.xl)

            // Calendar readings
            VStack(spacing: Meta.n) {
                ForEach(allCalendarReadings(), id: \.0) { system, value in
                    HStack(spacing: Meta.n) {
                        Image(systemName: system.iconName)
                            .foregroundStyle(Meta.systemAccent(system))
                            .font(.system(size: 14))
                            .frame(width: 20)
                        Text(Meta.systemTitle(system))
                            .font(.metaCaption).foregroundStyle(Meta.inkMuted)
                        Spacer()
                        Text(value)
                            .font(.system(size: 14, design: .rounded).weight(.medium))
                            .foregroundStyle(Meta.ink)
                    }
                }
            }
            .padding(Meta.xl)

            // Divider
            Rectangle().fill(Meta.gold.opacity(0.2)).frame(height: 1)
                .padding(.horizontal, Meta.xl)

            // Cosmic context
            VStack(spacing: Meta.n) {
                cosmicRow(emoji: moonEmoji, label: "Fase Bulan", value: moonLabel)
                cosmicRow(emoji: "🌅", label: "Matahari", value: sunLabel)
                cosmicRow(emoji: "🟢", label: "Weton", value: wetonLabel)
                cosmicRow(emoji: "✨", label: "Neptu", value: "\(JavaneseAdapter.totalNeptu(fixedDay: fixedDay))")
                cosmicRow(emoji: "🔆", label: "MetaSolar", value: metaSolarCoord)
            }
            .padding(Meta.xl)

            // Footer
            Text("Meta Calendar · Sidik waktu unik")
                .font(.system(size: 10, design: .serif).italic())
                .foregroundStyle(Meta.inkMuted)
                .padding(.bottom, Meta.l)
        }
        .background(
            LinearGradient(
                colors: [Meta.surfaceRaised, Meta.canvas],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Meta.rXL))
        .overlay(RoundedRectangle(cornerRadius: Meta.rXL).stroke(Meta.gold.opacity(0.15), lineWidth: 1))
    }

    private func cosmicRow(emoji: String, label: String, value: String) -> some View {
        HStack(spacing: Meta.n) {
            Text(emoji).font(.system(size: 16))
            Text(label).font(.metaCaption).foregroundStyle(Meta.inkMuted)
            Spacer()
            Text(value).font(.system(size: 14, design: .rounded).weight(.medium)).foregroundStyle(Meta.ink)
        }
    }

    // MARK: - Data computations

    private var monthYearLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        fmt.locale = Locale(identifier: "id_ID")
        return fmt.string(from: date)
    }

    private func allCalendarReadings() -> [(CalendarSystemID, String)] {
        var gCal = Calendar(identifier: .gregorian)
        gCal.timeZone = appState.displayTimeZone
        let date = gCal.date(from: DateComponents(
            year: Calendar.current.component(.year, from: self.date),
            month: Calendar.current.component(.month, from: self.date),
            day: Calendar.current.component(.day, from: self.date),
            hour: 12
        )) ?? self.date

        let bundle = CalendarEngine.project(
            instant: Instant(date), timeZone: appState.displayTimeZone,
            location: nil, ruleset: appState.ruleset
        )
        return bundle.projections.map { ($0.calendarSystemID, $0.displayString) }
    }

    private var moonEmoji: String {
        let phase = AstronomyEngine.moonPhaseAngle(forFixedDay: fixedDay)
        if phase < 22.5 || phase > 337.5 { return "🌑" }
        if phase < 67.5 { return "🌒" }
        if phase < 112.5 { return "🌓" }
        if phase < 157.5 { return "🌔" }
        if phase < 202.5 { return "🌕" }
        if phase < 247.5 { return "🌖" }
        if phase < 292.5 { return "🌗" }
        return "🌘"
    }

    private var moonLabel: String {
        let phase = AstronomyEngine.moonPhaseAngle(forFixedDay: fixedDay)
        let pct = Int((1 - cos(phase * .pi / 180)) / 2 * 100)
        let phaseName: String
        if phase < 22.5 || phase > 337.5 { phaseName = "Baru" }
        else if phase < 67.5 { phaseName = "Sabit Awal" }
        else if phase < 112.5 { phaseName = "Separuh Pertama" }
        else if phase < 157.5 { phaseName = "Cembung Akhir" }
        else if phase < 202.5 { phaseName = "Purnama" }
        else if phase < 247.5 { phaseName = "Cembung Awal" }
        else if phase < 292.5 { phaseName = "Separuh Akhir" }
        else { phaseName = "Sabit Akhir" }
        return "\(phaseName) · \(pct)%"
    }

    private var sunLabel: String {
        let jdn = Double(FixedDay.toJulianDayNumber(fixedDay)) + 0.5
        let lon = AstronomyEngine.solarLongitude(julianDay: jdn)
        let season: String
        if lon < 80 || lon > 355 { season = "Musim Dingin" }
        else if lon < 170 { season = "Musim Semi" }
        else if lon < 260 { season = "Musim Panas" }
        else { season = "Musim Gugur" }
        return String(format: "%.0f° · %@", lon, season)
    }

    private var wetonLabel: String {
        let sapta = JavaneseAdapter.saptawaraIndex(fixedDay: fixedDay)
        let pasaran = JavaneseAdapter.pasaranIndex(fixedDay: fixedDay)
        return JavaneseAdapter.wetonName(saptawara: sapta, pasaran: pasaran)
    }

    private var metaSolarCoord: String {
        return MetaSolarEngine.displayString(for: MetaSolarEngine.coordinate(forFixedDay: fixedDay))
    }
}

// MARK: - Share Sheet

struct ShareSignatureCard: View {
    let date: Date
    let fixedDay: Int64
    let appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                SignatureCard(date: date, fixedDay: fixedDay, appState: appState)
                    .padding(Meta.l)
            }
            .navigationTitle("Bagikan Sidik Waktu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Selesai") { dismiss() } }
            }
            .background(MetaBackground())
        }
    }
}
