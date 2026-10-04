import SwiftUI

/// The headline number at the top of a summary screen.
struct OweHero: View {
    let caption: String
    let amount: Decimal
    var footnote: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            Text(caption)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(Money.string(amount))
                .heroAmountFont()
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                // A small thump each time the total changes.
                .keyframeAnimator(initialValue: 1.0, trigger: amount) { content, scale in
                    content.scaleEffect(reduceMotion ? 1 : scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(1.06, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.3)
                    }
                }
            if let footnote {
                Text(footnote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.small)
        .animation(.snappy, value: amount)
        .accessibilityElement(children: .combine)
    }
}
