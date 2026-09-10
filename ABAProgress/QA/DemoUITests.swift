import XCTest

final class DemoUITests: XCTestCase {
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
                app.swipeUp(velocity: .slow)
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
        func write(_ title: String, _ text: String) {
            let field = app.descendants(matching: .any).matching(identifier: title).firstMatch
            reveal(field); field.tap(); field.typeText(text)
            app.swipeUp(velocity: .slow); pause()
        }
        write("종합 현황 · AI 초안 또는 직접 작성", "가상 데이터 시연입니다. 손뼉 치기의 정반응률은 초기 40%에서 최근 80%로 변화했습니다.")
        write("이번 기간의 강점과 주요 변화 · AI 초안 또는 직접 작성", "기록일별 정반응률이 점진적으로 증가했습니다. 이 문장은 치료사가 직접 작성한 시연 문구입니다.")
        write("치료사 종합 소견", "시연용 수동 소견입니다. 다음 회기에서도 수행을 관찰합니다.")
        write("가정에서 함께 하기", "시연용 안내: 놀이 중 손뼉 치기 활동을 함께 합니다.")
        write("다음 목표", "시연용 목표: 서로 다른 상황에서 반응을 기록합니다.")
        tap(app.switches["집계 기준·그래프·서술 내용을 검토했습니다"])
        tap(app.buttons["기본 양식 PDF 생성"])
        let share = app.buttons["PDF 공유 / 저장"]
        XCTAssertTrue(share.waitForExistence(timeout: 40))
        tap(share)
        pause(); pause()
        // The real system share sheet is the final step. No external recipient is contacted.
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "PDF ready to share"; shot.lifetime = .keepAlways; add(shot)
    }
}
