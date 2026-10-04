import Foundation
import Testing
@testable import DibsCore

private func d(_ string: String) -> Decimal { Decimal(string: string)! }

@Suite struct SplitUnclaimedTests {
    private let sam = Person(name: "Sam")
    private let alex = Person(name: "Alex")
    private let kim = Person(name: "Kim")

    /// Nothing is left over and nothing changed what the bill comes to.
    private func expectCovered(_ receipt: Receipt, by people: [Person], total: Decimal) {
        #expect(receipt.unclaimedItems.isEmpty)
        #expect(receipt.itemsSubtotal.roundedToCents() == total)
        let claimed = people.reduce(Decimal(0)) { $0 + ShareCalculator.claimedSubtotal(of: receipt, by: $1.id) }
        #expect(claimed.roundedToCents() == total)
    }

    @Test func singleItemIsSplitBetweenEveryone() {
        var receipt = Receipt(items: [LineItem(name: "Nachos", unitPrice: d("12.00"))])
        receipt.splitUnclaimedEvenly(among: [sam.id, alex.id, kim.id])

        #expect(receipt.items.count == 1)
        #expect(receipt.items[0].isSplit)
        #expect(receipt.items[0].quantity == 3)
        #expect(receipt.items[0].claimedTotal(by: sam.id) == d("4.00"))
        expectCovered(receipt, by: [sam, alex, kim], total: d("12.00"))
    }

    @Test func onePersonTakesTheRestWhole() {
        var receipt = Receipt(items: [
            LineItem(name: "Nachos", unitPrice: d("12.00")),
            LineItem(name: "Beer", unitPrice: d("8.00"), quantity: 3),
        ])
        receipt.splitUnclaimedEvenly(among: [sam.id])

        #expect(!receipt.items[0].isSplit)
        #expect(receipt.items[1].claimedQuantity(by: sam.id) == 3)
        expectCovered(receipt, by: [sam], total: d("36.00"))
    }

    @Test func unitsThatDivideEvenlyStayWholeUnits() {
        var receipt = Receipt(items: [LineItem(name: "Beer", unitPrice: d("8.00"), quantity: 5)])
        receipt.items[0].setClaimed(1, by: sam.id)
        receipt.splitUnclaimedEvenly(among: [sam.id, alex.id])

        #expect(receipt.items.count == 1)
        #expect(!receipt.items[0].isSplit)
        #expect(receipt.items[0].claimedQuantity(by: sam.id) == 3)
        #expect(receipt.items[0].claimedQuantity(by: alex.id) == 2)
        expectCovered(receipt, by: [sam, alex], total: d("40.00"))
    }

    @Test func leftoverUnitIsCarvedOffAndShared() {
        var receipt = Receipt(items: [LineItem(name: "Beer", unitPrice: d("9.00"), quantity: 3)])
        receipt.items[0].setClaimed(2, by: sam.id)
        receipt.splitUnclaimedEvenly(among: [sam.id, alex.id])

        #expect(receipt.items.count == 2)
        // Sam's two whole beers read as they did.
        #expect(receipt.items[0].quantity == 2)
        #expect(!receipt.items[0].isSplit)
        #expect(receipt.items[0].claimedQuantity(by: sam.id) == 2)
        // The third is shared.
        #expect(receipt.items[1].name == "Beer")
        #expect(receipt.items[1].isSplit)
        #expect(receipt.items[1].claimedTotal(by: alex.id) == d("4.50"))
        #expect(ShareCalculator.claimedSubtotal(of: receipt, by: sam.id) == d("22.50"))
        expectCovered(receipt, by: [sam, alex], total: d("27.00"))
    }

    @Test func untouchedUnitsThatDontDivideBecomeShares() {
        var receipt = Receipt(items: [LineItem(name: "Beer", unitPrice: d("9.00"), quantity: 3)])
        receipt.splitUnclaimedEvenly(among: [sam.id, alex.id])

        #expect(receipt.items.count == 1)
        #expect(receipt.items[0].isSplit)
        #expect(receipt.items[0].quantity == 2)
        #expect(receipt.items[0].claimedTotal(by: sam.id) == d("13.50"))
        expectCovered(receipt, by: [sam, alex], total: d("27.00"))
    }

    @Test func leftoverSharesKeepEarlierClaimsWorthTheSame() {
        var receipt = Receipt(items: [LineItem(name: "Tower", unitPrice: d("60.00"))])
        receipt.items[0].split(into: 5)
        receipt.items[0].setClaimed(1, by: sam.id)
        receipt.items[0].setClaimed(1, by: alex.id)
        receipt.items[0].setClaimed(1, by: kim.id)
        receipt.splitUnclaimedEvenly(among: [sam.id, alex.id, kim.id])

        // 5 shares with 2 left among 3 is 15ths, which reduce to thirds.
        #expect(receipt.items[0].quantity == 3)
        #expect(receipt.items[0].claimedQuantity(by: sam.id) == 1)
        #expect(receipt.items[0].claimedTotal(by: sam.id) == d("20.00"))
        expectCovered(receipt, by: [sam, alex, kim], total: d("60.00"))
    }

    @Test func amountsThatDontDivideStillCoverTheBill() {
        var receipt = Receipt(items: [LineItem(name: "Dip", unitPrice: d("10.00"))])
        receipt.splitUnclaimedEvenly(among: [sam.id, alex.id, kim.id])
        expectCovered(receipt, by: [sam, alex, kim], total: d("10.00"))
    }

    @Test func nobodyToShareWithChangesNothing() {
        let original = Receipt(items: [LineItem(name: "Dip", unitPrice: d("10.00"))])
        var receipt = original
        receipt.splitUnclaimedEvenly(among: [])
        #expect(receipt == original)
    }

    @Test func fullyClaimedItemsAreLeftAlone() {
        var receipt = Receipt(items: [LineItem(name: "Dip", unitPrice: d("10.00"))])
        receipt.items[0].setClaimed(1, by: sam.id)
        let before = receipt
        receipt.splitUnclaimedEvenly(among: [sam.id, alex.id])
        #expect(receipt == before)
    }
}
