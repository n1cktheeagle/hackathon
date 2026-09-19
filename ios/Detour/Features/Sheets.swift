import SwiftUI

struct PlaceSearchSheet: View {
    let planner: TripPlanner
    let purpose: SearchPurpose
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var sessionToken = UUID().uuidString
    @State private var searching = false
    @State private var selecting = false
    @State private var selectionTask: Task<Void, Never>?
    @State private var error: String?
    @State private var location = LocationService()
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 20)).accessibilityHidden(true)
                    TextField(purpose == .origin ? "Search a starting point" : "Search a destination", text: $query)
                        .focused($focused).autocorrectionDisabled().submitLabel(.search).accessibilityIdentifier("place-search")
                    if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundStyle(DetourTheme.secondary).frame(minWidth: 44, minHeight: 44) }.accessibilityLabel("Clear search") }
                }.padding(16).background(DetourTheme.muted, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 24)
                if let error { MessageBanner(message: error).padding(.horizontal, 24) }
                if searching || selecting { ProgressView().padding(8) }
                List {
                    if purpose == .origin && query.isEmpty {
                        Button {
                            selectionTask = Task {
                                do {
                                    if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                                        planner.select(PlaceReference(id: "current-location", name: "Current location", subtitle: "", coordinate: Fixtures.capeTown.coordinate), for: purpose)
                                    }
                                    else {
                                        let coordinate = try await location.current()
                                        try Task.checkCancellation()
                                        planner.select(PlaceReference(id: "current-location", name: "Current location", subtitle: "Start from here", coordinate: coordinate), for: purpose)
                                    }
                                    dismiss()
                                } catch { self.error = error.localizedDescription }
                            }
                        } label: { Label("Current location", systemImage: "location").padding(.vertical, 8) }.disabled(location.requesting)
                            .accessibilityIdentifier("search-current-location").accessibilityLabel("Current location")
                    }
                    if query.isEmpty && planner.isDemo {
                        ForEach([Fixtures.knysna, Fixtures.capeTown, Fixtures.johannesburg, Fixtures.durban]) { place in
                            Button { choose(place.id) } label: { row(place.name, place.subtitle) }
                        }
                    } else {
                        ForEach(results) { result in
                            Button { choose(result.id) } label: { row(result.name, result.subtitle) }.accessibilityIdentifier("search-result-\(result.id)")
                        }
                        if query.count >= 2 && !searching && results.isEmpty && error == nil { Text("No places found. Try another spelling or a nearby town.").foregroundStyle(DetourTheme.secondary).listRowSeparator(.hidden) }
                    }
                }.listStyle(.plain).disabled(selecting)
                if !planner.isDemo { Text("Google Maps").font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary).padding(.bottom, 8) }
            }
            .navigationTitle(purpose == .origin ? "Starting from" : "Missioning to").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task { if !planner.isDemo { focused = true } }
            .onDisappear { selectionTask?.cancel() }
            .task(id: query) {
                error = nil; results = []
                guard query.count >= 2 else { searching = false; return }
                searching = true
                do {
                    try await Task.sleep(for: .milliseconds(300))
                    let found = try await planner.service.search(query, sessionToken: sessionToken)
                    try Task.checkCancellation()
                    results = found; searching = false
                } catch {
                    if !Task.isCancelled { self.error = error.localizedDescription; searching = false }
                }
            }
        }
    }
    private func row(_ name: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse").font(.system(size: 22)).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) { Text(name).foregroundStyle(DetourTheme.ink); Text(subtitle).foregroundStyle(DetourTheme.secondary) }
            Spacer(minLength: 0); Image(systemName: "arrow.up.left").font(.system(size: 18)).foregroundStyle(DetourTheme.secondary).accessibilityHidden(true)
        }.padding(.vertical, 8)
    }
    private func choose(_ id: String) {
        selecting = true; error = nil
        selectionTask?.cancel()
        selectionTask = Task {
            do {
                let place = try await planner.service.details(id, sessionToken: sessionToken)
                try Task.checkCancellation()
                planner.select(place, for: purpose); dismiss()
            } catch { self.error = error.localizedDescription }
            selecting = false
        }
    }
}
struct CustomStopSheet: View {
    @Bindable var planner: TripPlanner
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Say what you're after and the stops will match it.").foregroundStyle(DetourTheme.secondary)
                TextEditor(text: $text).focused($focused).frame(minHeight: 100, maxHeight: 180)
                    .padding(12).scrollContentBackground(.hidden).background(DetourTheme.muted, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Describe your stop").accessibilityIdentifier("custom-request")
                    .onChange(of: text) { _, value in if value.count > 600 { text = String(value.prefix(600)) } }
                FlowLayout {
                    ForEach(["A swim spot", "Dog-friendly lunch", "EV charger with coffee"], id: \.self) { example in
                        Button(example) { text = example }.padding(.horizontal, 12).padding(.vertical, 10).background(DetourTheme.muted, in: Capsule())
                    }
                }
                Spacer(minLength: 0)
                PrimaryButton(title: "Use this request") {
                    planner.trip.preferences.customRequest = text.trimmingCharacters(in: .whitespacesAndNewlines); planner.save(); dismiss()
                    if planner.stage != .home { planner.findStops() }
                }
            }.padding(24).navigationTitle("Custom stop").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onAppear { text = planner.trip.preferences.customRequest }
        }
    }
}
struct PreferencesSheet: View {
    @Bindable var planner: TripPlanner
    @Environment(\.dismiss) private var dismiss
    @State private var initialPreferences = TripPreferences()
    @State private var initialDeparture = Date()
    var body: some View {
        NavigationStack {
            Form {
                Section("Stop for") {
                    ForEach(StopCategory.allCases) { category in
                        Toggle(isOn: Binding(get: { planner.trip.preferences.categories.contains(category) }, set: { _ in planner.toggle(category) })) {
                            Label(category.title, systemImage: category.symbol)
                        }
                    }
                    Button("Describe a custom stop") { planner.sheet = .custom }.accessibilityIdentifier("custom-stop")
                }
                Section("Your trip") {
                    DatePicker("Departure", selection: $planner.trip.departure, displayedComponents: [.date, .hourAndMinute])
                    Text(planner.isDemo ? "Times are shown in South African local time. Apple Maps driving estimates can change with traffic." : "Times are shown in South African local time. Driving estimates exclude live traffic.").foregroundStyle(DetourTheme.secondary)
                }
                Section("Room for a detour") {
                    Stepper("Up to \(planner.trip.preferences.maxDetourMinutes) extra minutes per stop", value: $planner.trip.preferences.maxDetourMinutes, in: 5...120, step: 5)
                }
                Section("Trip name") { TextField("My mission", text: $planner.trip.title).onChange(of: planner.trip.title) { _, value in if value.count > 80 { planner.trip.title = String(value.prefix(80)) } } }
            }
            .environment(\.timeZone, TimeZone(identifier: "Africa/Johannesburg")!)
            .navigationTitle("Trip preferences").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") {
                planner.save(); dismiss()
                if planner.stage != .home && planner.stage != .itinerary {
                    if initialDeparture != planner.trip.departure { planner.plan() }
                    else if initialPreferences != planner.trip.preferences { planner.findStops() }
                }
            } } }
            .onAppear { initialPreferences = planner.trip.preferences; initialDeparture = planner.trip.departure }
            .onDisappear { planner.save() }
        }
    }
}
struct PlaceDetailsSheet: View {
    @Bindable var planner: TripPlanner
    let initialPlace: PlaceReference
    @State private var fetched: PlaceReference?
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    private var place: PlaceReference { fetched ?? initialPlace }
    private var stopIndex: Int? { planner.trip.stops.firstIndex { $0.id == place.id } }
    private var suggestion: StopSuggestion? { planner.current?.id == place.id ? planner.current : nil }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PlacePhoto(place: place, service: planner.service, height: 220).clipShape(RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(place.name).font(DetourTheme.font(.title2, weight: .semibold))
                        Text("\(place.category.title) · \(place.subtitle)").foregroundStyle(DetourTheme.secondary)
                    }
                    if let error { MessageBanner(message: error) }
                    if let suggestion {
                        Text(suggestion.reason)
                        detailRow("Adds to your journey", "About \(suggestion.addedJourneyMinutes) min")
                        detailRow("Extra travel", "\(Int(ceil(suggestion.detourSeconds / 60))) min")
                        detailRow("Suggested stay", "\(suggestion.visitMinutes) min")
                        if !suggestion.unverifiedRequirements.isEmpty { Text("Not confirmed: \(suggestion.unverifiedRequirements.joined(separator: ", "))").foregroundStyle(DetourTheme.secondary) }
                    }
                    if let rating = place.rating ?? (planner.isDemo ? Fixtures.mockRatings[place.id] : nil) { detailRow(planner.isDemo ? "Rating" : "Google rating", String(format: "%.1f", rating) + (place.ratingCount.map { " from \($0) reviews" } ?? "")) }
                    if !planner.isDemo || !place.hours.isEmpty { detailRow("Hours", place.hours.isEmpty ? "Hours unavailable" : place.hours.joined(separator: "\n")) }
                    if let open = place.openNow { Text(open ? "Open now · check hours for your arrival" : "Closed now · check hours for your arrival").foregroundStyle(DetourTheme.secondary) }
                    if !planner.isDemo || !place.amenities.isEmpty { detailRow("Good for", place.amenities.isEmpty ? "Amenities have not been confirmed" : place.amenities.joined(separator: ", ")) }
                    if let index = stopIndex {
                        Stepper("Stay for \(planner.trip.stops[index].visitMinutes) min", value: $planner.trip.stops[index].visitMinutes, in: 5...240, step: 5)
                            .onChange(of: planner.trip.stops[index].visitMinutes) { _, _ in planner.save() }
                        Button(planner.trip.stops[index].visited ? "Mark as not visited" : "Mark visited") { planner.visited(place.id) }
                        PrimaryButton(title: "Navigate to this stop") { if let url = NavigationLinkBuilder.directions(to: place, isDemo: planner.isDemo) { openURL(url) } }
                        Button("Remove from trip", role: .destructive) { planner.removeStop(place.id); dismiss() }.frame(minHeight: 44).disabled(planner.isBusy)
                    }
                    ForEach(Array(place.reviews.enumerated()), id: \.offset) { _, review in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("“\(review.text)”")
                            HStack {
                                if let photo = review.author.photoURI, let url = URL(string: photo) {
                                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "person.crop.circle") }
                                        .frame(width: 28, height: 28).clipShape(Circle()).accessibilityHidden(true)
                                }
                                if let uri = review.author.uri, let url = URL(string: uri) { Link(review.author.name, destination: url) }
                                else { Text(review.author.name) }
                                Text("· \(review.relativeTime)")
                            }.foregroundStyle(DetourTheme.secondary)
                            if let uri = review.uri, let url = URL(string: uri) { Link("View original review", destination: url) }
                        }
                    }
                    if !planner.isDemo {
                        VStack(alignment: .leading, spacing: 8) {
                            if let url = URL(string: place.mapsURI) { Link("Place details on Google Maps", destination: url) }
                            if let uri = place.photoURI, let url = URL(string: uri) { Link("View original photo", destination: url) }
                            ForEach(Array(place.photoAttributions.enumerated()), id: \.offset) { _, credit in
                                if let uri = credit.uri, let url = URL(string: uri) { Link("Photo: \(credit.name)", destination: url) }
                                else { Text("Photo: \(credit.name)") }
                            }
                            if !place.reviews.isEmpty { Text("Reviews supplied by Google Maps, ordered by relevance.") }
                        }.font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary)
                    }
                }.padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                if suggestion != nil {
                    HStack(spacing: 12) {
                        PrimaryButton(title: "Skip", secondary: true) { planner.skip() }
                        PrimaryButton(title: "Add stop", busy: planner.isBusy) { planner.add() }
                    }.disabled(planner.isBusy).padding(24).background(.white)
                } else if planner.stage == .home {
                    PrimaryButton(title: "Make this the destination") { planner.select(place, for: .destination); dismiss() }.padding(24).background(.white)
                }
            }
            .navigationTitle("A closer look").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: initialPlace.id) {
                do { fetched = try await planner.service.details(initialPlace.id, sessionToken: nil) }
                catch { if !Task.isCancelled { self.error = "Some details couldn't be refreshed. Please check the source before travelling." } }
            }
        }
    }
    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title).foregroundStyle(DetourTheme.secondary).frame(width: 68, alignment: .leading)
            Text(value).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
