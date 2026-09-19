import SwiftUI

struct RouteContextCard: View {
    @Bindable var planner: TripPlanner
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(planner.route.map { TripFormat.duration($0.durationSeconds + planner.trip.visitSeconds) } ?? "Planning your route")
                    .font(DetourTheme.font(.title3, weight: .semibold)).accessibilityIdentifier("route-duration")
                if let route = planner.route {
                    Text("· \(TripFormat.distance(route.distanceMeters))")
                        .font(DetourTheme.font(.subheadline)).foregroundStyle(DetourTheme.secondary)
                    if route.isIllustrative == true {
                        Text("Estimated").font(DetourTheme.font(.caption2)).foregroundStyle(DetourTheme.secondary)
                    }
                }
                Spacer(minLength: 0)
                Button { planner.sheet = .preferences } label: { Image(systemName: "slider.horizontal.3").frame(width: 36, height: 36) }
                    .buttonStyle(.plain).accessibilityLabel("Trip preferences").accessibilityIdentifier("route-preferences")
            }
            Text("\(planner.trip.origin?.name ?? "Start") → \(planner.trip.destination?.name ?? "Destination")")
                .font(DetourTheme.font(.footnote, weight: .medium)).foregroundStyle(DetourTheme.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            if !planner.trip.stops.isEmpty {
                Text("Includes \(TripFormat.duration(planner.trip.visitSeconds)) at stops").font(DetourTheme.font(.caption)).foregroundStyle(DetourTheme.secondary)
            }
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(planner.trip.preferences.categories) { category in
                        Label(category.title, systemImage: category.symbol)
                            .font(DetourTheme.font(.caption2, weight: .medium))
                            .padding(.horizontal, 10).padding(.vertical, 6).background(DetourTheme.muted, in: Capsule())
                    }
                    if !planner.trip.preferences.customRequest.isEmpty {
                        Label("Custom", systemImage: "sparkle").font(DetourTheme.font(.caption2))
                            .padding(.horizontal, 10).padding(.vertical, 6).background(DetourTheme.muted, in: Capsule())
                    }
                }
            }.scrollIndicators(.hidden).accessibilityLabel("Stop filters")
        }.padding(.horizontal, 20).padding(.bottom, 14)
            .foregroundStyle(DetourTheme.ink)
    }
}

// This compact panel is used only if planning needs a retry or the user returns to the route.
struct RoutePanel: View {
    let planner: TripPlanner
    var body: some View {
        VStack(spacing: 8) {
            if planner.isBusy {
                HStack(spacing: 10) { ProgressView(); Text("Connecting the dots…").font(DetourTheme.font(.subheadline)) }.padding(12)
            } else {
                PrimaryButton(title: planner.route == nil ? "Try route again" : "Explore stops") {
                    if planner.route == nil { planner.plan() } else { planner.findStops() }
                }.accessibilityIdentifier("find-stops")
            }
        }.padding(.horizontal, 16).padding(.bottom, 12)
    }
}

