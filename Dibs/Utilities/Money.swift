import Foundation

enum Money {
    static var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    static func string(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode))
    }
}
