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
            return try ModelContainer(for: schema, configurations: [configuration])
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
