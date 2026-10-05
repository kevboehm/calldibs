import SwiftUI
import DibsCore

/// Shown after every scan: a plain summary of what was read, to check against
/// the receipt before anyone claims. Edit turns it into a form for fixing OCR
/// mistakes.
struct ReceiptSummaryView: View {
    @Environment(\.money) private var money
    @Bindable var session: ClaimViewModel
    let onContinue: () -> Void

    @State private var isEditing: Bool
    /// The scanned lines print in once; after that they just show.
    @State private var hasPrinted = false
    @State private var showScan = false
    @State private var confirmMismatch = false
    @State private var pickingCurrency = false

    init(session: ClaimViewModel, onContinue: @escaping () -> Void) {
        self.session = session
        self.onContinue = onContinue
        // Manual entry starts with one blank row, so open ready to type.
        let isBlank = session.receipt.items.allSatisfy { $0.name.isEmpty && $0.unitPrice == 0 }
        _isEditing = State(initialValue: isBlank)
    }

    private var receipt: Receipt { session.receipt }

    var body: some View {
        List {
            Section {
                BillNameField(name: $session.billName)
            }
            .receiptRow()
            reviewBanner
            if isEditing {
                editableItems
            } else {
                summaryItems
            }
            totals
        }
        .paperScreen()
        .task {
            try? await Task.sleep(for: .seconds(1))
            hasPrinted = true
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isEditing ? "Fix the items" : "Here's the bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if session.scanImage != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("See the receipt", systemImage: "doc.viewfinder") {
                        Keyboard.dismiss()
                        showScan = true
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    Keyboard.dismiss()
                    withAnimation { isEditing.toggle() }
                }
            }
            #if DEBUG
            if let scan = session.scan {
                ToolbarItem(placement: .secondaryAction) {
                    // Once the bill matches the paper, the scan and the
                    // corrections make a fixture for the parser's tests.
                    ShareLink(items: ScanFixture.pair(receipt: receipt, scan: scan)) {
                        SharePreview($0.filename)
                    } label: {
                        Label("Export as fixture", systemImage: "ladybug")
                    }
                }
            }
            #endif
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { Keyboard.dismiss() }
            }
        }
        .actionBar(hidesWithKeyboard: true) {
            PrimaryButton("Start calling dibs", systemImage: "hand.draw", action: continueTapped)
                .disabled(!session.hasRealItems)
                .confirmationDialog(
                    "This bill doesn't add up to the receipt",
                    isPresented: $confirmMismatch,
                    titleVisibility: .visible
                ) {
                    Button("Continue anyway", action: startClaiming)
                    Button("Review the bill", role: .cancel) {}
                } message: {
                    Text(mismatchNotes.joined(separator: " "))
                }
        }
        .sheet(isPresented: $showScan) {
            if let image = session.scanImage {
                ScanViewer(image: image)
            }
        }
    }

    /// Asks first when the bill fails the arithmetic check.
    private func continueTapped() {
        Keyboard.dismiss()
        if session.needsReview {
            confirmMismatch = true
        } else {
            startClaiming()
        }
    }

    private func startClaiming() {
        Keyboard.dismiss()
        session.removeBlankItems()
        isEditing = false
        onContinue()
    }

    // MARK: - Arithmetic check

    /// Up top, where it can't be scrolled past: the bill doesn't add up to
    /// what the receipt printed.
    @ViewBuilder
    private var reviewBanner: some View {
        if session.needsReview {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("This doesn't add up to the receipt", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.Palette.notMine)
                    ForEach(mismatchNotes, id: \.self) { note in
                        Text(note)
                            .font(.subheadline)
                    }
                    Text("Check every line against the receipt before anyone calls dibs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if session.scanImage != nil {
                        Button("See the receipt", systemImage: "doc.viewfinder") {
                            Keyboard.dismiss()
                            showScan = true
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .receiptRow()
        } else if session.nothingToCheckAgainst {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("No total to check against", systemImage: "questionmark.circle")
                        .font(.headline)
                    Text("The scan didn't find a subtotal or total on the receipt, so it can't tell whether an item is missing. Check every line against the receipt yourself.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if session.scanImage != nil {
                        Button("See the receipt", systemImage: "doc.viewfinder") {
                            Keyboard.dismiss()
                            showScan = true
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
            .receiptRow()
        }
    }

    /// One sentence for each check that failed.
    private var mismatchNotes: [String] {
        var notes: [String] = []
        if let printed = receipt.subtotal, session.subtotalMismatch {
            notes.append("\(gapNote(session.subtotalGap, of: "The items")) the receipt's subtotal of \(money.string(printed)).")
        }
        if let printed = receipt.total, session.totalMismatch {
            notes.append("\(gapNote(session.totalGap, of: "This")) the receipt's total of \(money.string(printed)).")
        }
        return notes
    }

    // MARK: - Summary

    private var summaryItems: some View {
        Section {
            ForEach(Array(receipt.items.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    Text("\(item.quantity)")
                        .font(.subheadline.bold())
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                        .frame(minWidth: 30, minHeight: 30)
                        .background(.tint.opacity(0.14), in: .rect(cornerRadius: 9))
                        .accessibilityLabel("Quantity \(item.quantity)")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayName)
                        if item.isMultiUnit {
                            Text(item.unitPriceLabel(money))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let doubt = session.doubt(about: item) {
                            DoubtLabel(doubt)
                        }
                    }
                    Spacer()
                    Text(money.string(item.lineTotal.roundedToCents()))
                        .fontDesign(.monospaced)
                }
                .printIn(index: index, isActive: !hasPrinted)
            }
            .receiptRow()
        } header: {
            Text("\(receipt.items.count) \(receipt.items.count == 1 ? "item" : "items")")
        } footer: {
            Text("Check this against the receipt. Tap Edit if the scan got something wrong.")
        }
    }

    // MARK: - Editing

    private var editableItems: some View {
        Section {
            ForEach($session.receipt.items) { $item in
                ItemEditRow(item: $item, strip: session.scanStrip(for: item.id), doubt: session.doubt(about: item))
            }
            .onDelete { session.receipt.items.remove(atOffsets: $0) }
            .receiptRow()

            Button {
                session.addItem()
            } label: {
                Label("Add item", systemImage: "plus")
            }
            .receiptRow()
        } header: {
            Text("Items")
        } footer: {
            Text("Make this match the receipt: Qty is how many were ordered, and prices are line totals. Swipe a row to delete it.")
        }
    }

    // MARK: - Totals

    private var totals: some View {
        Section("Totals") {
            currencyRow
            AmountRow("Subtotal", receipt.itemsSubtotal.roundedToCents())

            if let printed = receipt.subtotal, session.subtotalMismatch {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "\(gapNote(session.subtotalGap, of: "The items")) the receipt's subtotal of \(money.string(printed)), so \(session.subtotalGap > 0 ? "an item may be missing or priced too low" : "a line may be doubled or not an item"). Edit the items, or split tax by the item sum instead.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.footnote)
                    .foregroundStyle(Theme.Palette.notMine)
                    Button("Use the item sum") { session.receipt.subtotal = nil }
                        .buttonStyle(.glass)
                }
            }

            if isEditing {
                HStack {
                    Text("Tax")
                    Spacer()
                    MoneyField(amount: $session.receipt.tax)
                        .frame(width: 120)
                }
                ForEach($session.receipt.charges) { $charge in
                    HStack {
                        TextField("Service charge, fee…", text: $charge.name)
                        Spacer()
                        MoneyField(amount: $charge.amount)
                            .frame(width: 120)
                    }
                }
                .onDelete { session.receipt.charges.remove(atOffsets: $0) }
                Button("Add a charge or fee", systemImage: "plus", action: session.addCharge)
            } else {
                AmountRow("Tax", receipt.tax)
                ForEach(receipt.charges) { charge in
                    AmountRow(charge.name.isEmpty ? "Charge" : charge.name, charge.amount)
                }
            }

            AmountRow("Total", receipt.computedTotal.roundedToCents(), isTotal: true)

            if let printed = receipt.total, session.totalMismatch {
                Label(
                    "\(gapNote(session.totalGap, of: "This")) the receipt's total of \(money.string(printed)). If this bill has a service charge, fee or discount that isn't listed, tap Edit to add it.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(Theme.Palette.notMine)
            }
        }
        .receiptRow()
    }

    /// The currency the bill was read in, when that isn't the phone's own,
    /// and while editing a way to change it.
    @ViewBuilder
    private var currencyRow: some View {
        if isEditing || money.currencyCode != Money.deviceCode {
            HStack {
                Text("Currency")
                Spacer()
                Text("\(money.name) · \(money.currencyCode)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if isEditing {
                    Button("Change") {
                        Keyboard.dismiss()
                        pickingCurrency = true
                    }
                    .font(.subheadline)
                }
            }
            .sheet(isPresented: $pickingCurrency) {
                CurrencyPicker(selection: Binding(
                    get: { money.currencyCode },
                    set: { session.receipt.currencyCode = $0 }
                ))
            }
        }
    }

    /// "The items come to $4.50 less than", ready for what they fall short of.
    private func gapNote(_ gap: Decimal, of subject: String) -> String {
        "\(subject) come\(subject == "This" ? "s" : "") to \(money.string(abs(gap))) \(gap > 0 ? "less" : "more") than"
    }
}

/// Why a scanned line deserves a second look.
private struct DoubtLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(Theme.Palette.notMine)
    }
}

private struct ItemEditRow: View {
    @Environment(\.money) private var money
    @Binding var item: LineItem
    /// The row of the photo this item was read from.
    var strip: UIImage?
    var doubt: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let strip {
                ScanStrip(image: strip)
            }
            if let doubt {
                DoubtLabel(doubt)
            }

            TextField("Item name", text: $item.name)

            HStack {
                Stepper("Qty \(item.quantity)", value: quantity, in: 1...99)
                    .fixedSize()
                Spacer()
                MoneyField(amount: lineTotal)
                    .frame(width: 120)
            }

            if item.isMultiUnit {
                Text(item.unitPriceLabel(money))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // The receipt prints line totals, so that is what stays fixed while the
    // quantity is corrected.
    private var quantity: Binding<Int> {
        Binding(
            get: { item.quantity },
            set: { newValue in
                let total = item.lineTotal
                item.quantity = newValue
                item.unitPrice = total / Decimal(item.quantity)
            }
        )
    }

    private var lineTotal: Binding<Decimal> {
        Binding(
            get: { item.lineTotal.roundedToCents() },
            set: { item.unitPrice = $0 / Decimal(item.quantity) }
        )
    }
}
