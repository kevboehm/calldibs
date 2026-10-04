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
    @AppStorage("venmoHandle") private var venmoHandle = ""
    @State private var editingHandle = false

    private var hasPayableTotals: Bool {
        session.people.contains { session.summary(for: $0).total > 0 }
    }

    private var everyonePayMessage: String? {
        VenmoShare.everyoneMessage(
            people: session.people.map { (session.displayName($0), session.summary(for: $0).total) },
            handle: venmoHandle
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
                        payerHandle: venmoHandle
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
                    if VenmoLink.normalize(venmoHandle).isEmpty {
                        Button("Add your Venmo to share pay links", systemImage: "arrow.up.forward.app") {
                            editingHandle = true
                        }
                    } else {
                        HStack {
                            Label("Your Venmo", systemImage: "arrow.up.forward.app")
                            Spacer()
                            Text("@\(venmoHandle)")
                                .foregroundStyle(.secondary)
                            Button("Edit") { editingHandle = true }
                                .font(.subheadline)
                        }
                        if let message = everyonePayMessage {
                            ShareLink(item: message) {
                                Label("Share everyone's pay-me links", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                } header: {
                    Text("Get paid back")
                } footer: {
                    Text("Links open Venmo with each person's amount filled in, ready to pay you. You confirm nothing here — they do, in Venmo.")
                }
                .receiptRow()
            }

            Section {
                if !session.people.isEmpty {
                    let image = ShareCardImage(card: splitCard)
                    ShareLink(item: image, preview: SharePreview("The split", image: image.preview)) {
                        Label("Share the split as a picture", systemImage: "square.and.arrow.up")
                    }
                }
                Button("Start a new bill", systemImage: "trash", role: .destructive) { confirmNewBill = true }
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
            Button("Discard this split", role: .destructive, action: onNewBill)
        } message: {
            Text("This split isn't saved anywhere.")
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
            VenmoHandleSheet(handle: $venmoHandle)
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