struct FindingPanel: View {
    let planner: TripPlanner
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if planner.isBusy { ProgressView() }
                Text("Finding places worth a stop").font(DetourTheme.font(.headline))
            }
            Text(planner.progressMessage).font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary).lineLimit(2)
            if !planner.found.isEmpty { Text("\(planner.found.count) stops found").font(DetourTheme.font(.caption)).foregroundStyle(DetourTheme.secondary) }
            if !planner.isBusy {
                PrimaryButton(title: "Try again") { planner.findStops() }
                if !planner.found.isEmpty { Button("Review stops found so far") { planner.showFoundStops() } }
            }
            Button("Cancel") { planner.cancelDiscovery() }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("cancel-discovery")
        }.padding(.horizontal, 20).padding(.bottom, 12)
    }
}
struct SuggestionPanel: View {
    let planner: TripPlanner
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0
    var body: some View {
        VStack(spacing: 10) {
            if let suggestion = planner.current {
                HStack {
                    Text("Worth a stop").font(DetourTheme.font(.subheadline, weight: .semibold))
                    Spacer()
                    Text("\(planner.suggestionNumber) of \(planner.batchCount)").font(DetourTheme.font(.caption)).foregroundStyle(DetourTheme.secondary).accessibilityIdentifier("recommendation-count")
                }.padding(.horizontal, 4)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PlacePhoto(place: suggestion.place, service: planner.service, height: 110)
                            .overlay(alignment: .topTrailing) { RecommendationRating(place: suggestion.place, isDemo: planner.isDemo).padding(10) }
                            .overlay(alignment: .topLeading) {
                                Label("≈ +\(suggestion.addedJourneyMinutes) min", systemImage: "arrow.triangle.turn.up.right.diamond")
                                    .font(DetourTheme.font(.footnote, weight: .medium)).padding(.horizontal, 10).padding(.vertical, 8)
                                    .background(.white, in: Capsule()).padding(10).accessibilityIdentifier("recommendation-added-time")
                                    .accessibilityLabel("Adds about \(suggestion.addedJourneyMinutes) minutes to your journey, including \(suggestion.visitMinutes) minutes at the stop")
                            }
                        VStack(alignment: .leading, spacing: 7) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(suggestion.place.name).font(DetourTheme.font(.title3, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("recommendation-title")
                                Text([planner.isDemo ? RouteDiscoveries.label(for: suggestion.id) : nil, DestinationCatalog.categoryTitle(for: suggestion.place)].compactMap { $0 }.joined(separator: " · "))
                                    .font(DetourTheme.font(.caption, weight: .medium)).foregroundStyle(DetourTheme.secondary).accessibilityIdentifier("recommendation-kind")
                                Text("Adds about \(suggestion.addedJourneyMinutes) min · \(Int(ceil(suggestion.detourSeconds / 60))) min detour + \(suggestion.visitMinutes) min stop")
                                    .font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary).lineLimit(2)
                                    .accessibilityIdentifier("recommendation-time-breakdown")
                            }
                            Text(planner.isDemo ? RouteDiscoveries.recommendationReason(for: suggestion.place, interests: planner.profile.interests) ?? suggestion.reason : suggestion.reason)
                                .font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary).lineLimit(3).accessibilityIdentifier("recommendation-reason")
                            if !planner.isDemo { Text("Google Maps · Tap for details and photo credits").font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary) }
                        }.padding(16)
                    }
                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay { RoundedRectangle(cornerRadius: 24).strokeBorder(DetourTheme.border, lineWidth: 1) }
                    .overlay(alignment: drag < 0 ? .topLeading : .topTrailing) {
                        if abs(drag) > 30 {
                            Text(drag < 0 ? "Skip" : "Add stop").font(DetourTheme.font(.title2, weight: .semibold))
                                .padding(12).background(drag < 0 ? DetourTheme.muted : DetourTheme.green, in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(drag < 0 ? DetourTheme.ink : .white).padding(20).accessibilityHidden(true)
                        }
                    }
                    .rotationEffect(.degrees(reduceMotion ? 0 : Double(drag / 30))).offset(x: drag)
                    .onTapGesture { planner.sheet = .details(suggestion.place) }
                    .gesture(DragGesture(minimumDistance: 15).onChanged { value in
                        guard !planner.isBusy, abs(value.translation.width) > abs(value.translation.height) else { return }
                        drag = value.translation.width
                    }.onEnded { value in
                        let translation = value.translation.width
                        if abs(translation) > 90 && abs(translation) > abs(value.translation.height) && !planner.isBusy {
                            if translation > 0 { planner.add() } else { planner.skip() }
                        }
                        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { drag = 0 }
                    })
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(named: "Add stop") { planner.add() }
                    .accessibilityAction(named: "Skip") { planner.skip() }
                    .accessibilityAction(named: "Show details") { planner.sheet = .details(suggestion.place) }
                }.scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden).id(suggestion.id)
                HStack(spacing: 12) {
                    PrimaryButton(title: "Skip", secondary: true) { planner.skip() }.accessibilityIdentifier("skip-stop")
                    PrimaryButton(title: "Add stop", busy: planner.isBusy) { planner.add() }.accessibilityIdentifier("add-stop")
                }.disabled(planner.isBusy)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "signpost.right").font(.system(size: 32, weight: .light))
                    Text("A little further off the beaten track?").font(DetourTheme.font(.title3, weight: .semibold))
                    Text("No new stops matched this search. Try another category or allow a longer detour.").foregroundStyle(DetourTheme.secondary).multilineTextAlignment(.center)
                    PrimaryButton(title: "Adjust preferences") { planner.stage = .route }
                }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 24))
            }
        }.padding(.horizontal, 16).padding(.bottom, 12)
    }
}
struct RecommendationRating: View {
    let place: PlaceReference
    var isDemo: Bool
    private var rating: Double? { place.rating ?? (isDemo ? Fixtures.mockRatings[place.id] : nil) }
    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if let rating {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill").font(.system(size: 13, weight: .semibold)).accessibilityHidden(true)
                    Text(String(format: "%.1f", rating)).font(DetourTheme.font(.headline))
                }.padding(.horizontal, 10).padding(.vertical, 8)
                    .background(.white, in: Capsule()).accessibilityIdentifier("recommendation-rating")
                    .accessibilityElement(children: .ignore).accessibilityLabel("Rating \(String(format: "%.1f", rating)) out of 5")
                if !isDemo { Text("Google").font(DetourTheme.font(.caption2)).foregroundStyle(DetourTheme.secondary) }
                if let count = place.ratingCount {
                    Text("\(count.formatted()) reviews").font(DetourTheme.font(.caption2)).foregroundStyle(DetourTheme.secondary)
                }
            }
        }
    }
}
struct ItineraryPanel: View {
    @Bindable var planner: TripPlanner
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your itinerary").font(DetourTheme.font(.title3, weight: .semibold)).accessibilityIdentifier("itinerary-title")
                    Text("\(planner.trip.stops.count) \(planner.trip.stops.count == 1 ? "stop" : "stops") · \(TripFormat.duration((planner.route?.durationSeconds ?? 0) + planner.trip.visitSeconds)) including stops")
                        .font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary)
                }
                Spacer()
                ShareLink(item: planner.shareText) {
                    Image(systemName: "square.and.arrow.up").frame(width: 44, height: 44)
                }.accessibilityLabel("Share itinerary")
            }.padding(.horizontal, 4)
            List {
                HStack(spacing: 14) {
                    Image(systemName: "circle").frame(width: 24)
                    Text(planner.trip.origin?.name ?? "Start")
                    Spacer()
                    Text("Leave \(TripFormat.time(planner.trip.departure))").font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary)
                }.listRowSeparator(.hidden).listRowBackground(DetourTheme.muted).listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                ForEach(Array(planner.trip.stops.enumerated()), id: \.element.id) { index, stop in
                    Button { planner.sheet = .details(stop.place) } label: {
                        HStack(alignment: .center, spacing: 14) {
                            Text(stop.visited ? "✓" : "\(index + 1)").font(DetourTheme.font(.subheadline, weight: .medium))
                                .frame(width: 24, height: 24).background(DetourTheme.ink, in: Circle()).foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(stop.place.name).font(DetourTheme.font(.body, weight: .medium)).foregroundStyle(DetourTheme.ink)
                                if let date = arrival(at: index) {
                                    Text("\(TripFormat.time(date)) – \(TripFormat.time(date.addingTimeInterval(Double(stop.visitMinutes * 60))))")
                                        .font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(DetourTheme.font(.caption)).foregroundStyle(DetourTheme.secondary)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("itinerary-stop-\(index)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) { Button("Remove", role: .destructive) { planner.removeStop(stop.id) }.disabled(planner.isBusy) }
                        .swipeActions(edge: .leading) { Button(stop.visited ? "Unvisit" : "Visited") { planner.visited(stop.id) }.tint(DetourTheme.green) }
                        .listRowSeparator(.hidden).listRowBackground(DetourTheme.muted).listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
                HStack(spacing: 14) {
                    Image(systemName: "circle.inset.filled").frame(width: 24)
                    Text(planner.trip.destination?.name ?? "Destination")
                    Spacer()
                    if let date = planner.route?.arrivals(for: planner.trip).last { Text("Arrive \(TripFormat.time(date))").font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary) }
                }.listRowSeparator(.hidden).listRowBackground(DetourTheme.muted).listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }.listStyle(.plain).scrollContentBackground(.hidden).frame(minHeight: 140)
                .background(DetourTheme.muted, in: RoundedRectangle(cornerRadius: 16)).clipShape(RoundedRectangle(cornerRadius: 16))
            HStack(spacing: 12) {
                PrimaryButton(title: "More stops", secondary: true) { planner.findStops() }.disabled(planner.isBusy)
                PrimaryButton(title: planner.trip.stops.contains(where: \.visited) ? "Continue" : "Start", busy: planner.isBusy) { navigate(planner.nextPlace) }
                    .disabled(planner.isBusy).accessibilityIdentifier("start-driving")
            }
        }.padding(.horizontal, 16).padding(.bottom, 12)
    }
    private func arrival(at index: Int) -> Date? {
        let dates = planner.route?.arrivals(for: planner.trip) ?? []
        return dates.indices.contains(index) ? dates[index] : nil
    }
    private func navigate(_ place: PlaceReference?) {
        guard let place, let url = NavigationLinkBuilder.directions(to: place, isDemo: planner.isDemo) else { return }
        openURL(url)
    }
}

enum NavigationLinkBuilder {
    static func directions(to place: PlaceReference, isDemo: Bool) -> URL? {
        var components = URLComponents(string: "https://www.google.com/maps/dir/")!
        var items = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "destination", value: "\(place.coordinate.latitude),\(place.coordinate.longitude)")]
        if !isDemo && place.id != "current-location" { items.append(URLQueryItem(name: "destination_place_id", value: place.id)) }
        components.queryItems = items
        return components.url
    }
}
