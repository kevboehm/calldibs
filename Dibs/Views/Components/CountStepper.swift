import SwiftUI

/// Big minus / number / plus control shared by the pickers.
struct CountStepper: View {
    @Binding var count: Int
    let range: ClosedRange<Int>

    var body: some View {
        GlassEffectContainer(spacing: Theme.Spacing.large) {
            HStack(spacing: Theme.Spacing.large) {
                RoundGlassButton(title: "One fewer", systemImage: "minus", diameter: 52) { step(-1) }
                    .disabled(count <= range.lowerBound)
                Text("\(count)")
                    .counterFont()
                    .monospacedDigit()
                    .frame(minWidth: 72)
                    .contentTransition(.numericText(value: Double(count)))
                RoundGlassButton(title: "One more", systemImage: "plus", diameter: 52) { step(1) }
                    .disabled(count >= range.upperBound)
            }
        }
        .sensoryFeedback(.selection, trigger: count)
    }

    private func step(_ amount: Int) {
        withAnimation(.snappy) { count += amount }
    }
}
