import Foundation

/// Turns recognized text lines (top to bottom) into a best-effort `Receipt`.
/// Knows nothing about images or OCR, so it can be tuned against plain strings.
public enum ReceiptTextParser {
    public static func parse(lines: [String]) -> Receipt {
        parseWithSources(lines: lines).receipt
    }

    /// The receipt, plus which of `lines` each item was read from (its name
    /// line and its price line, when those are different rows), so the item
    /// can be shown next to that part of the photo.
    public static func parseWithSources(lines: [String]) -> (receipt: Receipt, itemLines: [LineItem.ID: [Int]]) {
        parse(lines: lines, rows: nil)
    }

    /// The same from OCR rows, whose positions in the photo help tell a
    /// name that wrapped onto a second line from a line of its own.
    public static func parse(rows: [OCRRow]) -> Receipt {
        parseWithSources(rows: rows).receipt
    }

    public static func parseWithSources(rows: [OCRRow]) -> (receipt: Receipt, itemLines: [LineItem.ID: [Int]]) {
        parse(lines: rows.map(\.text), rows: rows)
    }

    private static func parse(lines: [String], rows: [OCRRow]?) -> (receipt: Receipt, itemLines: [LineItem.ID: [Int]]) {
        let entries = entries(from: lines, rows: rows)

        // Items are printed first; from the first subtotal, tax or total line
        // on, a priced line is a summary, a payment or a tip suggestion.
        let summaryStart = entries.firstIndex { $0.kind.isSummary } ?? entries.count
        // "Service charge" under the items, with no subtotal line before it,
        // is still a charge. A name like "Room Service Club" in the middle of
        // the items is something someone ordered.
        let chargeStart = entries[..<summaryStart].lastIndex { $0.kind != .charge && $0.kind != .noise && $0.kind != .tip }
            .map { $0 + 1 } ?? 0
        var itemEntries = entries[..<chargeStart]
            .filter { ($0.kind == .item || $0.kind == .charge) && $0.price > 0 && !$0.isCredit }
        let summary = entries[summaryStart...]
        let totals = summary.filter { $0.kind == .total || $0.kind == .grandTotal }
        let firstTotal = summary.firstIndex { $0.kind == .total || $0.kind == .grandTotal } ?? entries.endIndex

        var subtotal = summary.first { $0.kind == .subtotal }?.price
        // Tax printed after the total is a breakdown of tax already included.
        var tax = summary[..<firstTotal].filter { $0.kind == .tax }.reduce(0) { $0 + $1.price }

        // A subtotal under another name ("Food 27.98") still equals the sum of
        // the items above it, and what follows it up to the total is tax.
        if subtotal == nil, let index = hiddenSubtotal(in: itemEntries, totals: totals.map(\.price), tax: tax) {
            subtotal = itemEntries[index].price
            tax += sum(itemEntries[(index + 1)...])
            itemEntries.removeSubrange(index...)
        }

        var items = itemEntries.map { makeItem(label: $0.label, linePrice: $0.price) }
        var itemLines: [LineItem.ID: [Int]] = [:]
        for (item, entry) in zip(items, itemEntries) { itemLines[item.id] = entry.lines }
        let base = subtotal ?? sum(items)

        // Service charges, gratuities and fees printed before the total.
        var chargeEntries = entries[chargeStart..<summaryStart].filter { $0.kind == .charge && !$0.isCredit }
            + summary[..<firstTotal].filter { $0.kind == .charge && !$0.isCredit }
        // One printed after a total is only real if a later total includes
        // it; otherwise it is a suggestion.
        let late = summary[firstTotal...].filter { $0.kind == .charge && !$0.isCredit }
        if !late.isEmpty, totals.contains(where: { $0.price == base + tax + sum(chargeEntries) + sum(late) }) {
            chargeEntries += late
        }
        // A tip printed on a paid copy is shared like a service charge, but
        // only when a total or payment after it shows it was added on.
        var paidTotal: Decimal?
        let owedBeforeTip = base + tax + sum(chargeEntries)
        if let tip = entries.first(where: { tip in
            tip.kind == .tip && tip.price > 0 && !tip.isCredit && entries[(tip.index + 1)...].contains {
                ($0.kind == .total || $0.kind == .grandTotal || $0.kind == .noise) && $0.price == owedBeforeTip + tip.price
            }
        }) {
            chargeEntries.append(tip)
            paidTotal = owedBeforeTip + tip.price
        }
        var charges = chargeEntries.map { Charge(name: cleanName($0.label), amount: $0.price) }
        // A discount is taken on trust only when the total proves it.
        let discounts = summary[..<firstTotal].filter { $0.kind == .discount }
        if !discounts.isEmpty, totals.contains(where: { $0.price == base + tax + sum(chargeEntries) - sum(discounts) }) {
            charges += discounts.map { Charge(name: cleanName($0.label), amount: -$0.price) }
        }
        let fees = charges.reduce(0) { $0 + $1.amount }

        // Charges under names the parser doesn't know ("SST 0.44"), sitting
        // between the subtotal and a total that only adds up with them.
        let unnamed = sum(summary[..<firstTotal].filter { $0.kind == .item && !$0.isCredit })
        if unnamed > 0, !totals.contains(where: { $0.price == base + tax + fees }),
           totals.contains(where: { $0.price == base + tax + fees + unnamed }) {
            tax += unnamed
        }

        // Of several totals, the one that adds up; otherwise the grand total,
        // otherwise the first (a later one may include a tip).
        var total = totals.first { $0.price == base + tax + fees }?.price
            ?? paidTotal
            ?? totals.first { $0.kind == .grandTotal }?.price
            ?? totals.first?.price
        // A total under another name ("Amount: 114.95"), or with no name.
        if total == nil, tax > 0 || subtotal != nil || items.count > 1 {
            // Failing that, a card or cash payment for exactly that amount.
            total = entries[(itemEntries.last?.index ?? 0)...]
                .first { !$0.kind.isSummary && $0.price == base + tax + fees }?.price
        }
        // A tax line too faint to read still shows as the gap between the
        // subtotal and the total.
        if tax == 0, let subtotal, let total, total > subtotal + fees, total - subtotal - fees <= subtotal / 4 {
            tax = total - subtotal - fees
        }

        // When the items don't add up to what the receipt says they should,
        // try the readings that would explain it.
        if let target = subtotal ?? total.map({ $0 - tax - fees }), sum(items) != target {
            // "2 Burger 9.50" printing the unit price, not the line total.
            let asUnitPrices = items.map { item in
                var item = item
                if item.quantity > 1 { item.unitPrice *= Decimal(item.quantity) }
                return item
            }
            if sum(asUnitPrices) == target {
                items = asUnitPrices
            } else if let start = items.indices.dropFirst().first(where: { sum(items[$0...]) == target }) {
                if sum(items[..<start]) == target || start == items.count - 1 {
                    // The sum restated under the items: per-category
                    // subtotals ("Food", "Beverage") or a single line.
                    items.removeSubrange(start...)
                } else if start < items.count - start {
                    // A few header lines that happened to end in a number.
                    items.removeSubrange(..<start)
                }
            } else if let extra = soleItem(in: items, priced: sum(items) - target) {
                // One line that is not a charge: a "was 6.17" note, or an
                // "each" price above the line that totals it.
                items.remove(at: extra)
            }
        }

        let kept = Set(items.map(\.id))
        return (
            Receipt(items: items, tax: tax, subtotal: subtotal, total: total, charges: charges),
            itemLines.filter { kept.contains($0.key) }
        )
    }

