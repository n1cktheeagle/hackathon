import SwiftUI

struct DestinationBrowser: View {
    let planner: TripPlanner
    @State private var personalized = true
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var searching = false
    @State private var selecting = false
    @State private var isListDragging = false
    @State private var dragResetTask: Task<Void, Never>?
    @State private var sessionToken = UUID().uuidString
    @State private var selectionTask: Task<Void, Never>?
    @State private var error: String?
    @State private var editingInterests = false
    @State private var showingCredits = false
    @Environment(\.dismiss) private var dismiss

    private var curated: [DestinationIdea] {
        DestinationCatalog.browse(interests: planner.profile.interests, personalized: personalized, query: query)
    }
    private var recommendations: [DestinationIdea] {
        DestinationCatalog.browse(interests: planner.profile.interests, personalized: personalized)
    }
    private var externalResults: [SearchResult] {
        let ids = Set(curated.map(\.id))
        return results.filter { !ids.contains($0.id) && $0.id != planner.trip.origin?.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    tab("For you", active: personalized, id: "destinations-for-you") { personalized = true }
                    tab("All", active: !personalized, id: "destinations-all") { personalized = false }
                    Spacer()
                    Button { editingInterests = true } label: {
                        Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44)
                            .background(DetourTheme.muted, in: Circle())
                    }.accessibilityLabel("Change interests").accessibilityIdentifier("destination-interests")
                }.padding(.horizontal, 24)
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 20)).accessibilityHidden(true)
                    TextField("Search places or interests", text: $query).autocorrectionDisabled().submitLabel(.search)
                        .accessibilityIdentifier("place-search")
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 32, height: 44) }
                            .accessibilityLabel("Clear search").foregroundStyle(DetourTheme.secondary)
                    }
                }.padding(.horizontal, 16).frame(minHeight: 56)
                    .background(DetourTheme.muted, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal, 24)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(query.isEmpty ? (personalized ? "Your kind of Cape Town" : "Cape Town favourites") : "Find your next destination")
                                .font(DetourTheme.font(.title3, weight: .semibold))
                            Text(personalized ? "Picked for your interests. A good place to start." : "The places worth making a day of.")
                                .font(DetourTheme.font(.subheadline)).foregroundStyle(DetourTheme.secondary)
                        }.padding(.bottom, 4)
                        if searching || selecting { ProgressView().frame(maxWidth: .infinity).padding(8) }
                        ForEach(Array(curated.enumerated()), id: \.element.id) { rank, idea in
                            destinationRow(idea, rank: rank + 1)
                        }
                        if !externalResults.isEmpty {
                            Text("Search results").font(DetourTheme.font(.subheadline, weight: .semibold)).padding(.top, 12)
                            ForEach(externalResults) { result in
                                Button {
                                    guard !isListDragging else { return }
                                    choose(result.id)
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "mappin.and.ellipse").frame(width: 40, height: 40)
                                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(result.name).fontWeight(.medium)
                                            Text(result.subtitle).font(DetourTheme.font(.subheadline)).foregroundStyle(DetourTheme.secondary)
                                        }
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right").font(DetourTheme.font(.caption)).foregroundStyle(DetourTheme.secondary)
                                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(DetourTheme.muted, in: RoundedRectangle(cornerRadius: 16))
                                }.buttonStyle(.plain).accessibilityIdentifier("search-result-\(result.id)")
                            }
                        }
                        if curated.isEmpty && externalResults.isEmpty && !searching {
                            Text("Here are a few places you might like while you keep exploring.")
                                .font(DetourTheme.font(.subheadline)).foregroundStyle(DetourTheme.secondary)
                            ForEach(Array(recommendations.prefix(5).enumerated()), id: \.element.id) { rank, idea in
                                destinationRow(idea, rank: rank + 1)
                            }
                            if personalized { Button("Browse all Cape Town places") { personalized = false; query = "" }.frame(minHeight: 44) }
                        }
                        if planner.isDemo {
                            Button("Photo credits") { showingCredits = true }.font(DetourTheme.font(.footnote)).frame(minHeight: 44)
                        } else { Text("Google Maps").font(DetourTheme.font(.footnote)).foregroundStyle(DetourTheme.secondary) }
                    }.padding(.horizontal, 24).padding(.bottom, 24)
                }
                .scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
                .simultaneousGesture(DragGesture(minimumDistance: 6)
                    .onChanged { _ in
                        dragResetTask?.cancel()
                        isListDragging = true
                    }
                    .onEnded { _ in
                        dragResetTask?.cancel()
                        dragResetTask = Task {
                            try? await Task.sleep(for: .milliseconds(180))
                            guard !Task.isCancelled else { return }
                            isListDragging = false
                        }
                    })
            }.padding(.top, 12).background(.white)
                .navigationTitle("Where to?").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .onDisappear { selectionTask?.cancel(); dragResetTask?.cancel() }
                .task(id: query) { await search() }
                .sheet(isPresented: $editingInterests) {
                    NavigationStack {
                        InterestOnboardingView(profile: planner.profile, editing: true) { editingInterests = false }
                            .navigationTitle("Your interests").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingInterests = false } } }
                    }
                }
                .sheet(isPresented: $showingCredits) {
                    NavigationStack {
                        List {
                            Text("Photos are cropped to fit the cards. Original photos and licences are linked below.").font(DetourTheme.font(.subheadline)).foregroundStyle(DetourTheme.secondary)
                            ForEach((DestinationCatalog.places.map(\.place) + RouteDiscoveries.places.map(\.place) + Fixtures.stops + Fixtures.extraStops).filter { !$0.photoAttributions.isEmpty }) { place in
                                Section(place.name) {
                                    ForEach(Array(place.photoAttributions.enumerated()), id: \.offset) { _, credit in
                                        if let uri = credit.uri, let url = URL(string: uri) { Link(credit.name, destination: url) }
                                        if let uri = credit.licenseURI, let url = URL(string: uri) { Link("Photo licence", destination: url) }
                                    }
                                }
                            }
                        }.navigationTitle("Photo credits").navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingCredits = false } } }
                    }
                }
        }
    }

    private func tab(_ title: String, active: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(DetourTheme.font(.subheadline, weight: .medium))
                .padding(.horizontal, 22).frame(minHeight: 44)
                .background(active ? DetourTheme.ink : DetourTheme.muted, in: Capsule())
                .foregroundStyle(active ? .white : DetourTheme.ink)
        }.buttonStyle(.plain).accessibilityIdentifier(id).accessibilityAddTraits(active ? .isSelected : [])
    }

    private func destinationRow(_ idea: DestinationIdea, rank: Int) -> some View {
        let matches = idea.interests.filter { planner.profile.interests.contains($0) }
        return Button {
            guard !isListDragging else { return }
            select(idea.place)
        } label: {
            PlaceDiscoveryRow(place: idea.place, service: planner.service, rank: rank,
                              detail: idea.summary, badge: personalized ? matches.map(\.title).joined(separator: " · ") : idea.interests.prefix(2).map(\.title).joined(separator: " · "),
                              showGoogleRating: !planner.isDemo, showMockRating: planner.isDemo)
        }.buttonStyle(.plain).disabled(selecting)
            .accessibilityIdentifier("destination-\(idea.id)")
            .accessibilityLabel("\(rank). \(idea.place.name), \(idea.place.subtitle)")
    }

    private func select(_ place: PlaceReference) { planner.select(place, for: .destination); dismiss() }
    private func choose(_ id: String) {
        selecting = true; error = nil; selectionTask?.cancel()
        selectionTask = Task {
            do {
                let place = try await planner.service.details(id, sessionToken: sessionToken)
                try Task.checkCancellation(); select(place)
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
            selecting = false
        }
    }
    private func search() async {
        results = []; error = nil
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { searching = false; return }
        searching = true
        do {
            try await Task.sleep(for: .milliseconds(300))
            let found = try await planner.service.search(query, sessionToken: sessionToken)
            try Task.checkCancellation(); results = found; searching = false
        } catch { if !Task.isCancelled { searching = false } }
    }
}
