import SwiftUI

/// A money amount typed as plain digits. Empty rather than "$0.00" when there
/// is no amount, so typing never lands in the middle of a placeholder value.
struct MoneyField: View {
    @Binding var amount: Decimal

    @Environment(\.money) private var money

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(display(0, blankWhenZero: false), text: $text)
            .keyboardType(money.fractionDigits == 0 ? .numberPad : .decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .focused($isFocused)
            .onAppear { text = display(amount) }
            .onChange(of: text) { commit() }
            // Tidy to the currency's decimals once they finish, and pick up
            // outside changes.
            .onChange(of: isFocused) { if !isFocused { text = display(amount) } }
            .onChange(of: amount) { if !isFocused { text = display(amount) } }
            .onChange(of: money) { text = display(amount) }
    }

    private func commit() {
        let cleaned = text
            .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
            .filter { $0.isNumber || $0 == "." || $0 == "-" }
        amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    /// Two decimals, or none for a currency without them.
    private func display(_ amount: Decimal, blankWhenZero: Bool = true) -> String {
        amount == 0 && blankWhenZero
            ? ""
            : amount.formatted(.number.precision(.fractionLength(money.fractionDigits)).grouping(.never))
    }
}
