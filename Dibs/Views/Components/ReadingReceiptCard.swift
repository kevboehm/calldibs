import SwiftUI

/// Shown while a scan is being read: a blank receipt whose lines print in
/// and pulse until the real ones are ready.
struct ReadingReceiptCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far across the card each placeholder line runs.
    private let lines: [CGFloat] = [0.7, 0.5, 0.82, 0.6, 0.44]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
            VStack(spacing: 14) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, length in
                    HStack {
                        Capsule()
                            .frame(width: 150 * length, height: 8)
                        Spacer()
                        Capsule()
                            .frame(width: 34, height: 8)
                    }
                    .printIn(index: index * 3)
                }
            }
            .foregroundStyle(Theme.Palette.rule)
            .phaseAnimator([false, true]) { content, isDim in
                content.opacity(isDim && !reduceMotion ? 0.45 : 1)
            } animation: { _ in
                .easeInOut(duration: 0.8)
            }

            Label("Reading receipt…", systemImage: "text.viewfinder")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.large)
        .padding(.bottom, Theme.Spacing.small)
        .frame(width: 250)
        .paperCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reading receipt")
    }
}

#Preview {
    ReadingReceiptCard()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperScreen()
}
