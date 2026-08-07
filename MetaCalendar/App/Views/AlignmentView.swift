import SwiftUI

// MARK: - Alignment Finder Screen (Killer Feature #1)

struct AlignmentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedConditions: [CycleCondition] = []
    @State private var searchResults: [AlignmentFinder.AlignmentResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchRange = 3650  // 10 years default

    // Quick presets
    enum Preset: String, CaseIterable, Identifiable {
        case jumatLegiFullMoon = "Jumat Legi + Purnama"
        case newMoonMetaSolar1 = "Bulan Baru + MetaSolar Hari 1"
        case wetonBirthday = "Weton + Tahun Baru Masehi"
        case kliwonSolstice = "Kliwon + Solstis"
        case muharramMeta13 = "1 Muharram + MetaSolar 13"
        case allRings = "Hari 1 Semua Kalender"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Meta.xl) {
                // Presets
                VStack(alignment: .leading, spacing: Meta.s) {
                    Text("PRESET POPULER")
                        .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

                    ForEach(Preset.allCases) { preset in
                        Button { applyPreset(preset) } label: {
                            HStack {
                                Text(preset.rawValue)
                                    .font(.metaBody).foregroundStyle(Meta.ink)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(Meta.jade)
                            }
                            .padding(Meta.n)
                            .background(Meta.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Meta.rSM))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Current conditions
                if !selectedConditions.isEmpty {
                    VStack(alignment: .leading, spacing: Meta.s) {
                        Text("KONDISI AKTIF (\(selectedConditions.count))")
                            .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

                        ForEach(Array(selectedConditions.enumerated()), id: \.offset) { idx, cond in
                            HStack {
                                Text(cond.emoji)
                                Text(cond.description)
                                    .font(.metaBody).foregroundStyle(Meta.ink)
                                Spacer()
                                Button { selectedConditions.remove(at: idx) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Meta.inkMuted)
                                }
                            }
                            .padding(Meta.n)
                            .background(Meta.surfaceRaised)
                            .clipShape(RoundedRectangle(cornerRadius: Meta.rSM))
                        }

                        // Range picker
                        HStack {
                            Text("Rentang:")
                                .font(.metaCaption).foregroundStyle(Meta.inkMuted)
                            Picker("", selection: $searchRange) {
                                Text("1 tahun").tag(365)
                                Text("5 tahun").tag(1825)
                                Text("10 tahun").tag(3650)
                                Text("50 tahun").tag(18250)
                            }
                            .pickerStyle(.menu)
                            .tint(Meta.jade)
                        }

                        // Search button
                        Button { performSearch() } label: {
                            HStack {
                                if isSearching {
                                    ProgressView().tint(Meta.canvas)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isSearching ? "Mencari..." : "Cari Penyelarasan")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Meta.canvas)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Meta.jade)
                            .clipShape(RoundedRectangle(cornerRadius: Meta.rMD))
                        }
                        .disabled(selectedConditions.isEmpty || isSearching)
                    }
                }

                // Results
                if hasSearched {
                    VStack(alignment: .leading, spacing: Meta.s) {
                        HStack {
                            Text("HASIL")
                                .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)
                            Spacer()
                            if !searchResults.isEmpty {
                                Text("\(searchResults.count) penyelarasan")
                                    .font(.metaCaption).foregroundStyle(Meta.inkMuted)
                            }
                        }

                        if searchResults.isEmpty && !isSearching {
                            MetaCard {
                                VStack(spacing: Meta.s) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 30))
                                        .foregroundStyle(Meta.inkMuted)
                                    Text("Tidak ada penyelarasan dalam rentang ini")
                                        .font(.metaBody).foregroundStyle(Meta.inkMuted)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }

                        ForEach(searchResults) { result in
                            AlignmentResultCard(result: result, appState: appState)
                        }
                    }
                }
            }
            .padding(.horizontal, Meta.l)
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
    }

    private func applyPreset(_ preset: Preset) {
        selectedConditions = []
        switch preset {
        case .jumatLegiFullMoon:
            selectedConditions = [.weekday(5), .pasaran(0), .moonPhase(180, tolerance: 15)]
        case .newMoonMetaSolar1:
            selectedConditions = [.moonPhase(0, tolerance: 15), .metaSolarDay(1)]
        case .wetonBirthday:
            // Jan 1 is the "birthday" anchor
            selectedConditions = [.weekday(1), .metaSolarDay(1)]
        case .kliwonSolstice:
            selectedConditions = [.pasaran(4), .seasonalEvent("solstice")]
        case .muharramMeta13:
            selectedConditions = [.hijriMonth(1), .hijriDay(1), .metaSolarMonth(13)]
        case .allRings:
            selectedConditions = [.metaSolarDay(1), .hijriDay(1)]
        }
        hasSearched = false
        searchResults = []
    }

    private func performSearch() {
        isSearching = true
        hasSearched = true

        let cal = Calendar(identifier: .gregorian)
        let todayFD = FixedDay.fromGregorian(
            year: cal.component(.year, from: Date()),
            month: cal.component(.month, from: Date()),
            day: cal.component(.day, from: Date())
        )

        // Run search asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            let results = AlignmentFinder.search(
                conditions: selectedConditions,
                from: todayFD,
                maxDays: searchRange,
                maxResults: 20,
                timeZone: appState.displayTimeZone,
                ruleset: appState.ruleset
            )
            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
}

