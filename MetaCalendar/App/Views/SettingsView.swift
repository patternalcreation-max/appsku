import SwiftUI

// MARK: - Settings v3 (Meta design + Indonesian)

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(spacing: Meta.xl) {
                timezoneSection
                profilesSection
                displayOrderSection
                astronomySection
                aboutSection
            }
            .padding(.horizontal, Meta.l)
            .padding(.bottom, 130)
        }
        .background(MetaBackground())
    }

    private var timezoneSection: some View {
        VStack(alignment: .leading, spacing: Meta.n) {
            Text("ZONA WAKTU")
                .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)
            Picker("Mode", selection: Binding(
                get: { appState.timeZoneMode },
                set: { appState.timeZoneMode = $0; appState.refreshToday() }
            )) {
                Text("Ikuti Sistem").tag(TimeZoneMode.followSystem)
                Text("Kunci").tag(TimeZoneMode.locked(identifier: appState.timeZone.identifier))
            }
            .pickerStyle(.segmented)
            MetaInfoRow(label: "ID", value: appState.displayTimeZone.identifier)
            let offset = appState.displayTimeZone.secondsFromGMT()
            MetaInfoRow(label: "GMT", value: String(format: "GMT%@%d:%02d", offset >= 0 ? "+" : "-", abs(offset) / 3600, (abs(offset) % 3600) / 60))
        }
        .padding(Meta.l)
        .background(Meta.surface)
        .clipShape(RoundedRectangle(cornerRadius: Meta.rLG))
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: Meta.n) {
            Text("PROFIL KALENDAR")
                .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)

            VStack(alignment: .leading, spacing: Meta.s) {
                Text("Metode Hisab Hijriah").font(.metaHeadline).foregroundStyle(Meta.ink)
                ForEach(HijriProfile.allCases) { p in
                    profileRow(title: p.displayName, subtitle: p.rawValue, isSelected: appState.ruleset.hijriProfile == p) {
                        appState.ruleset.hijriProfile = p; appState.refreshToday()
                    }
                }
            }

            Divider().overlay(Meta.hairline)

            VStack(alignment: .leading, spacing: Meta.s) {
                Text("Tradisi Jawa").font(.metaHeadline).foregroundStyle(Meta.ink)
                ForEach(JavaneseProfile.allCases) { p in
                    profileRow(title: p.displayName, subtitle: p.rawValue, isSelected: appState.ruleset.javaneseProfile == p) {
                        appState.ruleset.javaneseProfile = p; appState.refreshToday()
                    }
                }
            }
        }
        .padding(Meta.l)
        .background(Meta.surface)
        .clipShape(RoundedRectangle(cornerRadius: Meta.rLG))
    }

    private func profileRow(title: String, subtitle: String, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button { onTap() } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Meta.jade : Meta.inkMuted)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.metaBody).foregroundStyle(Meta.ink)
                    Text(subtitle).font(.system(size: 11, design: .monospaced)).foregroundStyle(Meta.inkMuted)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var displayOrderSection: some View {
        VStack(alignment: .leading, spacing: Meta.n) {
            Text("URUTAN TAMPILAN")
                .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)
            ForEach(Array(appState.ruleset.displayOrder.enumerated()), id: \.element) { idx, system in
                HStack {
                    Text("\(idx + 1).").font(.metaMono).foregroundStyle(Meta.inkMuted).frame(width: 24)
                    Image(systemName: system.iconName).foregroundStyle(Meta.systemAccent(system))
                    Text(Meta.systemTitle(system)).font(.metaBody).foregroundStyle(Meta.ink)
                    Spacer()
                    Button { moveOrder(system: system, direction: .up) } label: {
                        Image(systemName: "chevron.up").font(.system(size: 12))
                            .foregroundStyle(idx == 0 ? Meta.inkMuted.opacity(0.3) : Meta.inkMuted)
                    }.disabled(idx == 0).buttonStyle(.plain)
                    Button { moveOrder(system: system, direction: .down) } label: {
                        Image(systemName: "chevron.down").font(.system(size: 12))
                            .foregroundStyle(idx == appState.ruleset.displayOrder.count - 1 ? Meta.inkMuted.opacity(0.3) : Meta.inkMuted)
                    }.disabled(idx == appState.ruleset.displayOrder.count - 1).buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                if idx < appState.ruleset.displayOrder.count - 1 { Divider().overlay(Meta.hairline) }
            }
        }
        .padding(Meta.l)
        .background(Meta.surface)
        .clipShape(RoundedRectangle(cornerRadius: Meta.rLG))
    }

    private var astronomySection: some View {
        VStack(alignment: .leading, spacing: Meta.n) {
            Text("LOKASI ASTRONOMI")
                .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)
            Toggle(isOn: Binding(
                get: { appState.locationEnabled },
                set: { appState.locationEnabled = $0; appState.refreshToday() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aktifkan Matahari Terbit/Terbenam")
                        .font(.metaBody).foregroundStyle(Meta.ink)
                    Text("Menggunakan koordinat Jakarta untuk demo")
                        .font(.metaCaption).foregroundStyle(Meta.inkMuted)
                }
            }
            .tint(Meta.jade)
        }
        .padding(Meta.l)
        .background(Meta.surface)
        .clipShape(RoundedRectangle(cornerRadius: Meta.rLG))
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Meta.s) {
            Text("TENTANG")
                .font(.metaEyebrow).foregroundStyle(Meta.gold).kerning(1.35)
            MetaInfoRow(label: "Versi", value: "Meta Calendar v1.2.0")
            MetaInfoRow(label: "MetaSolar", value: MetaSolarEngine.profile.id)
            MetaInfoRow(label: "Astronomi", value: AstronomyEngine.providerID)
            MetaInfoRow(label: "Akurasi", value: AstronomyEngine.expectedErrorEnvelope)
            Text("Semua perhitungan dilakukan di perangkat. Tanpa akun, tanpa server, tanpa pelacakan.")
                .font(.metaCaption).foregroundStyle(Meta.inkMuted).padding(.top, Meta.s)
        }
        .padding(Meta.l)
        .background(Meta.surface)
        .clipShape(RoundedRectangle(cornerRadius: Meta.rLG))
    }

    enum MoveDirection { case up, down }
    private func moveOrder(system: CalendarSystemID, direction: MoveDirection) {
        var order = appState.ruleset.displayOrder
        guard let idx = order.firstIndex(of: system) else { return }
        let newIdx = direction == .up ? idx - 1 : idx + 1
        guard newIdx >= 0, newIdx < order.count else { return }
        order.swapAt(idx, newIdx)
        appState.ruleset.displayOrder = order
        appState.refreshToday()
    }
}
