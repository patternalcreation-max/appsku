import SwiftUI

// MARK: - Settings v2

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(spacing: DS.space20) {
                timezoneSection
                calendarProfilesSection
                displayOrderSection
                astronomySection
                aboutSection
            }
            .padding(.horizontal, DS.space16)
            .padding(.bottom, 40)
        }
        .background(DS.bgBase.ignoresSafeArea())
    }
    
    private var timezoneSection: some View {
        VStack(alignment: .leading, spacing: DS.space12) {
            SectionTitle(title: "Timezone", icon: "clock.fill")
            
            Picker("Mode", selection: Binding(
                get: { appState.timeZoneMode },
                set: { appState.timeZoneMode = $0; appState.refreshToday() }
            )) {
                Text("Follow System").tag(TimeZoneMode.followSystem)
                Text("Locked").tag(TimeZoneMode.locked(identifier: appState.timeZone.identifier))
            }
            .pickerStyle(.segmented)
            
            InfoRowV2(label: "Identifier", value: appState.displayTimeZone.identifier)
            
            let offset = appState.displayTimeZone.secondsFromGMT()
            let hours = abs(offset) / 3600
            let mins = (abs(offset) % 3600) / 60
            let sign = offset >= 0 ? "+" : "-"
            InfoRowV2(label: "GMT Offset", value: String(format: "GMT%@%d:%02d", sign, hours, mins))
        }
        .padding(DS.space16)
        .background(DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
    }
    
    private var calendarProfilesSection: some View {
        VStack(alignment: .leading, spacing: DS.space12) {
            SectionTitle(title: "Calendar Profiles", icon: "calendar.badge.plus")
            
            // Hijri
            VStack(alignment: .leading, spacing: DS.space8) {
                Text("Hijri Calculation Method")
                    .font(DS.fontBody).foregroundStyle(DS.textPrimary)
                
                ForEach(HijriProfile.allCases) { profile in
                    profileRow(profile: profile, isSelected: appState.ruleset.hijriProfile == profile) {
                        appState.ruleset.hijriProfile = profile
                        appState.refreshToday()
                    }
                }
            }
            
            Divider().frame(height: 1).overlay(DS.divider)
            
            // Javanese
            VStack(alignment: .leading, spacing: DS.space8) {
                Text("Javanese Tradition")
                    .font(DS.fontBody).foregroundStyle(DS.textPrimary)
                
                ForEach(JavaneseProfile.allCases) { profile in
                    profileRow(profile: profile, isSelected: appState.ruleset.javaneseProfile == profile) {
                        appState.ruleset.javaneseProfile = profile
                        appState.refreshToday()
                    }
                }
            }
        }
        .padding(DS.space16)
        .background(DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
    }
    
    private func profileRow<T: Identifiable>(profile: T, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button {
            onTap()
        } label: {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? DS.primary : DS.textTertiary)
                Text(String(describing: profile))
                    .font(DS.fontBody)
                    .foregroundStyle(DS.textPrimary)
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var displayOrderSection: some View {
        VStack(alignment: .leading, spacing: DS.space12) {
            SectionTitle(title: "Display Order", icon: "list.number")
            
            ForEach(Array(appState.ruleset.displayOrder.enumerated()), id: \.element) { idx, system in
                HStack {
                    Text("\(idx + 1).")
                        .font(DS.fontBodyMono)
                        .foregroundStyle(DS.textTertiary)
                        .frame(width: 24)
                    
                    Image(systemName: system.iconName)
                        .foregroundStyle(DS.systemColor(system))
                    
                    Text(system.displayName)
                        .font(DS.fontBody)
                        .foregroundStyle(DS.textPrimary)
                    
                    Spacer()
                    
                    Button { moveOrder(system: system, direction: .up) } label: {
                        Image(systemName: "chevron.up").font(.system(size: 12))
                            .foregroundStyle(idx == 0 ? DS.textTertiary : DS.textSecondary)
                    }.disabled(idx == 0).buttonStyle(.plain)
                    
                    Button { moveOrder(system: system, direction: .down) } label: {
                        Image(systemName: "chevron.down").font(.system(size: 12))
                            .foregroundStyle(idx == appState.ruleset.displayOrder.count - 1 ? DS.textTertiary : DS.textSecondary)
                    }.disabled(idx == appState.ruleset.displayOrder.count - 1).buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                if idx < appState.ruleset.displayOrder.count - 1 { Divider().overlay(DS.divider) }
            }
        }
        .padding(DS.space16)
        .background(DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
    }
    
    private var astronomySection: some View {
        VStack(alignment: .leading, spacing: DS.space12) {
            SectionTitle(title: "Astronomy Location", icon: "location.fill")
            
            Toggle(isOn: Binding(
                get: { appState.locationEnabled },
                set: { appState.locationEnabled = $0; appState.refreshToday() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Sunrise/Sunset")
                        .font(DS.fontBody).foregroundStyle(DS.textPrimary)
                    Text("Uses Jakarta coordinates for demo")
                        .font(DS.fontCaption).foregroundStyle(DS.textTertiary)
                }
            }
            .tint(DS.primary)
        }
        .padding(DS.space16)
        .background(DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DS.space8) {
            SectionTitle(title: "About", icon: "info.circle")
            
            InfoRowV2(label: "Engine", value: "Meta Calendar v1.1.0")
            InfoRowV2(label: "MetaSolar", value: MetaSolarEngine.profile.id)
            InfoRowV2(label: "Astronomy", value: AstronomyEngine.providerID)
            InfoRowV2(label: "Accuracy", value: AstronomyEngine.expectedErrorEnvelope)
            
            Text("All calculations performed on-device. No account, no server, no tracking.")
                .font(DS.fontCaption)
                .foregroundStyle(DS.textSecondary)
                .padding(.top, 4)
        }
        .padding(DS.space16)
        .background(DS.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.radiusLG))
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
