import Foundation

@main
struct ProgramNavigationTests {
    static func main() {
        let program = TherapyProgram(name: "ELCAR", category: "인지 및 학습")
        let car = TherapyTarget(name: "블럭모방", targetDescription: "그림과 같은 모형", levelNumber: 1)
        car.listTitle = "자동차 모양"
        let plane = TherapyTarget(name: "블럭모방", targetDescription: "그림과 같은 모형", status: .mastered, levelNumber: 2)
        plane.listTitle = "비행기 모양"
        let otherGoal = TherapyTarget(name: "블럭모방", targetDescription: "구두 지시에 따라 구성")
        let writing = TherapyTarget(name: "글씨모방")
        program.targets = [plane, writing, otherGoal, car]
        let groups = ProgramLibrary.taskGroups(program.targets)
        precondition(groups.count == 3, "Same task with a different goal must stay separate")
        precondition(groups.first?.name == "글씨모방", "Korean task ordering")
        let blocks = groups.first { $0.targets.count == 2 }!
        precondition(blocks.targets.map(\.id) == [car.id, plane.id], "Keep List order and original target IDs")
        let originalID = blocks.id
        car.name = "블록모방"
        plane.name = "블록모방"
        let renamed = ProgramLibrary.taskGroups(program.targets).first { $0.targets.count == 2 }!
        precondition(renamed.id == originalID, "Group identity survives name changes")
        let empty = TherapySession(date: Date())
        car.sessions.append(empty)
        precondition(renamed.latestDate == nil, "Empty sessions must not appear as recent treatment")
        let recorded = TherapySession(date: Date().addingTimeInterval(-86400))
        recorded.trials = [TrialRecord(trialNumber: 1, response: .correct)]
        plane.sessions.append(recorded)
        precondition(renamed.latestDate == recorded.date, "Historical Lists contribute their actual recorded date")
        precondition(ProgramLibrary.listStatus(car, in: program) == "진행중: List1")
        precondition(ProgramLibrary.listStatus(plane, in: program) == "완료")
        program.levels[0].status = .completed
        precondition(!ProgramLibrary.isRecordable(car, in: program), "Completed List cannot start a new session")
        precondition(ProgramLibrary.listStatus(car, in: program) == "완료")
        car.status = .discontinued
        precondition(ProgramLibrary.listStatus(car, in: program) == "중단")
        precondition(car.sessions.count == 1 && plane.sessions[0].id == recorded.id, "Grouping never mutates sessions")
        print("PASS: task grouping, stable identity, List status, history preservation, recent treatment dates")
    }
}
