import SwiftUI

@main
struct MetaCalendarApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                TodayView()
                    .tabItem { Label("Sekarang", systemImage: "sun.max.fill") }
                    .tag(0)

                CalendarGridView()
                    .tabItem { Label("Kalender", systemImage: "calendar") }
                    .tag(1)

                AlignmentView()
                    .tabItem { Label("Selaras", systemImage: "sparkles") }
                    .tag(2)

                CosmosTabView()
                    .tabItem { Label("Kosmos", systemImage: "moon.stars.fill") }
                    .tag(3)

                SelfTabView()
                    .tabItem { Label("Diri", systemImage: "person.crop.circle.fill") }
                    .tag(4)
            }
            .tint(Meta.jade)

            // Settings gear floating button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Meta.inkMuted)
                            .frame(width: 40, height: 40)
                            .background(Meta.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Meta.hairline, lineWidth: 0.5))
                    }
                    .padding(.trailing, Meta.l)
                    .padding(.top, Meta.l)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

// MARK: - Cosmos Tab (sub-tabs: Rings, Signature, Cycle Lab, Timeline)

struct CosmosTabView: View {
    @State private var cosmosTab = 0

    var body: some View {
        TabView(selection: $cosmosTab) {
            TimeRingsView()
                .tag(0)
                .tabItem { Label("Cincin", systemImage: "circle.hexagongrid") }

            CycleLabView()
                .tag(1)
                .tabItem { Label("Siklus", systemImage: "function") }

            TimelineView()
                .tag(2)
                .tabItem { Label("Linimasa", systemImage: "calendar.badge.clock") }
        }
        .tint(Meta.jade)
    }
}

// MARK: - Self Tab (sub-tabs: Signature, Birth Moment placeholder)

struct SelfTabView: View {
    @State private var selfTab = 0

    var body: some View {
        TabView(selection: $selfTab) {
            CosmicSignatureView()
                .tag(0)
                .tabItem { Label("Sidik", systemImage: "fingerprint") }

            AlignmentView()
                .tag(1)
                .tabItem { Label("Selaras", systemImage: "sparkles") }
        }
        .tint(Meta.jade)
    }
}
