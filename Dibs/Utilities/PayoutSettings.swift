import SwiftUI
import DibsCore

/// How the bill payer gets paid back, remembered between bills: the service
/// they chose and their handle on each one.
struct PayoutSettings: DynamicProperty {
    @AppStorage("paymentMethod") var method = PaymentMethod.venmo
    @AppStorage("venmoHandle") private var venmo = ""
    @AppStorage("cashAppHandle") private var cashApp = ""
    @AppStorage("payPalHandle") private var payPal = ""

    /// The handle on the chosen service, or "" if none has been entered.
    var handle: String { handle(for: method) }

    var hasHandle: Bool { !method.normalize(handle).isEmpty }

    func handle(for method: PaymentMethod) -> String {
        switch method {
        case .venmo: return venmo
        case .cashApp: return cashApp
        case .payPal: return payPal
        }
    }

    /// Stores the handle and makes that service the chosen one.
    func save(_ handle: String, for method: PaymentMethod) {
        switch method {
        case .venmo: venmo = handle
        case .cashApp: cashApp = handle
        case .payPal: payPal = handle
        }
        self.method = method
    }
}
