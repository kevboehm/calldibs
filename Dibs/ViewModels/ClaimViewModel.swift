import UIKit
import Observation
import DibsCore

enum ClaimMode: String, CaseIterable, Identifiable, Hashable, Codable {
    case swipe
    case checklist

    var id: Self { self }

    var title: String {
        switch self {
        case .swipe: return "Swipe"
        case .checklist: return "Checklist"
        }
    }
}

/// The one source of claim state for a bill being passed around. Swipe mode,
/// checklist mode and the mini receipt all read and write through this.
@Observable
final class ClaimViewModel {
    var receipt: Receipt
    /// Everyone who has taken a turn, in order.
    private(set) var people: [Person] = []
    /// Whose turn it is. Nil between turns, while the next name is being typed.
    private(set) var currentID: Person.ID?

    /// The name field's text, for a new person or the one being edited.
    var draftName = ""
    /// Position in the swipe stack. Lives here so switching modes keeps it.
    var swipeIndex = 0

    /// Where the bill was read from on its photo. Nil for a bill typed in.
    var scan: ScanSource?
    /// The photo the bill was scanned from.
    var scanImage: UIImage?

    init(receipt: Receipt) {
        self.receipt = receipt
    }

    // MARK: - Saving and restoring

    init(snapshot: BillSnapshot) {
        receipt = snapshot.receipt
        people = snapshot.people
        currentID = snapshot.currentID
        draftName = snapshot.draftName
        swipeIndex = snapshot.swipeIndex
        scan = snapshot.scan
    }

    func snapshot(path: [Route]) -> BillSnapshot {
        BillSnapshot(
            receipt: receipt,
            people: people,
            currentID: currentID,
            draftName: draftName,
            swipeIndex: swipeIndex,
            path: path,
            scan: scan
        )
    }

    var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Turns

    private var currentIndex: Int? {
        people.firstIndex { $0.id == currentID }
    }

    var current: Person? {
        currentIndex.map { people[$0] }
    }

    /// What to call someone on screen. People who skipped the name are
    /// numbered by the order they went in.
    func displayName(_ person: Person) -> String {
        if !person.name.isEmpty { return person.name }
        let position = people.firstIndex { $0.id == person.id }.map { $0 + 1 } ?? people.count + 1
        return "Person \(position)"
    }

    /// Commits the name field: renames the current person, or starts a turn
    /// for a new one. The name may be empty when it was skipped.
    func confirmName() {
        if let index = currentIndex {
            people[index].name = trimmedName
        } else {
            var person = Person(name: trimmedName)
            // A bill that already carries a gratuity or service charge
            // starts with no tip on top; they can still add one.
            if receipt.includesGratuity { person.tip.rate = 0 }
            people.append(person)
            currentID = person.id
        }
    }

    /// Hands the phone on. Claims stay with the person and remain editable.
    /// Anyone who ended up with nothing (a turn started by mistake, say) is
    /// dropped rather than listed as owing $0.
    func endTurn() {
        people.removeAll { person in
            !receipt.items.contains { $0.claimedQuantity(by: person.id) > 0 }
        }
        currentID = nil
        draftName = ""
        swipeIndex = 0
    }

    /// Reopens an earlier person's turn.
    func beginEditing(_ id: Person.ID) {
        guard let person = people.first(where: { $0.id == id }) else { return }
        currentID = id
        draftName = person.name
        swipeIndex = 0
    }

    func removePerson(_ id: Person.ID) {
        receipt.removeClaims(by: id)
        people.removeAll { $0.id == id }
        if currentID == id { endTurn() }
    }

    // MARK: - Claiming (for the current person)

    func claimed(_ item: LineItem) -> Int {
        currentID.map { item.claimedQuantity(by: $0) } ?? 0
    }

    /// Units the current person could hold: whatever others haven't claimed.
    func available(_ item: LineItem) -> Int {
        currentID.map { item.availableQuantity(for: $0) } ?? item.unclaimedQuantity
    }

    func setClaimed(_ quantity: Int, for id: LineItem.ID) {
        guard let person = currentID,
              let index = receipt.items.firstIndex(where: { $0.id == id }) else { return }
        receipt.items[index].setClaimed(quantity, by: person)
    }

    func toggleClaimed(_ id: LineItem.ID) {
        guard let item = receipt.items.first(where: { $0.id == id }) else { return }
        setClaimed(claimed(item) > 0 ? 0 : available(item), for: id)
    }

    /// The swipe deck: only items the current person can still claim from.
    var swipeItems: [LineItem] {
        receipt.items.filter { available($0) > 0 }
    }

    /// Other people's claims on this item, e.g. "Sam" or "Sam ×3, Alex ×2".
    func othersClaims(on item: LineItem) -> String? {
        let others = people.filter { $0.id != currentID && item.claimedQuantity(by: $0.id) > 0 }
        guard !others.isEmpty else { return nil }
        return others
            .map { item.isMultiUnit ? "\(displayName($0)) ×\(item.claimedQuantity(by: $0.id))" : displayName($0) }
            .joined(separator: ", ")
    }

