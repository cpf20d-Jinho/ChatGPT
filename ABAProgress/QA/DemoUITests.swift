import XCTest
import UIKit

final class DemoUITests: XCTestCase {
    @MainActor func testHelpAndWebConsent() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["ABA_DEMO"] = "1"
        app.launchArguments = ["-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"]
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        if isPad { XCUIDevice.shared.orientation = .landscapeLeft }
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
        let help = app.buttons["help-프로그램 선택"]
        reveal(help); shot("Report aligned controls"); help.tap()
        XCTAssertTrue(app.buttons["닫기"].waitForExistence(timeout: 5)); shot("Accessible help")
        app.buttons["닫기"].tap()
        let narrativesStep = app.buttons["2 서술"]
        XCTAssertTrue(narrativesStep.waitForExistence(timeout: 5)); narrativesStep.tap()
        let field = app.textFields["종합 현황 · AI 초안 또는 직접 작성"]
        reveal(field); shot("Report aligned narrative fields")
        if isPad {
            // A running iPad simulator can report a portrait app frame while the
            // physical screen remains landscape. Relaunch to capture true pixels.
            app.terminate(); XCUIDevice.shared.orientation = .portrait; app.launch()
            openReportAndChild()
            XCTAssertTrue(app.buttons["2 서술"].waitForExistence(timeout: 5)); app.buttons["2 서술"].tap()
            reveal(field); waitForOrientation(landscape: false)
        } else {
            XCUIDevice.shared.orientation = .landscapeLeft
            waitForOrientation(landscape: true)
        }
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        shot("Report alternate orientation")
        if isPad {
            app.terminate(); XCUIDevice.shared.orientation = .landscapeLeft; app.launch()
            openReportAndChild(); waitForOrientation(landscape: true)
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
        tap(app.tabBars.buttons["보고서"])
        tap(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "시연 아동")).firstMatch)
        pause()
        tap(app.buttons["2 서술"])
        func write(_ title: String, _ text: String) {
            let field = app.textFields[title]
            reveal(field); field.tap(); field.typeText(text)
            let done = app.buttons["입력 완료"]
            XCTAssertTrue(done.waitForExistence(timeout: 5))
            done.tap(); pause()
        }
        write("종합 현황 · AI 초안 또는 직접 작성", "가상 데이터 시연입니다. 손뼉 치기의 정반응률은 초기 40%에서 최근 80%로 변화했습니다.")
        write("이번 기간의 강점과 주요 변화 · AI 초안 또는 직접 작성", "기록일별 정반응률이 점진적으로 증가했습니다. 이 문장은 치료사가 직접 작성한 시연 문구입니다.")
        write("치료사 종합 소견", "시연용 수동 소견입니다. 다음 회기에서도 수행을 관찰합니다.")
        write("가정에서 함께 하기", "시연용 안내: 놀이 중 손뼉 치기 활동을 함께 합니다.")
        write("다음 목표", "시연용 목표: 서로 다른 상황에서 반응을 기록합니다.")
        tap(app.buttons["3 검토"])
        tap(app.switches["집계 기준·그래프·서술 내용을 검토했습니다"])
        tap(app.buttons["기본 양식 PDF 생성"])
        let share = app.buttons["PDF 공유 / 저장"]
        XCTAssertTrue(share.waitForExistence(timeout: 40))
        tap(share)
        pause(); pause()
        // The real system share sheet is the final step. No external recipient is contacted.
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); shot.name = "PDF ready to share"; shot.lifetime = .keepAlways; add(shot)
    }
}
