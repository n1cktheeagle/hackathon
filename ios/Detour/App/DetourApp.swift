import SwiftUI
import SwiftData
import GoogleMaps

@main struct DetourApp: App {
    private let configuration: AppConfiguration
    private let container: ModelContainer
    @State private var planner: TripPlanner
    init() {
        let config = AppConfiguration()
        configuration = config
        if !config.isDemo { GMSServices.provideAPIKey(config.mapKey) }
        let inMemory = ProcessInfo.processInfo.arguments.contains("--uitesting")
        do { container = try ModelContainer(for: SavedTrip.self, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)) }
        catch { fatalError("Unable to open the trip store: \(error)") }
        _planner = State(initialValue: TripPlanner(service: config.service, isDemo: config.isDemo))
    }
    var body: some Scene {
        WindowGroup {
            RootView(planner: planner)
                .modelContainer(container)
                .preferredColorScheme(.light)
                .tint(DetourTheme.ink)
        }
    }
}
