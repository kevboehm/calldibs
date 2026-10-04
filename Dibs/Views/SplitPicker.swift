import SwiftUI
import DibsCore

/// Splits one item into equal shares, which are then claimed like units.
struct SplitPicker: View {
    private let item: LineItem
    /// Called with the number of shares; 1 means "not split".
    private let onConfirm: (Int) -> Void
    @State private var parts: Int

    init(item: LineItem, onConfirm: @escaping (Int) -> Void) {
        self.item = item
        self.onConfirm = onConfirm
        _parts = State(initialValue: item.isSplit ? item.quantity : 2)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            VStack(spacing: 4) {
                Text("Split \(item.displayName)")
                    .font(.headline)
                Text("How many equal shares? Each person then claims theirs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            CountStepper(count: $parts, range: 2...20)

            Text("\(Money.string((item.lineTotal / Decimal(parts)).roundedToCents())) per share")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            HStack(spacing: 12) {
                if item.isSplit {
                    Button("Don't split") { onConfirm(1) }
                        .buttonStyle(.glass)
                }
                Button("Split \(parts) ways") { onConfirm(parts) }
                    .buttonStyle(.glassProminent)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.small)
    }
}
