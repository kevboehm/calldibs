import SwiftUI

/// A circular glass button with a colored symbol, for the swipe controls and
/// the quantity steppers.
struct RoundGlassButton: View {
    let title: String
    let systemImage: String
    var tint: Color = .primary
    var diameter: CGFloat = 60
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.bold())
                .foregroundStyle(isEnabled ? tint : Color.secondary)
                .frame(width: diameter, height: diameter)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(title)
    }
}
