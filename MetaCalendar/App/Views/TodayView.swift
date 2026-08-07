import SwiftUI

// MARK: - Today Screen v3 (OrbitHero + Indonesian + DayStepper)

struct TodayView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: Meta.xl) {
                // Orbit Hero
                OrbitHero(date: appState.selectedGregDay, timeZone: appState.displayTimeZone)

                // Day Stepper
                DayStepper()

                // Astronomy strip
                if let astro = appState.selectedDayBundle?.astronomy {
                    astronomyStrip(astro)
                }

                // Calendar projections
                VStack(spacing: Meta.n) {
                    MetaSection(title: "Hari Ini Lintas Kalender")
                    if let bundle = appState.selectedDayBundle {
                        ForEach(bundle.projections) { proj in
                            MetaProjectionCard(projection: proj)
                        }
                    }
                }

                // Upcoming events
                VStack(spacing: Meta.n) {
                    MetaSection(title: "Peristiwa Mendatang", action: "90 hari")
                    if appState.upcomingEvents.isEmpty {
                        MetaCard {
                            Text("Tidak ada peristiwa besar 90 hari ke depan")
                                .font(.metaBody)
                                .foregroundStyle(Meta.inkMuted)
                        }
                    } else {
                        ForEach(Array(appState.upcomingEvents.prefix(8))) { event in
                            MetaEventRow(event: event, daysUntil: event.daysFromToday)
                                .background(Meta.surface)
                                .clipShape(RoundedRectangle(cornerRadius: Meta.rSM))
                        }
                    }
                }

                // Footer
                Text("Satu momen, beberapa pandangan kalender.")
                    .font(.system(size: 12, design: .serif).italic())
                    .foregroundStyle(Meta.inkMuted)
                    .padding(.top, Meta.s)
            }
            .padding(.horizontal, Meta.l)
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
        .refreshable { appState.refreshToday() }
        .task { appState.refreshToday() }
    }

    @ViewBuilder
    private func astronomyStrip(_ astro: AstronomyData) -> some View {
        HStack(spacing: 0) {
            astroItem(icon: astro.moonPhaseEmoji, color: Meta.ink, value: "\(Int(astro.moonIllumination * 100))%", label: "Bulan")
            divider
            astroItem(icon: "sun.max.fill", color: Meta.gold, value: String(format: "%.0f°", astro.solarLongitude), label: "Solar λ")
            divider
            astroItem(icon: "leaf.fill", color: Meta.jade, value: astro.solarTerm.split(separator: " ").first.map(String.init) ?? "", label: "Surya")
            if astro.sunrise != nil {
                divider
                astroItem(icon: "sun.haze.fill", color: Meta.coral, value: timeOnly(astro.sunrise), label: "Terbit")
            }
        }
        .padding(Meta.n)
        .background(Meta.surface)
        .clipShape(RoundedRectangle(cornerRadius: Meta.rMD))
        .overlay(RoundedRectangle(cornerRadius: Meta.rMD).stroke(Meta.hairline, lineWidth: 0.5))
    }

    private func astroItem(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: Meta.s) {
            if icon.count == 1 && icon.unicodeScalars.first!.value > 0x2000 {
                Text(icon).font(.system(size: 20))
            } else {
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            }
            Text(value).font(.system(size: 11, design: .rounded).weight(.semibold)).foregroundStyle(Meta.ink)
            Text(label).font(.system(size: 9)).foregroundStyle(Meta.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Divider().frame(height: 44)
    }

    private func timeOnly(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.timeZone = appState.displayTimeZone
        return f.string(from: date)
    }
}
