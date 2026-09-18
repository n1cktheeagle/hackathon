import Foundation

protocol LocationSearching: Sendable {
    func search(_ query: String, sessionToken: String) async throws -> [SearchResult]
}
protocol PlaceProviding: Sendable {
    func details(_ id: String, sessionToken: String?) async throws -> PlaceReference
    func nearby(_ coordinate: Coordinate) async throws -> [PlaceReference]
    func photoURL(_ name: String) async throws -> URL?
}
protocol RouteProviding: Sendable {
    func route(_ request: RouteRequest) async throws -> RoutePlan
}
protocol StopDiscovering: Sendable {
    func discover(_ request: DiscoveryRequest) -> AsyncThrowingStream<DiscoveryEvent, Error>
}
protocol DetourService: LocationSearching, PlaceProviding, RouteProviding, StopDiscovering {}

struct APIClient: DetourService {
    let baseURL: URL
    let accessToken: String
    private let session: URLSession
    init(baseURL: URL, accessToken: String = "") {
        self.baseURL = baseURL; self.accessToken = accessToken
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 100
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }
    private func request(_ path: String, body: Data? = nil, query: [URLQueryItem] = []) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !accessToken.isEmpty { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        return request
    }
    private func decode<T: Decodable>(_ type: T.Type, request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw (try? JSONDecoder().decode(APIProblem.self, from: data)) ?? APIProblem(code: "network", message: "The service could not complete this request. Please retry.")
        }
        return try JSONDecoder().decode(type, from: data)
    }
    func search(_ query: String, sessionToken: String) async throws -> [SearchResult] {
        try await decode([SearchResult].self, request: request("v1/autocomplete", body: JSONEncoder().encode(["input": query, "sessionToken": sessionToken])))
    }
    func details(_ id: String, sessionToken: String? = nil) async throws -> PlaceReference {
        try await decode(PlaceReference.self, request: request("v1/places/\(id)", query: sessionToken.map { [URLQueryItem(name: "sessionToken", value: $0)] } ?? []))
    }
    func nearby(_ coordinate: Coordinate) async throws -> [PlaceReference] {
        try await decode([PlaceReference].self, request: request("v1/nearby", body: JSONEncoder().encode(coordinate)))
    }
    func photoURL(_ name: String) async throws -> URL? {
        struct Photo: Decodable { let uri: String }
        let result = try await decode(Photo.self, request: request("v1/photo", body: JSONEncoder().encode(["name": name])))
        return URL(string: result.uri)
    }
    func route(_ input: RouteRequest) async throws -> RoutePlan {
        try await decode(RoutePlan.self, request: request("v1/route", body: JSONEncoder().encode(input)))
    }
    func discover(_ input: DiscoveryRequest) -> AsyncThrowingStream<DiscoveryEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try request("v1/discover", body: JSONEncoder().encode(input))
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                        throw APIProblem(code: "discovery", message: "Stop discovery is unavailable. Check your connection and retry.")
                    }
                    var completed = false
                    for try await line in bytes.lines where !line.isEmpty {
                        try Task.checkCancellation()
                        let event = try JSONDecoder().decode(DiscoveryEvent.self, from: Data(line.utf8))
                        if event.type == "complete" { completed = true }
                        if event.type == "error" { throw APIProblem(code: event.code ?? "discovery", message: event.message ?? "Search failed. Please retry.") }
                        continuation.yield(event)
                    }
                    if !completed { throw APIProblem(code: "interrupted", message: "The search was interrupted. Please retry.") }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
