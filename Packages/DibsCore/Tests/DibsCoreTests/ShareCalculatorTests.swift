import Foundation
import Testing
@testable import DibsCore

private func d(_ string: String) -> Decimal { Decimal(string: string)! }

@Suite struct ShareCalculatorTests {
    private let sam = Person(name: "Sam")
    private let alex = Person(name: "Alex")

    // Subtotal 100.00, tax 8.00.
    private func sampleReceipt() -> Receipt {
        Receipt(
            items: [
                LineItem(name: "Burger", unitPrice: d("5.00"), quantity: 10),
                LineItem(name: "Salad", unitPrice: d("20.00")),
                LineItem(name: "Wine", unitPrice: d("30.00")),
            ],
            tax: d("8.00"),
            subtotal: d("100.00"),
            total: d("108.00")
        )
    }

    @Test func singleUnitClaim() {
        var receipt = sampleReceipt()
        receipt.items[1].setClaimed(1, by: sam.id)

        let summary = ShareCalculator.summary(for: receipt, person: sam)
        #expect(summary.lines.map(\.name) == ["Salad"])
        #expect(summary.claimedSubtotal == d("20.00"))
        #expect(summary.taxShare == d("1.60"))
        #expect(summary.tip == d("4.32"))
        #expect(summary.total == d("25.92"))
    }

    @Test func multiUnitPartialClaim() {
        var receipt = sampleReceipt()
        receipt.items[0].setClaimed(3, by: sam.id)

        let summary = ShareCalculator.summary(for: receipt, person: sam)
        #expect(summary.lines.map(\.quantity) == [3])
        #expect(summary.lines.map(\.outOf) == [10])
        #expect(summary.claimedSubtotal == d("15.00"))
        #expect(summary.taxShare == d("1.20"))
        #expect(summary.tip == d("3.24"))
        #expect(summary.total == d("19.44"))
    }

    @Test func taxIsProportionalToClaimedSubtotal() {
        var receipt = sampleReceipt()
        receipt.items[0].setClaimed(3, by: sam.id)
        receipt.items[2].setClaimed(1, by: sam.id)

        #expect(ShareCalculator.claimedSubtotal(of: receipt, by: sam.id) == d("45.00"))
        #expect(ShareCalculator.taxShare(of: receipt, by: sam.id) == d("3.60"))
    }

    @Test func taxUsesItemSumWhenNoPrintedSubtotal() {
        var receipt = sampleReceipt()
        receipt.subtotal = nil
        receipt.items[1].setClaimed(1, by: sam.id)

        #expect(receipt.preTaxSubtotal == d("100.00"))
        #expect(ShareCalculator.taxShare(of: receipt, by: sam.id) == d("1.60"))
    }

    @Test func tipIsPerPerson() {
        var receipt = sampleReceipt()
        receipt.items[1].setClaimed(1, by: sam.id)
        receipt.items[2].setClaimed(1, by: alex.id)

        var generous = alex
        generous.tip.rate = d("0.25")

        // Sam keeps the 20% default; Alex's rate doesn't touch Sam's total.
        #expect(ShareCalculator.summary(for: receipt, person: sam).tip == d("4.32"))
        #expect(ShareCalculator.summary(for: receipt, person: generous).tip == d("8.10"))
    }

    @Test func tipBaseIsConfigurable() {
        var receipt = sampleReceipt()
        receipt.items[1].setClaimed(1, by: sam.id)

        var preTax = sam
        preTax.tip.base = .preTax
        let summary = ShareCalculator.summary(for: receipt, person: preTax)
        #expect(summary.tip == d("4.00"))
        #expect(summary.total == d("25.60"))
    }

    @Test func chargesAreSharedInProportionAndNotTippedOn() {
        var receipt = sampleReceipt()
        receipt.charges = [
            Charge(name: "Service Charge", amount: d("18.00")),
            Charge(name: "Discount", amount: d("-10.00")),
        ]
        receipt.items[1].setClaimed(1, by: sam.id)

        // Sam had 20.00 of the 100.00 subtotal: a fifth of each charge.
        let summary = ShareCalculator.summary(for: receipt, person: sam)
        #expect(summary.chargeShares.map(\.amount) == [d("3.60"), d("-2.00")])
        #expect(summary.tip == d("4.32"))
        #expect(summary.total == d("27.52"))
        #expect(receipt.computedTotal == d("116.00"))
    }

    @Test func nothingClaimedOwesNothing() {
        let summary = ShareCalculator.summary(for: sampleReceipt(), person: sam)
        #expect(summary.lines.isEmpty)
        #expect(summary.total == 0)
    }