    private static func sum(_ entries: some Sequence<Entry>) -> Decimal {
        entries.reduce(0) { $0 + $1.price }
    }

    private static func sum(_ items: some Sequence<LineItem>) -> Decimal {
        items.reduce(0) { $0 + $1.lineTotal }
    }

    /// The item with this line total, when removing it could only mean one
    /// thing: it is the only one, or all of them carry the same name.
    private static func soleItem(in items: [LineItem], priced price: Decimal) -> Int? {
        let matches = items.indices.filter { items[$0].lineTotal == price }
        guard let last = matches.last, items.count > 1 else { return nil }
        return Set(matches.map { items[$0].name }).count == 1 ? last : nil
    }

    /// The first would-be item that equals the sum of at least two items
    /// above it. One with more lines beneath it only counts when those lines
    /// carry it to a printed total, so "5, 5, 10, 3" stays four items.
    private static func hiddenSubtotal(in candidates: [Entry], totals: [Decimal], tax: Decimal) -> Int? {
        candidates.indices.dropFirst(2).first { index in
            let price = candidates[index].price
            guard sum(candidates[..<index]) == price else { return false }
            let rest = sum(candidates[(index + 1)...])
            return index == candidates.count - 1 ? !totals.contains(sum(candidates) + tax)
                : totals.contains(price + rest + tax)
        }
    }

