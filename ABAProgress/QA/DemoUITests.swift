import XCTest
import UIKit

final class DemoUITests: XCTestCase {
    @MainActor func testHelpAndWebConsent() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ABA_DEMO"] = "1"
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        func reveal(_ element: XCUIElement) {
            for _ in 0..<28 {
                if element.exists && element.isHittable { return }
                let above = element.exists && element.frame.maxY < app.navigationBars.firstMatch.frame.maxY + 12
                let a = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: above ? 0.35 : 0.65))
                let b = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: above ? 0.65 : 0.35))
                a.press(forDuration: 0.1, thenDragTo: b)
            }
            print(app.debugDescription); XCTFail("Missing \(element)")
        }
        func shot(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        func waitForOrientation(landscape: Bool) {
            let predicate = NSPredicate { _, _ in
                landscape ? app.frame.width > app.frame.height : app.frame.height > app.frame.width
            }
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
        }
        func openReportAndChild() {
            if app.tabBars.buttons["보고서"].exists { app.tabBars.buttons["보고서"].tap() }
            else { app.staticTexts["보고서"].firstMatch.tap() }
            let child = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "시연 아동")).firstMatch
            XCTAssertTrue(child.waitForExistence(timeout: 10)); child.tap()
        }
        openReportAndChild()
        XCTAssertTrue(app.staticTexts["데이터 선택"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["시연 아동 · 가상 데이터"].exists)

        let programHeading = app.staticTexts["프로그램 선택"]
        let selectedProgram = app.buttons.matching(
            NSPredicate(format: "label == %@ AND isSelected == true", "소근육 모방")
        ).firstMatch
        XCTAssertTrue(programHeading.exists)
        XCTAssertTrue(selectedProgram.exists)
        XCTAssertLessThanOrEqual(abs(programHeading.frame.minX - selectedProgram.frame.minX), 8)

        let institution = app.textFields["기관명"]
        let therapist = app.textFields["담당 치료사"]
        reveal(institution)
        XCTAssertTrue(therapist.exists)
        XCTAssertLessThanOrEqual(abs(institution.frame.minX - therapist.frame.minX), 2)
        XCTAssertLessThan(institution.frame.height, 52)

        if isPad {
            let appTitle = app.staticTexts["ABA Progress"]
            let workspace = app.staticTexts["워크스페이스"]
            XCTAssertTrue(appTitle.exists)
            XCTAssertTrue(workspace.exists)
            XCTAssertLessThanOrEqual(abs(appTitle.frame.minX - workspace.frame.minX), 8)
            XCTAssertGreaterThan(appTitle.frame.width, 80)
        }

        let learning = app.staticTexts["학습 내용"].firstMatch
        reveal(learning)
        XCTAssertTrue(learning.exists)
        XCTAssertFalse(app.staticTexts["레벨별 경과"].exists)
        shot("Report chart and learning content")

        let help = app.buttons["help-프로그램 선택"]
        reveal(help); shot("Report aligned controls"); help.tap()
        XCTAssertTrue(app.buttons["닫기"].waitForExistence(timeout: 5)); shot("Accessible help")
        app.buttons["닫기"].tap()
        let narrativesStep = app.buttons["2 서술"]
        XCTAssertTrue(narrativesStep.waitForExistence(timeout: 5)); narrativesStep.tap()
        let field = app.buttons["종합 현황"]
        reveal(field); shot("Report aligned narrative fields")
        if isPad {
            // Relaunch after changing the iPad's physical direction because a
            // running simulator can report a changed app frame before rotating.
            app.terminate(); XCUIDevice.shared.orientation = .landscapeLeft; app.launch()
            openReportAndChild()
            XCTAssertTrue(app.buttons["2 서술"].waitForExistence(timeout: 5)); app.buttons["2 서술"].tap()
            reveal(field); waitForOrientation(landscape: true)
        } else {
            XCUIDevice.shared.orientation = .landscapeLeft
            waitForOrientation(landscape: true)
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        shot("Report alternate orientation")
        if isPad {
            app.terminate(); XCUIDevice.shared.orientation = .portrait; app.launch()
            openReportAndChild(); waitForOrientation(landscape: false)
        } else {
            XCUIDevice.shared.orientation = .portrait
            waitForOrientation(landscape: false)
        }
        let reviewStep = app.buttons["3 검토"]
        XCTAssertTrue(reviewStep.waitForExistence(timeout: 5)); reviewStep.tap()
        let web = app.buttons["보고서 웹 편집"]
        reveal(web); web.tap()
        let agree = app.switches["전송 범위와 링크 접근 권한을 확인했으며 동의합니다"]
        reveal(agree)
        XCTAssertEqual(agree.value as? String, "0")
        XCTAssertFalse(app.buttons["동의하고 편집 링크 만들기"].isEnabled)
        shot("Web editing explicit consent default off")
        app.buttons["닫기"].firstMatch.tap()
    }

    @MainActor func testConsolidatedProgramAndEditEntryPoints() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ABA_DEMO"] = "1"
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        func shot(_ name: String) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        XCTAssertTrue(app.staticTexts["오늘 진행 현황"].firstMatch.waitForExistence(timeout: 10))
        shot("Today recordable programs only")
        let childrenTab = app.tabBars.buttons["아동"]
        XCTAssertTrue(childrenTab.waitForExistence(timeout: 5)); childrenTab.tap()
        let childRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "시연 아동")).firstMatch
        XCTAssertTrue(childRow.waitForExistence(timeout: 5)); childRow.tap()
        XCTAssertTrue(app.staticTexts["오늘 현황"].waitForExistence(timeout: 5))
        shot("Child consolidated program list")
        let editChild = app.buttons["아동 정보 수정"]
        XCTAssertTrue(editChild.exists); editChild.tap()
        XCTAssertTrue(app.navigationBars["아동 정보 수정"].waitForExistence(timeout: 5))
        shot("Child metadata editor")
    }

    @MainActor func testReportWalkthrough() throws {
        // Shared by the 11-inch iPad usage-video workflow and the standard UI walkthrough.
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ABA_DEMO"] = "1"
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()
        func pause() { Thread.sleep(forTimeInterval: 2) }
        func reveal(_ element: XCUIElement) {
            for _ in 0..<24 {
                if element.exists && element.isHittable { return }
                let top = app.navigationBars.firstMatch.frame.maxY + 12
                let above = element.exists && element.frame.height > 0 && element.frame.maxY <= top
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.35 : 0.58))
                let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.58 : 0.35))
                start.press(forDuration: 0.1, thenDragTo: end)
            }
            print(app.debugDescription)
            XCTFail("Missing UI element: \(element)")
        }
        func tap(_ e: XCUIElement) { reveal(e); e.tap(); pause() }
        pause()
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "소근육 모방")).firstMatch)
        let trial = app.buttons["trial-1"]
        reveal(trial)
        for i in 1...8 {
            let b = app.buttons["trial-\(i)"]
            reveal(b); b.tap(); Thread.sleep(forTimeInterval: 0.4)
        }
        for i in 9...10 {
            let b = app.buttons["trial-\(i)"]
            reveal(b); b.tap(); b.tap()
        }
        pause()
        tap(app.buttons["기록 완료"])
        if app.buttons["완료 처리"].waitForExistence(timeout: 2) { tap(app.buttons["완료 처리"]) }
        if app.tabBars.buttons["보고서"].exists {
            tap(app.tabBars.buttons["보고서"])
        } else {
            tap(app.staticTexts["보고서"].firstMatch)
        }
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "시연 아동")).firstMatch)
        pause()
        tap(app.buttons["2 서술"])
        func write(_ title: String, _ text: String) {
            let entry = app.buttons[title]
            reveal(entry); entry.tap()
            let editor = app.textViews[title]
            XCTAssertTrue(editor.waitForExistence(timeout: 5)); editor.tap(); editor.typeText(text)
            let done = app.buttons["완료"]
            XCTAssertTrue(done.waitForExistence(timeout: 5)); done.tap(); pause()
        }
        write("종합 현황", "가상 데이터 시연입니다. 손뼉 치기의 정반응률은 초기 40%에서 최근 80%로 변화했습니다.")
        write("강점과 주요 변화", "기록일별 정반응률이 점진적으로 증가했습니다. 이 문장은 치료사가 직접 작성한 시연 문구입니다.")
        write("치료사 종합 소견", "시연용 수동 소견입니다. 다음 회기에서도 수행을 관찰합니다.")
        write("가정에서 함께 하기", "시연용 안내: 놀이 중 손뼉 치기 활동을 함께 합니다.")
        write("다음 목표", "시연용 목표: 서로 다른 상황에서 반응을 기록합니다.")
        tap(app.buttons["3 검토"])
        tap(app.switches["집계 기준, 그래프와 서술 내용을 검토했습니다"])
        tap(app.buttons["기본 양식 PDF 생성"])
        let share = app.buttons["PDF 공유 / 저장"]
        XCTAssertTrue(share.waitForExistence(timeout: 40))
        tap(share)
        pause(); pause()
        // The real system share sheet is the final step. No external recipient is contacted.
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "PDF ready to share"; shot.lifetime = .keepAlways; add(shot)
    }

    @MainActor func testEightProgramsAndHistoricalRecordReview() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ABA_EIGHT_PROGRAM_QA"] = "1"
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        app.launch()

        func reveal(_ element: XCUIElement) {
            for _ in 0..<32 {
                if element.exists && element.isHittable { return }
                app.swipeUp()
            }
            XCTFail("화면에서 찾을 수 없음: \(element)")
        }
        func openDestination(_ title: String) {
            let tab = app.tabBars.buttons[title]
            if tab.exists { tab.tap() }
            else { app.staticTexts[title].firstMatch.tap() }
        }

        let names = ["소근육 모방", "대근육 모방", "언어 모방", "수용 언어", "표현 언어", "시각 수행", "놀이 기술", "사회성 기술"]
        openDestination("아동")
        let child = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8개 프로그램 시연 아동")).firstMatch
        XCTAssertTrue(child.waitForExistence(timeout: 10)); child.tap()

        for name in names {
            let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
            reveal(row); XCTAssertTrue(row.isHittable); row.tap()
            XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5), "\(name) 관리 화면 진입 실패")
            XCTAssertTrue(app.staticTexts["기록 날짜"].exists)
            app.navigationBars.buttons.firstMatch.tap()
        }

        // Restart between independent navigation scenarios. On iPad a
        // NavigationSplitView can retain the program detail path even after
        // selecting another sidebar destination during UI automation.
        app.terminate(); app.launch()
        openDestination("보고서")
        let reportChild = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8개 프로그램 시연 아동")).firstMatch
        XCTAssertTrue(reportChild.waitForExistence(timeout: 5)); reportChild.tap()
        for name in names {
            let chip = app.buttons[name]
            if !chip.exists || !chip.isHittable {
                app.swipeLeft()
            }
            XCTAssertTrue(chip.waitForExistence(timeout: 3), "보고서 프로그램 선택 누락: \(name)")
        }

        app.terminate(); app.launch()
        openDestination("기록")
        let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        let components = Calendar.current.dateComponents([.year, .month, .day], from: oldDate)
        let oldDateIdentifier = String(format: "history-day-%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        let day = app.buttons[oldDateIdentifier]
        XCTAssertTrue(day.waitForExistence(timeout: 5)); day.tap()
        let historyChild = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "8개 프로그램 시연 아동")).firstMatch
        XCTAssertTrue(historyChild.waitForExistence(timeout: 5)); historyChild.tap()
        XCTAssertTrue(app.staticTexts["소근육 모방"].waitForExistence(timeout: 5))
        let target = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "손뼉 치기")).firstMatch
        XCTAssertTrue(target.exists); target.tap()
        XCTAssertTrue(app.staticTexts["과거 기록 수정"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["trial-1"].exists)
    }

}

