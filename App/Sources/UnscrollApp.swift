import SwiftUI
import UnscrollKit

@main
struct UnscrollApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.accent)
                .task { await model.bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await model.refresh() } }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if !model.isLoaded {
                ProgressView().controlSize(.large)
            } else if model.state.profile.onboardingComplete {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

struct MainTabView: View {
    // `-tab N` launch argument (via UserDefaults) opens a specific tab; handy for screenshots.
    @State private var selection = UserDefaults.standard.integer(forKey: "tab")

    var body: some View {
        TabView(selection: $selection) {
            HomeView().tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            ScreenTimeView().tabItem { Label("Screen Time", systemImage: "hourglass") }.tag(1)
            LeaderboardView().tabItem { Label("Leaderboard", systemImage: "trophy.fill") }.tag(2)
            ProfileView().tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }.tag(3)
        }
    }
}
