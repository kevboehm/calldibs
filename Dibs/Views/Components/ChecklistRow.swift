import SwiftUI
import DibsCore

/// One bill line in checklist mode, for the person currently claiming.
struct ChecklistRow: View {
    @Environment(\.money) private var money
    let item: LineItem
    let claimed: Int
    let available: Int
    let othersClaims: String?

    /// Other people hold every unit.
    private var isExhausted: Bool { available == 0 }

    private var symbol: String {
        if isExhausted { return "person.crop.circle.badge.checkmark" }
        return claimed > 0 ? "checkmark.circle.fill" : "circle"
    }

    private var detail: String? {
        if isExhausted {
            return othersClaims.map(DibsCopy.others) ?? "Already taken"
        }
        var parts: [String] = []
        if item.isMultiUnit {
            if claimed > 0 {
                parts.append(item.isSplit ? "Dibs on \(claimed)/\(item.quantity)" : "Dibs on \(claimed) of \(item.quantity)")
            } else if available < item.quantity {
                parts.append("\(available) left")
            }
            parts.append(item.unitPriceLabel(money))
        }
        if let othersClaims {
            parts.append(DibsCopy.others(othersClaims))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(claimed > 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: claimed)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .strikethrough(isExhausted)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(money.string(item.lineTotal.roundedToCents()))
                .fontDesign(.monospaced)
                .strikethrough(isExhausted)
                .foregroundStyle(claimed > 0 ? .primary : .secondary)
        }
        .opacity(isExhausted ? 0.5 : 1)
        .contentShape(.rect)
        .animation(.snappy, value: claimed)
    }
}
