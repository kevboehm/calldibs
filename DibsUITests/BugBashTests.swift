import XCTest

/// Exploratory walkthroughs of every flow. They record what the app shows
/// (screenshots and "OBS|" lines) rather than asserting, so a human or agent
/// can review the results after a run.
final class BugBashTests: XCTestCase {
    private var app: XCUIApplication!
    private let shotsDir = ProcessInfo.processInfo.environment["SHOTS_DIR"] ?? NSTemporaryDirectory()

    override func setUp() {
        continueAfterFailure = true
    }

    // MARK: - Helpers

    private func launch(_ seed: String? = nil, extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = (seed.map { ["-seedScreen", $0] } ?? []) + extra
        app.launch()
    }

    private func shot(_ name: String) {
        let url = URL(fileURLWithPath: shotsDir).appendingPathComponent("\(name).png")
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
    }

    private func note(_ text: String) {
        print("OBS| \(name) | \(text)")
    }

    private func texts() -> [String] {
        // Let animations settle so the element list isn't changing underneath us.
        usleep(800_000)
        return app.staticTexts.allElementsBoundByIndex.map(\.label)
    }

    private func counter() -> String {
        texts().first { $0.range(of: #"^\d+ of \d+$"#, options: .regularExpression) != nil } ?? "no counter"
    }

    @discardableResult
    private func tap(_ element: XCUIElement, _ what: String) -> Bool {
        guard element.waitForExistence(timeout: 3) else {
            note("MISSING: \(what)")
            return false
        }
        guard element.isHittable else {
            note("NOT HITTABLE: \(what)")
            return false
        }
        element.tap()
        return true
    }

    private func button(_ label: String) -> XCUIElement { app.buttons[label].firstMatch }

    /// Nudges the screen up in small steps until the element can be tapped.
    private func scrollTo(_ element: XCUIElement) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        for _ in 0..<12 where !(element.exists && element.isHittable) {
            start.press(forDuration: 0.05, thenDragTo: end)
        }
    }

    // MARK: - Flows

    func testManualEntryEndToEnd() {
        launch(extra: ["-resetBill"])
        shot("m01-home")
        tap(button("Scan a receipt"), "Scan a receipt")
        shot("m02-source-dialog")
        tap(button("Enter items manually"), "Enter items manually")
        shot("m03-blank-edit")

        // Can a blank bill be started?
        note("blank row: start button enabled = \(button("Start calling dibs").isEnabled)")

        let name = app.textFields["Item name"].firstMatch
        tap(name, "item name field")
        name.typeText("Extra Large Supreme Pizza With Everything On It And Then Some")
        let prices = app.textFields.matching(NSPredicate(format: "placeholderValue == '0.00'"))
        note("price-like fields: \(prices.count)")
        tap(prices.element(boundBy: 0), "line total field")
        prices.element(boundBy: 0).typeText("24.50")
        tap(button("Add item"), "Add item")
        let names = app.textFields.matching(NSPredicate(format: "placeholderValue == 'Item name'"))
        tap(names.element(boundBy: 1), "second name")
        names.element(boundBy: 1).typeText("Fries")
        tap(prices.element(boundBy: 1), "second price")
        prices.element(boundBy: 1).typeText("6")
        shot("m04-typing")
        tap(app.toolbars.buttons["Done"].firstMatch, "keyboard Done")
        shot("m05-filled")
        note("after typing: \(texts())")
        note("field values: \(app.textFields.allElementsBoundByIndex.map { "\($0.value ?? "nil")" })")

        tap(app.navigationBars.buttons["Done"].firstMatch, "nav Done")
        shot("m06-summary")
        note("summary: \(texts())")
        tap(button("Start calling dibs"), "Start calling dibs")
        shot("m07-name")
        let who = app.textFields["Your name"].firstMatch
        if who.waitForExistence(timeout: 3) { who.typeText("Kev") }
        tap(button("Call my dibs"), "Call my dibs")
        shot("m08-swipe")
        note("swipe start: \(counter()) \(texts())")

        let card = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Extra Large'")).firstMatch
        if card.waitForExistence(timeout: 3) { card.swipeRight() } else { note("MISSING: first card") }
        sleep(1)
        shot("m09-after-swipe-right")
        note("after swipe right: \(counter())")
        tap(button("Not mine"), "Not mine")
        sleep(1)
        shot("m10-finished")
        note("finished: \(texts())")
        tap(button("Review"), "Review")
        shot("m11-mini")
        note("mini: \(texts())")
    }

    func testSwipeDeckPickerAndSplit() {
        launch("swipe")
        note("start \(counter())")
        tap(button("Call dibs"), "Call dibs on a 2-unit item")
        shot("s01-picker")
        note("picker: \(texts())  buttons: \(app.buttons.allElementsBoundByIndex.map(\.label))")
        tap(button("One more"), "One more")
        shot("s02-picker-2")
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Dibs on 2'")).firstMatch, "Dibs on 2")
        sleep(1)
        shot("s03-after-dibs")
        note("after dibs on 2: \(counter())")

        // Swipe left on the next card by dragging its title.
        let boat = app.staticTexts["Sausage Ricotta Boat"].firstMatch
        if boat.waitForExistence(timeout: 3) { boat.swipeLeft() } else { note("MISSING: boat card") }
        sleep(1)
        note("after swipe left: \(counter())")

        tap(button("Split this item"), "Split this item")
        shot("s04-split-sheet")
        tap(button("One more"), "One more share")
        shot("s05-split-3")
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Split 3'")).firstMatch, "Split 3 ways")
        sleep(1)
        shot("s06-after-split")
        note("after split: \(texts())")
        tap(button("Call dibs"), "Call dibs on split item")
        shot("s07-share-picker")
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Dibs on 1'")).firstMatch, "Dibs on 1")
        sleep(1)
        note("after share dibs: \(counter())")
        tap(button("Previous item"), "Previous item")
        sleep(1)
        shot("s08-previous")
        note("previous card: \(texts())")

        for _ in 0..<8 where button("Not mine").exists { button("Not mine").tap(); usleep(700_000) }
        shot("s09-deck-finished")
        note("deck end: \(texts())")
        tap(button("Review"), "Review")
        shot("s10-mini")
        note("mini: \(texts())")
    }

    func testChecklist() {
        launch("checklist")
        shot("c01-start")
        tap(app.staticTexts["Chuckanut - Pilsner"].firstMatch, "single row")
        tap(app.staticTexts["Russian River - Pliny"].firstMatch, "multi row")
        shot("c02-expanded")
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Dibs on all'")).firstMatch, "Dibs on all")
        sleep(1)
        shot("c03-after-all")
        let taken = app.staticTexts["Sausage Ricotta Boat"].firstMatch
        note("taken row hittable: \(taken.isHittable)")
        if taken.exists { taken.tap() }
        tap(button("Split this item"), "split a single row")
        shot("c04-split")
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Split 2'")).firstMatch, "Split 2 ways")
        sleep(1)
        shot("c05-after-split")
        note("checklist: \(texts())")
        tap(button("Swipe"), "switch to swipe")
        sleep(1)
        shot("c06-swipe-mode")
        note("swipe after checklist: \(counter()) \(texts())")
    }

    func testMiniReceiptTipAndPass() {
        launch("share")
        shot("r01-start")
        scrollTo(button("25%"))
        shot("r01b-scrolled")
        tap(button("25%"), "25% chip")
        note("after 25%: \(texts().filter { $0.contains("Tip") || $0.contains("Total") })")
        let tip = app.textFields.firstMatch
        if tap(tip, "tip field") {
            tip.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "150")
            tap(app.toolbars.buttons["Done"].firstMatch, "keyboard Done")
            shot("r02-tip-150")
            note("tip 150 typed: field=\(tip.value ?? "nil") texts=\(texts().filter { $0.contains("Tip") || $0.contains("$") }.prefix(12))")
        }
        app.swipeUp()
        shot("r03-scrolled")
        note("bottom of mini: \(texts())")
        let plus = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Call dibs on'")).firstMatch
        tap(plus, "plus on not-yours row")
        shot("r04-after-plus")
        tap(button("Pass to the next person"), "Pass")
        shot("r05-next-name")
        note("next name: \(texts())")
        tap(button("Skip, no name needed"), "Skip")
        sleep(1)
        shot("r06-next-swipe")
        note("next deck: \(counter())")
        tap(button("Review"), "Review")
        shot("r07-empty-mini")
        note("empty mini: \(texts())")
        tap(button("That's everyone"), "That's everyone")
        shot("r08-overview")
        note("overview: \(texts())")
    }

