import XCTest

final class LendSharkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    @MainActor
    func testLaunchAndTabSwitching() throws {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))

        app.tabBars.buttons["The Ledger"].tap()
        XCTAssertTrue(app.staticTexts["THE LEDGER"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Quick Add"].tap()
        XCTAssertTrue(app.staticTexts["QUICK ADD"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Due Today"].tap()
        XCTAssertTrue(app.staticTexts["TODAY'S COLLECTIONS"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Collections"].tap()
        XCTAssertTrue(app.staticTexts["COLLECTIONS"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Tools"].tap()
        XCTAssertTrue(app.staticTexts["TOOLS"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testQuickAddCreatesLedgerEntry() throws {
        app.tabBars.buttons["Quick Add"].tap()

        let input = app.textFields["lendshark.quickadd.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("lent 50 to john")

        let addButton = app.buttons["lendshark.quickadd.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        app.tabBars.buttons["The Ledger"].tap()
        XCTAssertTrue(app.staticTexts["JOHN"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testClearAllDataRemovesEntries() throws {
        // Create an entry
        app.tabBars.buttons["Quick Add"].tap()

        let input = app.textFields["lendshark.quickadd.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText("lent 50 to john")

        let addButton = app.buttons["lendshark.quickadd.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        // Confirm it shows in ledger
        app.tabBars.buttons["The Ledger"].tap()
        XCTAssertTrue(app.staticTexts["JOHN"].waitForExistence(timeout: 5))

        // Clear all data in Settings
        app.tabBars.buttons["Tools"].tap()
        XCTAssertTrue(app.staticTexts["TOOLS"].waitForExistence(timeout: 5))

        let settingsRow = app.staticTexts["lendshark.tools.settings"]
        XCTAssertTrue(settingsRow.waitForExistence(timeout: 5))
        settingsRow.tap()

        let clearAllData = app.buttons["lendshark.settings.clearAllData"]
        for _ in 0..<10 where !clearAllData.exists {
            app.swipeUp()
        }
        XCTAssertTrue(clearAllData.waitForExistence(timeout: 5))
        clearAllData.tap()

        let alert = app.alerts["Clear All Data"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Clear"].tap()

        // Verify entry is gone
        app.tabBars.buttons["The Ledger"].tap()
        XCTAssertFalse(app.staticTexts["JOHN"].waitForExistence(timeout: 2))
    }
}
