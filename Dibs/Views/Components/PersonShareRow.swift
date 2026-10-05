import SwiftUI
import DibsCore

/// One person on the split screen: their total, what it is made up of and
/// ways to get paid, expanding to a way back into their turn.
struct PersonShareRow: View {
    @Environment(\.money) private var money
    let name: String
    let summary: ShareSummary
    /// What the bill is called, if anything, for the notes on pay links.
    var billName: String?
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
                payActions
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

    /// Ways to get this person's share back, in reach without opening the
    /// row: ask for it in Venmo, or send them a link that pays it.
    @ViewBuilder
    private var payActions: some View {
        let message = PayShare.payMessage(
            name: name, summary: summary, billName: billName, method: method, handle: payerHandle, money: money
        )
        if summary.total > 0, let message {
            HStack(spacing: Theme.Spacing.small) {
                if method == .venmo, offersPayLinks {
                    requestOnVenmo
                }
                ShareLink(item: message) {
                    PayPill(title: "Send link", systemImage: "paperplane")
                }
                .accessibilityLabel("Send \(name) a pay-me link")
            }
            // Their own style, so a tap lands on them and not on the row.
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
        }
    }

    /// Opens Venmo with a request for this person's share, ready to send.
    private var requestOnVenmo: some View {
        Button {
            VenmoLauncher.open(
                action: .charge,
                handle: "",
                amount: summary.total,
                note: "\(name)'s share of \(billName ?? "the bill")"
            )
        } label: {
            PayPill(title: "Request on Venmo", systemImage: "arrow.up.forward.app")
        }
        .accessibilityLabel("Request \(money.string(summary.total)) from \(name) on Venmo")
    }
}

/// A small tinted capsule, in the same wash as the person's initial.
private struct PayPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.tint.opacity(0.14), in: .capsule)
        .contentShape(.capsule)
    }
}
