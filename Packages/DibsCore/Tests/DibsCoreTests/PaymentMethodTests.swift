import Foundation
import Testing
@testable import DibsCore

struct PaymentMethodTests {

    @Test func venmoLinkMatchesVenmoLink() {
        let url = PaymentMethod.venmo.payLink(handle: "@alex", amount: 12.5, note: "Bill split")
        #expect(url == VenmoLink.web(action: .pay, handle: "alex", amount: 12.5, note: "Bill split"))
        #expect(url?.absoluteString == "https://venmo.com/alex?txn=pay&amount=12.50&note=Bill%20split")
    }

    @Test func cashAppLink() {
        let url = PaymentMethod.cashApp.payLink(handle: "$alex", amount: 12.34, note: "Bill split")
        #expect(url?.absoluteString == "https://cash.app/$alex/12.34")
    }

    @Test func payPalLink() {
        let url = PaymentMethod.payPal.payLink(handle: "alex", amount: 5, note: "Bill split")
        #expect(url?.absoluteString == "https://paypal.me/alex/5.00")
    }

    @Test func normalizeStripsSymbolsAndPastedLinks() {
        #expect(PaymentMethod.venmo.normalize("  @alex ") == "alex")
        #expect(PaymentMethod.cashApp.normalize("$alex") == "alex")
        #expect(PaymentMethod.cashApp.normalize("https://cash.app/$alex") == "alex")
        #expect(PaymentMethod.payPal.normalize("paypal.me/alex/") == "alex")
        #expect(PaymentMethod.payPal.normalize("   ") == "")
    }

    @Test func noLinkWithoutAHandleOrAnAmount() {
        for method in PaymentMethod.allCases {
            #expect(method.payLink(handle: "", amount: 10, note: "x") == nil)
            #expect(method.payLink(handle: "alex", amount: 0, note: "x") == nil)
            #expect(method.payLink(handle: "alex", amount: -3, note: "x") == nil)
        }
    }
}
