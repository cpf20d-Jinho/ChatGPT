import SwiftUI
import SwiftData

@main
struct ABAProgressApp: App {
    private let container: ModelContainer = {
        let schema = Schema([
            ChildProfile.self,
            TherapyProgram.self,
            ProgramLevel.self,
            TherapyTarget.self,
            TherapySession.self,
            TrialRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            #if DEBUG
            if ProcessInfo.processInfo.environment["ABA_DEMO"] == "1" ||
                ProcessInfo.processInfo.environment["ABA_EIGHT_PROGRAM_QA"] == "1" {
                // Seed through the same main context consumed by SwiftUI @Query.
                // A separate context can leave the first cold-launch query stale.
                let context = container.mainContext
                // Every UI test launch owns a deterministic fixture. Tests share
                // one simulator, so retaining the preceding launch's fixture
                // makes child selection and report assertions order-dependent.
                for existingChild in try context.fetch(FetchDescriptor<ChildProfile>()) {
                    context.delete(existingChild)
                }
                let child = ChildProfile(name: ProcessInfo.processInfo.environment["ABA_EIGHT_PROGRAM_QA"] == "1" ? "8개 프로그램 시연 아동" : "시연 아동")
                let programNames = ProcessInfo.processInfo.environment["ABA_EIGHT_PROGRAM_QA"] == "1"
                    ? ["소근육 모방", "대근육 모방", "언어 모방", "수용 언어", "표현 언어", "시각 수행", "놀이 기술", "사회성 기술"]
                    : ["소근육 모방"]
                child.programs = programNames.enumerated().map { index, name in
                    let program = TherapyProgram(name: name, category: "시연 영역")
                    program.levels[0].requiredDays = 10
                    let target = TherapyTarget(name: index == 0 ? "손뼉 치기" : "\(name) 과제")
                    target.startDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
                    let samples = index == 0 ? [(-8, 4), (-6, 5), (-4, 6), (-2, 7)] : [(-(8 - index), min(9, 4 + index))]
                    for (offset, correct) in samples {
                        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                        let session = TherapySession(date: date, completed: true)
                        session.trials = (1...10).map { TrialRecord(trialNumber: $0, response: $0 <= correct ? .correct : .prompted) }
                        target.sessions.append(session)
                    }
                    program.targets = [target]
                    return program
                }
                context.insert(child); try context.save()
            }
            #endif
            return container
        } catch {
            fatalError("SwiftData container creation failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .task {
                    #if DEBUG
                    if ProcessInfo.processInfo.environment["ABA_REPORT_QA"] == "1" {
                        await ReportTemplateExporter.runSyntheticVerification()
                    }
                    #endif
                }
        }
        .modelContainer(container)
    }
}