    func testTipBaseToggle() {
        launch("share")
        // The picker sits under the action bar and still counts as hittable
        // there, so drag it well clear rather than using scrollTo.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: end)
        shot("tb01-after-tax")
        note("after tax: \(texts().filter { $0.contains("Tip") || $0.contains("Total") || $0.contains("$") })")
        tap(button("Before tax"), "Before tax segment")
        shot("tb02-before-tax")
        note("before tax: \(texts().filter { $0.contains("Tip") || $0.contains("Total") || $0.contains("$") })")
    }

    func testMismatchedBillIsFlagged() {
        launch("mismatch")
        shot("mm01-banner")
        note("banner: \(texts().filter { $0.contains("add up") || $0.contains("receipt's") })")
        tap(button("Start calling dibs"), "Start calling dibs")
        shot("mm02-dialog")
        note("dialog buttons: \(app.buttons.allElementsBoundByIndex.map(\.label).filter { $0.contains("anyway") || $0.contains("Review") })")
        tap(button("Continue anyway"), "Continue anyway")
        sleep(1)
        shot("mm03-after-continue")
    }

    func testScanWithNoTotalSaysSo() {
        launch("nototal")
        shot("nt01-banner")
        note("banner: \(texts().filter { $0.contains("total") })")
        tap(button("Start calling dibs"), "Start calling dibs")
        sleep(1)
        note("dialog shown: \(button("Continue anyway").exists)")
    }

    func testPrintedTipIsSharedLikeACharge() {
        launch("tipped-share")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        start.press(forDuration: 0.05, thenDragTo: end)
        shot("tp01-share")
        note("tip rows: \(texts().filter { $0.lowercased().contains("tip") || $0.contains("Total") })")
    }

    func testOverviewEditDeleteAndReset() {
        launch("split")
        tap(app.staticTexts["Sam"].firstMatch, "expand Sam")
        shot("o01-expanded")
        tap(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Edit Sam'")).firstMatch, "Edit Sam")
        shot("o02-edit-name")
        note("edit name: \(texts()) field=\(app.textFields.firstMatch.value ?? "nil")")
        tap(button("Keep the name as it is"), "Keep the name while editing")
        sleep(1)
        tap(button("Review"), "Review")
        shot("o03-edited-mini")
        note("after skip while editing: \(texts().prefix(3)) nav=\(app.navigationBars.allElementsBoundByIndex.map(\.identifier))")
        let done = button("Pass to the next person").exists ? button("That's everyone") : button("See the full split")
        tap(done, "back to overview")
        shot("o04-overview")
        note("overview after edit: \(texts())")

        app.swipeUp()
        app.swipeUp()
        scrollTo(button("Start a new bill"))
        tap(button("Start a new bill"), "Start a new bill")
        shot("o07-confirm")
        tap(button("Start fresh"), "Start fresh")
        sleep(1)
        shot("o08-home")
        note("home again: \(texts().prefix(3))")
    }

    func testBackingOutOfANewTurn() {
        launch("split")
        tap(button("Add another person"), "Add another person")
        let who = app.textFields["Your name"].firstMatch
        if who.waitForExistence(timeout: 3) { who.typeText("Zed") }
        tap(button("Call my dibs"), "Call my dibs")
        sleep(1)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        shot("b01-back-to-name")
        note("back on name: \(texts())")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        shot("b02-back-to-overview")
        note("overview: \(texts())")
    }

    func testRemovePerson() {
        launch("split")
        tap(app.staticTexts["Kevin"].firstMatch, "expand Kevin")
        // The breakdown in the row pushes its buttons below the fold.
        scrollTo(button("Remove Kevin"))
        tap(button("Remove Kevin"), "Remove Kevin")
        shot("d01-confirm")
        tap(button("Remove and free their dibs"), "confirm removal")
        shot("d02-removed")
        note("after removal: \(texts())")
    }

    func testBillSurvivesBeingClosed() {
        launch("share")
        scrollTo(button("25%"))
        tap(button("25%"), "25% chip")
        note("before closing: \(texts().filter { $0.contains("owe") || $0.contains("Total") })")

        // Leave the app, then kill it the way the system would in the background.
        XCUIDevice.shared.press(.home)
        sleep(UInt32(ProcessInfo.processInfo.environment["BACKGROUND_SECONDS"] ?? "2") ?? 2)
        app.terminate()
        app.launchArguments = []
        app.launch()
        sleep(2)
        shot("p01-relaunched")
        note("after relaunch: nav=\(app.navigationBars.allElementsBoundByIndex.map(\.identifier)) \(texts().filter { $0.contains("owe") || $0.contains("Tip (") || $0.contains("Total") })")

        // Force-quit from the app switcher, which should discard the bill.
        XCUIDevice.shared.press(.home)
        sleep(1)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let bottom = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.999))
        let middle = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        bottom.press(forDuration: 0.1, thenDragTo: middle, withVelocity: .slow, thenHoldForDuration: 1.2)
        sleep(1)
        shot("p02-switcher")
        let card = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
        let top = springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.0))
        card.press(forDuration: 0.02, thenDragTo: top, withVelocity: .fast, thenHoldForDuration: 0)
        sleep(2)
        shot("p03-after-force-quit")
        app.launch()
        sleep(2)
        shot("p04-after-force-quit-relaunch")
        note("after force quit: nav=\(app.navigationBars.allElementsBoundByIndex.map(\.identifier)) \(texts().prefix(3))")
    }

    /// A receipt drawn for the purpose, whose subtotal is $2 more than its
    /// items, scanned on launch.
    func testScannedBill() throws {
        let lines = [
            "JOE'S DINER", "", "2 Burger          19.00", "Caesar Salad      12.50", "x                  3.00",
            "", "Subtotal          36.50", "Tax                2.50", "Total             39.00",
        ]
        let size = CGSize(width: 700, height: 900)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let receipt = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (row, line) in lines.enumerated() {
                line.draw(at: CGPoint(x: 60, y: 60 + row * 80), withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .regular),
                    .foregroundColor: UIColor.black,
                ])
            }
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("drawn-receipt.png")
        try XCTUnwrap(receipt.pngData()).write(to: url)

        launch(nil, extra: ["-resetBill"])
        app.terminate()
        launch(nil, extra: ["-seedScan", url.path])
        guard button("See the receipt").waitForExistence(timeout: 60) else {
            shot("s00-scan-never-opened")
            return note("MISSING: the scanned bill")
        }
        shot("s01-scanned-bill")
        note("bill: \(texts())")

        tap(button("See the receipt"), "See the receipt")
        sleep(1)
        shot("s02-receipt-viewer")
        note("viewer: image=\(app.images["Photo of the receipt"].exists) nav=\(app.navigationBars.allElementsBoundByIndex.map(\.identifier))")
        tap(button("Done"), "Done")

        tap(button("Edit"), "Edit")
        sleep(1)
        shot("s03-editing-with-strips")
        note("editing: fields=\(app.textFields.allElementsBoundByIndex.map { $0.value as? String ?? "" }) \(texts())")

        // The photo should come back with the bill.
        tap(button("Done"), "Done editing")
        XCUIDevice.shared.press(.home)
        sleep(2)
        app.terminate()
        app.launchArguments = []
        app.launch()
        sleep(2)
        shot("s04-relaunched")
        note("after relaunch: receipt button=\(button("See the receipt").exists)")
    }

    func testSplitTheRestEvenly() {
        launch("split")
        note("before: \(texts().prefix(4)) no dibs=\(app.staticTexts["No dibs yet"].exists)")
        app.swipeUp()
        scrollTo(button("Split the rest evenly"))
        tap(button("Split the rest evenly"), "Split the rest evenly")
        shot("r01-confirm")
        tap(button("Split it evenly"), "Split it evenly")
        sleep(1)
        app.swipeDown()
        shot("r02-covered")
        note("after: \(texts().prefix(4)) no dibs=\(app.staticTexts["No dibs yet"].exists) add person=\(button("Add another person").exists)")
        tap(app.staticTexts["Sam"].firstMatch, "expand Sam")
        shot("r03-sam")
        note("sam: \(texts())")
    }

    func testHistory() {
        launch(nil, extra: ["-resetBill"])
        note("fresh home: history button=\(button("History").exists)")
        launch("split")
        let before = texts().prefix(4)
        shot("h00-split")
        // Twice: each person's breakdown makes the split a long screen.
        app.swipeUp()
        app.swipeUp()
        scrollTo(button("Start a new bill"))
        tap(button("Start a new bill"), "Start a new bill")
        shot("h01-confirm")
        tap(button("Start fresh"), "Start fresh")
        sleep(1)
        shot("h02-home")
        tap(button("History"), "History")
        shot("h03-history")
        note("history: \(texts())")
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Sam'")).firstMatch, "open the split")
        sleep(1)
        shot("h04-audit")
        note("audit: \(texts())")
        scrollTo(button("Reopen this split"))
        tap(button("Reopen this split"), "Reopen this split")
        sleep(1)
        shot("h05-reopened")
        note("reopened: \(texts().prefix(4)) was: \(before)")
    }

    func testPaymentMethods() {
        launch("split")
        app.swipeUp()
        let add = button("Add how you get paid to share pay links")
        note("plain share offered: \(button("Share what everyone owes").exists)")
        tap(add.exists ? add : button("Edit"), "open the payout sheet")
        shot("p01-sheet")
        tap(button("Cash App"), "Cash App")
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) {
            field.tap()
            field.typeText("dibs-tester")
        }
        shot("p02-cashapp")
        tap(button("Save"), "Save")
        sleep(1)
        shot("p03-saved")
        note("after save: \(texts().filter { $0.contains("Cash App") || $0.contains("dibs-tester") }) links=\(button("Send everyone their pay links").exists)")
    }

    func testBillInAnotherCurrency() {
        launch("bill", extra: ["-seedCurrency", "EUR"])
        note("bill: \(texts().filter { $0.contains("€") || $0.contains("EUR") }.prefix(6))")
        tap(button("Edit"), "Edit")
        scrollTo(button("Change"))
        tap(button("Change"), "Change currency")
        sleep(1)
        shot("c01-picker")
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 3) {
            search.tap()
            search.typeText("yen")
        }
        shot("c02-search")
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS 'JPY'")).firstMatch, "Japanese Yen")
        sleep(1)
        shot("c03-yen")
        note("after picking yen: \(texts().filter { $0.contains("¥") || $0.contains("JPY") }.prefix(6))")

        launch("split", extra: ["-seedCurrency", "EUR"])
        app.swipeUp()
        app.swipeUp()
        sleep(1)
        shot("c04-split-bottom")
        note("pay links offered: \(button("Add how you get paid to share pay links").exists || button("Send everyone their pay links").exists) plain share: \(button("Share what everyone owes").exists)")
        note("footer: \(texts().filter { $0.contains("US dollars") })")

        launch("share", extra: ["-seedCurrency", "EUR"])
        sleep(1)
        shot("c05-share")
        note("share: \(texts().filter { $0.contains("€") || $0.contains("Tip") }.prefix(8))")
    }

    func testNamedBillPayButtonsAndDone() {
        launch(nil, extra: ["-resetBill"])
        launch("split", extra: ["-venmoHandle", "dibs-tester", "-paymentMethod", "venmo"])
        let name = app.textFields["Bill name"].firstMatch
        if tap(name, "bill name field") {
            name.typeText("Dinner at Nopa\n")
        }
        shot("n01-named")
        let request = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Request'")).firstMatch
        note("row buttons: request=\(request.exists) send=\(button("Send Sam a pay-me link").exists)")
        tap(button("Send Sam a pay-me link"), "Send Sam a link")
        sleep(2)
        shot("n02-share-sheet")
        let editSam = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Edit Sam'")).firstMatch
        // Drag the share sheet off the bottom to put it away.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
            .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.0)))
        sleep(2)
        note("row opened by the button tap: \(editSam.exists)")
        tap(app.staticTexts["Sam"].firstMatch, "expand Sam")
        note("row opens on its own tap: \(editSam.waitForExistence(timeout: 2))")
        shot("n03-expanded")

        app.swipeUp()
        scrollTo(button("Split the rest evenly"))
        tap(button("Split the rest evenly"), "Split the rest evenly")
        tap(button("Split it evenly"), "Split it evenly")
        sleep(1)
        shot("n04-covered")
        note("covered bar: send all=\(button("Send everyone their pay links").exists) add person=\(button("Add another person").exists)")

        tap(button("Done"), "Done")
        sleep(1)
        shot("n05-home")
        tap(button("History"), "History")
        shot("n06-history")
        note("history: \(texts())")
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Nopa'")).firstMatch, "open the named split")
        sleep(1)
        shot("n07-saved")
        note("saved nav=\(app.navigationBars.allElementsBoundByIndex.map(\.identifier))")
    }

    func testBottomOfSplitScreenIsReachable() {
        launch("split")
        _ = button("Add another person").waitForExistence(timeout: 10)
        app.swipeUp()
        app.swipeUp()
        scrollTo(button("Start a new bill"))
        sleep(1)
        shot("z01-split-bottom")
        note("new bill reachable: \(button("Start a new bill").exists)")
        guard button("Start a new bill").exists else { return }
        note("new bill frame=\(button("Start a new bill").frame) add person frame=\(button("Add another person").frame)")
    }

    func testLargeText() {
        let big = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        for seed in ["bill", "name", "swipe", "checklist", "share", "split"] {
            launch(seed, extra: big)
            sleep(1)
            shot("a11y-\(seed)")
        }
        launch(nil, extra: big + ["-resetBill"])
        sleep(1)
        shot("a11y-home")
    }
}
