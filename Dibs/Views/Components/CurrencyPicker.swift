import SwiftUI

/// Chooses the bill's currency, for when the scan guessed wrong or the
/// receipt didn't say.
struct CurrencyPicker: View {
    /// ISO 4217, like "EUR".
    @Binding var selection: String

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    /// The ones most bills are in, after the bill's own and the phone's.
    private static let common = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY", "MXN", "CHF"]

    private static let all = Locale.commonISOCurrencyCodes
        .map(Money.init)
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

    private var suggested: [Money] {
        var seen: Set<String> = []
        return ([selection, Money.deviceCode] + Self.common).filter { seen.insert($0).inserted }.map(Money.init)
    }

    private var matches: [Money] {
        guard !search.isEmpty else { return Self.all }
        return Self.all.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.currencyCode.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section("Suggested") {
                        ForEach(suggested, id: \.self, content: row)
                    }
                    .receiptRow()
                }
                Section(search.isEmpty ? "All currencies" : "") {
                    ForEach(matches, id: \.self, content: row)
                }
                .receiptRow()
            }
            .paperScreen()
            .searchable(text: $search, prompt: "Name or code")
            .navigationTitle("Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ money: Money) -> some View {
        Button {
            selection = money.currencyCode
            dismiss()
        } label: {
            HStack {
                Text(money.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text(money.currencyCode)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                Image(systemName: "checkmark")
                    .opacity(money.currencyCode == selection ? 1 : 0)
                    .accessibilityHidden(money.currencyCode != selection)
            }
        }
    }
}