struct SavedTripsSheet: View {
    let planner: TripPlanner
    let repository: TripRepository
    @State private var trips: [SavedTrip] = []
    @State private var renaming: SavedTrip?
    @State private var newTitle = ""
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if let error { Text(error).foregroundStyle(.red) }
                if trips.isEmpty { ContentUnavailableView("Your next mission starts here", systemImage: "bookmark", description: Text("Trips are saved on this iPhone as you plan.")) }
                ForEach(trips) { saved in
                    Button { planner.restore(saved) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(saved.title).foregroundStyle(DetourTheme.ink)
                            Text(saved.updatedAt, style: .date).foregroundStyle(DetourTheme.secondary)
                        }.padding(.vertical, 6)
                    }.disabled(planner.isBusy)
                        .swipeActions { Button("Delete", role: .destructive) { do { try repository.delete(saved); load() } catch { self.error = error.localizedDescription } } }
                        .contextMenu { Button("Rename") { renaming = saved; newTitle = saved.title } }
                }
                if planner.isBusy { ProgressView("Opening your trip") }
                if let message = planner.errorMessage { Text(message).foregroundStyle(DetourTheme.secondary) }
            }
            .navigationTitle("Your trips").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("New trip") { planner.newTrip(); dismiss() } }
            }
            .onAppear(perform: load)
            .alert("Rename trip", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Trip name", text: $newTitle)
                Button("Save") {
                    if let renaming { do { try repository.rename(renaming, to: String(newTitle.prefix(80))); if planner.trip.id == renaming.id { planner.trip.title = renaming.title }; load() } catch { self.error = error.localizedDescription } }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
        }
    }
    private func load() { do { trips = try repository.all(isDemo: planner.isDemo) } catch { self.error = error.localizedDescription } }
}
