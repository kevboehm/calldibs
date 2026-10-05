import Foundation
import Testing
@testable import DibsCore

private func d(_ string: String) -> Decimal { Decimal(string: string)! }

@Suite struct ReceiptTextParserTests {
    // MARK: - Other currencies

    @Test func readsAEuroReceiptWithCommaDecimals() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Gasthaus zur Post",
            "2 Pils 0,5l          9,00 €",
            "Schnitzel           18,50 €",
            "Apfelstrudel         6,50 €",
            "Summe               34,00 €",
            "MwSt 19%             5,43 €",
            "Bar                 40,00 €",
            "Rückgeld             6,00 €",
        ])

        #expect(receipt.currencyCode == "EUR")
        #expect(receipt.items.map(\.name) == ["Pils 0,5l", "Schnitzel", "Apfelstrudel"])
        #expect(receipt.items.map(\.quantity) == [2, 1, 1])
        #expect(receipt.itemsSubtotal == d("34.00"))
        #expect(receipt.tax == 0)
        #expect(receipt.total == d("34.00"))
        #expect(receipt.reconciles == true)
    }

    @Test func readsACodeInFrontOfTheAmount() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Rösti                    CHF 24.50",
            "Fondue für zwei       CHF 1'234.50",
            "Total                 CHF 1'259.00",
        ])

        #expect(receipt.currencyCode == "CHF")
        #expect(receipt.items.map(\.name) == ["Rösti", "Fondue für zwei"])
        #expect(receipt.items.map(\.unitPrice) == [d("24.50"), d("1234.50")])
        #expect(receipt.total == d("1259.00"))
    }

    @Test func readsEuropeanGrouping() {
        #expect(ReceiptTextParser.splitTrailingPrice("Menü 1.234,56")?.price == d("1234.56"))
        #expect(ReceiptTextParser.splitTrailingPrice("Menü 1.234,56 €")?.price == d("1234.56"))
        #expect(ReceiptTextParser.splitTrailingPrice("Gutschein -5,00 €")?.isCredit == true)
        #expect(ReceiptTextParser.splitTrailingPrice("Total 45.00 USD")?.label == "Total")
    }

    @Test func aSpaceGroupsThousandsOnlyWhereTheCommaIsTheDecimalMark() {
        let swedish = ReceiptTextParser.parse(lines: [
            "Avsmakningsmeny     1 250,00",
            "Vinpaket              695,00",
            "Summa               1 945,00 kr",
        ])
        #expect(swedish.currencyCode == "SEK")
        #expect(swedish.items.map(\.unitPrice) == [d("1250.00"), d("695.00")])
        #expect(swedish.total == d("1945.00"))

        let american = ReceiptTextParser.parse(lines: ["Item 2 150.00", "Total 150.00"])
        #expect(american.items.map(\.name) == ["Item 2"])
        #expect(american.items.map(\.unitPrice) == [d("150.00")])
    }

    @Test func readsAYenReceipt() {
        let receipt = ReceiptTextParser.parse(lines: [
            "居酒屋 さくら",
            "TEL 03-1234-5678",
            "2026/10/03 19:45",
            "テーブル 12",
            "生ビール          ¥1,200",
            "2 焼き鳥           ¥900",
            "枝豆               ¥450",
            "小計             ¥2,550",
            "消費税 10%",
            "消費税             ¥255",
            "合計             ¥2,805",
            "お預り           ¥3,000",
            "お釣り             ¥195",
        ])

        #expect(receipt.currencyCode == "JPY")
        #expect(receipt.items.map(\.name) == ["生ビール", "焼き鳥", "枝豆"])
        #expect(receipt.items.map(\.quantity) == [1, 2, 1])
        #expect(receipt.items.map(\.unitPrice) == [1200, 450, 450])
        #expect(receipt.subtotal == 2550)
        #expect(receipt.tax == 255)
        #expect(receipt.total == 2805)
        #expect(receipt.reconciles == true)
    }

    @Test func wholeDollarPricesNeedTheirSign() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Table 12",
            "Burger $12",
            "Fries $5",
            "Total $17",
        ])
        #expect(receipt.items.map(\.name) == ["Burger", "Fries"])
        #expect(receipt.total == 17)
    }

    @Test func taxAlreadyInThePricesIsNotAddedAgain() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Fish & Chips        £14.00",
            "Pint of Bitter       £6.00",
            "Net                 £16.67",
            "VAT 20%              £3.33",
            "Total               £20.00",
        ])

        #expect(receipt.currencyCode == "GBP")
        #expect(receipt.items.map(\.name) == ["Fish & Chips", "Pint of Bitter"])
        #expect(receipt.tax == 0)
        #expect(receipt.total == d("20.00"))
        #expect(receipt.reconciles == true)
    }

    @Test func aReceiptWithNoSignHasNoCurrency() {
        let receipt = ReceiptTextParser.parse(lines: ["Burger 12.00", "Total 12.00"])
        #expect(receipt.currencyCode == nil)
    }

    @Test func aDollarSignFollowsTheHomeCurrency() {
        let lines = ["Poutine $12.00", "Total $12.00"]
        #expect(ReceiptTextParser.parse(lines: lines, homeCurrency: "CAD").currencyCode == "CAD")
        #expect(ReceiptTextParser.parse(lines: lines, homeCurrency: "EUR").currencyCode == "USD")
    }

    @Test func parsesTypicalReceipt() {
        let receipt = ReceiptTextParser.parse(lines: [
            "JOE'S DINER",
            "123 Main St",
            "(555) 123-4567",
            "10/03/2026 7:45 PM",
            "Table 12   Guests 4",
            "2 Burger            $19.00",
            "Caesar Salad         12.50",
            "3x IPA               21.00",
            "Fries x2              9.00",
            "Subtotal             61.50",
            "Sales Tax             5.07",
            "Total                66.57",
            "Tip: ____________",
            "VISA ****1234        66.57",
            "Thank you!",
        ])

        #expect(receipt.items.map(\.name) == ["Burger", "Caesar Salad", "IPA", "Fries"])
        #expect(receipt.items.map(\.quantity) == [2, 1, 3, 2])
        #expect(receipt.items.map(\.unitPrice) == [d("9.50"), d("12.50"), d("7.00"), d("4.50")])
        #expect(receipt.subtotal == d("61.50"))
        #expect(receipt.tax == d("5.07"))
        #expect(receipt.total == d("66.57"))
        #expect(receipt.itemsSubtotal == d("61.50"))
    }

    @Test func explicitUnitPriceWins() {
        let receipt = ReceiptTextParser.parse(lines: ["Taco 3 @ 4.50   13.50"])
        #expect(receipt.items.count == 1)
        #expect(receipt.items[0].name == "Taco")
        #expect(receipt.items[0].quantity == 3)
        #expect(receipt.items[0].unitPrice == d("4.50"))
    }

    @Test func joinsNameAndPriceOnSeparateLines() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Margherita Pizza",
            "$18.00",
            "Tax",
            "1.44",
            "TOTAL",
            "19.44",
        ])
        #expect(receipt.items.map(\.name) == ["Margherita Pizza"])
        #expect(receipt.items[0].unitPrice == d("18.00"))
        #expect(receipt.tax == d("1.44"))
        #expect(receipt.total == d("19.44"))
    }

    @Test func handlesPriceQuirks() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Tasting Menu      1,250.00",
            "Espresso              3,50",
            "Soda                  2.99 T",
            "Water                 0.00",
            "Discount              5.00-",
        ])
        #expect(receipt.items.map(\.name) == ["Tasting Menu", "Espresso", "Soda"])
        #expect(receipt.items.map(\.unitPrice) == [d("1250.00"), d("3.50"), d("2.99")])
    }

    @Test func sumsMultipleTaxLines() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Pasta   20.00",
            "GST      1.00",
            "PST      1.40",
            "Total   22.40",
        ])
        #expect(receipt.tax == d("2.40"))
        #expect(receipt.items.count == 1)
    }

    @Test func skipsPaymentAndTipLines() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Ramen          16.00",
            "Tax             1.28",
            "Total          17.28",
            "Suggested Tip 20%   3.46",
            "Cash           20.00",
            "Change          2.72",
        ])
        #expect(receipt.items.map(\.name) == ["Ramen"])
        #expect(receipt.total == d("17.28"))
    }

    @Test func parsesXPrefixedQuantitiesAndInlineUnitPrices() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Table Barll",
            "Date: 10/3/2026 11:16 AM (1)",
            "Server: Andy",
            "x2 Vodka($9.00) $18.00",
            "x1 Sausage Ricotta Boat $30.00",
            "x1 Chuckanut - Pilsner $8.90",
            "x2 Russian River - Pliny ($9.50) $19.00",
            "x3 Elysian - Hazy IPA($9.00) $27.00",
            "Total 7 item(s) $102.90",
            "Sales Tax (10.55%) $10.86",
            "Grand Total $113.76",
            "Tip Guide: 15%-$17.06 / 18%-$20.48 / 20%=$",
            "22.75",
        ])

        #expect(receipt.items.map(\.name) == [
            "Vodka", "Sausage Ricotta Boat", "Chuckanut - Pilsner", "Russian River - Pliny", "Elysian - Hazy IPA",
        ])
        #expect(receipt.items.map(\.quantity) == [2, 1, 1, 2, 3])
        #expect(receipt.items.map(\.unitPrice) == [d("9.00"), d("30.00"), d("8.90"), d("9.50"), d("9.00")])
        #expect(receipt.subtotal == d("102.90"))
        #expect(receipt.tax == d("10.86"))
        #expect(receipt.total == d("113.76"))
    }

    @Test func headerFieldsNeverBecomeItems() {
        // A stray price right under a header line must not adopt its name.
        let receipt = ReceiptTextParser.parse(lines: [
            "Server: Andy",
            "$18.00",
            "Table #4  12.00",
            "Burger  9.00",
        ])
        #expect(receipt.items.map(\.name) == ["Burger"])
    }

    @Test func nothingAfterTheSummaryIsAnItem() {
        let receipt = ReceiptTextParser.parse(lines: [
            "1 Sausage Burrito    1.00",
            "Sub. Total:          1.00",
            "Tax                  0.09",
            "Take-Out Total       1.09",
            "TRANSACTION AMOUNT   1.09",
            "Next Dollar          2.00",
            "Even Split (4):      0.27",
        ])
        #expect(receipt.items.map(\.name) == ["Sausage Burrito"])
        #expect(receipt.subtotal == d("1.00"))
        #expect(receipt.total == d("1.09"))
    }

    @Test func findsSubtotalTaxAndTotalByArithmetic() {
        // None of the summary lines carries a word the parser knows.
        let receipt = ReceiptTextParser.parse(lines: [
            "Iced Tea       2.50",
            "Diet Coke      2.50",
            "Cuban         11.99",
            "TxblPur       16.99",
            "StTx           1.23",
            "Total         18.22",
        ])
        #expect(receipt.items.map(\.name) == ["Iced Tea", "Diet Coke", "Cuban"])
        #expect(receipt.subtotal == d("16.99"))
        #expect(receipt.tax == d("1.23"))
        #expect(receipt.total == d("18.22"))
    }

    @Test func itemThatHappensToEqualTheOnesAboveStaysAnItem() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Soup      5.00",
            "Salad     5.00",
            "Steak    10.00",
            "Tax       1.60",
            "Total    21.60",
        ])
        #expect(receipt.items.count == 3)
        #expect(receipt.subtotal == nil)
    }

    @Test func unnamedTotalAndUnreadableTax() {
        let unnamed = ReceiptTextParser.parse(lines: [
            "Pho           12.00",
            "Spring Rolls   6.00",
            "Subtotal      18.00",
            "Tax            1.50",
            "Amount;       19.50",
        ])
        #expect(unnamed.total == d("19.50"))

        // The tax amount was lost, but the gap to the total gives it.
        let unreadable = ReceiptTextParser.parse(lines: [
            "Pho           12.00",
            "Spring Rolls   6.00",
            "Subtotal      18.00",
            "lax",
            "Total         19.50",
        ])
        #expect(unreadable.tax == d("1.50"))
    }

    @Test func sumsDecideAmbiguousLines() {
        // A header line ending in a number, a note that is not a charge, and
        // category subtotals: each is dropped because the subtotal says so.
        let header = ReceiptTextParser.parse(lines: [
            "Register 1 14:17.07", "Salad 15.00", "Pizza 22.00", "Soda 3.00", "Subtotal 40.00",
        ])
        #expect(header.items.map(\.name) == ["Salad", "Pizza", "Soda"])

        let note = ReceiptTextParser.parse(lines: [
            "Eggs 3.24", "Milk 1.68", "REDUCED WAS 6.17", "Subtotal 4.92",
        ])
        #expect(note.items.map(\.name) == ["Eggs", "Milk"])

        let categories = ReceiptTextParser.parse(lines: [
            "Fillet 150.00", "Mojito 35.00", "Food 150.00", "Beverage 35.00", "Amount Due 185.00",
        ])
        #expect(categories.items.map(\.name) == ["Fillet", "Mojito"])
    }

    @Test func unitPriceColumnIsRecognized() {
        let receipt = ReceiptTextParser.parse(lines: [
            "2 Burger       9.50",
            "Fries 4.00     4.00",
            "Subtotal      23.00",
        ])
        #expect(receipt.items.map(\.name) == ["Burger", "Fries"])
        #expect(receipt.items.map(\.lineTotal) == [d("19.00"), d("4.00")])
    }

    @Test func readsNoisyLines() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Tri-Tip Sandwich     14.00",
            "12 Eggs w Sausage    14.00",
            "> 1 16PC MEAL        35.99 TX",
            "Lettuce - Iceberg -  12.42",
            "Coffee               $4 .00 1",
            "Subtota1             80.41",
            "T0TAL                80.41",
        ])
        #expect(receipt.items.map(\.name) == [
            "Tri-Tip Sandwich", "12 Eggs w Sausage", "16PC MEAL", "Lettuce - Iceberg", "Coffee",
        ])
        #expect(receipt.items.map(\.quantity) == [1, 1, 1, 1, 1])
        #expect(receipt.subtotal == d("80.41"))
        #expect(receipt.total == d("80.41"))
    }

    @Test func readsServiceChargesAndFees() {
        let receipt = ReceiptTextParser.parse(lines: [
            "2 Burger            24.00",
            "Room Service Club   16.00",
            "Fries                6.00",
            "Subtotal            46.00",
            "Service Charge 18%   8.28",
            "Card Surcharge       1.38",
            "Tax                  4.60",
            "Total               60.26",
            "Suggested Gratuity 20%  9.20",
            "VISA                60.26",
        ])
        #expect(receipt.items.map(\.name) == ["Burger", "Room Service Club", "Fries"])
        #expect(receipt.charges.map(\.name) == ["Service Charge 18%", "Card Surcharge"])
        #expect(receipt.charges.map(\.amount) == [d("8.28"), d("1.38")])
        #expect(receipt.tax == d("4.60"))
        #expect(receipt.total == d("60.26"))
        #expect(receipt.computedTotal == d("60.26"))
        #expect(receipt.includesGratuity)
    }

    @Test func readsAChargeWithNoSubtotalLine() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Pasta        20.00",
            "Wine         30.00",
            "Gratuity     10.00",
            "Tax           4.00",
            "Total        64.00",
        ])
        #expect(receipt.items.map(\.name) == ["Pasta", "Wine"])
        #expect(receipt.charges.map(\.amount) == [d("10.00")])
        #expect(receipt.total == d("64.00"))
    }

    @Test func gratuityAfterTheTotalNeedsATotalThatIncludesIt() {
        // Added on, with a second total that proves it.
        let added = ReceiptTextParser.parse(lines: [
            "Ramen 16.00", "Gyoza 8.00", "Tax 2.00", "Total 26.00", "Gratuity 4.68", "Amount Due 30.68",
        ])
        #expect(added.charges.map(\.amount) == [d("4.68")])
        #expect(added.total == d("30.68"))

        // Printed as a hint under the total: not a charge.
        let hint = ReceiptTextParser.parse(lines: [
            "Ramen 16.00", "Gyoza 8.00", "Tax 2.00", "Total 26.00", "Gratuity 18% 4.68", "Gratuity 20% 5.20",
        ])
        #expect(hint.charges.isEmpty)
        #expect(hint.total == d("26.00"))
    }

    /// A paid copy prints the tip that was left. It is shared like a service
    /// charge once a later amount shows it was really added.
    @Test func printedTipIsAChargeWhenALaterAmountIncludesIt() {
        let secondTotal = ReceiptTextParser.parse(lines: [
            "Pasta 60.00", "Wine 40.00", "Subtotal 100.00", "Tax 8.00", "Total 108.00", "Tip 20.00", "Total 128.00",
        ])
        #expect(secondTotal.charges.map(\.name) == ["Tip"])
        #expect(secondTotal.charges.map(\.amount) == [d("20.00")])
        #expect(secondTotal.total == d("128.00"))
        #expect(secondTotal.reconciles == true)
        #expect(secondTotal.includesGratuity)

        let payment = ReceiptTextParser.parse(lines: [
            "Pasta 60.00", "Wine 40.00", "Subtotal 100.00", "Tax 8.00", "Total 108.00", "Tip 20.00", "Visa 128.00",
        ])
        #expect(payment.charges.map(\.amount) == [d("20.00")])
        #expect(payment.total == d("128.00"))
        #expect(payment.reconciles == true)

        let aboveTheTotal = ReceiptTextParser.parse(lines: [
            "Pasta 60.00", "Wine 40.00", "Subtotal 100.00", "Tax 8.00", "Tip 20.00", "Total 128.00",
        ])
        #expect(aboveTheTotal.charges.map(\.amount) == [d("20.00")])
        #expect(aboveTheTotal.tax == d("8.00"))
        #expect(aboveTheTotal.reconciles == true)
    }

    @Test func tipNoTotalAccountsForIsIgnored() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Pasta 60.00", "Wine 40.00", "Subtotal 100.00", "Tax 8.00", "Total 108.00",
            "Tip 18% 19.44", "Tip 20% 21.60", "Suggested Tip 22% 23.76", "Visa 108.00",
        ])
        #expect(receipt.charges.isEmpty)
        #expect(receipt.total == d("108.00"))
        #expect(!receipt.includesGratuity)
    }

    /// A long name wraps under its own line, which filled the name column.
    @Test func wrappedNameBelowThePriceLineIsOneItem() {
        let receipt = ReceiptTextParser.parse(lines: [
            "1 Caesar Salad 12.00",
            "1 Buttermilk Fried Chicken 16.00",
            "Sandwich",
            "1 Truffle Parmesan Fries 9.00",
            "1 Iced Tea 4.00",
            "Subtotal 41.00",
        ])
        #expect(receipt.items.map(\.name) == [
            "Caesar Salad", "Buttermilk Fried Chicken Sandwich", "Truffle Parmesan Fries", "Iced Tea",
        ])
        #expect(receipt.itemsSubtotal == d("41.00"))
    }

    /// A line under a short name didn't wrap from it: a modifier, or an item
    /// whose price wasn't read. Neither belongs in the name above.
    @Test func lineUnderAShortNameIsNotAWrap() {
        let receipt = ReceiptTextParser.parse(lines: [
            "1 Sapporo 7.00",
            "Cider",
            "1 Salt and Pepper Shrimp 19.00",
            "1 Iced Tea 4.00",
            "No ice",
            "1 Garlic Noodles 16.00",
        ])
        #expect(receipt.items.map(\.name) == ["Sapporo", "Salt and Pepper Shrimp", "Iced Tea", "Garlic Noodles"])
    }

    /// The price sits on the last line of the name. Where items start with a
    /// quantity, the line that has one is where the item starts.
    @Test func wrappedNameAboveThePriceLineIsOneItem() {
        let receipt = ReceiptTextParser.parse(lines: [
            "1 Caesar Salad 12.00",
            "1 Grilled Salmon with Lemon",
            "Butter Sauce 24.00",
            "2 Iced Tea 8.00",
            "1 Garlic Noodles 16.00",
        ])
        #expect(receipt.items.map(\.name) == ["Caesar Salad", "Grilled Salmon with Lemon Butter Sauce", "Iced Tea", "Garlic Noodles"])
        #expect(receipt.items.map(\.quantity) == [1, 1, 2, 1])
    }

    /// A line ending in a comma runs on into the next.
    @Test func linesEndingInACommaRunOn() {
        let receipt = ReceiptTextParser.parse(lines: [
            "2 Cokes 5.00",
            "Bacon Burger, burger mods,",
            "cheddar, add bacon,",
            "sour cream 13.75",
            "Sub Total: 18.75",
        ])
        #expect(receipt.items.map(\.name) == ["Cokes", "Bacon Burger, burger mods, cheddar, add bacon, sour cream"])
    }

    /// Two name lines above a price on a row of its own.
    @Test func wrappedNameAboveABarePriceIsOneItem() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Caesar Salad", "12.00",
            "Buttermilk Fried Chicken", "Sandwich", "16.00",
            "Truffle Parmesan Fries", "9.00",
        ])
        #expect(receipt.items.map(\.name) == ["Caesar Salad", "Buttermilk Fried Chicken Sandwich", "Truffle Parmesan Fries"])
    }

    /// A digital receipt in a proportional font: names wrap under their
    /// own line, and a note in smaller print sits under some items. Sizes
    /// and positions are as the OCR reported them.
    @Test func wrappedNamesAreJoinedByPositionAndSmallPrintIsLeftOut() {
        func row(_ name: String, _ x: Double, _ width: Double, _ height: Double, price: String? = nil) -> OCRRow {
            var spans = [OCRRow.Span(minX: x, width: width, height: height, length: name.count)]
            if let price {
                spans.append(OCRRow.Span(minX: 0.795, width: 0.1, height: 0.0233, length: price.count))
            }
            return OCRRow(
                text: [name, price].compactMap { $0 }.joined(separator: " "),
                minX: x, minY: 0, width: 0.8, height: height, spans: spans
            )
        }
        let receipt = ReceiptTextParser.parse(rows: [
            row("Trillium Vanilla PM Dawn Imp. Stout*16oz", 0.109, 0.620, 0.0190, price: "$7.30"),
            row("Loose", 0.105, 0.080, 0.0131),
            row("Epic BA Imperial Pumpkin Porter CANS", 0.106, 0.589, 0.0206, price: "$8.50"),
            row("• 16oz", 0.106, 0.094, 0.0176),
            row("Loose", 0.108, 0.077, 0.0131),
            row("House Pretzel", 0.109, 0.230, 0.0190, price: "$2.00"),
            row("Himemaru Japanese Rice Crackers -", 0.106, 0.554, 0.0175, price: "$5.00"),
            row("Toasted, Mildly Spicy 3.45oz", 0.109, 0.434, 0.0191),
            row("#35: Little Beast : Festbier ($16", 0.106, 0.523, 0.0161, price: "$5.00"),
            row("Liter/$8.50 ½ Liter)", 0.109, 0.291, 0.0176),
            row("Half (8oz or 1/2L)", 0.109, 0.217, 0.0132),
            row("Purchase Subtotal", 0.109, 0.271, 0.0147, price: "$27.80"),
        ])
        #expect(receipt.items.map(\.name) == [
            "Trillium Vanilla PM Dawn Imp. Stout*16oz",
            "Epic BA Imperial Pumpkin Porter CANS • 16oz",
            "House Pretzel",
            "Himemaru Japanese Rice Crackers - Toasted, Mildly Spicy 3.45oz",
            "#35: Little Beast : Festbier ($16 Liter/$8.50 ½ Liter)",
        ])
        #expect(receipt.itemsSubtotal == d("27.80"))
    }

    /// Names well short of the price column didn't wrap, whatever sits
    /// under them.
    @Test func lineUnderANameWithRoomToSpareIsNotAWrap() {
        func row(_ name: String, _ width: Double, price: String? = nil) -> OCRRow {
            var spans = [OCRRow.Span(minX: 0.1, width: width, height: 0.02, length: name.count)]
            if let price {
                spans.append(OCRRow.Span(minX: 0.8, width: 0.1, height: 0.02, length: price.count))
            }
            return OCRRow(
                text: [name, price].compactMap { $0 }.joined(separator: " "),
                minX: 0.1, minY: 0, width: 0.8, height: 0.02, spans: spans
            )
        }
        let receipt = ReceiptTextParser.parse(rows: [
            row("Supreme Burger", 0.28, price: "16.95"),
            row("Medium", 0.12),
            row("Pastrami Burger", 0.30, price: "15.25"),
            row("Medium", 0.12),
            row("Fountain Soda", 0.26, price: "2.25"),
            row("Club soda", 0.18),
        ])
        #expect(receipt.items.map(\.name) == ["Supreme Burger", "Pastrami Burger", "Fountain Soda"])
    }

    @Test func readsADiscountTheTotalConfirms() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Pizza 20.00", "Salad 10.00", "Subtotal 30.00", "Happy Hour Discount -5.00", "Tax 2.00", "Total 27.00",
        ])
        #expect(receipt.charges.map(\.amount) == [d("-5.00")])
        #expect(receipt.computedTotal == d("27.00"))
        #expect(!receipt.includesGratuity)
    }

    @Test func emptyInputGivesEmptyReceipt() {
        let receipt = ReceiptTextParser.parse(lines: [])
        #expect(receipt.items.isEmpty)
        #expect(receipt.tax == 0)
        #expect(receipt.subtotal == nil)
        #expect(receipt.total == nil)
    }
}

