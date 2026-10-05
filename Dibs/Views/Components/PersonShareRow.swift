import SwiftUI
import DibsCore

/// One person on the split screen: their total and what it is made up of,
/// expanding to a way back into their turn and ways to get paid.
struct PersonShareRow: View {
    @Environment(\.money) private var money
    let name: String
    let summary: ShareSummary
    /// Where the bill payer gets paid, and their handle there ("" if they
    /// haven't set one).
    var method: PaymentMethod = .venmo
    var payerHandle: String = ""
    /// False on a bill in a currency Venmo and the rest can't be asked for.
    var offersPayLinks = true
    let onEdit: () -> Void
    let onRemove: () -> Void
    /// The row was opened: its actions sit under the breakdown, so the
    /// screen may need to scroll to show them.
    var onExpand: () -> Void = {}

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Button("Edit \(name)'s dibs or tip", systemImage: "pencil", action: onEdit)
            if summary.total > 0 {
                if method == .venmo, offersPayLinks {
                    requestOnVenmo
                }
                if let message = PayShare.payMessage(name: name, summary: summary, method: method, handle: payerHandle, money: money) {
                    ShareLink(item: message) {
                        Label("Send \(name) a pay-me link", systemImage: "square.and.arrow.up")
                    }
                }
            }
            Button("Remove \(name)", systemImage: "trash", role: .destructive, action: onRemove)
        } label: {
            VStack(spacing: Theme.Spacing.small) {
                HStack(spacing: 12) {
                    Text(name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .frame(width: 36, height: 36)
                        .background(.tint.opacity(0.14), in: .circle)
                        .accessibilityHidden(true)
                    Text(name)
                    Spacer()
                    Text(money.string(summary.total))
                        .fontDesign(.monospaced)
                        .contentTransition(.numericText())
                }
                .font(.headline)
                breakdown
            }
        }
        .font(.subheadline)
        .onChange(of: isExpanded) {
            if isExpanded { onExpand() }
        }
    }

    /// What the total is made up of, shown without having to open the row.
    private var breakdown: some View {
        VStack(spacing: 4) {
            if summary.lines.isEmpty {
                Text("No dibs.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(Array(summary.breakdown.enumerated()), id: \.offset) { _, line in
                AmountRow(line.label, line.amount)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    /// Opens Venmo with a request for this person's share, ready to send.
    private var requestOnVenmo: some View {
        Button("Request \(money.string(summary.total)) on Venmo", systemImage: "arrow.up.forward.app") {
            VenmoLauncher.open(
                action: .charge,
                handle: "",
                amount: summary.total,
                note: "\(name)'s share of the bill"
            )
        }
    }
}
