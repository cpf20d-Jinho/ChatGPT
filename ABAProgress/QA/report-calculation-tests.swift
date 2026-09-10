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
        precondition(first.goals[0].points.map(\.value) == [90,90], "NA/unfinished dates must be excluded")
        precondition(first.goals[0].points.map(\.date) == ["2026-01-01","2026-01-03"])
        precondition(first.incompleteCount == 1 && first.stoCount == 1 && first.masteredCount == 1)
        b.sessions[1].trials[3].response = .prompted
        let changed = report()
        precondition(changed.goals[0].points.map(\.value) == [90,80])
        precondition(changed.masteredCount == 0, "Mean 80 alone must not establish mastery")
        precondition(changed.fingerprint != first.fingerprint, "Historical edits must invalidate review")
        let encoded = try JSONEncoder().encode(ReportAIPayload(document: changed))
        let text = String(decoding: encoded, as: UTF8.self)
        precondition(!text.contains("PRIVATE") && !text.contains("2026"))
        let fields = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        precondition(Set(fields.keys) == ["version", "series"])
        precondition(fields["series"] as? [[Double]] == [[90,80]])
        let restricted = ReportDocument.build(child: child, start: day(3), end: day(3), programs: [program], draft: draft)
        precondition(restricted.goals[0].points.count == 1 && restricted.goals[0].points[0].value == 80)
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
    }
}