    // MARK: - Line anatomy

    /// A line that ends in a price, with the name that goes with it.
    private struct Entry {
        var label: String
        var price: Decimal
        /// Printed as a negative amount: a discount, void or refund.
        var isCredit: Bool
        var kind: Kind
        /// Position among the priced lines.
        var index = 0
        /// Which input lines it was read from.
        var lines: [Int] = []
    }

    private static func entries(from lines: [String], rows: [OCRRow]?) -> [Entry] {
        var entries: [Entry] = []
        let layout = Layout(lines, rows: rows)
        // Name-only lines in a row, waiting to learn whose they are: the
        // price line beneath them, or the item above that they wrapped from.
        var pending: [Layout.Name] = []
        // The entry directly above `pending`, the name on its own line, and
        // whether its price sat on a row of its own.
        var above: (entry: Int, name: Layout.Name, barePrice: Bool)?

        // Whatever the price line beneath didn't take may be the wrapped
        // end of the item above.
        func settle(_ names: [Layout.Name]) {
            guard let above, entries[above.entry].kind == .item, !entries[above.entry].isCredit else { return }
            var from = above.name
            for name in names.prefix(2) {
                // A quantity or unit price at the end of the line means the
                // name was complete.
                guard !entries[above.entry].label.contains(#/(\d[.,]\d{2}\)?|[xX×]\s?\d{1,2})$/#),
                      layout.wraps(from: from, onto: name) else { break }
                entries[above.entry].label += " " + name.text
                entries[above.entry].lines.append(name.line)
                from = name
            }
        }

        for (number, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            guard let (ownLabel, price, isCredit) = splitTrailingPrice(line) else {
                if line.contains(where: \.isLetter), !isMetadata(line.lowercased()) {
                    pending.append(Layout.Name(text: line, line: number))
                } else {
                    settle(pending)
                    pending = []
                    above = nil
                }
                continue
            }
            let hasOwnLabel = ownLabel.contains(where: \.isLetter)
            var names = pending
            var name = Layout.Name(text: ownLabel, line: number)
            var label = ownLabel
            var source = [number]
            if !hasOwnLabel, let named = names.popLast() {
                name = named
                label = named.text
                source = [named.line, number]
            }
            // The start of a name that ran on to this line: it says so, or,
            // above a price on its own row, it filled the line.
            var first = name
            while let start = names.last, source.count < 4, classify(start.text) == .item,
                  layout.runsOn(start, into: first)
                    || !hasOwnLabel && above?.barePrice == true && layout.wraps(from: start, onto: first) {
                label = start.text + " " + label
                source.insert(start.line, at: 0)
                first = start
                names.removeLast()
            }
            settle(names)
            pending = []

            let kind = label.contains(where: \.isLetter) ? classify(label) : .bare
            entries.append(Entry(label: label, price: price, isCredit: isCredit, kind: kind, index: entries.count, lines: source))
            above = (entries.count - 1, name, !hasOwnLabel)
        }
        settle(pending)
        return markingSubtotal(in: entries)
    }

    /// What the receipt's item lines have in common, to tell a name that
    /// wrapped onto a second line from a line that is something else.
    private struct Layout {
        /// A name, or part of one, and the line it is on.
        struct Name {
            var text: String
            var line: Int
        }

        /// Where each row sits in the photo, when every row says.
        private let rows: [OCRRow]?
        /// Where the name stops on each line that carries an item's price,
        /// or sits directly above a price on a row of its own.
        private var nameEnds: [Double] = []
        /// Most items start with a quantity.
        private var usesQuantity = false
        /// Where the names start and the prices begin, when the photo shows
        /// prices in a column of their own beside the names.
        private var nameColumn: (left: Double, right: Double)?

        init(_ lines: [String], rows: [OCRRow]?) {
            self.rows = rows.flatMap { rows in
                rows.count == lines.count && rows.allSatisfy { $0.spans?.contains { $0.length > 0 } == true } ? rows : nil
            }
            let lines = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            var names: [Name] = []
            var lastText: Int?
            for (index, line) in lines.enumerated() where !line.isEmpty {
                defer { lastText = index }
                guard let label = splitTrailingPrice(line)?.label else { continue }
                if label.contains(where: \.isLetter) {
                    names.append(Name(text: label, line: index))
                } else if let lastText, splitTrailingPrice(lines[lastText]) == nil {
                    names.append(Name(text: lines[lastText], line: lastText))
                }
            }
            names = names.filter { classify($0.text) == .item }
            nameEnds = names.map(end)
            nameColumn = Self.nameColumn(beside: names, in: self.rows)
            let counted = names.filter { Self.startsWithQuantity($0.text) }.count
            usesQuantity = counted >= 2 && counted * 2 > names.count
        }

        /// From the left edge of the names to the leftmost price printed
        /// beside one.
        private static func nameColumn(beside names: [Name], in rows: [OCRRow]?) -> (left: Double, right: Double)? {
            guard let rows else { return nil }
            let priced = names.compactMap { name -> (left: Double, price: Double)? in
                let spans = rows[name.line].spans ?? []
                guard spans.count > 1, let first = spans.first, let last = spans.last else { return nil }
                return (first.minX, last.minX)
            }
            guard priced.count >= 2, let left = priced.map(\.left).min(), let right = priced.map(\.price).min(),
                  right > left else { return nil }
            return (left, right)
        }

        /// How far a name could run before its next word had to wrap. The
        /// longest name on another line shows it, when names come close to
        /// the prices; when every name is short, only the prices mark it.
        private func limit(besides end: Double) -> Double? {
            var others = nameEnds
            if let own = others.firstIndex(of: end) { others.remove(at: own) }
            guard others.count >= 2, let longest = others.max() else { return nil }
            guard let nameColumn else { return longest }
            return longest - nameColumn.left >= 0.8 * (nameColumn.right - nameColumn.left) ? longest : nameColumn.right
        }

        /// Where a name stops along its line: its right edge in the photo,
        /// or with no photo to go by, its length in characters.
        private func end(of name: Name) -> Double {
            guard let spans = rows?[name.line].spans?.filter({ $0.length > 0 }), var last = spans.first else {
                return Double(name.text.count)
            }
            // The name is the start of its row's text, a space between fragments.
            var remaining = name.text.count
            for span in spans {
                guard remaining > 0 else { break }
                last = span
                if remaining <= span.length {
                    return span.minX + span.width * Double(remaining) / Double(span.length)
                }
                remaining -= span.length + 1
            }
            return last.minX + last.width
        }

        /// The row's longest fragment: the one that best shows its print.
        private func print(onLine line: Int) -> OCRRow.Span? {
            rows?[line].spans?.max { $0.length < $1.length }
        }

        /// The room a word of this many characters takes on a line, with the
        /// space before it, in the same measure.
        private func room(for characters: Int, onLine line: Int) -> Double {
            guard let span = print(onLine: line), span.length > 0 else { return Double(characters + 1) }
            return span.width * Double(characters + 1) / Double(span.length)
        }

        /// Smaller print under an item is a note about it, not more of its name.
        private func sameSize(_ first: Int, _ second: Int) -> Bool {
            guard let above = print(onLine: first)?.height, let below = print(onLine: second)?.height,
                  above > 0 else { return true }
            return (0.76...1.32).contains(below / above)
        }

        /// A name wraps when its next word didn't fit, so the line it left
        /// was full: with the word, longer than any other line's name. A
        /// line that stops mid-phrase says so itself.
        func wraps(from name: Name, onto next: Name) -> Bool {
            let letters = next.text.filter(\.isLetter).count
            guard sameSize(name.line, next.line),
                  letters >= 2, next.text.filter(\.isNumber).count <= letters,
                  classify(next.text) == .item,
                  !(usesQuantity && Self.startsWithQuantity(next.text)),
                  !Self.isModifier(next.text), !Self.repeats(next.text, name.text) else { return false }
            if Self.stopsMidPhrase(name.text) { return true }

            let end = end(of: name)
            // A line with an amount in it is an entry of its own.
            guard let column = limit(besides: end),
                  !next.text.contains(#/\d[.,]\d{2}/#), !name.text.contains(#/\d[.,]\d{2}/#) else { return false }
            return end + room(for: Self.firstWord(of: next.text).count, onLine: next.line) > column
                && self.end(of: next) <= column * 1.03
        }

        /// A name-only line that is the start of the item priced beneath it:
        /// it stops mid-phrase, or it has the quantity that line lacks.
        func runsOn(_ name: Name, into next: Name) -> Bool {
            guard sameSize(name.line, next.line) else { return false }
            // A dash or an open bracket ends headings too ("Wine Glass-").
            if let last = name.text.last, ",&".contains(last) { return true }
            return usesQuantity && Self.startsWithQuantity(name.text) && !Self.startsWithQuantity(next.text)
        }

        /// Ends on a comma, a spaced dash or the like, or inside a bracket.
        private static func stopsMidPhrase(_ text: String) -> Bool {
            if let last = text.last, ",&/".contains(last) || text.hasSuffix(" -") { return true }
            return text.filter { $0 == "(" }.count > text.filter { $0 == ")" }.count
        }

        /// Up to the first space after something readable, so a bullet
        /// stays with the word it introduces.
        private static func firstWord(of text: String) -> Substring {
            var seenWord = false
            for index in text.indices {
                if text[index].isLetter || text[index].isNumber { seenWord = true }
                if text[index] == " ", seenWord { return text[..<index] }
            }
            return text[...]
        }

        /// "Side : Focaccia Bread" over "focaccia bread": the same words
        /// again, not more of the name.
        private static func repeats(_ next: String, _ name: String) -> Bool {
            let said = Set(name.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }))
            let words = next.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            return !words.isEmpty && words.allSatisfy(said.contains)
        }

        private static func startsWithQuantity(_ label: String) -> Bool {
            label.firstMatch(of: #/^(\d{1,2}\s*[xX×]?|[xX×]\s?\d{1,2})\s+\S/#) != nil
        }

        /// "+ Grilled", "No onion": said about the item above, not part of
        /// its name.
        private static func isModifier(_ line: String) -> Bool {
            let lower = line.lowercased()
            return "+-*>(#".contains(lower.first ?? " ")
                || ["add ", "no ", "extra ", "sub ", "w/"].contains { lower.hasPrefix($0) }
        }
    }

    /// "Total" printed above the charges and tax, with a larger total beneath
    /// them, is the subtotal under another name. Only when the lines between
    /// the two carry one to the other, so a total restated with a tip stays.
    private static func markingSubtotal(in entries: [Entry]) -> [Entry] {
        guard !entries.contains(where: { $0.kind == .subtotal }),
              let first = entries.firstIndex(where: { $0.kind == .total }) else { return entries }
        let later = entries[(first + 1)...]
        guard let last = later.firstIndex(where: { $0.kind == .total || $0.kind == .grandTotal }),
              last > first + 1 else { return entries }
        let between = entries[(first + 1)..<last].filter { !$0.isCredit }
        guard between.allSatisfy({ $0.kind == .tax || $0.kind == .charge || $0.kind == .item }),
              entries[first].price + sum(between) == entries[last].price else { return entries }

        var entries = entries
        entries[first].kind = .subtotal
        return entries
    }

    /// Splits "2 Burger  $19.00 T" into ("2 Burger", 19.00). Nil when the line
    /// does not end in a price. A tax flag ("T", "FS", "1") may follow the
    /// price, and a minus sign touching either side of it marks a credit.
    static func splitTrailingPrice(_ line: String) -> (label: String, price: Decimal, isCredit: Bool)? {
        let pattern = #/^(.*?)\s*(-\$?|\$\s?)?(\d[\d,]*)\s?[.,]\s?(\d{2})(-?)(?:\s*[A-Z*]{1,2}|\s+\d)?$/#
        guard let match = line.wholeMatch(of: pattern) else { return nil }
        let whole = match.3.replacingOccurrences(of: ",", with: "")
        guard let price = Decimal(string: "\(whole).\(match.4)", locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        let isCredit = match.2?.hasPrefix("-") == true || !match.5.isEmpty
        return (String(match.1).trimmingCharacters(in: .whitespaces), price, isCredit)
    }

    private enum Kind {
        /// `bare` is a price with no words on its line or the line above.
        /// `charge` is a service charge, gratuity or fee; `discount` a
        /// named reduction; `tip` a tip line, which is a charge only when
        /// a later amount includes it.
        case subtotal, tax, total, grandTotal, charge, discount, tip, noise, bare, item

        var isSummary: Bool { self == .subtotal || self == .tax || self == .total || self == .grandTotal }
    }

    /// Header fields like "Server: Andy" or "Table #12". Never an item.
    private static func isMetadata(_ lower: String) -> Bool {
        lower.firstMatch(of: #/^(server|cashier|waiter|host|table|guests?|check|order|ticket|date|time|tel|phone|station|terminal|invoice)\b\s*[:#.]/#) != nil
    }

    private static let taxWords: Set<String> = ["tax", "taxes", "vat", "gst", "hst", "pst", "qst"]
    private static let noiseWords: Set<String> = [
        "tip", "gratuity", "change", "cash", "visa", "mastercard", "amex", "discover",
        "card", "debit", "credit", "tendered", "tender", "payment", "paid",
        "savings", "saved",
    ]
    private static let chargeWords: Set<String> = [
        "gratuity", "grat", "service", "svc", "surcharge", "fee", "fees", "charge", "delivery", "corkage", "cover",
    ]
    /// A gratuity line that is advice, not a charge: "Suggested gratuity 18%".
    private static let suggestionWords: Set<String> = [
        "suggested", "suggestion", "suggest", "guide", "recommended", "optional", "example", "tip",
    ]
    private static let discountWords: Set<String> = ["discount", "coupon", "promo", "comp"]

    private static func classify(_ label: String) -> Kind {
        // OCR reads "Tota1" and "T0TAL"; cuts of beef are not tips.
        let lower = label.lowercased()
            .replacing("0", with: "o")
            .replacing("1", with: "l")
            .replacing(#/\b(tri|sirloin)[\s-]?tip/#, with: "")
        let words = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))

        if words.contains("subtotal") || words.contains("sub") && words.contains("total") {
            return .subtotal
        }
        // "Total 11 item(s)" is the pre-tax sum of the items.
        if words.contains("total"), words.contains("item") || words.contains("items") {
            return .subtotal
        }
        if !words.isDisjoint(with: taxWords) { return .tax }
        if !words.isDisjoint(with: discountWords) { return .discount }
        // "Parties of 6+": the automatic gratuity for a large table.
        if label.lowercased().contains(#/\bpart(y|ies) of \d/#) { return .charge }
        if !words.isDisjoint(with: chargeWords), words.isDisjoint(with: suggestionWords) { return .charge }
        if words.contains("tip") || words.contains("tips"), words.isDisjoint(with: suggestionWords.subtracting(["tip"])) {
            return .tip
        }
        if !words.isDisjoint(with: noiseWords) || isMetadata(lower) { return .noise }
        if words.contains("due") || lower.contains("grand total") { return .grandTotal }
        if words.contains("total") { return .total }
        return .item
    }

    // MARK: - Items

    /// The price at the end of an item line is the line total, so a quantity
    /// prefix divides it. An explicit "2 @ 4.50" wins over the division.
    private static func makeItem(label rawLabel: String, linePrice: Decimal) -> LineItem {
        let posix = Locale(identifier: "en_US_POSIX")
        // "Vodka($9.00)": a unit price printed after the name. The line price
        // and quantity already give it, so it is only clutter in the name.
        // "Burger 9.50 19.00" prints it as a column of its own.
        let unstarred = rawLabel.replacing(#/^[>»*+\s]+/#, with: "")
        // "Sapporo (5@7.00)": the quantity and unit price after the name. OCR
        // reads the "@" as a zero, which only counts when the sum proves it.
        if let m = unstarred.wholeMatch(of: #/^(.*?)\s*\(\s*(\d{1,2})\s*([@0oO])\s*\$?(\d+)[.,](\d{2})\s*\)$/#),
           let quantity = Int(m.2), quantity > 0,
           let unit = Decimal(string: "\(m.4).\(m.5)", locale: posix),
           m.3 == "@" || quantity > 1 && unit * Decimal(quantity) == linePrice {
            return LineItem(name: cleanName(String(m.1)), unitPrice: unit, quantity: quantity)
        }
        let label = unstarred
            .replacing(#/\s*\(\s*\$?\d+[.,]\d{2}\s*\)\s*$/#, with: "")
            .replacing(#/([A-Za-z])\s+\$?\d+[.,]\d{2}$/#) { $0.1 }
            .trimmingCharacters(in: .whitespaces)

        if let m = label.wholeMatch(of: #/^(.*?)(\d{1,2})\s*@\s*\$?(\d+)[.,](\d{2})$/#),
           let quantity = Int(m.2), quantity > 0,
           let unit = Decimal(string: "\(m.3).\(m.4)", locale: posix) {
            return LineItem(name: cleanName(String(m.1)), unitPrice: unit, quantity: quantity)
        }
        // "x2 Burger"
        if let m = label.wholeMatch(of: #/^[xX×]\s?(\d{1,2})\s+(\S.*)$/#),
           let quantity = Int(m.1), divides(quantity, linePrice) {
            return LineItem(name: cleanName(String(m.2)), unitPrice: linePrice / Decimal(quantity), quantity: quantity)
        }
        // "2 Burger", "2x Burger", "2 x Burger"
        if let m = label.wholeMatch(of: #/^(\d{1,2})\s*[xX×]?\s+(\S.*)$/#),
           let quantity = Int(m.1), divides(quantity, linePrice) {
            return LineItem(name: cleanName(String(m.2)), unitPrice: linePrice / Decimal(quantity), quantity: quantity)
        }
        // "Burger x2"
        if let m = label.wholeMatch(of: #/^(.*\S)\s+[xX×]\s*(\d{1,2})$/#),
           let quantity = Int(m.2), divides(quantity, linePrice) {
            return LineItem(name: cleanName(String(m.1)), unitPrice: linePrice / Decimal(quantity), quantity: quantity)
        }
        return LineItem(name: cleanName(label), unitPrice: linePrice, quantity: 1)
    }

    /// A real quantity splits the line total into whole cents. "12 Eggs 14.00"
    /// is one dish, not twelve.
    private static func divides(_ quantity: Int, _ linePrice: Decimal) -> Bool {
        guard quantity > 0 else { return false }
        let cents = NSDecimalNumber(decimal: linePrice * 100).intValue
        return cents % quantity == 0
    }

    private static func cleanName(_ name: String) -> String {
        let cleaned = name.trimmingCharacters(in: CharacterSet(charactersIn: " .:-$*>»\t"))
        return cleaned.isEmpty ? "Item" : cleaned
    }
}
