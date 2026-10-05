import Foundation
import Testing
@testable import DibsCore

@Suite struct CurrencyDetectorTests {
    @Test func readsSignsOnlyOneCurrencyUses() {
        #expect(CurrencyDetector.detect(lines: ["Bier 4,50 €", "Summe 4,50 €"]) == "EUR")
        #expect(CurrencyDetector.detect(lines: ["Fish & Chips £12.50"]) == "GBP")
        #expect(CurrencyDetector.detect(lines: ["Masala Dosa ₹180.00"]) == "INR")
        #expect(CurrencyDetector.detect(lines: ["コーヒー 450円"]) == "JPY")
    }

    @Test func readsCodesBesideAnAmount() {
        #expect(CurrencyDetector.detect(lines: ["Rösti 24.50", "Total CHF 24.50"]) == "CHF")
        #expect(CurrencyDetector.detect(lines: ["Pizza 12,00", "Totale 12,00 EUR"]) == "EUR")
        #expect(CurrencyDetector.detect(lines: ["Köttbullar 125,00 kr"]) == "SEK")
        #expect(CurrencyDetector.detect(lines: ["Pierogi 28,00 zł"]) == "PLN")
        #expect(CurrencyDetector.detect(lines: ["Nasi Lemak RM 12.00"]) == "MYR")
    }

    @Test func aCodeOutranksTheSignItExplains() {
        let lines = ["Poutine $12.00", "Beer $8.00", "Total $20.00", "CAD 20.00"]
        #expect(CurrencyDetector.detect(lines: lines) == "CAD")
        #expect(CurrencyDetector.detect(lines: ["Flat White A$5.50"]) == "AUD")
        #expect(CurrencyDetector.detect(lines: ["Feijoada R$ 42,00"]) == "BRL")
    }

    @Test func aDollarSignIsTheHomeCurrencyWhenThatIsADollar() {
        let lines = ["Burger $12.00", "Total $12.00"]
        #expect(CurrencyDetector.detect(lines: lines) == "USD")
        #expect(CurrencyDetector.detect(lines: lines, homeCurrency: "USD") == "USD")
        #expect(CurrencyDetector.detect(lines: lines, homeCurrency: "CAD") == "CAD")
        #expect(CurrencyDetector.detect(lines: lines, homeCurrency: "MXN") == "MXN")
        // Someone from the eurozone looking at a "$" is looking at US dollars.
        #expect(CurrencyDetector.detect(lines: lines, homeCurrency: "EUR") == "USD")
    }

    @Test func sharedSignsLeanOnTheHomeCurrency() {
        #expect(CurrencyDetector.detect(lines: ["ラーメン ¥900"]) == "JPY")
        #expect(CurrencyDetector.detect(lines: ["炒饭 ¥28.00"], homeCurrency: "CNY") == "CNY")
        #expect(CurrencyDetector.detect(lines: ["Smørrebrød 95,00 kr"], homeCurrency: "DKK") == "DKK")
    }

    @Test func wordsThatLookLikeCodesAreNotCurrencies() {
        #expect(CurrencyDetector.detect(lines: ["CAD Design Fee", "6 Ft Sub 8.99", "PEN 1.99", "CUP 3.00"]) == nil)
        #expect(CurrencyDetector.detect(lines: ["BURGER$5.00", "FRIES$3.00"]) == "USD")
    }

    @Test func nothingPrintedMeansNoCurrency() {
        #expect(CurrencyDetector.detect(lines: ["Burger 12.00", "Total 12.00"]) == nil)
    }

    @Test func knowsWhichCurrenciesHaveNoDecimals() {
        #expect(Currency.fractionDigits(for: "USD") == 2)
        #expect(Currency.fractionDigits(for: "EUR") == 2)
        #expect(Currency.fractionDigits(for: "JPY") == 0)
        #expect(Currency.fractionDigits(for: "KRW") == 0)
    }
}
