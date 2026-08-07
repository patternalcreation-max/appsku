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

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Hari Ini", systemImage: "sun.max.fill") }
                .tag(0)
            TimelineView()
                .tabItem { Label("Linimasa", systemImage: "calendar.badge.clock") }
                .tag(1)
            CalendarGridView()
                .tabItem { Label("Kalender", systemImage: "calendar") }
                .tag(2)
            ExploreView()
                .tabItem { Label("Konversi", systemImage: "arrow.triangle.swap") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Pengaturan", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .tint(Meta.jade)
    }
}
