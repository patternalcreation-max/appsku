import SwiftUI

// MARK: - Settings Screen

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                timezoneSection
                hijriSection
                javaneseSection
                displayOrderSection
                astronomySection
                aboutSection
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(AppTheme.bgPrimary.ignoresSafeArea())
    }
    
    // Timezone
    private var timezoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Timezone", systemImage: "clock.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            
            Picker("Mode", selection: Binding(
                get: { appState.timeZoneMode },
                set: { appState.timeZoneMode = $0; appState.refreshToday() }
            )) {
                Text("Follow System").tag(TimeZoneMode.followSystem)
                Text("Locked").tag(TimeZoneMode.locked(identifier: appState.timeZone.identifier))
            }
            .pickerStyle(.segmented)
            
            HStack {
                Text("Identifier")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Text(appState.displayTimeZone.identifier)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            
            let offset = appState.displayTimeZone.secondsFromGMT()
            let hours = abs(offset) / 3600
            let mins = (abs(offset) % 3600) / 60
            let sign = offset >= 0 ? "+" : "-"
            HStack {
                Text("GMT Offset")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Text(String(format: "GMT%@%d:%02d", sign, hours, mins))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // Hijri profile
    private var hijriSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hijri Profile", systemImage: "moon.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            
            ForEach(HijriProfile.allCases) { profile in
                Button {
                    appState.ruleset.hijriProfile = profile
                    appState.refreshToday()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName)
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(profile.rawValue)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Spacer()
                        if appState.ruleset.hijriProfile == profile {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if profile != HijriProfile.allCases.last {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // Javanese profile
    private var javaneseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Javanese Profile", systemImage: "circle.grid.cross.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            
            ForEach(JavaneseProfile.allCases) { profile in
                Button {
                    appState.ruleset.javaneseProfile = profile
                    appState.refreshToday()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.displayName)
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(profile.rawValue)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                        Spacer()
                        if appState.ruleset.javaneseProfile == profile {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if profile != JavaneseProfile.allCases.last {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // Display order
    private var displayOrderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Calendar Display Order", systemImage: "list.number")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            
            ForEach(Array(appState.ruleset.displayOrder.enumerated()), id: \.element) { idx, system in
                HStack {
                    Text("\(idx + 1).")
                        .font(.system(size: 15, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .frame(width: 24)
                    
                    Image(systemName: system.iconName)
                        .foregroundStyle(AppTheme.systemColor(system))
                    
                    Text(system.displayName)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textPrimary)
                    
                    Spacer()
                    
                    // Move up/down buttons
                    Button {
                        moveOrder(system: system, direction: .up)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12))
                            .foregroundStyle(idx == 0 ? AppTheme.textTertiary : AppTheme.textSecondary)
                    }
                    .disabled(idx == 0)
                    .buttonStyle(.plain)
                    
                    Button {
                        moveOrder(system: system, direction: .down)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(idx == appState.ruleset.displayOrder.count - 1 ? AppTheme.textTertiary : AppTheme.textSecondary)
                    }
                    .disabled(idx == appState.ruleset.displayOrder.count - 1)
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                
                if idx < appState.ruleset.displayOrder.count - 1 {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // Astronomy
    private var astronomySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Astronomy Location", systemImage: "location.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            
            Toggle(isOn: Binding(
                get: { appState.locationEnabled },
                set: { appState.locationEnabled = $0; appState.refreshToday() }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Sunrise/Sunset")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Uses default location for calculation demo")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            .tint(AppTheme.accent)
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("About", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            
            InfoRow(label: "Engine", value: "Meta Calendar Engine")
            InfoRow(label: "MetaSolar Profile", value: MetaSolarEngine.profile.id)
            InfoRow(label: "Astronomy Provider", value: AstronomyEngine.providerID)
            InfoRow(label: "Version", value: AstronomyEngine.version)
            InfoRow(label: "Accuracy", value: AstronomyEngine.expectedErrorEnvelope)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Privacy")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textTertiary)
                Text("All calculations are performed on-device. No account, no server, no tracking. Location is optional and used only for sunrise/sunset calculations.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(AppTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    // Helpers
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