    @Test func emptyReceiptDoesNotDivideByZero() {
        let receipt = Receipt(items: [], tax: d("5.00"))
        #expect(ShareCalculator.taxShare(of: receipt, by: sam.id) == 0)
    }

    @Test func passingTheBillAroundExhaustsIt() {
        var receipt = sampleReceipt()

        // Sam: 3 burgers and the salad.
        receipt.items[0].setClaimed(3, by: sam.id)
        receipt.items[1].setClaimed(1, by: sam.id)
        #expect(receipt.unclaimedItems.map(\.name) == ["Burger", "Wine"])

        // Alex can't take more burgers than are left, or the salad at all.
        receipt.items[0].setClaimed(10, by: alex.id)
        receipt.items[1].setClaimed(1, by: alex.id)
        receipt.items[2].setClaimed(1, by: alex.id)
        #expect(receipt.items.map { $0.claimedQuantity(by: alex.id) } == [7, 0, 1])
        #expect(receipt.unclaimedItems.isEmpty)

        let a = ShareCalculator.summary(for: receipt, person: sam)
        let b = ShareCalculator.summary(for: receipt, person: alex)
        #expect(a.claimedSubtotal + b.claimedSubtotal == d("100.00"))
        #expect(a.taxShare + b.taxShare == d("8.00"))
    }

    @Test func earlierClaimsCanBeEdited() {
        var receipt = sampleReceipt()
        receipt.items[0].setClaimed(3, by: sam.id)
        receipt.items[0].setClaimed(7, by: alex.id)

        // Sam is boxed in by Alex's claim until Alex gives some back.
        receipt.items[0].setClaimed(5, by: sam.id)
        #expect(receipt.items[0].claimedQuantity(by: sam.id) == 3)

        receipt.items[0].setClaimed(4, by: alex.id)
        receipt.items[0].setClaimed(5, by: sam.id)
        #expect(receipt.items[0].claimedQuantity(by: sam.id) == 5)
        #expect(receipt.items[0].unclaimedQuantity == 1)

        receipt.removeClaims(by: alex.id)
        #expect(receipt.items[0].unclaimedQuantity == 5)
    }

    @Test func splitItemIsClaimedInShares() {
        // A 100.00 seafood tower split five ways; Sam pays for one fifth.
        var receipt = Receipt(items: [LineItem(name: "Seafood Tower", unitPrice: d("100.00"))], tax: d("8.00"))
        receipt.items[0].split(into: 5)

        #expect(receipt.items[0].isSplit)
        #expect(receipt.items[0].quantity == 5)
        #expect(receipt.items[0].lineTotal == d("100.00"))

        receipt.items[0].setClaimed(1, by: sam.id)
        let summary = ShareCalculator.summary(for: receipt, person: sam)
        #expect(summary.lines[0].quantity == 1)
        #expect(summary.lines[0].outOf == 5)
        #expect(summary.lines[0].isSplit)
        #expect(summary.claimedSubtotal == d("20.00"))
        #expect(summary.taxShare == d("1.60"))

        // Undoing the split restores one unit at the full price.
        receipt.items[0].split(into: 1)
        #expect(!receipt.items[0].isSplit)
        #expect(receipt.items[0].quantity == 1)
        #expect(receipt.items[0].unitPrice == d("100.00"))
        #expect(receipt.items[0].totalClaimed == 0)
    }

    @Test func unevenSplitStillAddsUp() {
        // 10.00 split three ways: three people each claiming a share cover it.
        var item = LineItem(name: "Wings", unitPrice: d("10.00"))
        item.split(into: 3)
        item.setClaimed(3, by: sam.id)

        let receipt = Receipt(items: [item], tax: d("0.83"))
        let summary = ShareCalculator.summary(for: receipt, person: sam)
        #expect(summary.claimedSubtotal == d("10.00"))
        #expect(summary.taxShare == d("0.83"))
        #expect(summary.tip == d("2.17"))
    }

    @Test func claimsAreClamped() {
        var item = LineItem(name: "Burger", unitPrice: d("5.00"), quantity: 10)

        item.setClaimed(99, by: sam.id)
        #expect(item.claimedQuantity(by: sam.id) == 10)

        item.setClaimed(-4, by: sam.id)
        #expect(item.claimedQuantity(by: sam.id) == 0)
        #expect(item.claims.isEmpty)

        // Shrinking the quantity below what's claimed clears the claims.
        item.setClaimed(7, by: sam.id)
        item.quantity = 5
        #expect(item.totalClaimed == 0)

        item.quantity = 0
        #expect(item.quantity == 1)
    }
}
