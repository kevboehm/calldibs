import SwiftUI
import DibsCore

/// The one multi-unit claim control, used by both swipe and checklist modes,
/// for separate units (3 of 10 burgers) and shares (1/5 of a seafood tower).
/// A partial amount needs the confirm button, so a stray tap or swipe can't
/// claim the wrong number of units.
struct QuantityPicker: View {
    private let title: String
    private let caption: String
    private let range: ClosedRange<Int>
    private let onConfirm: (Int) -> Void
    @State private var count: Int

    /// - Parameters:
    ///   - claimed: what this person already holds.
    ///   - available: the most they could hold, given other people's claims.
    ///   - minimum: 1 where opening the picker already means "mine" (swipe
    ///     right), 0 where the picker can also un-claim (checklist).
    init(item: LineItem, claimed: Int, available: Int, minimum: Int, onConfirm: @escaping (Int) -> Void) {
        let noun = item.isSplit ? "shares" : "on the bill"
        self.title = item.isSplit ? "How many shares were yours?" : "How many were yours?"
        self.caption = available < item.quantity
            ? "\(item.displayName), \(available) left of \(item.quantity)"
            : "\(item.displayName), \(item.quantity) \(noun)"
        self.range = minimum...max(minimum, available)
        self.onConfirm = onConfirm
        _count = State(initialValue: min(max(claimed, minimum), max(minimum, available)))
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            CountStepper(count: $count, range: range)

            HStack(spacing: 12) {
                // Unambiguous, so it claims straight away.
                Button("Dibs on all \(range.upperBound)") { onConfirm(range.upperBound) }
                    .buttonStyle(.glass)
                Button(count == 0 ? "None are mine" : "Dibs on \(count)") { onConfirm(count) }
                    .buttonStyle(.glassProminent)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.small)
    }
}

#Preview {
    QuantityPicker(
        item: LineItem(name: "Burger", unitPrice: 9.5, quantity: 10),
        claimed: 0,
        available: 10,
        minimum: 1
    ) { _ in }
}
