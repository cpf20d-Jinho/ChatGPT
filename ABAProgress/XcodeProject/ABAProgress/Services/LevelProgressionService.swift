import Foundation
import SwiftData

enum LevelProgressionService {
    enum EvaluationResult: Equatable {
        case unchanged
        case advanced(from: Int, to: Int)
    }
    static func targets(for level: ProgramLevel, in program: TherapyProgram) -> [TherapyTarget] {
        program.targets.filter {
            $0.levelNumber == level.levelNumber && $0.status != .discontinued
        }
    }

    static func trailingQualifiedDays(
        for level: ProgramLevel,
        in program: TherapyProgram,
        through cutoffDate: Date? = nil
    ) -> Int {
        let levelTargets = targets(for: level, in: program)
        guard !levelTargets.isEmpty else { return 0 }

        let calendar = Calendar.current
        let dates = Set(
            levelTargets
                .flatMap(\.sessions)
                .filter { session in
                    guard session.completed, session.hasMeaningfulData else { return false }
                    if let cutoffDate {
                        return calendar.startOfDay(for: session.date) <= calendar.startOfDay(for: cutoffDate)
                    }
                    return true
                }
                .map { calendar.startOfDay(for: $0.date) }
        )
        let orderedDates = dates.sorted()

        var trailing = 0
        for date in orderedDates.reversed() {
            let allQualified = levelTargets.allSatisfy { target in
                let accuracies = target.sessions.filter {
                    $0.completed && $0.hasMeaningfulData && calendar.isDate($0.date, inSameDayAs: date)
                }.compactMap(\.accuracy)
                guard !accuracies.isEmpty else { return false }
                return ReportDocument.mean(accuracies) >= level.criterionPercent
            }
            if allQualified {
                trailing += 1
            } else {
                break
            }
        }
        return trailing
    }

    @discardableResult
    static func evaluateCurrentLevel(in program: TherapyProgram, modelContext: ModelContext) throws -> EvaluationResult {
        guard let level = program.currentLevel else { return .unchanged }
        let levelTargets = targets(for: level, in: program)
        guard !levelTargets.isEmpty else { return .unchanged }
        guard trailingQualifiedDays(for: level, in: program) >= level.requiredDays else {
            return .unchanged
        }

        level.status = .completed
        for target in levelTargets where target.status == .active {
            target.status = .mastered
        }

        let nextNumber = level.levelNumber + 1
        if !program.levels.contains(where: { $0.levelNumber == nextNumber }) {
            program.levels.append(
                ProgramLevel(
                    levelNumber: nextNumber,
                    requiredDays: level.requiredDays,
                    criterionPercent: level.criterionPercent
                )
            )
        } else if let next = program.levels.first(where: { $0.levelNumber == nextNumber }) {
            next.status = .active
        }

        do {
            try modelContext.save()
            return .advanced(from: level.levelNumber, to: nextNumber)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    static func integrityIssues(in program: TherapyProgram) -> [String] {
        program.orderedLevels.compactMap { level in
            guard level.status == .completed, let completedAt = level.completedAt else { return nil }
            let levelTargets = targets(for: level, in: program)
            guard !levelTargets.isEmpty else { return nil }

            let qualified = trailingQualifiedDays(for: level, in: program, through: completedAt)
            guard qualified < level.requiredDays else { return nil }

            return "\(level.label): 완료 당시 기준인 \(level.requiredDays)회 연속, 전체 과제 \(Int(level.criterionPercent))% 이상을 현재 기록이 충족하지 않습니다."
        }
    }
}