@Suite struct OCRRowGrouperTests {
    @Test func rejoinsFragmentsOnTheSameRow() {
        let lines = OCRRowGrouper.lines(from: [
            TextFragment(text: "12.50", minX: 0.80, midY: 0.702, height: 0.02),
            TextFragment(text: "Total", minX: 0.10, midY: 0.60, height: 0.02),
            TextFragment(text: "Caesar Salad", minX: 0.10, midY: 0.70, height: 0.02),
            TextFragment(text: "JOE'S DINER", minX: 0.30, midY: 0.95, height: 0.04),
            TextFragment(text: "13.50", minX: 0.80, midY: 0.598, height: 0.02),
        ])
        #expect(lines == ["JOE'S DINER", "Caesar Salad 12.50", "Total 13.50"])
    }

    @Test func pairsRowsOnATiltedReceipt() {
        // Rows run uphill, so each price sits nearer the name on the row above
        // than the name on its own row.
        let slope = 0.03
        func row(_ name: String, _ price: String, y: Double) -> [TextFragment] {
            [
                TextFragment(text: name, minX: 0.10, midY: y + slope * (0.25 - 0.5), height: 0.02, midX: 0.25, width: 0.30, slope: slope),
                TextFragment(text: price, minX: 0.75, midY: y + slope * (0.80 - 0.5), height: 0.02, midX: 0.80, width: 0.10, slope: slope),
            ]
        }
        let fragments = row("Vodka", "18.00", y: 0.70) + row("Sausage Boat", "30.00", y: 0.675) + row("Pilsner", "8.90", y: 0.65)

        #expect(OCRRowGrouper.lines(from: fragments) == ["Vodka 18.00", "Sausage Boat 30.00", "Pilsner 8.90"])
    }

