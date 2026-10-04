import SwiftUI

/// A money amount typed as plain digits. Empty rather than "$0.00" when there
/// is no amount, so typing never lands in the middle of a placeholder value.
struct MoneyField: View {
    @Binding var amount: Decimal

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("0.00", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .focused($isFocused)
            .onAppear { text = Self.display(amount) }
            .onChange(of: text) { commit() }
            // Tidy to two decimals once they finish, and pick up outside changes.
            .onChange(of: isFocused) { if !isFocused { text = Self.display(amount) } }
            .onChange(of: amount) { if !isFocused { text = Self.display(amount) } }
    }

    private func commit() {
        let cleaned = text
            .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
            .filter { $0.isNumber || $0 == "." || $0 == "-" }
        amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private static func display(_ amount: Decimal) -> String {
        amount == 0 ? "" : amount.formatted(.number.precision(.fractionLength(2)).grouping(.never))
    }
}
