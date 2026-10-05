import SwiftUI
import DibsCore

/// Everyone's totals, plus whatever nobody has claimed yet. Also the hub for
/// going back into anyone's turn.
struct SplitOverviewView: View {
    @Environment(\.money) private var money
    @Bindable var session: ClaimViewModel
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
            billName: session.billTitle,
            method: payout.method,
            handle: payHandle,
            money: money
        )
    }

    /// The payer's handle, or none on a bill pay links aren't offered for:
    /// they would ask for the same number of dollars.
    private var payHandle: String {
        session.offersPayLinks ? payout.handle : ""
    }

    private var sharesPayLinks: Bool {
        session.offersPayLinks && payout.hasHandle
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
        ScrollViewReader { scroll in
            list(scroll)
        }
    }

    private func list(_ scroll: ScrollViewProxy) -> some View {
        List {
            Section {
                VStack(spacing: Theme.Spacing.medium) {
                    BillNameField(name: $session.billName, isCentered: true)
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
                        billName: session.billTitle,
                        method: payout.method,
                        payerHandle: payHandle,
                        offersPayLinks: session.offersPayLinks
                    ) {
                        onEdit(person.id)
                    } onRemove: {
                        personToRemove = person
                    } onExpand: {
                        withAnimation { scroll.scrollTo(person.id, anchor: .top) }
                    }
                }
            } header: {
                Text("Who owes what")
            } footer: {
                if !session.people.isEmpty {
                    Text("Open a name to edit it or remove that person.")
                }
            }
            .receiptRow()

            if !session.people.isEmpty {
                Section {
                    if !session.offersPayLinks {
                        // Amounts only: nothing to set up.
                    } else if payout.hasHandle {
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
                    // Once everything is covered this is the screen's main
                    // action, down in the bar.
                    if session.hasUnclaimedItems, let message = everyonePayMessage {
                        ShareLink(item: message) {
                            Label(everyoneShareTitle, systemImage: "square.and.arrow.up")
                        }
                    }
                } header: {
                    Text("Get paid back")
                } footer: {
                    if !session.offersPayLinks {
                        Text("Pay links only work for bills in US dollars. This one is in \(money.currencyCode), so this shares the amounts without links.")
                    } else if payout.hasHandle {
                        Text("Each person's link opens \(payout.method.title) with their amount filled in, ready to pay you.")
                    } else {
                        Text("Add your Venmo, Cash App or PayPal and each person gets a link with their amount filled in.")
                    }
                }
                .receiptRow()
            }

            if session.hasUnclaimedItems {
                Section {
                    ForEach(session.receipt.unclaimedItems) { item in
                        AmountRow(item.unclaimedLabel, item.unclaimedTotal.roundedToCents())
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

            Section {
                if !session.people.isEmpty {
                    let image = ShareCardImage(card: splitCard)
                    ShareLink(item: image, preview: SharePreview(session.billTitle ?? "The split", image: image)) {
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
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done", action: done)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done", action: Keyboard.dismiss)
            }
        }
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
        .actionBar(hidesWithKeyboard: true) {
            if session.hasUnclaimedItems {
                PrimaryButton("Add another person", systemImage: "person.badge.plus", action: onAddPerson)
            } else if session.offersPayLinks, !payout.hasHandle, hasPayableTotals {
                PrimaryButton("Set up pay links", systemImage: "arrow.up.forward.app") { editingHandle = true }
            } else if let message = everyonePayMessage {
                ShareLink(item: message) {
                    PrimaryButtonLabel(title: everyoneShareTitle, systemImage: "paperplane.fill")
                }
                .primaryButtonStyle()
            }
        }
    }

    private var everyoneShareTitle: String {
        sharesPayLinks ? "Send everyone their pay links" : "Share what everyone owes"
    }

    /// Puts the bill away. It goes to History if anyone called dibs, so
    /// only a bill that would be lost asks first.
    private func done() {
        Keyboard.dismiss()
        if session.people.isEmpty {
            confirmNewBill = true
        } else {
            onNewBill()
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
            ? "Put the remaining \(money.string(unclaimedTotal)) on \(session.displayName(session.people[0]))?"
            : "Split the remaining \(money.string(unclaimedTotal)) between \(count) people?"

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

    private var splitCard: ShareCard {
        ShareCard(
            title: session.billTitle,
            people: session.people.map { (session.displayName($0), session.summary(for: $0)) },
            unclaimed: unclaimedTotal,
            money: money
        )
    }
}

/// Where a bill gets its name. Optional: an unnamed bill goes by who was on it.
struct BillNameField: View {
    @Binding var name: String
    var isCentered = false

    var body: some View {
        TextField(isCentered ? "Name this bill" : "Name this bill, like Dinner at Nopa", text: $name)
            .font(isCentered ? .headline : .body)
            .multilineTextAlignment(isCentered ? .center : .leading)
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .accessibilityLabel("Bill name")
    }
}
