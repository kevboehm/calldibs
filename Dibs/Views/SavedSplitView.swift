import SwiftUI
import DibsCore

/// A past split to look at, not change: what each person owed and what it
/// was made up of, beside the bill it came from.
struct SavedSplitView: View {
    let split: SavedSplit
    /// Bring it back as the bill in hand.
    let onReopen: () -> Void

    var body: some View {
        let receipt = split.snapshot.receipt
        let shares = split.shares
        let unclaimed = receipt.unclaimedItems

        List {
            Section {
                OweHero(
                    caption: unclaimed.isEmpty ? "All covered" : "Covered",
                    amount: split.total,
                    footnote: split.date.formatted(date: .abbreviated, time: .shortened)
                )
                .listRowBackground(Color.clear)
            }

            ForEach(Array(shares.enumerated()), id: \.offset) { _, share in
                Section(share.name) {
                    if share.summary.lines.isEmpty {
                        Text("No dibs.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(share.summary.breakdown.enumerated()), id: \.offset) { _, line in
                        AmountRow(line.label, line.amount)
                    }
                    AmountRow("Total", share.summary.total, isTotal: true)
                }
                .receiptRow()
            }

            if !unclaimed.isEmpty {
                Section {
                    ForEach(unclaimed) { item in
                        AmountRow(item.unclaimedLabel, item.unclaimedTotal.roundedToCents())
                    }
                } header: {
                    Label("No dibs", systemImage: "exclamationmark.circle")
                        .foregroundStyle(Theme.Palette.notMine)
                } footer: {
                    Text("Amounts are before tax and tip.")
                }
                .receiptRow()
            }

            Section {
                AmountRow("Items", receipt.itemsSubtotal.roundedToCents())
                AmountRow("Tax", receipt.tax)
                ForEach(receipt.charges) { charge in
                    AmountRow(charge.name, charge.amount)
                }
                if let total = receipt.total {
                    AmountRow("Total on the receipt", total, isTotal: true)
                }
            } header: {
                Text("The bill")
            } footer: {
                Text("Before anyone's own tip.")
            }
            .receiptRow()

            Section {
                let image = ShareCardImage(card: ShareCard(
                    people: shares,
                    unclaimed: unclaimed.reduce(0) { $0 + $1.unclaimedTotal }.roundedToCents(),
                    money: split.money
                ))
                ShareLink(item: image, preview: SharePreview("The split", image: image)) {
                    Label("Share the split as a picture", systemImage: "square.and.arrow.up")
                }
                Button("Reopen this split", systemImage: "arrow.uturn.backward", action: onReopen)
            } footer: {
                Text("Reopening makes it the bill in hand, so it can be changed.")
            }
            .receiptRow()
        }
        .paperScreen()
        .environment(\.money, split.money)
        .navigationTitle(split.names)
        .navigationBarTitleDisplayMode(.inline)
    }
}
