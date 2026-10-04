import SwiftUI
import DibsCore

/// One person on the split screen: their total, expanding to the breakdown
/// and a way back into their turn.
struct PersonShareRow: View {
    let name: String
    let summary: ShareSummary
    /// Where the bill payer gets paid, and their handle there ("" if they
    /// haven't set one).
    var method: PaymentMethod = .venmo
    var payerHandle: String = ""
    let onEdit: () -> Void
    let onRemove: () -> Void

    private var tipPercent: Int {
        NSDecimalNumber(decimal: summary.person.tip.rate * 100).intValue
    }

    var body: some View {
        DisclosureGroup {
            // First, so they aren't pushed off screen by a long breakdown.
            Button("Edit \(name)'s dibs or tip", systemImage: "pencil", action: onEdit)
            if summary.total > 0 {
                if method == .venmo {
                    requestOnVenmo
                }
                if let message = PayShare.payMessage(name: name, amount: summary.total, method: method, handle: payerHandle) {
                    ShareLink(item: message) {
                        Label("Send \(name) a pay-me link", systemImage: "square.and.arrow.up")
                    }
                }
            }
            Button("Remove \(name)", systemImage: "trash", role: .destructive, action: onRemove)
            if summary.lines.isEmpty {
                Text("No dibs.")
                    .foregroundStyle(.secondary)
            }
            ForEach(summary.lines) { line in
                AmountRow(line.label, line.amount)
            }
            Group {
                AmountRow("Subtotal", summary.claimedSubtotal)
                AmountRow("Tax", summary.taxShare)
                ForEach(summary.chargeShares) { charge in
                    AmountRow(charge.name, charge.amount)
                }
                AmountRow("Tip (\(tipPercent)%)", summary.tip)
            }
            .foregroundStyle(.secondary)
        } label: {
            HStack(spacing: 12) {
                Text(name.prefix(1).uppercased())
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(.tint.opacity(0.14), in: .circle)
                    .accessibilityHidden(true)
                Text(name)
                Spacer()
                Text(Money.string(summary.total))
                    .fontDesign(.monospaced)
                    .contentTransition(.numericText())
            }
            .font(.headline)
        }
        .font(.subheadline)
    }

    /// Opens Venmo with a request for this person's share, ready to send.
    private var requestOnVenmo: some View {
        Button("Request \(Money.string(summary.total)) on Venmo", systemImage: "arrow.up.forward.app") {
            VenmoLauncher.open(
                action: .charge,
                handle: "",
                amount: summary.total,
                note: "\(name)'s share of the bill"
            )
        }
    }
}
