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
            if ProcessInfo.processInfo.environment["ABA_DEMO"] == "1" {
                let context = ModelContext(container)
                let child = ChildProfile(name: "시연 아동")
                let program = TherapyProgram(name: "소근육 모방", category: "모방")
                program.levels[0].requiredDays = 10
                let target = TherapyTarget(name: "손뼉 치기")
                target.startDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
                for (offset, correct) in [(-8, 4), (-6, 5), (-4, 6), (-2, 7)] {
                    let date = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                    let session = TherapySession(date: date, completed: true)
                    session.trials = (1...10).map { TrialRecord(trialNumber: $0, response: $0 <= correct ? .correct : .prompted) }
                    target.sessions.append(session)
                }
                program.targets = [target]; child.programs = [program]
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
