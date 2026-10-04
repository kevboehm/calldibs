import Foundation
import DibsCore

/// How one parsed receipt compares with its ground truth.
public struct Score: Sendable {
    public var truthItems = 0
    public var parsedItems = 0
    /// Parsed items whose line total equals a ground-truth item's.
    public var matchedItems = 0
    /// Matched items whose ground truth states a quantity, and how many of
    /// those the parse got right.
    public var quantityKnown = 0
    public var quantityCorrect = 0
    /// Sum over matched items of name similarity, each 0...1.
    public var nameSimilarity = 0.0

    public var subtotalCorrect: Bool?
    public var taxCorrect: Bool?
    public var totalCorrect: Bool?
    /// The parse agrees with itself: items + tax come to the parsed total.
    public var reconciles = false

    public var isPerfect: Bool {
        matchedItems == truthItems && parsedItems == truthItems && quantityCorrect == quantityKnown
            && subtotalCorrect != false && taxCorrect != false && totalCorrect != false
    }

    public init(parsed: Receipt, truth: GroundTruth) {
        truthItems = truth.items.count
        parsedItems = parsed.items.count

        // Pair items by line total; among equal totals, take the closest name.
        var remaining = truth.items
        for item in parsed.items {
            let total = cents(item.lineTotal)
            let candidates = remaining.indices.filter { cents(remaining[$0].total) == total }
            guard let best = candidates.max(by: {
                similarity(remaining[$0].name, item.name) < similarity(remaining[$1].name, item.name)
            }) else { continue }
            matchedItems += 1
            nameSimilarity += similarity(remaining[best].name, item.name)
            if let quantity = remaining[best].quantity {
                quantityKnown += 1
                if quantity == item.quantity { quantityCorrect += 1 }
            }
            remaining.remove(at: best)
        }

        subtotalCorrect = truth.subtotal.map { parsed.subtotal.map(cents) == cents($0) }
        taxCorrect = truth.tax.map { cents(parsed.tax) == cents($0) }
        totalCorrect = truth.total.map { parsed.total.map(cents) == cents($0) }
        if let total = parsed.total {
            reconciles = !parsed.items.isEmpty && cents(parsed.computedTotal) == cents(total)
        }
    }
}

/// Scores for a whole corpus.
public struct Summary: Sendable {
    public private(set) var receipts = 0
    private var perfect = 0, reconciling = 0
    private var truthItems = 0, parsedItems = 0, matchedItems = 0
    private var quantityKnown = 0, quantityCorrect = 0
    private var nameSimilarity = 0.0
    private var subtotal = Tally(), tax = Tally(), total = Tally()

    public init() {}

    public mutating func add(_ score: Score) {
        receipts += 1
        if score.isPerfect { perfect += 1 }
        if score.reconciles { reconciling += 1 }
        truthItems += score.truthItems
        parsedItems += score.parsedItems
        matchedItems += score.matchedItems
        quantityKnown += score.quantityKnown
        quantityCorrect += score.quantityCorrect
        nameSimilarity += score.nameSimilarity
        subtotal.add(score.subtotalCorrect)
        tax.add(score.taxCorrect)
        total.add(score.totalCorrect)
    }

    public var perfectRate: Double { ratio(perfect, receipts) }
    public var itemRecall: Double { ratio(matchedItems, truthItems) }
    public var itemPrecision: Double { ratio(matchedItems, parsedItems) }

    public var report: String {
        func percent(_ value: Double) -> String { String(format: "%5.1f%%", value * 100) }
        return """
        receipts            \(receipts)
        perfect             \(percent(perfectRate))
        reconciles          \(percent(ratio(reconciling, receipts)))
        item recall         \(percent(itemRecall))  (\(matchedItems)/\(truthItems))
        item precision      \(percent(itemPrecision))  (\(matchedItems)/\(parsedItems))
        quantity correct    \(percent(ratio(quantityCorrect, quantityKnown)))  (of \(quantityKnown))
        name similarity     \(percent(matchedItems > 0 ? nameSimilarity / Double(matchedItems) : 0))
        subtotal correct    \(percent(subtotal.rate))  (of \(subtotal.count))
        tax correct         \(percent(tax.rate))  (of \(tax.count))
        total correct       \(percent(total.rate))  (of \(total.count))
        """
    }

    private struct Tally {
        var count = 0, correct = 0
        mutating func add(_ result: Bool?) {
            guard let result else { return }
            count += 1
            if result { correct += 1 }
        }
        var rate: Double { ratio(correct, count) }
    }
}

private func ratio(_ part: Int, _ whole: Int) -> Double {
    whole > 0 ? Double(part) / Double(whole) : 0
}

/// 1 for the same letters and digits, falling toward 0 as they differ.
func similarity(_ a: String, _ b: String) -> Double {
    let a = Array(a.lowercased().filter { $0.isLetter || $0.isNumber })
    let b = Array(b.lowercased().filter { $0.isLetter || $0.isNumber })
    guard !a.isEmpty, !b.isEmpty else { return a.isEmpty && b.isEmpty ? 1 : 0 }

    var previous = Array(0...b.count)
    for i in 1...a.count {
        var current = [i] + Array(repeating: 0, count: b.count)
        for j in 1...b.count {
            current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
        }
        previous = current
    }
    return 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
}
