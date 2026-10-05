import SwiftUI
import DibsCore

/// The picture that gets shared: a little paper receipt on a dark backdrop.
/// Colors are fixed so it looks the same whatever the phone's appearance, and
/// it avoids List and other views that don't render off screen.
struct ShareCard: View {
    struct Row: Identifiable {
        let id = UUID()
        var label: String
        var amount: String
        var isEmphasized = false
    }

    var eyebrow: String
    var amount: String
    var caption: String?
    /// Groups of rows, separated by dashed rules.
    var sections: [[Row]]

    private let ink = Color(red: 0.11, green: 0.12, blue: 0.15)
    private let faded = Color(red: 0.45, green: 0.47, blue: 0.52)
    private let accent = Color(red: 0.07, green: 0.56, blue: 0.42)
    private let paper = Color(red: 0.99, green: 0.98, blue: 0.96)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(accent)
                Text(amount)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let caption {
                    Text(caption)
                        .font(.system(size: 14))
                        .foregroundStyle(faded)
                }
            }
            .padding(.top, 30)
            .padding(.bottom, 22)

            ForEach(Array(sections.enumerated()), id: \.offset) { _, rows in
                rule
                VStack(spacing: 9) {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(row.label)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Text(row.amount)
                        }
                        .font(.system(size: row.isEmphasized ? 18 : 15, weight: row.isEmphasized ? .bold : .regular, design: .monospaced))
                        .foregroundStyle(ink)
                    }
                }
                .padding(.vertical, 16)
            }

            rule
            Text("Split with Call Dibs")
                .font(.system(size: 11, weight: .medium))
                .tracking(1)
                .foregroundStyle(faded)
                .padding(.top, 14)
                .padding(.bottom, 26)
        }
        .padding(.horizontal, 24)
        .background(paper, in: TornPaper())
        .padding(.horizontal, 26)
        .padding(.top, 34)
        .padding(.bottom, 30)
        .frame(width: 380)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.08, blue: 0.14), Color(red: 0.12, green: 0.20, blue: 0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var rule: some View {
        RuleLine()
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(faded.opacity(0.6))
            .frame(height: 1)
    }
}

// MARK: - What goes on the card

extension ShareCard {
    /// One person's share: their items and how the total is made up.
    init(summary: ShareSummary, name: String?) {
        let percent = NSDecimalNumber(decimal: summary.person.tip.rate * 100).intValue
        var sections: [[Row]] = []
        if !summary.lines.isEmpty {
            sections.append(summary.lines.map { Row(label: $0.label, amount: Money.string($0.amount)) })
        }
        sections.append([
            Row(label: "Subtotal", amount: Money.string(summary.claimedSubtotal)),
            Row(label: "Tax", amount: Money.string(summary.taxShare)),
        ] + summary.chargeShares.map { Row(label: $0.name, amount: Money.string($0.amount)) }
            // A tip already on the bill is one of the charges above.
            + (summary.tip == 0 ? [] : [Row(label: "Tip (\(percent)%)", amount: Money.string(summary.tip))]))
        sections.append([Row(label: "Total", amount: Money.string(summary.total), isEmphasized: true)])

        self.init(
            eyebrow: name.map { "\($0)'s share" } ?? "My share",
            amount: Money.string(summary.total),
            caption: nil,
            sections: sections
        )
    }

    /// The whole table: what each person owes, and anything nobody claimed.
    init(people: [(name: String, total: Decimal)], unclaimed: Decimal) {
        var sections = [people.map { Row(label: $0.name, amount: Money.string($0.total)) }]
        if unclaimed > 0 {
            sections.append([Row(label: "No dibs yet, before tax and tip", amount: Money.string(unclaimed))])
        }
        let total = people.reduce(0) { $0 + $1.total }
        sections.append([Row(label: unclaimed > 0 ? "Covered so far" : "Total", amount: Money.string(total), isEmphasized: true)])

        self.init(
            eyebrow: "The split",
            amount: Money.string(total),
            caption: "\(people.count) \(people.count == 1 ? "person" : "people"), tax and tip included",
            sections: sections
        )
    }
}
