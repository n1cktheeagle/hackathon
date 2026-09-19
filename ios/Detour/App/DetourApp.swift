import SwiftUI
import SwiftData
import GoogleMaps

@main struct DetourApp: App {
    private let configuration: AppConfiguration
    private let container: ModelContainer
    @State private var planner: TripPlanner
    init() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithDefaultBackground()
        navigation.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: UIFont(name: "ApfelGrotezk-Mittel", size: 17) ?? .systemFont(ofSize: 17, weight: .medium))]
        navigation.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: UIFont(name: "ApfelGrotezk-Fett", size: 34) ?? .boldSystemFont(ofSize: 34))]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        let config = AppConfiguration()
        configuration = config
        if !config.mapKey.isEmpty { GMSServices.provideAPIKey(config.mapKey) }
        let inMemory = ProcessInfo.processInfo.arguments.contains("--uitesting")
        do { container = try ModelContainer(for: SavedTrip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)) }
        catch { fatalError("Unable to open the trip store: \(error)") }
        let profile = TravelerProfile(defaults: inMemory ? nil : .standard)
        let planner = TripPlanner(service: config.service, isDemo: config.isDemo, profile: profile)
        if inMemory && !ProcessInfo.processInfo.arguments.contains("--onboarding-test") {
            profile.update([.nature, .food, .culture])
            planner.showingOnboarding = false
        }
        _planner = State(initialValue: planner)
    }
    var body: some Scene {
        WindowGroup {
            RootView(planner: planner, usesGoogleMaps: !configuration.mapKey.isEmpty)
                .modelContainer(container)
                .preferredColorScheme(.light)
                .tint(DetourTheme.ink)
        }
    }
}
