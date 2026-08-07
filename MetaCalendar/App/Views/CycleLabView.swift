import SwiftUI

// MARK: - Cycle Lab (Killer Feature #4)
// Mathematical laboratory for comparing cycle lengths, computing LCM, and drift.

struct CycleLabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedCycles: Set<Int> = [7, 5]
    @State private var customCycle = 30

    private let availableCycles: [(name: String, days: Int, color: Color, emoji: String)] = [
        ("Pasaran", 5, Meta.gold, "🟢"),
        ("Saptawara", 7, Meta.coral, "📅"),
        ("Weton", 35, Meta.violet, "🟣"),
        ("Bulan Suryal", 28, Meta.coral.opacity(0.6), "🔆"),
        ("Bulan Sinodik", 30, Meta.jade, "🌙"),
        ("Wuku", 210, Meta.violet.opacity(0.6), "🌀"),
        ("Tahun", 365, Meta.gold.opacity(0.6), "🌍"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Meta.xl) {
                // Available cycles
                VStack(alignment: .leading, spacing: Meta.s) {
                    Text("PILIH SIKLUS")
                        .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

                    ForEach(availableCycles, id: \.days) { cycle in
                        Button {
                            if selectedCycles.contains(cycle.days) {
                                selectedCycles.remove(cycle.days)
                            } else {
                                selectedCycles.insert(cycle.days)
                            }
                        } label: {
                            HStack(spacing: Meta.n) {
                                Image(systemName: selectedCycles.contains(cycle.days) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedCycles.contains(cycle.days) ? Meta.jade : Meta.inkMuted)
                                Text(cycle.emoji)
                                Text(cycle.name)
                                    .font(.metaBody).foregroundStyle(Meta.ink)
                                Spacer()
                                Text("\(cycle.days) hari")
                                    .font(.metaMono).foregroundStyle(Meta.inkMuted)
                            }
                            .padding(Meta.n)
                            .background(Meta.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Meta.rSM))
                        }
                        .buttonStyle(.plain)
                    }

                    // Custom cycle
                    HStack(spacing: Meta.n) {
                        Text("Custom:")
                            .font(.metaCaption).foregroundStyle(Meta.inkMuted)
                        TextField("30", value: $customCycle, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                        Button {
                            selectedCycles.insert(customCycle)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Meta.jade)
                        }
                    }
                }

                // Results
                if selectedCycles.count >= 2 {
                    resultsCard
                    driftCard
                    timelineCard
                }
            }
            .padding(.horizontal, Meta.l)
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
    }

    private var resultsCard: some View {
        MetaCard {
            VStack(alignment: .leading, spacing: Meta.s) {
                Text("HASIL SIKLUS")
                    .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

                let selected = selectedCycles.sorted()
                let realign = AlignmentFinder.cycleRealignment(days: selected)

                MetaInfoRow(label: "Siklus dipilih", value: selected.map { "\($0)" }.joined(separator: ", "))
                MetaInfoRow(label: "FPB", value: "\(AlignmentFinder.gcd(selected.reduce(0) { AlignmentFinder.gcd($0, $1) }))")
                MetaInfoRow(label: "KPK", value: "\(realign)")
                MetaInfoRow(label: "Realignment", value: AlignmentFinder.formatDuration(realign))

                if realign > 0 {
                    let years = Double(realign) / 365.25
                    MetaInfoRow(label: "Dalam tahun", value: String(format: "%.1f tahun", years))
                    MetaInfoRow(label: "Putaran", value: selected.map { "\(realign / $0)×" }.joined(separator: " · "))
                }

                Text("Semua siklus kembali sejajar dalam \(AlignmentFinder.formatDuration(realign)). Setelah itu, pola berulang sempurna.")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundStyle(Meta.inkMuted)
                    .padding(.top, Meta.s)
            }
        }
    }

    private var driftCard: some View {
        MetaCard {
            VStack(alignment: .leading, spacing: Meta.s) {
                Text("DRIFT ANTAR SIKLUS")
                    .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

                let selected = selectedCycles.sorted()
                let base = selected.first ?? 1

                ForEach(selected.dropFirst(), id: \.self) { cycle in
                    let driftPerBase = Double(cycle - base) / Double(base) * 100
                    MetaInfoRow(label: "\(base) → \(cycle)", value: String(format: "%+.1f%% per putaran base", driftPerBase))
                }

                Text("Drift menunjukkan seberapa cepat siklus berjalan terpisah. Positive = siklus kedua lebih panjang.")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundStyle(Meta.inkMuted)
                    .padding(.top, Meta.s)
            }
        }
    }

    private var timelineCard: some View {
        MetaCard {
            VStack(alignment: .leading, spacing: Meta.s) {
                Text("TIMELINE 10 TAHUN")
                    .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

                let selected = selectedCycles.sorted()
                let realign = AlignmentFinder.cycleRealignment(days: selected)
                let tenYears = 3650

                if realign <= tenYears && realign > 0 {
                    let count = tenYears / realign
                    Text("Dalam 10 tahun, siklus ini sejajar \(count) kali.")
                        .font(.metaBody).foregroundStyle(Meta.ink)

                    ForEach(0..<min(count, 5), id: \.self) { i in
                        let days = realign * (i + 1)
                        let years = Double(days) / 365.25
                        HStack {
                            Circle().fill(Meta.violet).frame(width: 8, height: 8)
                            Text(String(format: "Penyelarasan #%d: %d hari (%.1f tahun)", i + 1, days, years))
                                .font(.system(size: 13)).foregroundStyle(Meta.inkMuted)
                        }
                    }
                } else if realign > tenYears {
                    Text("Siklus ini hanya sejajar setiap \(AlignmentFinder.formatDuration(realign)). Dalam 10 tahun tidak ada realignment penuh.")
                        .font(.metaBody).foregroundStyle(Meta.inkMuted)
                }
            }
        }
    }
}
