import SwiftUI
import DibsCore

/// Writes amounts in one currency: the bill's, which is not always the
/// phone's.
struct Money: Hashable {
    /// ISO 4217, like "EUR".
    let currencyCode: String

    /// The currency of the phone's region.
    static var deviceCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static var device: Money { Money(nil) }

    /// A bill that doesn't say is in the phone's currency.
    init(_ currencyCode: String?) {
        self.currencyCode = currencyCode ?? Self.deviceCode
    }

    /// Decimal places amounts are typed and shown with: none for yen.
    var fractionDigits: Int {
        Currency.fractionDigits(for: currencyCode)
    }

    func string(_ amount: Decimal) -> String {
        // Halves round up, as `ShareCalculator` rounds them.
        amount.formatted(.currency(code: currencyCode).rounded(rule: .toNearestOrAwayFromZero))
    }

    /// "Euro", in the phone's language.
    var name: String {
        Locale.current.localizedString(forCurrencyCode: currencyCode) ?? currencyCode
    }
}

extension Receipt {
    var money: Money { Money(currencyCode) }
}

extension EnvironmentValues {
    /// The currency of the bill on screen.
    @Entry var money = Money.device
}
