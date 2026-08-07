import SwiftUI

// MARK: - Main App Entry Point

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

// MARK: - Root Content View (Tab Navigation)

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)
            
            CalendarGridView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(1)
            
            ExploreView()
                .tabItem { Label("Explore", systemImage: "arrow.triangle.swap") }
                .tag(2)
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(3)
        }
        .tint(DS.primary)
    }
}