// MARK: - Alignment Result Card

struct AlignmentResultCard: View {
    let result: AlignmentFinder.AlignmentResult
    let appState: AppState
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle().fill(Meta.violet).frame(height: 3)

                VStack(alignment: .leading, spacing: Meta.s) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.dateString)
                                .font(.metaHeadline).foregroundStyle(Meta.ink)
                            Text(result.daysFromToday == 0 ? "HARI INI" : "\(AlignmentFinder.formatDuration(result.daysFromToday)) lagi")
                                .font(.metaCaption)
                                .foregroundStyle(result.daysFromToday <= 365 ? Meta.coral : Meta.inkMuted)
                        }
                        Spacer()
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12)).foregroundStyle(Meta.inkMuted)
                    }

                    // Matched conditions badges
                    FlowLayout(spacing: 6) {
                        ForEach(result.conditions, id: \.id) { cond in
                            HStack(spacing: 3) {
                                Text(cond.emoji)
                                Text(cond.description)
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Meta.violet)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Meta.violet.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }

                    // Weton badge
                    HStack(spacing: Meta.s) {
                        Image(systemName: "circle.grid.cross")
                            .foregroundStyle(Meta.violet)
                        Text("Weton: \(result.wetonName)")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Meta.inkMuted)
                    }

                    if expanded {
                        Divider().overlay(Meta.hairline)

                        Text("DI SEMUA KALENDER")
                            .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

                        ForEach(crossCalendar(), id: \.0) { system, dateStr in
                            HStack(spacing: 8) {
                                Image(systemName: system.iconName)
                                    .foregroundStyle(Meta.systemAccent(system))
                                    .font(.system(size: 12)).frame(width: 18)
                                Text(Meta.systemTitle(system))
                                    .font(.system(size: 13)).foregroundStyle(Meta.inkMuted)
                                Spacer()
                                Text(dateStr)
                                    .font(.system(size: 13, design: .rounded)).foregroundStyle(Meta.ink)
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

    private func crossCalendar() -> [(CalendarSystemID, String)] {
        let (y, m, d) = result.gregorianDate
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

// MARK: - Flow Layout (for condition badges)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth && lineWidth > 0 {
                width = max(width, lineWidth)
                height += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += (lineWidth > 0 ? spacing : 0) + size.width
                lineHeight = max(lineHeight, size.height)
            }
        }
        width = max(width, lineWidth)
        height += lineHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