    // MARK: - Splitting an item into shares

    /// An item can be (re)split while it is one thing and nobody else holds a
    /// share of it, since splitting recounts the shares.
    func canSplit(_ item: LineItem) -> Bool {
        (item.quantity == 1 || item.isSplit) && item.totalClaimed == claimed(item)
    }

    func split(_ id: LineItem.ID, into parts: Int) {
        guard let index = receipt.items.firstIndex(where: { $0.id == id }) else { return }
        receipt.items[index].split(into: parts)
    }

    /// Shares everything nobody called dibs on equally between everyone who
    /// took a turn.
    func splitRemainderEvenly() {
        receipt.splitUnclaimedEvenly(among: people.map(\.id))
    }

    // MARK: - Totals

    func summary(for person: Person) -> ShareSummary {
        ShareCalculator.summary(for: receipt, person: person)
    }

    /// The current person's mini receipt.
    var summary: ShareSummary {
        summary(for: current ?? Person(name: trimmedName))
    }

    /// The current person's tip rate as a whole percentage, 0...100.
    var tipPercent: Int {
        get { NSDecimalNumber(decimal: (current?.tip.rate ?? TipConfig.defaultRate) * 100).intValue }
        set {
            guard let index = currentIndex else { return }
            people[index].tip.rate = Decimal(min(max(0, newValue), 100)) / 100
        }
    }

    /// What the current person's tip is calculated on.
    var tipBase: TipConfig.Base {
        get { current?.tip.base ?? TipConfig.defaultBase }
        set {
            guard let index = currentIndex else { return }
            people[index].tip.base = newValue
        }
    }

    var hasUnclaimedItems: Bool {
        !receipt.unclaimedItems.isEmpty
    }

    // MARK: - Editing the receipt

    func addItem() {
        receipt.items.append(LineItem(name: "", unitPrice: 0))
    }

    func addCharge() {
        receipt.charges.append(Charge(name: "", amount: 0))
    }

    /// True when the receipt printed a total that items, charges and tax
    /// don't add up to, so something is probably missing or misread.
    var totalMismatch: Bool {
        guard let printed = receipt.total else { return false }
        return printed.roundedToCents() != receipt.computedTotal.roundedToCents()
    }

    /// True when the bill fails either check against what the receipt
    /// printed: items against the subtotal, or everything against the total.
    var needsReview: Bool {
        subtotalMismatch || totalMismatch
    }

    /// True when a scan found neither a subtotal nor a total on the receipt,
    /// so the arithmetic can't be checked at all.
    var nothingToCheckAgainst: Bool {
        scan != nil && receipt.subtotal == nil && receipt.total == nil
    }

    /// A row counts once it has a name or a price; untouched rows don't.
    private func isBlank(_ item: LineItem) -> Bool {
        item.name.trimmingCharacters(in: .whitespaces).isEmpty && item.unitPrice == 0
    }

    var hasRealItems: Bool {
        receipt.items.contains { !isBlank($0) }
    }

    func removeBlankItems() {
        receipt.charges.removeAll { $0.amount == 0 }
        receipt.items.removeAll(where: isBlank)
    }

    /// True when the receipt printed a subtotal that the items don't add up to.
    var subtotalMismatch: Bool {
        subtotalGap != 0
    }

    /// How far the items fall short of the printed subtotal. Negative when
    /// they come to more than it; zero when they match or none was printed.
    var subtotalGap: Decimal {
        guard let printed = receipt.subtotal else { return 0 }
        return (printed - receipt.itemsSubtotal).roundedToCents()
    }

    /// How far the bill falls short of the printed total, likewise.
    var totalGap: Decimal {
        guard let printed = receipt.total else { return 0 }
        return (printed - receipt.computedTotal).roundedToCents()
    }

    // MARK: - Checking against the scan

    /// Why a scanned line deserves a second look, or nil when it reads fine.
    func doubt(about item: LineItem) -> String? {
        guard let scan, !isBlank(item) else { return nil }
        if item.unitPrice == 0 { return "No price was read" }
        // "Item" is what the parser calls a line with no words on it.
        if item.name == "Item" || item.name.filter(\.isLetter).count < 2 { return "The name couldn't be read" }
        // The items come to more than the receipt says, by exactly this line.
        if subtotalGap < 0, item.lineTotal.roundedToCents() == -subtotalGap {
            return "This may not be an item"
        }
        if let confidence = scan.confidence(of: item.id), confidence < 0.5 {
            return "Hard to read, check it"
        }
        return nil
    }

    /// The strip of the photo an item was printed on.
    func scanStrip(for item: LineItem.ID) -> UIImage? {
        guard let image = scanImage?.cgImage,
              let rect = scan?.stripRect(for: item, in: CGSize(width: image.width, height: image.height)),
              rect.width > 1, rect.height > 1,
              let strip = image.cropping(to: rect) else { return nil }
        return UIImage(cgImage: strip)
    }
}
