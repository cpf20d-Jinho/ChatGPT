import Foundation
import CryptoKit

struct ReportDraft: Codable, Equatable {
    var institution = "검단ABA언어행동연구소"
    var therapist = ""
    var director = ""
    var directorCredential = ""
    var className = "개별 ABA"
    var schedule = ""
    var duration = ""
    var programFamily = ""
    var copyright = ""
    var signedDate = ""
    var behavior = ""
    var currentStatus = ""
    var majorChanges = ""
    var therapistOpinion = ""
    var homePractice = ""
    var nextGoals = ""
    var groupByProgram: [String: String] = [:]
    var confirmedObservations = ""
    var reviewedFingerprint = ""
}

struct ReportPoint: Codable {
    let date: String
    let value: Double
    let level: Int
}

struct ReportGoal: Codable {
    let id: String
    let name: String
    let domain: String
    let group: String
    let points: [ReportPoint]
    let learning: [String: String]
    let criteria: [String: Double]
    let masteredLevels: [Int]
    let binary: Bool
}

struct ReportDocument: Codable {
    let childName: String
    let birthDate: String
    let start: String
    let end: String
    let goals: [ReportGoal]
    let incompleteCount: Int
    let draft: ReportDraft

    var fingerprint: String {
        struct Source: Encodable {
            let start: String
            let end: String
            let goals: [ReportGoal]
            let observations: String
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(Source(start: start, end: end, goals: goals, observations: draft.confirmedObservations)) else { return "" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    var stoCount: Int { goals.reduce(0) { $0 + Set($1.points.map(\.level)).count } }
    var masteredCount: Int { goals.reduce(0) { $0 + $1.masteredLevels.count } }

    // Equal weighting of observed program-level goals, not pooled trial counts.
    var domains: [(name: String, count: Int, first: Double, recent: Double)] {
        Dictionary(grouping: goals, by: \.domain).map { name, goals in
            let series = goals.flatMap { goal in
                Dictionary(grouping: goal.points, by: \.level).values.map { $0.sorted { $0.date < $1.date } }
            }
            return (name, series.count,
                    Self.mean(series.map { Self.mean(Array($0.prefix(3)).map(\.value)) }),
                    Self.mean(series.map { Self.mean(Array($0.suffix(3)).map(\.value)) }))
        }.sorted { $0.recent > $1.recent }
    }

    // Carry forward within the currently observed level only; no fabricated zero before first observation.
    var growth: [ReportPoint] {
        let dates = Set(goals.flatMap(\.points).map(\.date)).sorted()
        return dates.compactMap { date in
            let values = goals.compactMap { goal in
                goal.points.filter { $0.date <= date }.sorted {
                    $0.date == $1.date ? $0.level < $1.level : $0.date < $1.date
                }.last?.value
            }
            return values.isEmpty ? nil : ReportPoint(date: date, value: Self.mean(values), level: 0)
        }
    }

    static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    static func date(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    static func build(child: ChildProfile, start: Date, end: Date,
                      programs: [TherapyProgram], draft: ReportDraft) -> ReportDocument {
        let calendar = Calendar.current
        let lower = calendar.startOfDay(for: start)
        let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
        var incomplete = 0
        let goals = programs.map { program -> ReportGoal in
            var points: [ReportPoint] = []
            var learning: [String: String] = [:]
            var criteria: [String: Double] = [:]
            var mastered: [Int] = []
            let levels = Set(program.targets.map(\.levelNumber)).sorted()
            for level in levels {
                let targets = program.targets.filter { $0.levelNumber == level }
                let definition = program.levels.first { $0.levelNumber == level }
                let criterion = definition?.criterionPercent ?? 80
                let required = definition?.requiredDays ?? 2
                criteria[String(level)] = criterion
                learning[String(level)] = targets.map {
                    $0.targetDescription.isEmpty ? $0.name : "\($0.name): \($0.targetDescription)"
                }.joined(separator: ", ")
                let sessions = targets.flatMap(\.sessions).filter { $0.date >= lower && $0.date < upper }
                incomplete += sessions.filter { !$0.completed && $0.hasMeaningfulData }.count
                let recorded = sessions.filter { $0.completed && $0.accuracy != nil }
                let dates = Set(recorded.map { calendar.startOfDay(for: $0.date) }).sorted()
                var streak = 0
                var met = false
                for day in dates {
                    let values = targets.compactMap { target -> Double? in
                        let daily = target.sessions.filter {
                            $0.completed && $0.accuracy != nil && calendar.isDate($0.date, inSameDayAs: day)
                        }.compactMap(\.accuracy)
                        return daily.isEmpty ? nil : mean(daily)
                    }
                    points.append(ReportPoint(date: date(day), value: mean(values), level: level))
                    // Averages alone do not establish mastery. Every applicable target must pass.
                    let applicable = targets.filter { target in
                        calendar.startOfDay(for: target.startDate) <= day &&
                        (target.endDate == nil || calendar.startOfDay(for: target.endDate!) >= day)
                    }
                    let allPassed = !applicable.isEmpty && applicable.allSatisfy { target in
                        let values = target.sessions.filter {
                            $0.completed && calendar.isDate($0.date, inSameDayAs: day)
                        }.compactMap(\.accuracy)
                        return !values.isEmpty && mean(values) >= criterion
                    }
                    streak = allPassed ? streak + 1 : 0
                    if streak >= required { met = true }
                }
                if met { mastered.append(level) }
            }
            return ReportGoal(
                id: program.id.uuidString, name: program.name,
                domain: program.category.isEmpty ? "미분류" : program.category,
                group: draft.groupByProgram[program.id.uuidString] ?? "기타 목표",
                points: points.sorted { $0.date == $1.date ? $0.level < $1.level : $0.date < $1.date },
                learning: learning, criteria: criteria, masteredLevels: mastered,
                binary: program.targets.count == 1 && program.targets.first?.maxTrials == 1
            )
        }.filter { !$0.points.isEmpty }
        return ReportDocument(childName: child.name, birthDate: child.birthDate.map(date) ?? "",
                              start: date(start), end: date(end), goals: goals,
                              incompleteCount: incomplete, draft: draft)
    }
}

enum ReportDraftStore {
    static func url(childID: UUID, start: Date, end: Date) throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                               appropriateFor: nil, create: true)
            .appendingPathComponent("ReportDrafts", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent("\(childID)-\(ReportDocument.date(start))-\(ReportDocument.date(end)).json")
    }

    static func load(childID: UUID, start: Date, end: Date) throws -> ReportDraft {
        let file = try url(childID: childID, start: start, end: end)
        guard FileManager.default.fileExists(atPath: file.path) else { return ReportDraft() }
        return try JSONDecoder().decode(ReportDraft.self, from: Data(contentsOf: file))
    }

    static func save(_ draft: ReportDraft, childID: UUID, start: Date, end: Date) throws {
        try JSONEncoder().encode(draft).write(to: url(childID: childID, start: start, end: end),
                                            options: [.atomic, .completeFileProtection])
    }
}
