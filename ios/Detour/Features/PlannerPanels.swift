import SwiftUI

struct RoutePanel: View {
    @Bindable var planner: TripPlanner
    var body: some View {
        VStack(spacing: 0) {
            SheetHandle()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(planner.route.map { TripFormat.duration($0.durationSeconds) } ?? "Finding your route")
                                .font(.system(.title2, design: .rounded, weight: .semibold)).accessibilityIdentifier("route-duration")
                            Text(planner.route.map { "\(TripFormat.distance($0.distanceMeters)) · \(planner.trip.origin?.name ?? "") to \(planner.trip.destination?.name ?? "")" } ?? "One moment while we connect the dots.")
                                .foregroundStyle(DetourTheme.secondary)
                        }
                        Spacer(minLength: 4)
                        Button { planner.sheet = .preferences } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }.accessibilityLabel("Trip preferences")
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stop for").fontWeight(.medium)
                        FlowLayout(spacing: 8) {
                            ForEach(StopCategory.allCases) { category in
                                let selected = planner.trip.preferences.categories.contains(category)
                                Button { planner.toggle(category) } label: {
                                    Label(category.title, systemImage: category.symbol)
                                        .padding(.horizontal, 14).padding(.vertical, 12)
                                        .background(selected ? DetourTheme.ink : DetourTheme.muted, in: Capsule())
                                        .foregroundStyle(selected ? .white : DetourTheme.ink)
                                }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
                            }
                            Button { planner.sheet = .custom } label: {
                                Label("Custom", systemImage: "sparkle").padding(.horizontal, 14).padding(.vertical, 12)
                                    .background(planner.trip.preferences.customRequest.isEmpty ? DetourTheme.muted : DetourTheme.ink, in: Capsule())
                                    .foregroundStyle(planner.trip.preferences.customRequest.isEmpty ? DetourTheme.ink : .white)
                            }.buttonStyle(.plain).accessibilityIdentifier("custom-stop")
                        }
                        if !planner.trip.preferences.customRequest.isEmpty {
                            Button { planner.sheet = .custom } label: {
                                HStack(alignment: .top) { Text(planner.trip.preferences.customRequest).multilineTextAlignment(.leading); Spacer(); Image(systemName: "pencil") }
                                    .foregroundStyle(DetourTheme.secondary)
                            }.buttonStyle(.plain)
                        }
                    }
                    Button { planner.sheet = .preferences } label: {
                        HStack { Text("Leave \(TripFormat.time(planner.trip.departure))"); Spacer(); Text("Up to +\(planner.trip.preferences.maxDetourMinutes) min"); Image(systemName: "chevron.right").font(.caption) }
                            .foregroundStyle(DetourTheme.secondary).font(.system(.subheadline, design: .rounded))
                    }
                    if !planner.trip.stops.isEmpty { Button("View itinerary · \(planner.trip.stops.count) stops") { planner.showItinerary() } }
                    PrimaryButton(title: planner.route == nil && !planner.isBusy ? "Try route again" : "Find stops along the way", busy: planner.isBusy) {
                        if planner.route == nil { planner.plan() } else { planner.findStops() }
                    }.disabled(planner.isBusy || (!planner.canDiscover && planner.route != nil)).accessibilityIdentifier("find-stops")
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }.scrollBounceBehavior(.basedOnSize)
        }.background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
    }
}
struct FindingPanel: View {
    let planner: TripPlanner
    var body: some View {
        VStack(spacing: 0) {
            SheetHandle()
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) { if planner.isBusy { ProgressView() }; Text(planner.progressMessage).font(.system(.title3, design: .rounded, weight: .semibold)) }
                Text("\(planner.found.count) found so far").foregroundStyle(DetourTheme.secondary)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(planner.found) { suggestion in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                Text(suggestion.place.name)
                                Spacer()
                                Text(suggestion.place.category.title).foregroundStyle(DetourTheme.secondary)
                            }.padding(.vertical, 16)
                            Divider().overlay(DetourTheme.border)
                        }
                        if planner.isBusy {
                            HStack { Circle().fill(DetourTheme.muted).frame(width: 16, height: 16); RoundedRectangle(cornerRadius: 8).fill(DetourTheme.muted).frame(height: 14); Spacer(minLength: 40) }.padding(.vertical, 18).accessibilityHidden(true)
                        }
                    }
                }.frame(maxHeight: 170)
                if !planner.isBusy {
                    PrimaryButton(title: "Try again") { planner.findStops() }
                    if !planner.found.isEmpty { Button("Review stops found so far") { planner.showFoundStops() } }
                }
                Button("Cancel") { planner.cancelDiscovery() }.frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("cancel-discovery")
            }.padding(.horizontal, 24).padding(.bottom, 24)
        }.background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
    }
}
struct SuggestionPanel: View {
    let planner: TripPlanner
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0
    var body: some View {
        VStack(spacing: 16) {
            if let suggestion = planner.current {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        PlacePhoto(place: suggestion.place, service: planner.service, height: 180)
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(suggestion.place.name).font(.system(.title3, design: .rounded, weight: .semibold))
                                Text("\(suggestion.place.category.title) · \(suggestion.place.subtitle) · \(TripFormat.duration(suggestion.arrivalOffsetSeconds)) in")
                                    .foregroundStyle(DetourTheme.secondary).lineLimit(2)
                            }
                            FlowLayout(spacing: 16) {
                                Label("+\(Int(ceil(suggestion.detourSeconds / 60))) min off route", systemImage: "arrow.triangle.turn.up.right.diamond")
                                if let rating = suggestion.place.rating { Label(String(format: "%.1f", rating) + (suggestion.place.ratingCount.map { " · \($0) reviews" } ?? ""), systemImage: "star") }
                            }
                            Text(suggestion.reason).foregroundStyle(DetourTheme.secondary).fixedSize(horizontal: false, vertical: true)
                            if !planner.isDemo { Text("Google Maps · Tap for details and photo credits").font(.system(.footnote, design: .rounded)).foregroundStyle(DetourTheme.secondary) }
                        }.padding(20)
                    }
                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(alignment: drag < 0 ? .topLeading : .topTrailing) {
                        if abs(drag) > 30 {
                            Text(drag < 0 ? "Skip" : "Add stop").font(.system(.title2, design: .rounded, weight: .semibold))
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
                }.scrollBounceBehavior(.basedOnSize).scrollIndicators(.hidden).defaultScrollAnchor(.bottom, for: .alignment)
                HStack(spacing: 12) {
                    PrimaryButton(title: "Skip", secondary: true) { planner.skip() }.accessibilityIdentifier("skip-stop")
                    PrimaryButton(title: "Add stop", busy: planner.isBusy) { planner.add() }.accessibilityIdentifier("add-stop")
                }.disabled(planner.isBusy)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "signpost.right").font(.system(size: 32, weight: .light))
                    Text("A little further off the beaten track?").font(.system(.title3, design: .rounded, weight: .semibold))
                    Text("No new stops matched this search. Try another category or allow a longer detour.").foregroundStyle(DetourTheme.secondary).multilineTextAlignment(.center)
                    PrimaryButton(title: "Adjust preferences") { planner.stage = .route }
                    Button("View itinerary") { planner.showItinerary() }.frame(minHeight: 44)
                }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 24))
            }
        }.padding(.horizontal, 24).padding(.bottom, 16).padding(.top, 12)
    }
}
struct ItineraryPanel: View {
    @Bindable var planner: TripPlanner
    @Environment(\.openURL) private var openURL
    var body: some View {
        VStack(spacing: 0) {
            SheetHandle()
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(TripFormat.duration((planner.route?.durationSeconds ?? 0) + planner.trip.visitSeconds)).font(.system(.title, design: .rounded, weight: .semibold))
                    Text("\(TripFormat.duration(planner.route?.durationSeconds ?? 0)) driving · \(TripFormat.duration(planner.trip.visitSeconds)) at stops")
                        .foregroundStyle(DetourTheme.secondary)
                }
                Spacer()
                Button { planner.sheet = .preferences } label: { Image(systemName: "clock").frame(width: 44, height: 44) }.accessibilityLabel("Change departure time")
            }.padding(.horizontal, 24).padding(.bottom, 12)
            List {
                HStack(spacing: 14) {
                    Image(systemName: "circle").frame(width: 24)
                    Text(planner.trip.origin?.name ?? "Start")
                    Spacer()
                    Text("Leave \(TripFormat.time(planner.trip.departure))").foregroundStyle(DetourTheme.secondary)
                }.listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
                ForEach(Array(planner.trip.stops.enumerated()), id: \.element.id) { index, stop in
                    Button { planner.sheet = .details(stop.place) } label: {
                        HStack(alignment: .center, spacing: 14) {
                            Text(stop.visited ? "✓" : "\(index + 1)").font(.system(.subheadline, design: .rounded, weight: .medium))
                                .frame(width: 24, height: 24).background(DetourTheme.ink, in: Circle()).foregroundStyle(.white)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(stop.place.name).foregroundStyle(DetourTheme.ink)
                                if let date = arrival(at: index) {
                                    Text("\(TripFormat.time(date)) – \(TripFormat.time(date.addingTimeInterval(Double(stop.visitMinutes * 60))))")
                                        .foregroundStyle(DetourTheme.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(DetourTheme.secondary)
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("itinerary-stop-\(index)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) { Button("Remove", role: .destructive) { planner.removeStop(stop.id) }.disabled(planner.isBusy) }
                        .swipeActions(edge: .leading) { Button(stop.visited ? "Unvisit" : "Visited") { planner.visited(stop.id) }.tint(DetourTheme.green) }
                        .listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
                }
                HStack(spacing: 14) {
                    Image(systemName: "circle.inset.filled").frame(width: 24)
                    Text(planner.trip.destination?.name ?? "Destination")
                    Spacer()
                    if let date = planner.route?.arrivals(for: planner.trip).last { Text("Arrive \(TripFormat.time(date))").foregroundStyle(DetourTheme.secondary) }
                }.listRowSeparator(.hidden).listRowInsets(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
            }.listStyle(.plain).scrollContentBackground(.hidden).frame(minHeight: 140)
            VStack(spacing: 4) {
                PrimaryButton(title: planner.trip.stops.contains(where: \.visited) ? "Continue driving" : "Start driving", busy: planner.isBusy) { navigate(planner.nextPlace) }
                    .disabled(planner.isBusy).accessibilityIdentifier("start-driving")
                Button("Keep looking for stops") { planner.findStops() }.frame(minHeight: 44).disabled(planner.isBusy)
            }.padding(.horizontal, 24).padding(.bottom, 16).padding(.top, 8)
        }.background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
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
        var items = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "destination", value: "\(place.coordinate.latitude),\(place.coordinate.longitude)"), URLQueryItem(name: "travelmode", value: "driving"), URLQueryItem(name: "dir_action", value: "navigate")]
        if !isDemo && place.id != "current-location" { items.append(URLQueryItem(name: "destination_place_id", value: place.id)) }
        components.queryItems = items
        return components.url
    }
}
