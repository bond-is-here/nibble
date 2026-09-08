import XCTest

/// These journeys use the real SwiftUI app and its protected on-device JSON store.
/// No live barcode service, credentials, or customer diary is used.
@MainActor
final class NibbleUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["NIBBLE_UI_TEST_ID"] = UUID().uuidString
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        tap(app.buttons["Just start logging"])
        expectCalories("0")
    }

    override func tearDownWithError() throws {
        if let app {
            capture(name)
            app.terminate()
        }
    }

    func testQuickLoggingPersistsAndCanBeDeletedAndUndone() {
        tap(app.buttons["Add food"])
        tap(app.buttons["Quick add Greek yogurt, 1 cup"])
        expectCalories("150")
        relaunch()
        expectCalories("150")

        tap(app.buttons["Options for Greek yogurt"])
        tap(app.buttons["Delete"])
        XCTAssertFalse(app.buttons["Edit Greek yogurt, 150 calories"].exists)
        // Undo is intentionally time-limited; exercise it before navigating away.
        tap(app.buttons["Undo"])
        expectCalories("150", towardTop: true)
        relaunch()
        expectCalories("150")
    }

    func testPortionPreviewReplacesExistingEntryAndUndoRestoresIt() {
        tap(app.buttons["Add food"])
        tap(app.buttons["Choose Greek yogurt, 1 cup, 150 calories"])
        XCTAssertTrue(app.buttons["portion.save"].isHittable, "Saving must be available without scrolling the portion screen")
        tap(app.buttons["2 servings"])
        expectLabel(app.staticTexts["macro.preview.after.protein"], "40 g")
        expectLabel(app.staticTexts["macro.preview.after.carbs"], "16 g")
        expectLabel(app.staticTexts["macro.preview.after.fat"], "8 g")
        capture("Two-serving macro preview")
        tap(app.buttons["portion.save"])
        expectCalories("300")

        tap(app.buttons["Edit Greek yogurt, 300 calories"])
        tap(app.buttons["0.5 servings"])
        expectLabel(app.staticTexts["macro.preview.after.protein"], "10 g")
        expectLabel(app.staticTexts["macro.preview.after.carbs"], "4 g")
        expectLabel(app.staticTexts["macro.preview.after.fat"], "2 g")
        tap(app.buttons["portion.save"])
        XCTAssertTrue(app.buttons["Edit Greek yogurt, 75 calories"].exists)
        tap(app.buttons["Undo"])
        expectCalories("300", towardTop: true)
        relaunch()
        expectCalories("300")
    }

    func testManualTargetAndCustomMacroMixSurviveRelaunch() {
        tap(app.buttons["You"])
        tap(app.buttons["Tune my plan"])
        tap(app.buttons["Set my own"])
        replace(app.textFields["Daily calorie target"], with: "2000.5")
        tap(app.buttons["Save my plan"])
        tap(app.buttons["Tune my plan"])
        XCTAssertEqual(app.textFields["Daily calorie target"].value as? String, "2000.5")
        tap(app.buttons["Close setup"], towardTop: true)

        tap(app.buttons["macro.edit"])
        replace(app.textFields["Protein target percentage"], with: "30")
        reveal(app.buttons["Save my mix"])
        XCTAssertFalse(app.buttons["Save my mix"].isEnabled, "A 105% split must not save")
        replace(app.textFields["Carbs target percentage"], with: "40", towardTop: true)
        tap(app.buttons["Save my mix"])
        XCTAssertEqual(app.buttons["macro.edit"].label, "Tune macro mix · 30/40/30")
        capture("Saved custom macro mix")

        relaunch()
        tap(app.buttons["You"])
        tap(app.buttons["Tune my plan"])
        XCTAssertEqual(app.textFields["Daily calorie target"].value as? String, "2000.5")
        tap(app.buttons["Close setup"], towardTop: true)
        tap(app.buttons["macro.edit"])
        XCTAssertEqual(app.textFields["Protein target percentage"].value as? String, "30")
        XCTAssertEqual(app.textFields["Carbs target percentage"].value as? String, "40")
        XCTAssertEqual(app.textFields["Fat target percentage"].value as? String, "30")
        tap(app.buttons["Reset draft to 25 / 45 / 30"])
        tap(app.buttons["Cancel macro changes"], towardTop: true)
        XCTAssertEqual(app.buttons["macro.edit"].label, "Tune macro mix · 30/40/30", "Cancel must discard the reset draft")
    }

    func testCalorieOnlyFoodDoesNotInventMacros() {
        tap(app.buttons["Add food"])
        tap(app.buttons["Enter calories or create a food"])
        replace(app.textFields["What did you have?"], with: "Mystery soup")
        replace(app.textFields["Calories"], with: "275")
        tap(app.buttons["Choose a portion"])
        expectLabel(app.staticTexts["macro.preview.after.protein"], "—")
        expectLabel(app.staticTexts["macro.preview.after.carbs"], "—")
        expectLabel(app.staticTexts["macro.preview.after.fat"], "—")
        tap(app.buttons["portion.save"])
        expectCalories("275")
        tap(app.buttons["Explore your macro mix"])
        reveal(app.staticTexts["A few pieces are missing."])
        XCTAssertTrue(app.staticTexts["A few pieces are missing."].exists)
        capture("Calorie-only macros stay unknown")
        tap(app.buttons["Close macro mix"], towardTop: true)
        relaunch()
        expectCalories("275")
        tap(app.buttons["Add food"])
        tap(app.buttons["Recent"])
        XCTAssertTrue(app.buttons["Choose Mystery soup, 1 serving, 275 calories"].waitForExistence(timeout: 5))
    }

    func testEstimateValidatesAgeAndPreservesMetricProfile() {
        tap(app.buttons["You"])
        tap(app.buttons["Tune my plan"])
        tap(app.buttons["Estimate for me"])
        tap(app.buttons["kg / cm"])
        replace(app.textFields["Height"], with: "170")
        replace(app.textFields["Weight"], with: "70")
        replace(app.textFields["Age"], with: "17")
        tap(app.buttons["Save my plan"])
        let validation = app.staticTexts["Check your details: age 18–100, height 120–230 cm (47–90 in), and weight 35–300 kg (77–661 lb)."]
        XCTAssertTrue(validation.waitForExistence(timeout: 5), "Underage estimates must be rejected")
        replace(app.textFields["Age"], with: "30", towardTop: true)
        tap(app.buttons["Save my plan"])
        // The midpoint formula at 170 cm / 70 kg / 30 years, light activity,
        // and maintenance rounds to 2,100 calories. No body data is sent anywhere.
        expectLabel(app.staticTexts["plan.calories"], "2,100")
        capture("Estimated plan from metric profile")
        relaunch()
        tap(app.buttons["You"])
        expectLabel(app.staticTexts["plan.calories"], "2,100")
        tap(app.buttons["Tune my plan"])
        XCTAssertEqual(app.textFields["Height"].value as? String, "170")
        XCTAssertEqual(app.textFields["Weight"].value as? String, "70")
        XCTAssertEqual(app.textFields["Age"].value as? String, "30")
        XCTAssertTrue(app.buttons["kg / cm"].isSelected)
    }

    func testZeroCalorieLoggedDayShowsZeroAverage() {
        tap(app.buttons["Patterns"])
        expectLabel(app.staticTexts["patterns.average"], "—")
        tap(app.buttons["Add food"])
        tap(app.buttons["Enter calories or create a food"])
        replace(app.textFields["What did you have?"], with: "Plain water")
        replace(app.textFields["Calories"], with: "0")
        tap(app.buttons["Choose a portion"])
        tap(app.buttons["portion.save"])
        // A logged zero is real data; only a completely unlogged week shows a dash.
        expectLabel(app.staticTexts["patterns.average"], "0")
        capture("Zero-calorie day is not missing data")
        relaunch()
        tap(app.buttons["Patterns"])
        expectLabel(app.staticTexts["patterns.average"], "0")
    }

    func testInvalidBarcodeFallsBackToLabelWithMilliliterMacros() {
        tap(app.buttons["Add food"])
        tap(app.buttons["Scan barcode"])
        replace(app.textFields["Barcode number"], with: "123")
        tap(app.buttons["Look up barcode"])
        // Invalid GTINs fail locally, so this journey never contacts the provider.
        tap(app.buttons["Enter the label instead"])
        replace(app.textFields["What did you have?"], with: "Sample juice")
        replace(app.textFields["Calories"], with: "50")
        replace(app.textFields["Portion"], with: "per 100 ml")
        tap(app.switches["Add macros"])
        replace(app.textFields["Protein"], with: "1")
        replace(app.textFields["Carbs"], with: "10")
        replace(app.textFields["Fat"], with: "0")
        tap(app.buttons["Choose a portion"])
        tap(app.buttons["200 ml"])
        expectLabel(app.staticTexts["macro.preview.after.protein"], "2 g")
        expectLabel(app.staticTexts["macro.preview.after.carbs"], "20 g")
        expectLabel(app.staticTexts["macro.preview.after.fat"], "0 g")
        capture("Label fallback with 200 ml portion")
        tap(app.buttons["portion.save"])
        expectCalories("100")
        relaunch()
        expectCalories("100")
        tap(app.buttons["Add food"])
        tap(app.buttons["Recent"])
        tap(app.buttons["Favorite Sample juice"])
        tap(app.buttons["Favorites"])
        XCTAssertTrue(app.buttons["Unfavorite Sample juice"].exists)
        tap(app.buttons["Quick add Sample juice, per 100 ml"])
        expectCalories("150")
    }

    func testLargestTextCanOnboardLogAndExploreMacros() throws {
        let ordinaryAddHeight = app.buttons["Add food"].frame.height
        app.terminate()
        app.launchEnvironment["NIBBLE_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["NIBBLE_UI_TEST_TEXT_SIZE"] = "accessibility5"
        app.launch()
        capture("Largest text onboarding")
        tap(app.buttons["Just start logging"])
        expectCalories("0")
        XCTAssertGreaterThan(app.buttons["Add food"].frame.height, ordinaryAddHeight, "The launch must actually exercise scaled text")
        capture("Largest text diary")
        tap(app.buttons["Add food"])
        tap(app.buttons["Choose Greek yogurt, 1 cup, 150 calories"])
        XCTAssertTrue(app.buttons["portion.save"].isHittable, "Save stays reachable at the largest text size")
        capture("Largest text portion and visible save")
        tap(app.buttons["portion.save"])
        expectCalories("150")
        tap(app.buttons["Explore your macro mix"])
        capture("Largest text Macro Mix")
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription, .contrast])
        tap(app.buttons["Close macro mix"], towardTop: true)
        relaunch()
        expectCalories("150")
    }

    func testSlowBarcodeCannotReplaceManualFoodDraft() {
        launchWithBarcodeFixture("delayed-product")
        tap(app.buttons["Add food"])
        tap(app.buttons["Scan barcode"])
        replace(app.textFields["Barcode number"], with: "3017620422003")
        tap(app.buttons["Look up barcode"])
        XCTAssertFalse(app.buttons["Look up barcode"].isEnabled, "The fake request must be in flight")
        tap(app.buttons["Enter calories or create a food"], towardTop: true)
        let cancel = app.buttons["Cancel custom food"]
        XCTAssertTrue(cancel.exists)
        replace(app.textFields["What did you have?"], with: "My manual snack")

        // Wait beyond the transport's ten-second response, rather than passing as
        // soon as the form appears. The original bug replaces it with the product.
        let interrupted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: cancel)
        interrupted.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [interrupted], timeout: 12), .completed)
        XCTAssertEqual(app.textFields["What did you have?"].value as? String, "My manual snack")
        capture("Slow barcode leaves manual draft intact")
        tap(cancel, towardTop: true)
        reveal(app.buttons["Look up barcode"])
        XCTAssertTrue(app.buttons["Look up barcode"].isEnabled, "Cancelling clears the old loading state")
    }

    func testBarcodeProductPersistsAndCanBeReusedOffline() {
        launchWithBarcodeFixture("delayed-product")
        tap(app.buttons["Add food"])
        tap(app.buttons["Scan barcode"])
        replace(app.textFields["Barcode number"], with: "3017620422003")
        tap(app.buttons["Look up barcode"])
        XCTAssertTrue(app.staticTexts["Delayed test drink"].waitForExistence(timeout: 20), "The delayed transport must deliver through the real decoder")
        XCTAssertTrue(app.buttons["portion.save"].isHittable)
        expectLabel(app.staticTexts["macro.preview.after.protein"], "1 g")
        expectLabel(app.staticTexts["macro.preview.after.carbs"], "10 g")
        expectLabel(app.staticTexts["macro.preview.after.fat"], "0 g")
        capture("Barcode product has known per-100-ml macros")
        tap(app.buttons["portion.save"])
        expectCalories("50")

        // Same protected diary, but all new requests now fail deterministically.
        app.launchEnvironment["NIBBLE_UI_TEST_BARCODE"] = "offline"
        relaunch()
        expectCalories("50")
        tap(app.buttons["Add food"])
        tap(app.buttons["Scan barcode"])
        replace(app.textFields["Barcode number"], with: "3017620422003")
        tap(app.buttons["Look up barcode"])
        reveal(app.staticTexts["You appear to be offline. Check your connection and try again."])
        XCTAssertTrue(app.buttons["Enter the label instead"].exists)
        capture("Offline lookup keeps manual fallback available")
        tap(app.buttons["Find a food"], towardTop: true)
        tap(app.buttons["Recent"])
        tap(app.buttons["Favorite Delayed test drink"])
        tap(app.buttons["Favorites"])
        tap(app.buttons["Quick add Delayed test drink, per 100 ml"])
        expectCalories("100")
        relaunch()
        expectCalories("100")
    }

    private func launchWithBarcodeFixture(_ fixture: String) {
        app.terminate()
        app.launchEnvironment["NIBBLE_UI_TEST_ID"] = UUID().uuidString
        app.launchEnvironment["NIBBLE_UI_TEST_BARCODE"] = fixture
        app.launch()
        tap(app.buttons["Just start logging"])
    }

    private func relaunch() {
        app.terminate()
        // Keep the same test ID: a new process must load the same saved diary.
        app.launch()
        XCTAssertTrue(app.buttons["Add food"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Just start logging"].exists)
    }

    private func capture(_ title: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = title
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func expectCalories(_ value: String, towardTop: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        expectLabel(app.staticTexts["diary.calories"], value, towardTop: towardTop, file: file, line: line)
    }

    private func expectLabel(_ element: XCUIElement, _ value: String, towardTop: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        reveal(element, towardTop: towardTop, file: file, line: line)
        let expected = NSPredicate(format: "label == %@", value)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: expected, object: element)], timeout: 5)
        XCTAssertEqual(result, .completed, "Expected \(value), found \(element.label)", file: file, line: line)
    }

    private func replace(_ field: XCUIElement, with value: String, towardTop: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        reveal(field, towardTop: towardTop, file: file, line: line)
        field.tap()
        // A right-aligned field can retain an insertion point before its text,
        // even after tapping the trailing edge. Select its contents explicitly;
        // deleting at an assumed caret position silently left "25" behind.
        let text = field.value as? String ?? ""
        if field.label.hasSuffix("target percentage") {
            field.press(forDuration: 1.2)
            let selectAll = app.descendants(matching: .any).matching(identifier: "Select All").firstMatch
            XCTAssertTrue(selectAll.waitForExistence(timeout: 3), "The percentage must be selected before replacement", file: file, line: line)
            selectAll.tap()
            field.typeText(value)
        } else {
            if !text.isEmpty {
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
            }
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count) + value)
        }
        // Compact simulators can deliver the final key event a beat after
        // typeText returns. If the field contains a partial prefix, append the
        // missing suffix; otherwise retry the full replacement from a fresh
        // caret position before reporting a real failure.
        for _ in 0..<2 {
            let typed = field.value as? String ?? ""
            if typed == value { break }
            field.tap()
            if value.hasPrefix(typed) {
                field.typeText(String(value.dropFirst(typed.count)))
            } else {
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count) + value)
            }
            _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: field)], timeout: 1)
        }
        XCTAssertEqual(field.value as? String, value, file: file, line: line)
    }

    private func tap(_ element: XCUIElement, towardTop: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        reveal(element, towardTop: towardTop, file: file, line: line)
        XCTAssertTrue(element.isEnabled, "Control must be enabled", file: file, line: line)
        element.tap()
    }

    private func reveal(_ element: XCUIElement, towardTop: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        if !element.exists { _ = element.waitForExistence(timeout: 3) }
        if element.exists && element.isHittable { return }

        // Sheets can leave the underlying tab's ScrollView in the hierarchy.
        // Drive the deepest scroll view that contains the target's actual
        // element type and accessibility identity. XCTest does not expose a
        // parent pointer for XCUIElement, and SwiftUI can reuse labels such as
        // "0" across unrelated text and text fields.
        let scroll = app.scrollViews.allElementsBoundByIndex.reversed().first { candidate in
            candidate.descendants(matching: element.elementType).allElementsBoundByIndex.contains { descendant in
                if !element.identifier.isEmpty { return descendant.identifier == element.identifier }
                return descendant.label == element.label
            }
        }
            ?? app.scrollViews.firstMatch
        guard scroll.exists else {
            XCTAssertTrue(false, "Control is not reachable: no scroll view for \(element)", file: file, line: line)
            return
        }

        // Re-evaluate after every short drag. SwiftUI can report a stale frame
        // while a sheet or compact ScrollView is settling, so a one-shot
        // direction can pull the sheet away from the control. Keep gestures in
        // the middle of the viewport to avoid starting a sheet dismissal.
        for _ in 0..<20 {
            if element.exists && element.isHittable { return }
            let targetFrame = element.frame
            let viewport = scroll.frame.isEmpty ? app.windows.firstMatch.frame : scroll.frame
            let targetIsAbove = !targetFrame.isEmpty && targetFrame.maxY <= viewport.minY + 4
            let targetIsBelow = !targetFrame.isEmpty && targetFrame.minY >= viewport.maxY - 4
            let moveTowardTop = targetIsAbove || (!targetIsBelow && towardTop)
            let startY: CGFloat = moveTowardTop ? 0.40 : 0.60
            let endY: CGFloat = moveTowardTop ? 0.60 : 0.40
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        XCTAssertTrue(element.exists && element.isHittable, "Control is not reachable: \(element)\n\(app.debugDescription)", file: file, line: line)
    }
}
