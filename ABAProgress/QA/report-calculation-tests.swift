import Foundation
import SwiftData
import CryptoKit

@main struct ReportCalculationChecks {
    static func main() throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: scratch) }
        let deletedID = UUID(), otherID = UUID()
        let deleted = scratch.appendingPathComponent("\(deletedID)-2026-01-01.json")
        let kept = scratch.appendingPathComponent("\(otherID)-2026-01-01.json")
        try Data("{}".utf8).write(to: deleted); try Data("{}".utf8).write(to: kept)
        try ReportDraftStore.remove(childID: deletedID, directory: scratch)
        precondition(!FileManager.default.fileExists(atPath: deleted.path))
        precondition(FileManager.default.fileExists(atPath: kept.path), "Deleting one child must preserve other drafts")
        let calendar = Calendar.current
        func day(_ n: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 1, day: n))! }
        func session(_ n: Int, _ responses: [TrialResponse], completed: Bool = true) -> TherapySession {
            let s = TherapySession(date: day(n), note: "PRIVATE_NOTE", completed: completed)
            s.trials = responses.enumerated().map { TrialRecord(trialNumber: $0.offset + 1, response: $0.element) }
            return s
        }
        let child = ChildProfile(name: "PRIVATE_CHILD", birthDate: day(1), memo: "PRIVATE_MEMO")
        let program = TherapyProgram(name: "PRIVATE_PROGRAM", category: "PRIVATE_DOMAIN")
        let a = TherapyTarget(name: "PRIVATE_A"), b = TherapyTarget(name: "PRIVATE_B")
        a.listTitle = "PRIVATE_CAR"; b.listTitle = "PRIVATE_WRITING"
        a.startDate = day(1); b.startDate = day(1)
        a.sessions = [session(1, [.correct, .notApplicable]), session(3, [.correct]),
                      session(2, [.prompted], completed: false), session(4, [.notApplicable])]
        b.sessions = [session(1, [.correct,.correct,.correct,.correct,.prompted]),
                      session(3, [.correct,.correct,.correct,.correct,.prompted])]
        program.targets = [a,b]; child.programs = [program]
        var draft = ReportDraft(); draft.confirmedObservations = "PRIVATE_OBSERVATIONS"
        func report() -> ReportDocument {
            ReportDocument.build(child: child, start: day(1), end: day(4), programs: [program], draft: draft)
        }
        let first = report()
        precondition(first.goals[0].points.map(\.value) == [100,100], "NA/unfinished dates must be excluded")
        precondition(first.goals[0].points.map(\.date) == ["2026-01-01","2026-01-03"])
        precondition(first.goals[0].points.allSatisfy { $0.recordedCount == 1 && $0.applicableCount == 1 && $0.hasCompleteCoverage })
        precondition(first.incompleteCount == 1 && first.stoCount == 2 && first.masteredCount == 2)
        precondition(first.goals.count == 2 && first.goals[0].name == a.name)
        precondition(first.goals[0].learning["1"] == a.listTitle)
        precondition(first.goals[0].id == a.id.uuidString && first.goals[1].id == b.id.uuidString)
        b.sessions[1].trials[3].response = .prompted
        let changed = report()
        precondition(changed.goals[0].points.map(\.value) == [100,100] && changed.goals[1].points.map(\.value) == [80,60])
        precondition(changed.masteredCount == 1, "Other task results must not alter this List mastery")
        precondition(changed.fingerprint != first.fingerprint, "Historical edits must invalidate review")
        let encoded = try JSONEncoder().encode(ReportAIPayload(document: changed))
        let text = String(decoding: encoded, as: UTF8.self)
        precondition(!text.contains("PRIVATE") && !text.contains("2026"))
        let fields = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        precondition(Set(fields.keys) == ["version", "series"])
        precondition(fields["series"] as? [[Double]] == [[100,100],[80,60]])
        let restricted = ReportDocument.build(child: child, start: day(3), end: day(3), programs: [program], draft: draft)
        precondition(restricted.goals[0].points.count == 1 && restricted.goals[0].points[0].value == 100)

        let transitionProgram = TherapyProgram(name: "LEVEL_RESET")
        transitionProgram.levels[0].status = .completed
        let level2 = ProgramLevel(levelNumber: 2)
        transitionProgram.levels.append(level2)
        let l1 = TherapyTarget(name: "L1_TARGET", levelNumber: 1)
        l1.startDate = day(1); l1.status = .mastered
        l1.sessions = [session(1, [.correct]), session(2, [.correct])]
        let l2 = TherapyTarget(name: "L2_TARGET", levelNumber: 2)
        l2.startDate = day(3)
        l2.sessions = [session(3, [.prompted]), session(4, [.correct, .prompted])]
        transitionProgram.targets = [l1, l2]
        let transition = ReportDocument.build(
            child: child, start: day(1), end: day(4), programs: [transitionProgram], draft: draft
        ).goals
        precondition(transition[0].points.filter { $0.level == 1 }.map(\.value) == [100, 100])
        precondition(transition[1].points.filter { $0.level == 2 }.map(\.value) == [0, 50],
                     "L2 must restart from its own observations instead of carrying L1 accuracy")

        let partialProgram = TherapyProgram(name: "PARTIAL_COVERAGE")
        let p1 = TherapyTarget(name: "P1"), p2 = TherapyTarget(name: "P2")
        p1.startDate = day(1); p2.startDate = day(1)
        p1.sessions = [session(1, [.correct])]
        partialProgram.targets = [p1, p2]
        let partialPoint = ReportDocument.build(
            child: child, start: day(1), end: day(1), programs: [partialProgram], draft: draft
        ).goals[0].points[0]
        precondition(partialPoint.recordedCount == 1 && partialPoint.applicableCount == 1 && partialPoint.hasCompleteCoverage,
                     "An unrecorded different task must not dilute a recorded List")
        // Even identical task names and List numbers remain separate observations.
        b.name = a.name
        let sameNames = report()
        precondition(Set(sameNames.goals.map(\.id)).count == 2)
        precondition(sameNames.goals.first { $0.id == a.id.uuidString }!.points.map(\.value) == [100,100])
        precondition(sameNames.goals.first { $0.id == b.id.uuidString }!.points.map(\.value) == [80,60])
        draft.groupByProgram[program.id.uuidString] = "기존 분류"
        precondition(report().goals.allSatisfy { $0.group == "기존 분류" }, "Preserve saved legacy classifications")
        draft.groupByProgram[a.id.uuidString] = "List 분류"
        precondition(report().goals.first { $0.id == a.id.uuidString }!.group == "List 분류")
        precondition(targetRecordCount(program) == 6, "Reporting must not mutate records")
        draft.institution = "PRIVATE_INSTITUTION"
        draft.therapist = "PRIVATE_THERAPIST"
        draft.currentStatus = "가상 보고서"
        let editable = ReportEditableText(draft)
        let editableJSON = String(decoding: try JSONEncoder().encode(editable), as: UTF8.self)
        precondition(!editableJSON.contains("PRIVATE"), "Web text excludes profile, cover and local observations")
        let key = SymmetricKey(size: .bits256)
        let sealed = try ReportWebEditing.seal(editable, key: key)
        let reopened = try ReportWebEditing.open(sealed, key: key)
        precondition(reopened == editable)
        var remote = editable; remote.currentStatus = "웹 수정본"
        let applied = remote.applying(to: draft)
        precondition(applied.currentStatus == "웹 수정본" && applied.institution == draft.institution && applied.confirmedObservations == draft.confirmedObservations)
        do {
            _ = try ReportWebEditing.open(sealed, key: SymmetricKey(size: .bits256))
            fatalError("Wrong key must fail")
        } catch {}
        let invalid = try AES.GCM.seal(Data("{\"childName\":\"blocked\"}".utf8), using: key).combined!.base64EncodedString()
        do { _ = try ReportWebEditing.open(invalid, key: key); fatalError("Extra fields must fail") } catch {}
        let webSession = ReportWebSession(id: String(repeating: "a", count: 32), capability: String(repeating: "b", count: 64), key: key, expiresAt: Date(), baseURL: URL(string: "https://example.invalid/report")!, original: editable, fingerprint: "local-only")
        precondition(webSession.link.query == nil && webSession.link.fragment != nil)
        print("PASS: encrypted web edit boundary, wrong-key rejection, strict field whitelist and local profile preservation")
        print("PASS: actual models and report builder: NA, incomplete sessions, date range, every-target mastery, stale review and identity-free serializer")
        print("PASS: independent List series, no cross-task averaging, List titles and privacy")
    }

    static func targetRecordCount(_ program: TherapyProgram) -> Int {
        program.targets.flatMap(\.sessions).count
    }
}
