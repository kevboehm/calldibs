import SwiftUI

/// "DIBS!" / "NOT MINE", fading in as the card is dragged towards a side.
struct SwipeHintBadge: View {
    /// -1...1, negative towards "not mine".
    let progress: Double

    var body: some View {
        Text(progress > 0 ? "DIBS!" : "NOT MINE")
            .font(.headline)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(progress > 0 ? Color.accentColor : Theme.Palette.notMine, in: .capsule)
            .padding(.top, Theme.Spacing.medium)
            .opacity(min(1, abs(progress) * 1.4))
            .accessibilityHidden(true)
    }
}
