import Foundation

struct AppConfiguration {
    let apiURL: URL?
    let mapKey: String
    let accessToken: String
    let isDemo: Bool
    private let fixtureRoutes: Bool
    init(bundle: Bundle = .main, arguments: [String] = ProcessInfo.processInfo.arguments) {
        func value(_ key: String) -> String {
            let value = bundle.object(forInfoDictionaryKey: key) as? String ?? ""
            return value.hasPrefix("$(") ? "" : value
        }
        apiURL = URL(string: value("DetourAPIURL"))
        mapKey = value("GoogleMapsAPIKey")
        accessToken = value("DetourAccessToken")
        isDemo = arguments.contains("--demo") || apiURL == nil || mapKey.isEmpty
        fixtureRoutes = arguments.contains("--uitesting") && !arguments.contains("--live-map-test")
    }
    @MainActor var service: any DetourService {
        if !isDemo, let apiURL { return APIClient(baseURL: apiURL, accessToken: accessToken) }
        if fixtureRoutes { return FixtureService() }
        return AppleMapDemoService(routes: AppleRouteProvider())
    }
}
