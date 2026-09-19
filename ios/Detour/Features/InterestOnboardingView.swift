import SwiftUI

struct InterestOnboardingView: View {
    let profile: TravelerProfile
    var editing = false
    var onContinue: () -> Void
    @State private var selected: Set<TravelInterest>

    init(profile: TravelerProfile, editing: Bool = false, onContinue: @escaping () -> Void) {
        self.profile = profile; self.editing = editing; self.onContinue = onContinue
        _selected = State(initialValue: Set(profile.interests))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image("Wordmark").resizable().scaledToFit().frame(width: 92, height: 42).accessibilityLabel("Detour")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What draws you out?").font(DetourTheme.font(.largeTitle, weight: .semibold)).accessibilityIdentifier("interest-onboarding-title")
                        Text("Choose 3 interests. We’ll find places worth making a day of.")
                            .foregroundStyle(DetourTheme.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(TravelInterest.allCases) { interest in
                            interestCard(interest)
                        }
                    }
                }.padding(24)
            }.scrollIndicators(.hidden)
            VStack {
                PrimaryButton(title: editing ? "Save interests" : "Continue") {
                    profile.update(selected); onContinue()
                }.disabled(selected.count != 3).opacity(selected.count == 3 ? 1 : 0.45)
                    .accessibilityIdentifier("interests-continue")
            }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 20)
                .background(.white).overlay(alignment: .top) { Divider().overlay(DetourTheme.border) }
        }.background(.white)
    }

    private func interestCard(_ interest: TravelInterest) -> some View {
        let active = selected.contains(interest)
        return Button {
            if active { selected.remove(interest) }
            else if selected.count < 3 { selected.insert(interest) }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: interest.symbol).font(.system(size: 26, weight: .regular)).accessibilityHidden(true)
                    Spacer()
                    Image(systemName: active ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 19)).foregroundStyle(active ? .white : DetourTheme.border).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(interest.title).font(DetourTheme.font(.body, weight: .medium))
                    Text(interest.subtitle).font(DetourTheme.font(.caption))
                        .foregroundStyle(active ? .white.opacity(0.8) : DetourTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.frame(maxWidth: .infinity, minHeight: 98, alignment: .leading).padding(14)
                .background(active ? DetourTheme.ink : DetourTheme.muted, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(active ? .white : DetourTheme.ink).contentShape(RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).accessibilityIdentifier("interest-\(interest.id)")
            .accessibilityLabel(interest.title).accessibilityValue(active ? "Selected" : "Not selected")
            .accessibilityAddTraits(active ? .isSelected : [])
    }
}
