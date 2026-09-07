import Foundation
import SwiftData

@Model
final class ChildProfile {
    var id: UUID
    var name: String
    var birthDate: Date?
    var memo: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var programs: [TherapyProgram]

    init(name: String, birthDate: Date? = nil, memo: String = "") {
        self.id = UUID()
        self.name = name
        self.birthDate = birthDate
        self.memo = memo
        self.createdAt = Date()
        self.programs = []
    }
}

enum ProgramLevelStatus: String, Codable {
    case active = "진행"
    case completed = "완료"
}

@Model
final class ProgramLevel {
    var id: UUID
    var levelNumber: Int = 1
    var requiredDays: Int
    var criterionPercent: Double
    var statusRaw: String
    var startedAt: Date
    var completedAt: Date?

    init(levelNumber: Int, requiredDays: Int = 2, criterionPercent: Double = 80) {
        self.id = UUID()
        self.levelNumber = max(levelNumber, 1)
        self.requiredDays = max(requiredDays, 2)
        self.criterionPercent = min(max(criterionPercent, 0), 100)
        self.statusRaw = ProgramLevelStatus.active.rawValue
        self.startedAt = Date()
        self.completedAt = nil
    }

    var status: ProgramLevelStatus {
        get { ProgramLevelStatus(rawValue: statusRaw) ?? .active }
        set {
            statusRaw = newValue.rawValue
            completedAt = newValue == .completed ? Date() : nil
        }
    }

    var label: String { "L\(levelNumber)" }
}

@Model
final class TherapyProgram {
    var id: UUID
    var name: String
    var category: String
    var programDescription: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var levels: [ProgramLevel]

    @Relationship(deleteRule: .cascade)
    var targets: [TherapyTarget]

    init(name: String, category: String = "", programDescription: String = "") {
        self.id = UUID()
        self.name = name
        self.category = category
        self.programDescription = programDescription
        self.createdAt = Date()
        self.levels = [ProgramLevel(levelNumber: 1)]
        self.targets = []
    }

    var orderedLevels: [ProgramLevel] {
        levels.sorted { $0.levelNumber < $1.levelNumber }
    }

    var currentLevel: ProgramLevel? {
        orderedLevels.first { $0.status == .active }
    }
}

enum TargetStatus: String, CaseIterable, Codable, Identifiable {
    case active = "진행"
    case mastered = "습득"
    case discontinued = "중단"

    var id: String { rawValue }
}

@Model
final class TherapyTarget {
    var id: UUID
    var name: String
    var targetDescription: String
    var maxTrials: Int
    var masteryPercent: Double
    var masterySessions: Int
    var statusRaw: String
    var startDate: Date
    var endDate: Date?
    var levelNumber: Int = 1

    @Relationship(deleteRule: .cascade)
    var sessions: [TherapySession]

    init(
        name: String,
        targetDescription: String = "",
        maxTrials: Int = 10,
        masteryPercent: Double = 80,
        masterySessions: Int = 3,
        status: TargetStatus = .active,
        levelNumber: Int = 1
    ) {
        self.id = UUID()
        self.name = name
        self.targetDescription = targetDescription
        self.maxTrials = min(max(maxTrials, 1), 10)
        self.masteryPercent = min(max(masteryPercent, 0), 100)
        self.masterySessions = max(masterySessions, 1)
        self.statusRaw = status.rawValue
        self.startDate = Date()
        self.endDate = nil
        self.levelNumber = max(levelNumber, 1)
        self.sessions = []
    }

    var status: TargetStatus {
        get { TargetStatus(rawValue: statusRaw) ?? .active }
        set {
            statusRaw = newValue.rawValue
            endDate = newValue == .active ? nil : Date()
        }
    }
}

@Model
final class TherapySession {
    var id: UUID
    var date: Date
    var note: String
    var completed: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var trials: [TrialRecord]

    init(date: Date, note: String = "", completed: Bool = false) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.note = note
        self.completed = completed
        self.createdAt = Date()
        self.updatedAt = Date()
        self.trials = []
    }

    var correctCount: Int { trials.filter { $0.response == .correct }.count }
    var promptedCount: Int { trials.filter { $0.response == .prompted }.count }
    var naCount: Int { trials.filter { $0.response == .notApplicable }.count }
    var attemptedCount: Int { correctCount + promptedCount }
    var accuracy: Double? {
        guard attemptedCount > 0 else { return nil }
        return Double(correctCount) / Double(attemptedCount) * 100
    }

    var hasMeaningfulData: Bool {
        attemptedCount > 0 || completed || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wasEditedAfterCreation: Bool {
        updatedAt.timeIntervalSince(createdAt) > 2
    }
}

enum TrialResponse: String, CaseIterable, Codable {
    case notApplicable = "NA"
    case correct = "+"
    case prompted = "-"

    var next: TrialResponse {
        switch self {
        case .notApplicable: return .correct
        case .correct: return .prompted
        case .prompted: return .notApplicable
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .notApplicable: return "미기록 또는 미시행"
        case .correct: return "정반응"
        case .prompted: return "촉구반응"
        }
    }
}

@Model
final class TrialRecord {
    var id: UUID
    var trialNumber: Int
    var responseRaw: String
    var updatedAt: Date

    init(trialNumber: Int, response: TrialResponse = .notApplicable) {
        self.id = UUID()
        self.trialNumber = trialNumber
        self.responseRaw = response.rawValue
        self.updatedAt = Date()
    }

    var response: TrialResponse {
        get { TrialResponse(rawValue: responseRaw) ?? .notApplicable }
        set {
            responseRaw = newValue.rawValue
            updatedAt = Date()
        }
    }
}
