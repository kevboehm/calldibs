import Foundation

/// Works out which currency a receipt is in from the symbols and codes
/// printed beside its amounts. Plain text in, an ISO 4217 code out.
public enum CurrencyDetector {
    /// The receipt's currency, or nil when nothing on it says.
    ///
    /// `homeCurrency` is the currency of the phone's region. It settles the
    /// signs that several currencies share: "$" is the home currency for
    /// someone who pays in dollars or pesos, and US dollars for anyone else.
    public static func detect(lines: [String], homeCurrency: String? = nil) -> String? {
        var named: [String: Int] = [:]
        var signed: [String: Int] = [:]
        // The order they were first seen in, to settle a tie.
        var order: [String] = []
        func count(_ code: String, in tally: inout [String: Int], _ times: Int = 1) {
            guard times > 0 else { return }
            if !order.contains(code) { order.append(code) }
            tally[code, default: 0] += times
        }

        for line in lines {
            // A code, or a dollar sign that says whose dollar, is explicit.
            for token in captures(of: dollarPrefix, in: line) {
                if let code = dollarPrefixes[token] { count(code, in: &named) }
            }
            for token in captures(of: tokenBeforeAmount, in: line) + captures(of: tokenAfterAmount, in: line) {
                if let code = codes[token] {
                    count(code, in: &named)
                } else if let code = words[token.lowercased()] ?? shared(token.lowercased(), home: homeCurrency) {
                    count(code, in: &signed)
                }
            }
            for (sign, code) in signs {
                count(code, in: &signed, line.filter { $0 == sign }.count)
            }
            for sign in ["$", "¥", "￥"] {
                let times = line.components(separatedBy: sign).count - 1
                if let code = shared(sign, home: homeCurrency) { count(code, in: &signed, times) }
            }
        }

        // A cash register's tax flag is easily misread as a rarer sign
        // ("2.00 B" as "2.00 ฿"), so one of those has to be on most of the
        // priced lines to be believed, unless it is the home currency.
        let pricedLines = lines.filter { $0.contains(#/\d\D{0,3}$/#) }.count
        for code in rareSigns where code != homeCurrency {
            if let times = signed[code], times < 3 || times * 2 < pricedLines { signed[code] = nil }
        }

        let tally = named.isEmpty ? signed : named
        return order.filter { tally[$0] != nil }.max { tally[$0]! < tally[$1]! }
    }

    /// The same line with the currency beside its last amount written as a
    /// "$" in front of it, so "12,50 €", "EUR 12,50" and "C$12.50" all read
    /// like "$12.50" does. Other currency signs become "$" where they stand.
    static func markingAmount(in line: String, spaceGrouping: Bool) -> String {
        var line = replace(spaceGrouping ? afterAmountSpaced : afterAmount, in: line, with: "$1$2\\$$3$4$5")
        line = replace(dollarPrefix, in: line, with: "\\$")
        line = replace(spaceGrouping ? beforeAmountSpaced : beforeAmount, in: line, with: "$2\\$$3")
        for sign in signs.keys where sign != "円" && sign != "元" {
            line = line.replacingOccurrences(of: String(sign), with: "$")
        }
        return line.replacingOccurrences(of: "¥", with: "$").replacingOccurrences(of: "￥", with: "$")
    }

    // MARK: - What currencies are written as

    /// Signs only one currency uses.
    private static let signs: [Character: String] = [
        "€": "EUR", "£": "GBP", "₹": "INR", "₩": "KRW", "₪": "ILS", "₫": "VND", "₱": "PHP",
        "฿": "THB", "₺": "TRY", "₴": "UAH", "₦": "NGN", "円": "JPY", "元": "CNY",
    ]

    /// The currencies of the signs a scan sees less often than it misreads.
    private static let rareSigns = ["KRW", "ILS", "VND", "PHP", "THB", "TRY", "UAH", "NGN"]

    /// "US$", "C$", "HK$": a dollar sign that says whose dollar.
    private static let dollarPrefixes: [String: String] = [
        "US": "USD", "USD": "USD", "CA": "CAD", "CAD": "CAD", "C": "CAD", "AU": "AUD", "AUD": "AUD", "A": "AUD",
        "NZ": "NZD", "HK": "HKD", "SG": "SGD", "S": "SGD", "R": "BRL", "MX": "MXN", "NT": "TWD",
    ]

    /// Codes printed beside an amount. Left out are the ones that are also
    /// words on a menu: a PEN, a CUP, a TRY.
    private static let codes: [String: String] = {
        let plain = [
            "USD", "EUR", "GBP", "CAD", "AUD", "NZD", "CHF", "JPY", "CNY", "HKD", "SGD", "SEK", "NOK", "DKK",
            "ISK", "PLN", "CZK", "HUF", "RON", "MXN", "BRL", "ARS", "CLP", "INR", "KRW", "THB", "TWD", "PHP",
            "IDR", "MYR", "VND", "ZAR", "AED", "ILS",
        ]
        var codes = Dictionary(uniqueKeysWithValues: plain.map { ($0, $0) })
        codes["RMB"] = "CNY"
        return codes
    }()

    /// Abbreviations that stand for one currency, in lowercase.
    private static let words: [String: String] = [
        "zł": "PLN", "kč": "CZK", "ft": "HUF", "rm": "MYR", "rp": "IDR", "rs": "INR", "fr": "CHF",
    ]

    /// What a sign several currencies share means here: the home currency
    /// when it is one of them, otherwise the most likely.
    private static func shared(_ sign: String, home: String?) -> String? {
        let users: [String]
        switch sign {
        case "$":
            users = ["USD", "CAD", "AUD", "NZD", "SGD", "HKD", "MXN", "ARS", "CLP", "COP", "TWD", "BBD", "BSD", "JMD"]
        case "¥", "￥": users = ["JPY", "CNY"]
        case "kr": users = ["SEK", "NOK", "DKK", "ISK"]
        default: return nil
        }
        return home.flatMap { users.contains($0) ? $0 : nil } ?? users[0]
    }

    // MARK: - Where they are printed

    /// Codes and abbreviations as they are printed in front of an amount
    /// and behind one. Two capitals behind an amount are a tax flag, so
    /// only the spellings that can't be one count there.
    private static let prefixes = (codes.keys.sorted() + ["RM", "Rp", "Rs", "Fr", "kr", "Kr"]).joined(separator: "|")
    private static let suffixes = (codes.keys.sorted() + ["zł", "Zł", "ZŁ", "Kč", "KČ", "Ft", "kr", "Kr"]).joined(separator: "|")

    /// An amount as it ends a line, with the tax flag that may follow it.
    private static let amount = #"\d[\d.,'’]*"#
    private static let spacedAmount = #"\d{1,3}(?: \d{3})+,\d{2}|\d[\d.,'’]*"#
    private static let flag = #"(?:\s+[A-Z*]{1,2}|\s*\*|\s+\d)?"#

    private static let dollarPrefix = regex(#"(?<![A-Za-z])(US|USD|CAD|CA|C|AUD|AU|A|NZ|HK|SG|S|R|MX|NT)\$"#)
    /// "12,50 €", "12.50 EUR", "125,00 kr", "1,200円".
    private static let afterAmount = regex(after(amount))
    private static let afterAmountSpaced = regex(after(spacedAmount))
    /// "EUR 12,50", "CHF 12.50", "Rs. 450.00".
    private static let beforeAmount = regex(before(amount))
    private static let beforeAmountSpaced = regex(before(spacedAmount))
    private static let tokenAfterAmount = regex(#"\d\s?("# + suffixes + #")\.?(?![A-Za-z])"# + flag + "$")
    private static let tokenBeforeAmount = regex(#"(?<![A-Za-z])("# + prefixes + #")\.?\s?-?(?:"# + amount + ")-?" + flag + "$")

    private static func after(_ amount: String) -> String {
        #"^(.*?)(-?)("# + amount + #")(-?)\s?(?:[$€£₹₩₪₫₱฿₺₴₦円元]|(?:"# + suffixes + #")\.?(?![A-Za-z]))("# + flag + ")$"
    }

    private static func before(_ amount: String) -> String {
        #"(?<![A-Za-z])("# + prefixes + #")\.?\s?(-?)((?:"# + amount + ")-?" + flag + ")$"
    }

    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern)
    }

    private static func replace(_ regex: NSRegularExpression, in line: String, with template: String) -> String {
        regex.stringByReplacingMatches(in: line, range: NSRange(line.startIndex..., in: line), withTemplate: template)
    }

    /// The first capture group of every match.
    private static func captures(of regex: NSRegularExpression, in line: String) -> [String] {
        regex.matches(in: line, range: NSRange(line.startIndex..., in: line)).compactMap {
            Range($0.range(at: 1), in: line).map { String(line[$0]) }
        }
    }
}
