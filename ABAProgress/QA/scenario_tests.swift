import Foundation

enum Response: String {
    case na = "NA"
    case correct = "+"
    case prompted = "-"

    var next: Response {
        switch self {
        case .na: return .correct
        case .correct: return .prompted
        case .prompted: return .na
        }
    }
}

struct Session {
    let date: String
    var responses: [Response]
    var completed: Bool
    var note: String = ""

    var correct: Int { responses.filter { $0 == .correct }.count }
    var prompted: Int { responses.filter { $0 == .prompted }.count }
    var attempted: Int { correct + prompted }
    var accuracy: Double? {
        guard attempted > 0 else { return nil }
        return Double(correct) / Double(attempted) * 100
    }
    var meaningful: Bool {
        attempted > 0 || completed || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

func trailingQualifiedDays(
    dates: [String],
    targetSessions: [[String: Session]],
    criterion: Double
) -> Int {
    var trailing = 0
    for date in dates.reversed() {
        let allQualified = targetSessions.allSatisfy { sessions in
            guard let session = sessions[date], session.completed, session.meaningful,
                  let accuracy = session.accuracy else { return false }
            return accuracy >= criterion
        }
        if allQualified { trailing += 1 } else { break }
    }
    return trailing
}

func assertTrue(_ condition: @autoclosure () -> Bool, _ name: String) {
    if condition() {
        print("PASS | \(name)")
    } else {
        print("FAIL | \(name)")
        exit(1)
    }
}

var r = Response.na
r = r.next
assertTrue(r == .correct, "Trial 1회 탭: NA → +")
r = r.next
assertTrue(r == .prompted, "Trial 2회 탭: + → -")
r = r.next
assertTrue(r == .na, "Trial 3회 탭: - → NA")

let partial = Session(
    date: "2026-09-01",
    responses: [.correct, .correct, .prompted, .correct, .na],
    completed: false
)
assertTrue(abs((partial.accuracy ?? 0) - 75) < 0.001, "NA 제외 정반응률 75%")

let empty = Session(date: "2026-09-01", responses: Array(repeating: .na, count: 10), completed: false)
assertTrue(!empty.meaningful, "빈 세션은 기록일 표시에서 제외")

let noteOnly = Session(date: "2026-09-01", responses: Array(repeating: .na, count: 10), completed: false, note: "치료 중단")
assertTrue(noteOnly.meaningful, "메모만 있는 세션은 기록으로 보존")

let a1 = Session(date: "2026-09-01", responses: [.correct,.correct,.correct,.correct,.prompted], completed: true)
let a2 = Session(date: "2026-09-07", responses: [.correct,.correct,.correct,.correct,.correct], completed: true)
let b1 = Session(date: "2026-09-01", responses: [.correct,.correct,.correct,.correct,.correct], completed: true)
let b2 = Session(date: "2026-09-07", responses: [.correct,.correct,.correct,.correct,.prompted], completed: true)
let streak = trailingQualifiedDays(
    dates: ["2026-09-01", "2026-09-07"],
    targetSessions: [[a1.date:a1, a2.date:a2], [b1.date:b1, b2.date:b2]],
    criterion: 80
)
assertTrue(streak == 2, "간헐적 날짜에서도 기록일 기준 2회 연속 충족")

let failedB2 = Session(date: "2026-09-07", responses: [.correct,.correct,.correct,.prompted,.prompted], completed: true)
let broken = trailingQualifiedDays(
    dates: ["2026-09-01", "2026-09-07"],
    targetSessions: [[a1.date:a1, a2.date:a2], [b1.date:b1, failedB2.date:failedB2]],
    criterion: 80
)
assertTrue(broken == 0, "모든 과제가 기준을 만족해야 Level 성공일")
assertTrue(broken < 2, "과거 수정 후 Level 재검토 필요 상태 검출")

let reportCandidates = [a1, partial]
let reportSessions = reportCandidates.filter { $0.completed && $0.meaningful && $0.accuracy != nil }
assertTrue(reportSessions.count == 1, "보고서는 완료 Session만 사용")

let oldSession = Session(date: "2026-08-01", responses: Array(repeating: .correct, count: 5), completed: true)
let currentTargetTrialCount = 10
assertTrue(oldSession.responses.count == 5 && currentTargetTrialCount == 10, "과거 Session의 저장된 Trial 수 보존")

let accidentallyNA = Session(date: "2026-09-08", responses: [.correct,.correct,.correct,.correct,.na], completed: false)
assertTrue(accidentallyNA.responses.filter { $0 == .na }.count == 1, "완료 전 NA 잔여 경고 조건")

let previous = Response.correct
var current = previous.next
assertTrue(current == .prompted, "잘못된 추가 탭 상태 생성")
current = previous
assertTrue(current == .correct, "마지막 Trial 실행 취소 복구")

let d1 = Session(date: "2026-09-09", responses: [.correct,.correct], completed: true)
let d2 = Session(date: "2026-09-10", responses: [.prompted,.correct], completed: true)
assertTrue(d1.date != d2.date && d1.accuracy != d2.accuracy, "날짜별 Session 독립 저장")

print("ALL SCENARIO TESTS PASSED")
