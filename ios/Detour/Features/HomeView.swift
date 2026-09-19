import SwiftUI

struct HomeView: View {
    @Bindable var planner: TripPlanner
    @Bindable var location: LocationService
    var usesGoogleMaps = false
    var recenter: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var topHeight: CGFloat = 200
    @State private var bottomHeight: CGFloat = 300

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView { controls }.scrollIndicators(.hidden)
                } else { controls }
            }
            .onPreferenceChange(HomeTopHeight.self) { topHeight = $0 }
            .onPreferenceChange(HomeBottomHeight.self) { bottomHeight = $0 }
        }
        .task {
            guard !location.attemptedInitialLocation,
                  !ProcessInfo.processInfo.arguments.contains("--uitesting"),
                  ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
            location.attemptedInitialLocation = true
            // A late GPS response must not replace a starting point the user has chosen.
            let originalOrigin = planner.trip.origin
            let originalDestination = planner.trip.destination
            do {
                let coordinate = try await location.current()
                try Task.checkCancellation()
                if planner.stage == .home, planner.sheet == nil,
                   planner.trip.origin == originalOrigin, planner.trip.destination == originalDestination {
                    selectCurrentLocation(coordinate)
                }
            } catch { }
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                header
                routeInputs
            }
            .padding(.horizontal, 20).padding(.top, 8)
            .background { GeometryReader { proxy in Color.clear.preference(key: HomeTopHeight.self, value: proxy.size.height) } }
            if dynamicTypeSize.isAccessibilitySize { Color.clear.frame(height: 160) }
            else { Spacer(minLength: 24) }
            discovery
            .padding(.bottom, 12)
            .background { GeometryReader { proxy in Color.clear.preference(key: HomeBottomHeight.self, value: proxy.size.height) } }
        }
    }

    private var header: some View {
        HStack {
            Image("Wordmark").resizable().scaledToFit().frame(width: 78, height: 34).accessibilityLabel("Detour")
                .padding(.horizontal, 12).padding(.vertical, 5).background(.white, in: Capsule())
            Spacer()
            CircleButton(symbol: "suitcase.fill", label: "My trips") { planner.sheet = .saved }
                .accessibilityIdentifier("saved-trips")
            CircleButton(symbol: "slider.horizontal.3", label: "Your interests") { planner.sheet = .interests }
                .accessibilityIdentifier("edit-interests")
        }.buttonStyle(.plain)
    }

    private var routeInputs: some View {
        HStack(spacing: 14) {
            VStack(spacing: 7) {
                Circle().fill(DetourTheme.ink).frame(width: 9, height: 9)
                Rectangle().fill(DetourTheme.border).frame(width: 2, height: 40)
                Rectangle().fill(DetourTheme.ink).frame(width: 9, height: 9)
            }.frame(width: 12).accessibilityHidden(true)
            VStack(spacing: 0) {
                input(label: "From", value: planner.trip.origin?.name ?? "Choose a starting point", purpose: .origin)
                Divider().overlay(DetourTheme.border)
                input(label: planner.trip.destination == nil ? nil : "To", value: planner.trip.destination?.name ?? "Where to?", purpose: .destination)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 3)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
    }

    private func input(label: String?, value: String, purpose: SearchPurpose) -> some View {
        Button { planner.sheet = .search(purpose) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    if let label { Text(label).font(DetourTheme.font(.caption)).foregroundStyle(DetourTheme.secondary) }
                    Text(value).font(DetourTheme.font(.body, weight: .medium))
                        .multilineTextAlignment(.leading).lineLimit(2)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: purpose == .destination ? "magnifyingglass" : "chevron.right")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(DetourTheme.secondary).accessibilityHidden(true)
            }.padding(.vertical, 13).frame(minHeight: 58).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityIdentifier(purpose == .origin ? "origin-field" : "destination-field")
            .accessibilityLabel("\(purpose == .origin ? "Starting point" : "Destination"), \(value)")
    }

    private var discovery: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(planner.isDemo ? "Explore Cape Town" : "Explore nearby").font(DetourTheme.font(.title3, weight: .medium))
                if !dynamicTypeSize.isAccessibilitySize {
                    Text(planner.isDemo ? "Discover places around Cape Town" : "Find a reason to take the scenic route.")
                        .font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary)
                }
            }.padding(.horizontal, 18)
            if !dynamicTypeSize.isAccessibilitySize {
                if planner.loadingNearby {
                    ProgressView("Finding nearby places").frame(maxWidth: .infinity, minHeight: 140)
                } else if planner.nearby.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(planner.trip.origin == nil ? "Choose your starting point to discover places nearby." : "Nearby places are unavailable. You can still plan a route.")
                            .font(DetourTheme.font(.subheadline)).foregroundStyle(DetourTheme.secondary)
                        if planner.trip.origin != nil { Button("Try again") { Task { await planner.loadNearby() } }.frame(minHeight: 44) }
                    }.padding(.horizontal, 18).padding(.vertical, 12)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(planner.nearby) { place in
                                Button { planner.sheet = .details(place) } label: {
                                    PlaceDiscoveryRow(place: place, service: planner.service, compact: true, showGoogleRating: !planner.isDemo, showMockRating: planner.isDemo).frame(width: 284)
                                }.buttonStyle(.plain).accessibilityIdentifier("nearby-\(place.id)")
                            }
                        }.padding(.horizontal, 18)
                    }.scrollIndicators(.hidden)
                }
            } else if !planner.nearby.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(planner.nearby) { place in
                            Button { planner.sheet = .details(place) } label: {
                                Text(place.name).font(DetourTheme.font(.subheadline, weight: .medium))
                                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                    .padding(12).frame(width: 270, alignment: .leading)
                                    .background(DetourTheme.muted, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).accessibilityIdentifier("nearby-\(place.id)")
                        }
                    }.padding(.horizontal, 18)
                }.scrollIndicators(.hidden)
            }
            PrimaryButton(title: planner.trip.canPlan ? "Plan my route" : "Choose a destination") {
                if planner.trip.canPlan { planner.plan() }
                else { planner.sheet = .search(planner.trip.origin == nil ? .origin : .destination) }
            }.fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(planner.trip.canPlan ? "plan-trip" : "choose-destination")
                .padding(.horizontal, 18)
        }
        .padding(.vertical, 18).background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.08), radius: 16, y: 4).padding(.horizontal, 12)
    }

    private func selectCurrentLocation(_ coordinate: Coordinate) {
        recenter()
        planner.select(PlaceReference(id: "current-location", name: "Current location", subtitle: "Start from here", coordinate: coordinate), for: .origin)
    }
}

struct HomeTopHeight: PreferenceKey {
    static let defaultValue: CGFloat = 200
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
struct HomeBottomHeight: PreferenceKey {
    static let defaultValue: CGFloat = 300
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

#Preview("Home · stationary") {
    let planner = TripPlanner(service: FixtureService(), isDemo: true)
    planner.nearby = Fixtures.nearby
    planner.showingOnboarding = false
    return RootView(planner: planner).modelContainer(for: SavedTrip.self, inMemory: true)
        .foregroundStyle(DetourTheme.ink).tint(DetourTheme.ink)
}
