import SwiftUI
import DibsCore

/// An item (or the part of one) the current person didn't claim, with a
/// shortcut to add a unit of it.
struct NotYoursRow: View {
    let item: LineItem
    /// Units of this item that aren't the current person's.
    let notMine: Int
    let othersClaims: String?
    let canAdd: Bool
    let onAdd: () -> Void

    private var label: String {
        if item.isSplit { return "\(notMine)/\(item.quantity) of \(item.displayName)" }
        return notMine > 1 ? "\(notMine) × \(item.displayName)" : item.displayName
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(othersClaims.map(DibsCopy.others) ?? "No dibs yet")
                    .font(.subheadline)
            }
            Spacer()
            Text(Money.string((item.unitPrice * Decimal(notMine)).roundedToCents()))
                .fontDesign(.monospaced)
            if canAdd {
                Button("Call dibs on \(item.displayName)", systemImage: "plus.circle.fill", action: onAdd)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .buttonStyle(.borderless)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .foregroundStyle(.secondary)
    }
}
