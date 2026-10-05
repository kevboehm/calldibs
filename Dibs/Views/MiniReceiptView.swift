import SwiftUI
import UIKit
import DibsCore

struct MiniReceiptView: View {
    @Environment(\.money) private var money
    @Bindable var session: ClaimViewModel
    /// Hand the phone to the next person.
    let onPass: () -> Void
    /// Show everyone's totals.
    let onFinish: () -> Void

    @State private var copied = false

    var body: some View {
        let summary = session.summary
        let name = summary.person.name

        List {
            Section {
                OweHero(caption: name.isEmpty ? "You owe" : "\(name), you owe", amount: summary.total)
                    .listRowBackground(Color.clear)
            }

            Section("Your dibs") {
                if summary.lines.isEmpty {
                    Text("You haven't called dibs on anything.")
                        .foregroundStyle(.secondary)
                }
                ForEach(summary.lines) { line in
                    AmountRow(line.label, line.amount)
                }
            }
            .receiptRow()

            Section {
                AmountRow("Subtotal", summary.claimedSubtotal)
                AmountRow("Tax (your share)", summary.taxShare)
                ForEach(summary.chargeShares) { charge in
                    AmountRow(label(for: charge), charge.amount)
                }
                TipControl(percent: $session.tipPercent, base: $session.tipBase)
                AmountRow("\(session.receipt.includesGratuity ? "Extra tip" : "Tip") (\(session.tipPercent)%)", summary.tip)
                AmountRow("Total", summary.total, isTotal: true)
            } header: {
                Text("How it adds up")
            } footer: {
                Text(tipNote(for: summary))
            }
            .receiptRow()

            notYours

            Section {
                Button(copied ? "Copied" : "Copy amount", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    copy(summary.total)
                }
                .contentTransition(.symbolEffect(.replace))

                let image = ShareCardImage(card: ShareCard(summary: summary, name: name.isEmpty ? nil : name, billName: session.billTitle, money: money))
                ShareLink(
                    item: image,
                    preview: SharePreview("My share: \(money.string(summary.total))", image: image)
                ) {
                    Label("Share as a picture", systemImage: "square.and.arrow.up")
                }
            }
            .receiptRow()
        }
        .paperScreen()
        .animation(.snappy, value: summary.total)
        .onChange(of: summary.total) { copied = false }
        .sensoryFeedback(.success, trigger: copied) { _, isCopied in isCopied }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(name.isEmpty ? "Your share" : "\(name)'s share")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: Keyboard.dismiss)
            }
        }
        .actionBar(hidesWithKeyboard: true) {
            VStack(spacing: Theme.Spacing.medium) {
                if session.hasUnclaimedItems {
                    PrimaryButton("Pass to the next person", systemImage: "arrow.right", action: pass)
                    Button("That's everyone", action: finish)
                } else {
                    PrimaryButton("See the full split", action: finish)
                }
            }
        }
    }

    /// Everything this person didn't claim, so a missed item is easy to spot
    /// and add without going back.
    @ViewBuilder
    private var notYours: some View {
        let items = session.receipt.items.filter { session.claimed($0) < $0.quantity }
        if !items.isEmpty {
            Section {
                ForEach(items) { item in
                    let claimed = session.claimed(item)
                    NotYoursRow(
                        item: item,
                        notMine: item.quantity - claimed,
                        othersClaims: session.othersClaims(on: item),
                        canAdd: session.available(item) > claimed
                    ) {
                        withAnimation(.snappy) { session.setClaimed(claimed + 1, for: item.id) }
                    }
                }
            } header: {
                Text("Not yours")
            } footer: {
                Text("Missed something? Tap + to call dibs on it.")
            }
            .receiptRow()
        }
    }

    /// A tip or gratuity on the bill is one rate for the whole table, so it
    /// reads as that rate on this person's subtotal.
    private func label(for share: ChargeShare) -> String {
        let receipt = session.receipt
        guard let charge = receipt.charges.first(where: { $0.id == share.id }), charge.isGratuity else {
            return "\(share.name) (your share)"
        }
        let rate = receipt.rate(of: charge).formatted(.percent.precision(.fractionLength(0...1)))
        return "\(share.name) (\(rate) of your subtotal)"
    }

    private func tipNote(for summary: ShareSummary) -> String {
        let postTax = summary.person.tip.base == .postTax
        if session.receipt.includesGratuity {
            let basis = postTax ? "your subtotal plus tax" : "your subtotal before tax"
            return "This bill already includes a tip, gratuity or service charge, so your own tip starts at 0%. Anything you add is on \(basis) and only affects your total."
        }
        return postTax
            ? "Your tip is calculated on your subtotal plus your share of tax, not on service charges or fees. It only affects your total."
            : "Your tip is calculated on your food and drink subtotal, before tax, service charges and fees. It only affects your total."
    }

    private func copy(_ amount: Decimal) {
        UIPasteboard.general.string = money.string(amount)
        copied = true
    }

    private func pass() {
        Keyboard.dismiss()
        onPass()
    }

    private func finish() {
        Keyboard.dismiss()
        onFinish()
    }
}
