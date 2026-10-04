#if DEBUG
import Foundation
import DibsCore

/// Launching with `-seedScreen <name>` opens the app on that screen with a
/// sample bill, so each screen can be checked without tapping through.
/// Debug builds only.
enum DebugSeed {
    static var requestedScreen: String? {
        UserDefaults.standard.string(forKey: "seedScreen")
    }

    static func session(for screen: String) -> (session: ClaimViewModel, path: [Route])? {
        let withCharges = screen.hasPrefix("charges")
        let session = ClaimViewModel(receipt: sampleReceipt(withCharges: withCharges))
        let items = session.receipt.items

        func turn(_ name: String, _ claims: [(Int, Int)]) {
            session.endTurn()
            session.draftName = name
            session.confirmName()
            for (index, quantity) in claims {
                session.setClaimed(quantity, for: items[index].id)
            }
        }

        switch screen {
        case "charges-share":
            turn("Kevin", [(0, 1), (3, 1), (5, 2)])
            return (session, [.edit, .name, .claim(.swipe), .summary])
        case "bill", "charges":
            return (session, [.edit])
        case "mismatch":
            // A scan that missed the last item.
            session.receipt.items.removeLast()
            return (session, [.edit])
        case "nototal":
            // A scan that found the items but no subtotal or total.
            session.receipt.subtotal = nil
            session.receipt.total = nil
            session.scan = ScanSource(rows: [], itemRows: [:], fragments: [])
            return (session, [.edit])
        case "name":
            return (session, [.edit, .name])
        case "swipe", "stamp":
            turn("Kevin", [])
            return (session, [.edit, .name, .claim(.swipe)])
        case "checklist":
            turn("Sam", [(0, 1), (1, 1), (5, 2)])
            turn("Kevin", [(0, 1), (3, 1)])
            return (session, [.overview, .name, .claim(.checklist)])
        case "share":
            turn("Sam", [(1, 1), (5, 1)])
            turn("Kevin", [(0, 1), (3, 1), (5, 2)])
            return (session, [.overview, .name, .claim(.swipe), .summary])
        case "split":
            turn("Sam", [(0, 1), (1, 1), (5, 2)])
            turn("Kevin", [(0, 1), (3, 1), (5, 1)])
            session.endTurn()
            return (session, [.overview])
        default:
            return nil
        }
    }

    private static func sampleReceipt(withCharges: Bool) -> Receipt {
        func d(_ value: String) -> Decimal { Decimal(string: value)! }
        return Receipt(
            items: [
                LineItem(name: "Vodka", unitPrice: d("9.00"), quantity: 2),
                LineItem(name: "Sausage Ricotta Boat", unitPrice: d("30.00")),
                LineItem(name: "Chuckanut - Pilsner", unitPrice: d("8.90")),
                LineItem(name: "Obec", unitPrice: d("8.50")),
                LineItem(name: "Russian River - Pliny", unitPrice: d("9.50"), quantity: 2),
                LineItem(name: "Elysian - Hazy IPA", unitPrice: d("9.00"), quantity: 3),
                LineItem(name: "S- Pizza - Larb Moo", unitPrice: d("27.00")),
            ],
            tax: d("14.60"),
            subtotal: d("138.40"),
            total: withCharges ? d("177.91") : d("153.00"),
            charges: withCharges ? [
                Charge(name: "Service Charge 18%", amount: d("24.91")),
            ] : []
        )
    }
}
#endif
