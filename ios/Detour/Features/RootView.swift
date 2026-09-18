import SwiftUI
import SwiftData

struct RootView: View {
    @Bindable var planner: TripPlanner
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    if planner.stage == .home { HomeView(planner: planner) }
                    else {
                        TripMap(planner: planner, bottomPadding: geometry.size.height * panelFraction + geometry.safeAreaInsets.bottom).ignoresSafeArea()
                        VStack(spacing: 0) {
                            HStack {
                                CircleButton(symbol: "chevron.left", label: "Back") { planner.back() }.accessibilityIdentifier("planner-back")
                                Spacer()
                                if planner.stage == .suggestions, planner.current != nil {
                                    Text("Suggestion \(planner.suggestionNumber) of \(planner.batchCount)")
                                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                                        .padding(.horizontal, 14).padding(.vertical, 10).background(.white, in: Capsule())
                                }
                                Spacer()
                                if planner.stage == .itinerary {
                                    ShareLink(item: planner.shareText) { Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44).background(.white, in: Circle()) }.accessibilityLabel("Share itinerary")
                                } else if !planner.trip.stops.isEmpty {
                                    CircleButton(symbol: "list.bullet", label: "View itinerary") { planner.showItinerary() }
                                } else { Color.clear.frame(width: 44, height: 44) }
                            }.padding(.horizontal, 24).padding(.top, 8)
                            Spacer(minLength: 16)
                            if let toast = planner.toast {
                                Text(toast).padding(12).background(.white, in: Capsule()).padding(.bottom, 8)
                                    .task(id: toast) { try? await Task.sleep(for: .seconds(2)); if planner.toast == toast { planner.toast = nil } }
                                    .accessibilityAddTraits(.updatesFrequently)
                            }
                            panel.frame(maxHeight: geometry.size.height * panelFraction)
                        }
                    }
                }
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
        .font(.system(size: bodySize, design: .rounded)).foregroundStyle(DetourTheme.ink)
        .sheet(item: $planner.sheet) { sheet in
            switch sheet {
            case .search(let purpose): PlaceSearchSheet(planner: planner, purpose: purpose).presentationDetents([.large])
            case .custom: CustomStopSheet(planner: planner).presentationDetents([.medium, .large])
            case .preferences: PreferencesSheet(planner: planner).presentationDetents([.medium, .large])
            case .details(let place): PlaceDetailsSheet(planner: planner, initialPlace: place).presentationDetents([.large])
            case .saved: SavedTripsSheet(planner: planner, repository: TripRepository(context: modelContext))
            case .settings: BuildSettingsSheet()
            }
        }
        .task {
            planner.attach(TripRepository(context: modelContext))
            await planner.loadNearby()
        }
    }
    private var panelFraction: CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 0.83 }
        return switch planner.stage {
        case .itinerary: 0.65
        case .suggestions: 0.63
        case .finding: 0.47
        default: 0.57
        }
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

#Preview("Detour · demo") {
    RootView(planner: TripPlanner(service: FixtureService(), isDemo: true))
        .modelContainer(for: SavedTrip.self, inMemory: true)
}