    @Test func rowsCoverTheirFragments() throws {
        let rows = OCRRowGrouper.rows(from: [
            TextFragment(text: "Caesar Salad", minX: 0.10, midY: 0.70, height: 0.02, midX: 0.25, width: 0.30, confidence: 0.9),
            TextFragment(text: "12.50", minX: 0.80, midY: 0.702, height: 0.02, midX: 0.85, width: 0.10, confidence: 0.4),
        ])
        let row = try #require(rows.first)
        #expect(rows.count == 1)
        #expect(row.text == "Caesar Salad 12.50")
        #expect(abs(row.minX - 0.10) < 1e-9 && abs(row.width - 0.80) < 1e-9)
        #expect(abs(row.minY - 0.69) < 1e-9 && abs(row.height - 0.022) < 1e-9)
        #expect(row.confidence == 0.4)
    }

    @Test func fragmentsSavedWithoutConfidenceStillLoad() throws {
        let saved = #"[{"text":"Total","minX":0.1,"midX":0.2,"midY":0.6,"width":0.2,"height":0.02,"slope":0}]"#
        let fragments = try JSONDecoder().decode([TextFragment].self, from: Data(saved.utf8))
        #expect(fragments.first?.confidence == 1)
    }
}

@Suite struct ReceiptSourceTests {
    @Test func itemsRememberTheLinesTheyCameFrom() throws {
        let (receipt, sources) = ReceiptTextParser.parseWithSources(lines: [
            "JOE'S DINER",
            "2 Burger 19.00",
            "Caesar Salad",
            "12.50",
            "Subtotal 31.50",
            "Tax 2.50",
            "Total 34.00",
        ])
        #expect(receipt.items.count == 2)
        let burger = try #require(receipt.items.first)
        let salad = try #require(receipt.items.last)
        #expect(sources[burger.id] == [1])
        // The name and the price were on separate rows.
        #expect(sources[salad.id] == [2, 3])
        #expect(sources.count == 2)
    }

