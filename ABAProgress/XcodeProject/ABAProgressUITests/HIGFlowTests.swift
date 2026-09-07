import XCTest

final class HIGFlowTests: XCTestCase {
    @MainActor
    private func childRow(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

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
        XCTAssertTrue(childRow(app, name).waitForExistence(timeout: 5))

        // A completed registration must survive an actual app process restart.
        app.terminate()
        app.launch()
        XCTAssertTrue(childRow(app, name).waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        if !search.isHittable { app.swipeDown() }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("일치하지않는검색어")
        XCTAssertFalse(childRow(app, name).exists)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Search empty state"
        attachment.lifetime = .keepAlways
        add(attachment)
        search.buttons.firstMatch.tap()
        search.typeText(name)
        XCTAssertTrue(childRow(app, name).waitForExistence(timeout: 5))
    }

    @MainActor
    func testTrialControlsAndSavedResponses() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        let name = "HIG-" + String(UUID().uuidString.prefix(6))
        XCTAssertTrue(app.navigationBars.buttons["아동 추가"].firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons["아동 추가"].firstMatch.tap()
        app.textFields["이름"].tap()
        app.textFields["이름"].typeText(name)
        app.navigationBars.buttons["추가"].tap()
        XCTAssertTrue(childRow(app, name).waitForExistence(timeout: 5))
        childRow(app, name).tap()
        let addProgram = app.buttons["empty-add-program"]
        if !addProgram.isHittable { app.swipeUp() }
        XCTAssertTrue(addProgram.waitForExistence(timeout: 5))
        addProgram.tap()
        app.textFields["프로그램명"].tap()
        app.textFields["프로그램명"].typeText("HIG Program")
        app.navigationBars.buttons["추가"].tap()
        XCTAssertTrue(app.staticTexts["HIG Program"].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts["HIG Program"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars.buttons["과제 추가"].firstMatch.waitForExistence(timeout: 5))
        app.navigationBars.buttons["과제 추가"].firstMatch.tap()
        app.textFields["과제명"].tap()
        app.textFields["과제명"].typeText("HIG Target")
        app.navigationBars.buttons["추가"].tap()
        let trial = app.buttons["trial-1"]
        for _ in 0..<5 {
            if trial.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(trial.isHittable)
        XCTAssertGreaterThanOrEqual(trial.frame.height, 44)
        XCTAssertGreaterThanOrEqual(trial.frame.width, 44)
        XCTAssertEqual(trial.value as? String, "미기록 또는 미시행")
        trial.tap()
        XCTAssertEqual(trial.value as? String, "정반응")
        trial.tap()
        XCTAssertEqual(trial.value as? String, "촉구반응")
        trial.tap()
        XCTAssertEqual(trial.value as? String, "미기록 또는 미시행")
        trial.tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Trial controls"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        XCTAssertTrue(childRow(app, name).waitForExistence(timeout: 5))
        childRow(app, name).tap()
        app.staticTexts["HIG Program"].firstMatch.tap()
        for _ in 0..<5 {
            if trial.isHittable { break }
            app.swipeUp()
        }
        XCTAssertEqual(trial.value as? String, "정반응")
    }
}
