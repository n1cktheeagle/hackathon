import SwiftUI

enum DetourTheme {
    static let ink = Color(red: 27/255, green: 31/255, blue: 29/255)
    static let secondary = Color(red: 106/255, green: 112/255, blue: 108/255)
    static let muted = Color(red: 242/255, green: 244/255, blue: 242/255)
    static let border = Color(red: 227/255, green: 231/255, blue: 228/255)
    static let orange = Color(red: 229/255, green: 100/255, blue: 28/255)
    static let green = Color(red: 34/255, green: 165/255, blue: 91/255)
    static let water = Color(red: 216/255, green: 231/255, blue: 236/255)
    static func font(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
struct PrimaryButton: View {
    let title: String
    var busy = false
    var secondary = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if busy { ProgressView().tint(secondary ? DetourTheme.ink : .white) }
                Text(title).font(.system(.body, design: .rounded, weight: .medium))
            }
            .frame(maxWidth: .infinity).frame(minHeight: 52)
            .background(secondary ? DetourTheme.muted : DetourTheme.ink, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(secondary ? DetourTheme.ink : .white)
        }
        .buttonStyle(.plain)
    }
}
struct CircleButton: View {
    let symbol: String
    let label: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44).background(.white, in: Circle())
                .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}
struct SheetHandle: View {
    var body: some View {
        Capsule().fill(DetourTheme.border).frame(width: 36, height: 4).padding(.top, 12).padding(.bottom, 14).accessibilityHidden(true)
    }
}
struct MessageBanner: View {
    let message: String
    var dismiss: (() -> Void)?
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle")
            Text(message).font(.system(.subheadline, design: .rounded)).frame(maxWidth: .infinity, alignment: .leading)
            if let dismiss { Button(action: dismiss) { Image(systemName: "xmark").frame(width: 24, height: 24) }.accessibilityLabel("Dismiss message") }
        }
        .padding(16).background(DetourTheme.muted, in: RoundedRectangle(cornerRadius: 12))
    }
}
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let width = proposal.width ?? 342
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        var positions: [CGPoint] = []
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += row + spacing; row = 0 }
            positions.append(CGPoint(x: x, y: y)); x += size.width + spacing; row = max(row, size.height)
        }
        return (CGSize(width: width, height: y + row), positions)
    }
}
