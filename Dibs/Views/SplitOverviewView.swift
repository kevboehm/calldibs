import SwiftUI
import DibsCore

/// Everyone's totals, plus whatever nobody has claimed yet. Also the hub for
/// going back into anyone's turn.
struct SplitOverviewView: View {
    var session: ClaimViewModel
    let onAddPerson: () -> Void
    let onEdit: (Person.ID) -> Void
    let onNewBill: () -> Void

    @State private var confirmNewBill = false
    @State private var personToRemove: Person?
    var payout = PayoutSettings()
    @State private var editingHandle = false
    @State private var confirmSplitRest = false

    private var hasPayableTotals: Bool {
        session.people.contains { session.summary(for: $0).total > 0 }
    }

    private var everyonePayMessage: String? {
        PayShare.everyoneMessage(
            people: session.people.map { (session.displayName($0), session.summary(for: $0).total) },
            method: payout.method,
            handle: payout.handle
        )
    }

    private var owedTotal: Decimal {
        session.people.reduce(0) { $0 + session.summary(for: $1).total }
    }

    private var unclaimedTotal: Decimal {
        session.receipt.unclaimedItems.reduce(0) { $0 + $1.unclaimedTotal }.roundedToCents()
    }

    /// 0...1: how much of the bill's items have been claimed.
    private var claimedFraction: Double {
        let all = session.receipt.itemsSubtotal
        guard all > 0 else { return 0 }
        return NSDecimalNumber(decimal: (all - unclaimedTotal) / all).doubleValue
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: Theme.Spacing.medium) {
                    OweHero(
                        caption: session.hasUnclaimedItems ? "Covered so far" : "All covered",
                        amount: owedTotal,
                        footnote: "Tax and tip included"
                    )
                    ProgressView(value: claimedFraction)
                        .tint(session.hasUnclaimedItems ? .accentColor : .green)
                        .accessibilityLabel("Share of the bill covered")
                }
                .listRowBackground(Color.clear)
            }

            Section {
                if session.people.isEmpty {
                    Text("Nobody has called dibs yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(session.people) { person in
                    PersonShareRow(
                        name: session.displayName(person),
                        summary: session.summary(for: person),
                        method: payout.method,
                        payerHandle: payout.handle
                    ) {
                        onEdit(person.id)
                    } onRemove: {
                        personToRemove = person
                    }
                }
            } header: {
                Text("Who owes what")
            } footer: {
                if !session.people.isEmpty {
                    Text("Open a name to see the breakdown, edit it, or remove that person.")
                }
            }
            .receiptRow()

            if session.hasUnclaimedItems {
                Section {
                    ForEach(session.receipt.unclaimedItems) { item in
                        AmountRow(unclaimedLabel(item), item.unclaimedTotal.roundedToCents())
                    }
                    if !session.people.isEmpty {
                        splitRestButton
                    }
                } header: {
                    Label("No dibs yet", systemImage: "exclamationmark.circle")
                        .foregroundStyle(Theme.Palette.notMine)
                } footer: {
                    Text("Amounts are before tax and tip.")
                }
                .receiptRow()
            } else {
                Section {
                    Label("Every item is accounted for.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.tint)
                }
                .receiptRow()
            }

            if !session.people.isEmpty {
                Section {
                    if payout.hasHandle {
                        HStack {
                            Label("Your \(payout.method.title)", systemImage: "arrow.up.forward.app")
                            Spacer()
                            Text(payout.method.prefix + payout.handle)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Button("Edit") { editingHandle = true }
                                .font(.subheadline)
                        }
                    } else {
                        Button("Add how you get paid to share pay links", systemImage: "arrow.up.forward.app") {
                            editingHandle = true
                        }
                    }
                    if let message = everyonePayMessage {
                        ShareLink(item: message) {
                            Label(
                                payout.hasHandle ? "Share everyone's pay-me links" : "Share what everyone owes",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    }
                } header: {
                    Text("Get paid back")
                } footer: {
                    if payout.hasHandle {
                        Text("Links open \(payout.method.title) with each person's amount filled in, ready to pay you. You confirm nothing here — they do, in \(payout.method.title).")
                    } else {
                        Text("Add your Venmo, Cash App or PayPal and each person gets a link with their amount filled in.")
                    }
                }
                .receiptRow()
            }

            Section {
                if !session.people.isEmpty {
                    let image = ShareCardImage(card: splitCard)
                    ShareLink(item: image, preview: SharePreview("The split", image: image)) {
                        Label("Share the split as a picture", systemImage: "square.and.arrow.up")
                    }
                }
                Button("Start a new bill", systemImage: "plus.circle") { confirmNewBill = true }
            }
            .receiptRow()
        }
        .paperScreen()
        .navigationTitle("The split")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        // Arriving here by the Back button abandons whatever turn was open.
        .onAppear(perform: session.endTurn)
        .confirmationDialog("Start a new bill?", isPresented: $confirmNewBill, titleVisibility: .visible) {
            Button("Start fresh", action: onNewBill)
        } message: {
            Text(session.people.isEmpty
                ? "Nobody has called dibs on this bill, so it won't be kept."
                : "This split will be kept in History.")
        }
        .confirmationDialog(
            "Remove \(personToRemove.map(session.displayName) ?? "this person")?",
            isPresented: removalIsPresented,
            titleVisibility: .visible,
            presenting: personToRemove
        ) { person in
            Button("Remove and free their dibs", role: .destructive) {
                withAnimation { session.removePerson(person.id) }
            }
        } message: { _ in
            Text("Everything they called dibs on goes back up for grabs.")
        }
        .sheet(isPresented: $editingHandle) {
            PaymentHandleSheet()
        }
        .actionBar {
            if session.hasUnclaimedItems {
                PrimaryButton("Add another person", systemImage: "person.badge.plus", action: onAddPerson)
            }
        }
    }

    private var removalIsPresented: Binding<Bool> {
        Binding(
            get: { personToRemove != nil },
            set: { if !$0 { personToRemove = nil } }
        )
    }

    /// One tap for the shared plates and whatever got forgotten.
    private var splitRestButton: some View {
        let count = session.people.count
        let title = count == 1
            ? "Put the remaining \(Money.string(unclaimedTotal)) on \(session.displayName(session.people[0]))?"
            : "Split the remaining \(Money.string(unclaimedTotal)) between \(count) people?"

        return Button(count == 1 ? "Add the rest to their share" : "Split the rest evenly", systemImage: "person.2") {
            confirmSplitRest = true
        }
        .confirmationDialog(title, isPresented: $confirmSplitRest, titleVisibility: .visible) {
            Button(count == 1 ? "Add the rest" : "Split it evenly") {
                withAnimation(.snappy) { session.splitRemainderEvenly() }
            }
        } message: {
            Text("Everything nobody called dibs on is shared equally. Each person's tax and tip go up with their share.")
        }
    }

    private func unclaimedLabel(_ item: LineItem) -> String {
        if item.isSplit { return "\(item.unclaimedQuantity)/\(item.quantity) of \(item.displayName)" }
        return item.unclaimedQuantity > 1 ? "\(item.unclaimedQuantity) × \(item.displayName)" : item.displayName
    }

    private var splitCard: ShareCard {
        ShareCard(
            people: session.people.map { (session.displayName($0), session.summary(for: $0).total) },
            unclaimed: unclaimedTotal
        )
    }
}
