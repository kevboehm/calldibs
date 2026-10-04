import Foundation
import Testing
@testable import DibsCore

struct VenmoLinkTests {

    // MARK: - App links

    @Test func appChargeFullURL() {
        let url = VenmoLink.app(action: .charge, handle: "alex", amount: 12.34, note: "Dinner")
        #expect(url?.absoluteString == "venmo://paycharge?txn=charge&recipients=alex&amount=12.34&note=Dinner")
    }

    @Test func appPayPadsWholeAmount() {
        let url = VenmoLink.app(action: .pay, handle: "jordan", amount: 5, note: "Coffee")
        #expect(url?.absoluteString == "venmo://paycharge?txn=pay&recipients=jordan&amount=5.00&note=Coffee")
    }

    @Test func appLinkAllowsEmptyRecipient() {
        // Venmo opens with amount+note filled and lets the user pick the person.
        let url = VenmoLink.app(action: .charge, handle: "", amount: 8.50, note: "Lunch")
        #expect(url?.absoluteString == "venmo://paycharge?txn=charge&recipients=&amount=8.50&note=Lunch")
    }

    // MARK: - Web links

    @Test func webPayFullURL() {
        let url = VenmoLink.web(action: .pay, handle: "alex", amount: 12.34, note: "Dinner")
        #expect(url?.absoluteString == "https://venmo.com/alex?txn=pay&amount=12.34&note=Dinner")
    }

    @Test func webRequiresHandle() {
        #expect(VenmoLink.web(action: .pay, handle: "   ", amount: 10, note: "x") == nil)
    }

    @Test func webNormalizesHandleInPath() {
        let url = VenmoLink.web(action: .pay, handle: "@alex", amount: 3, note: "n")
        #expect(url?.absoluteString == "https://venmo.com/alex?txn=pay&amount=3.00&note=n")
    }

    // MARK: - Note encoding

    @Test func noteWithSpacesAmpersandAndEmoji() {
        let url = VenmoLink.app(action: .charge, handle: "sam", amount: 20, note: "Tapas & drinks 🍷")
        #expect(url?.absoluteString ==
            "venmo://paycharge?txn=charge&recipients=sam&amount=20.00&note=Tapas%20%26%20drinks%20%F0%9F%8D%B7")
    }

    // MARK: - Handle normalization

    @Test func handleStripsLeadingAtAndWhitespace() {
        #expect(VenmoLink.normalize("  @alex  ") == "alex")
        #expect(VenmoLink.normalize("alex") == "alex")
        // Only one leading @ is dropped.
        #expect(VenmoLink.normalize("@@alex") == "@alex")
    }

    // MARK: - Amount rounding / validation

    @Test func amountPadsToTwoPlaces() {
        let url = VenmoLink.app(action: .pay, handle: "a", amount: 12.3, note: "n")
        #expect(url?.absoluteString.contains("amount=12.30") == true)
    }

    @Test func amountRoundsHalfUp() {
        let url = VenmoLink.app(action: .pay, handle: "a", amount: Decimal(string: "1.005")!, note: "n")
        #expect(url?.absoluteString.contains("amount=1.01") == true)
    }

    @Test func zeroAndNegativeAmountsReturnNil() {
        #expect(VenmoLink.app(action: .pay, handle: "a", amount: 0, note: "n") == nil)
        #expect(VenmoLink.app(action: .pay, handle: "a", amount: -5, note: "n") == nil)
        #expect(VenmoLink.web(action: .pay, handle: "a", amount: 0, note: "n") == nil)
    }
}
