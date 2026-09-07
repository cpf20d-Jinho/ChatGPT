import XCTest

final class HIGFlowTests: XCTestCase {
    @MainActor
    func testRegistrationSearchAndPersistence() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        let name = "검증아동" + String(UUID().uuidString.prefix(6))
        let emptyAction = app.buttons["empty-add-child"]
        if emptyAction.waitForExistence(timeout: 5) {
            emptyAction.tap()
        } else {
            app.navigationBars.buttons["아동 추가"].firstMatch.tap()
        }
        let nameField = app.textFields["이름"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["추가"].isEnabled)
        nameField.tap()
        nameField.typeText(name)
        app.navigationBars.buttons["추가"].tap()
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 5))

        // A completed registration must survive an actual app process restart.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        if !search.isHittable { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("일치하지않는검색어")
        XCTAssertFalse(app.staticTexts[name].firstMatch.exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Search empty state"
        attachment.lifetime = .keepAlways
        add(attachment)
        search.buttons.firstMatch.tap()
        search.typeText(name)
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 5))
    }
}
