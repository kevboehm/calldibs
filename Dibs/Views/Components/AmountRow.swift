import SwiftUI

/// A label with a money amount on the trailing edge.
struct AmountRow: View {
    @Environment(\.money) private var money
    let title: String
    let amount: Decimal
    var isTotal = false

    init(_ title: String, _ amount: Decimal, isTotal: Bool = false) {
        self.title = title
        self.amount = amount
        self.isTotal = isTotal
    }

    var body: some View {
        LabeledContent(title) {
            Text(money.string(amount))
                .fontDesign(.monospaced)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .bold(isTotal)
    }
}
