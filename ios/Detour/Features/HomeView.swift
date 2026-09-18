import SwiftUI

struct HomeView: View {
    @Bindable var planner: TripPlanner
    @ScaledMetric(relativeTo: .title2) private var headlineSize = 28.0
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image("Wordmark").resizable().scaledToFit().frame(width: 68, height: 30).accessibilityLabel("Detour")
                Spacer()
                if planner.isDemo {
                    Button { planner.sheet = .settings } label: { Text("Demo").font(.system(.subheadline, design: .rounded)).foregroundStyle(DetourTheme.secondary) }
                    .accessibilityIdentifier("demo-settings")
                }
                Button { planner.sheet = .saved } label: {
                    Image(systemName: "bookmark").font(.system(size: 15, weight: .medium)).frame(width: 44, height: 44).background(DetourTheme.muted, in: Circle())
                }.accessibilityLabel("Saved trips").accessibilityIdentifier("saved-trips")
            }.padding(.horizontal, 24).padding(.top, 8)
            ScrollView {
                VStack(alignment: .leading, spacing: 42) {
                    VStack(alignment: .leading, spacing: 2) {
                        FlowLayout(spacing: 6) {
                            Text("I'm in").foregroundStyle(DetourTheme.secondary)
                            Button { planner.sheet = .search(.origin) } label: { Text("\(planner.trip.origin?.name ?? "somewhere"),").underline() }
                                .accessibilityIdentifier("origin-field").accessibilityLabel("Starting point, \(planner.trip.origin?.name ?? "choose a place")")
                        }
                        FlowLayout(spacing: 6) {
                            Text("missioning to").foregroundStyle(DetourTheme.secondary)
                            Button { planner.sheet = .search(.destination) } label: { Text(planner.trip.destination?.name ?? "somewhere").underline() }
                                .accessibilityIdentifier("destination-field").accessibilityLabel("Destination, \(planner.trip.destination?.name ?? "choose a place")")
                        }
                    }
                    .font(.system(size: headlineSize, weight: .semibold, design: .rounded))
                    .buttonStyle(.plain).padding(.horizontal, 24).padding(.top, 58)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Worth a stop nearby").font(.system(.body, design: .rounded, weight: .medium)).padding(.horizontal, 24)
                        if planner.loadingNearby {
                            ProgressView("Finding nearby places").padding(24)
                        } else if planner.nearby.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(planner.trip.origin == nil ? "Choose where you're starting to find a few local discoveries." : "Nearby places couldn't be loaded.").foregroundStyle(DetourTheme.secondary)
                                if planner.trip.origin != nil { Button("Try again") { Task { await planner.loadNearby() } } }
                            }.padding(.horizontal, 24)
                        } else {
                            ScrollView(.horizontal) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(planner.nearby) { place in
                                        Button { planner.sheet = .details(place) } label: {
                                            VStack(alignment: .leading, spacing: 0) {
                                                PlacePhoto(place: place, service: planner.service, height: 130)
                                                VStack(alignment: .leading, spacing: 5) {
                                                    Text(place.name).foregroundStyle(DetourTheme.ink).lineLimit(2)
                                                    Text(place.subtitle).foregroundStyle(DetourTheme.secondary).lineLimit(2)
                                                }.font(.system(.body, design: .rounded)).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                                            }.frame(width: 208).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(DetourTheme.border, lineWidth: 1))
                                        }.buttonStyle(.plain)
                                    }
                                }.padding(.horizontal, 24).padding(.bottom, 2)
                            }.scrollIndicators(.hidden)
                        }
                    }
                }.padding(.bottom, 30)
            }
            PrimaryButton(title: "Plan the mission", secondary: !planner.trip.canPlan) { planner.plan() }
                .disabled(!planner.trip.canPlan).opacity(planner.trip.canPlan ? 1 : 0.65)
                .accessibilityIdentifier("plan-trip").padding(.horizontal, 24).padding(.bottom, 16).padding(.top, 12)
        }.background(.white)
    }
}
