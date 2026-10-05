import SwiftUI
import DibsCore

/// The card for one item in the swipe stack.
struct SwipeItemCard: View {
    @Environment(\.money) private var money
    let item: LineItem
    let claimed: Int
    let available: Int
    let othersClaims: String?

    private var status: some View {
        Label(
            item.isMultiUnit ? "Dibs on \(claimed) of \(item.quantity)" : "You called dibs",
            systemImage: "checkmark.circle.fill"
        )
        .font(.subheadline.bold())
        .foregroundStyle(.tint)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.medium) {
            Spacer()

            if item.isMultiUnit {
                Text(item.isSplit ? "Split \(item.quantity) ways" : "\(item.quantity) on the bill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.tint.opacity(0.14), in: .capsule)
            }

            Text(item.displayName)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(money.string(item.lineTotal.roundedToCents()))
                .cardAmountFont()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            if item.isMultiUnit {
                Text(item.unitPriceLabel(money))
                    .foregroundStyle(.secondary)
            }

            if let othersClaims {
                Text("\(available) left · \(DibsCopy.others(othersClaims))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Keeps its space when not showing, so the card doesn't jump;
            // hidden() also keeps it away from VoiceOver.
            if claimed > 0 {
                status
            } else {
                status.hidden()
            }
        }
        .padding(Theme.Spacing.large)
        .frame(maxWidth: .infinity, minHeight: 340)
        .paperCard()
    }
}