    /// "Total" is the items' sum here; the party charge, a surcharge and
    /// the tax sit between it and the grand total.
    @Test func totalAboveChargesAndTaxIsTheSubtotal() {
        let receipt = ReceiptTextParser.parse(lines: [
            "Chubby Noodle",
            "Server: Marisol Ta. 23",
            "Guests: 6",
            "Description Amount",
            "MOMOKAWA SAKE $38.00*",
            "SMALL SAPORRO (5@7.00) $ 35.00*",
            "CIDER $ 10.00*",
            "SALT & PEPPER SHRIMP $ 19.00*",
            "CHILE PRAWNS $33.00*",
            "add 3 steaj rice sfss",
            "GARLIC NOODLES $ 16.00*",
            "Total $ 151.00",
            "Parties of 6+ $ 30.20",
            "*(5%) Healthy SF Surcharge $7.55",
            "*(8.63 %) Sales Tax $ 16.31",
            "Grand Total $ 205.06",
        ])

        #expect(receipt.items.map(\.name) == [
            "MOMOKAWA SAKE", "SMALL SAPORRO", "CIDER", "SALT & PEPPER SHRIMP", "CHILE PRAWNS", "GARLIC NOODLES",
        ])
        #expect(receipt.items.map(\.quantity) == [1, 5, 1, 1, 1, 1])
        #expect(receipt.items[1].unitPrice == d("7.00"))
        #expect(receipt.subtotal == d("151.00"))
        #expect(receipt.tax == d("16.31"))
        #expect(receipt.charges.map(\.name) == ["Parties of 6+", "(5%) Healthy SF Surcharge"])
        #expect(receipt.charges.map(\.amount) == [d("30.20"), d("7.55")])
        #expect(receipt.total == d("205.06"))
        #expect(receipt.reconciles == true)
        // A charge for a large party is the tip.
        #expect(receipt.includesGratuity)
    }

    /// OCR reads the "@" of "(5@7.00)" as a zero.
    @Test func quantityInParenthesesSurvivesAMisreadAtSign() {
        let receipt = ReceiptTextParser.parse(lines: ["SMALL SAPORRO (507.00) $ 35.00*", "Vodka ($9.00) 9.00"])
        #expect(receipt.items.map(\.name) == ["SMALL SAPORRO", "Vodka"])
        #expect(receipt.items.map(\.quantity) == [5, 1])
        #expect(receipt.items.map(\.unitPrice) == [d("7.00"), d("9.00")])
    }

    @Test func chargesCountTowardsReconciling() {
        let d = { (value: String) in Decimal(string: value)! }
        var receipt = Receipt(
            items: [LineItem(name: "Pizza", unitPrice: d("20.00"))],
            tax: d("2.00"),
            total: d("25.60"),
            charges: [Charge(name: "Service Charge", amount: d("3.60"))]
        )
        #expect(receipt.reconciles == true)
        receipt.charges = []
        #expect(receipt.reconciles == false)
    }
}
