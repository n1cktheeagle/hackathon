import SwiftUI
import SwiftData

struct RootView: View {
    @Bindable var planner: TripPlanner
    var usesGoogleMaps = false
    @State private var location = LocationService()
    @State private var homeTopHeight: CGFloat = 200
    @State private var homeBottomHeight: CGFloat = 300
    @State private var cameraRevision = 0
    @State private var planningHeaderHeight: CGFloat = 170
    @State private var drawerExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let drawerHeight = drawerHeight(in: geometry)
                ZStack {
                    TripMap(planner: planner,
                            padding: UIEdgeInsets(top: planner.stage == .home ? min(homeTopHeight + geometry.safeAreaInsets.top + 12, geometry.size.height * 0.4) : planningHeaderHeight + geometry.safeAreaInsets.top + 72,
                                                  left: 30, bottom: (planner.stage == .home ? min(homeBottomHeight, geometry.size.height * 0.45) : drawerHeight + (planner.toast == nil ? 0 : 44)) + geometry.safeAreaInsets.bottom + 20, right: 30),
                            usesGoogleMaps: usesGoogleMaps, showsUserLocation: location.coordinate != nil || planner.trip.origin?.id == "current-location",
                            cameraRevision: cameraRevision).ignoresSafeArea()
                    if planner.showingOnboarding {
                        InterestOnboardingView(profile: planner.profile) { planner.showingOnboarding = false }
                    }
                    else if planner.stage == .home { HomeView(planner: planner, location: location, usesGoogleMaps: usesGoogleMaps) { cameraRevision += 1 } }
                    else {
                        VStack(spacing: 0) {
                            planningHeader
                            Spacer(minLength: 8)
                            if let toast = planner.toast {
                                Text(toast).padding(12).background(.white, in: Capsule()).padding(.bottom, 8)
                                    .task(id: toast) { try? await Task.sleep(for: .seconds(2)); if planner.toast == toast { planner.toast = nil } }
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            TripDrawer(expanded: $drawerExpanded, title: planner.stage == .itinerary ? "Itinerary" : "Recommendations",
                                       resizable: planner.stage == .suggestions || planner.stage == .itinerary) { panel }
                                .frame(height: drawerHeight)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .onPreferenceChange(HomeTopHeight.self) { homeTopHeight = $0 }
                .onPreferenceChange(HomeBottomHeight.self) { homeBottomHeight = $0 }
                .onPreferenceChange(PlanningHeaderHeight.self) { planningHeaderHeight = $0 }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: planner.stage)
                .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.88), value: drawerExpanded)
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                if let message = planner.errorMessage { MessageBanner(message: message, dismiss: { planner.errorMessage = nil }).padding(.horizontal, 16).padding(.vertical, 6).background(.white) }
                if let message = planner.warningMessage, planner.stage == .suggestions || planner.stage == .finding {
                    VStack(spacing: 4) {
                        MessageBanner(message: message, dismiss: { planner.warningMessage = nil })
                        if !planner.isBusy && !planner.trip.preferences.customRequest.isEmpty {
                            Button("Retry custom matching") { planner.findStops() }.frame(minHeight: 44)
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 6).background(.white)
                }
            }
        }
        .font(DetourTheme.font(.body)).foregroundStyle(DetourTheme.ink)
        .sheet(item: $planner.sheet) { sheet in
            switch sheet {
            case .search(let purpose):
                if purpose == .destination && planner.isDemo { DestinationBrowser(planner: planner).presentationDetents([.large]) }
                else { PlaceSearchSheet(planner: planner, purpose: purpose).presentationDetents([.large]) }
            case .custom: CustomStopSheet(planner: planner).presentationDetents([.medium, .large])
            case .preferences: PreferencesSheet(planner: planner).presentationDetents([.medium, .large])
            case .details(let place): PlaceDetailsSheet(planner: planner, initialPlace: place).presentationDetents([.large])
            case .saved: SavedTripsSheet(planner: planner, repository: TripRepository(context: modelContext))
            case .interests:
                NavigationStack {
                    InterestOnboardingView(profile: planner.profile, editing: true) { planner.sheet = nil }
                        .navigationTitle("Your interests").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { planner.sheet = nil } } }
                }.presentationDetents([.large])
            }
        }
        .task {
            planner.attach(TripRepository(context: modelContext))
            await planner.loadNearby()
        }
    }
    private var planningHeader: some View {
        VStack(spacing: 6) {
            HStack {
                CircleButton(symbol: "chevron.left", label: "Back") { planner.back() }.accessibilityIdentifier("planner-back")
                Spacer()
                Image("Wordmark").resizable().scaledToFit().frame(width: 74, height: 32).accessibilityLabel("Detour")
                Spacer()
                if planner.stage == .itinerary {
                    CircleButton(symbol: "xmark", label: "Back to recommendations") {
                        planner.stage = planner.suggestions.isEmpty ? .route : .suggestions
                    }.accessibilityIdentifier("close-itinerary")
                } else {
                    CircleButton(symbol: "list.bullet", label: "View itinerary, \(planner.trip.stops.count) stops") { planner.showItinerary() }
                        .overlay(alignment: .bottomTrailing) {
                            if !planner.trip.stops.isEmpty {
                                Text("\(planner.trip.stops.count)").font(DetourTheme.font(.caption2, weight: .semibold))
                                    .frame(width: 18, height: 18).background(DetourTheme.ink, in: Circle()).foregroundStyle(.white).accessibilityHidden(true)
                            }
                        }.disabled(planner.isBusy).accessibilityIdentifier("review-itinerary")
                }
            }.padding(.horizontal, 20).padding(.top, 8)
            RouteContextCard(planner: planner)
        }
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24).fill(.white).ignoresSafeArea(edges: .top)
                .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
        }
        .background { GeometryReader { proxy in Color.clear.preference(key: PlanningHeaderHeight.self, value: proxy.size.height) } }
    }
    private func drawerHeight(in geometry: GeometryProxy) -> CGFloat {
        let fraction: CGFloat = switch planner.stage {
        case .suggestions, .itinerary: dynamicTypeSize.isAccessibilitySize ? 0.60 : (drawerExpanded ? 0.64 : 0.52)
        case .finding: 0.28
        default: 0.19
        }
        let available = geometry.size.height - planningHeaderHeight - (dynamicTypeSize.isAccessibilitySize ? 120 : 160)
        return min(max(140, geometry.size.height * fraction), max(140, available))
    }
    @ViewBuilder private var panel: some View {
        switch planner.stage {
        case .home: EmptyView()
        case .route: RoutePanel(planner: planner)
        case .finding: FindingPanel(planner: planner)
        case .suggestions: SuggestionPanel(planner: planner)
        case .itinerary: ItineraryPanel(planner: planner)
        }
    }
}

struct PlanningHeaderHeight: PreferenceKey {
    static let defaultValue: CGFloat = 170
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct TripDrawer<Content: View>: View {
    @Binding var expanded: Bool
    let title: String
    var resizable = true
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            Button { expanded.toggle() } label: { SheetHandle().frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle()) }
                .buttonStyle(.plain).accessibilityLabel("\(title) drawer")
                .accessibilityValue(expanded ? "Expanded" : "Compact").accessibilityIdentifier("trip-drawer-handle")
                .accessibilityAdjustableAction { direction in if resizable { expanded = direction == .increment } }
                .simultaneousGesture(DragGesture(minimumDistance: 15).onEnded { value in
                    guard abs(value.translation.height) > abs(value.translation.width), abs(value.translation.height) > 25 else { return }
                    expanded = value.translation.height < 0
                })
                .disabled(!resizable)
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24).fill(.white).ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.10), radius: 12, y: -3)
        }
    }
}

#Preview("Detour") {
    RootView(planner: TripPlanner(service: FixtureService(), isDemo: true))
        .modelContainer(for: SavedTrip.self, inMemory: true)
}
