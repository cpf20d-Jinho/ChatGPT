import Foundation

struct WeeklyLesson: Codable, Identifiable, Equatable {
    var id = UUID()
    var weekday = 2
    var startMinute = 900
    var endMinute = 950
    var category = ""
}

struct LessonException: Codable, Identifiable {
    var id = UUID()
    var lessonID: UUID
    var originalDate: Date
    var category: String
    var originalStartMinute: Int
    var originalEndMinute: Int
    var makeupStart: Date?
    var makeupEnd: Date?
}

extension ChildProfile {
    var weeklyLessons: [WeeklyLesson] {
        get { weeklyLessonsData.flatMap { try? JSONDecoder().decode([WeeklyLesson].self, from: $0) } ?? [] }
        set { weeklyLessonsData = try? JSONEncoder().encode(newValue) }
    }
    var lessonExceptions: [LessonException] {
        get { lessonExceptionsData.flatMap { try? JSONDecoder().decode([LessonException].self, from: $0) } ?? [] }
        set { lessonExceptionsData = try? JSONEncoder().encode(newValue) }
    }
}

struct LessonOccurrence: Identifiable {
    var child: ChildProfile
    var lessonID: UUID
    var originalDate: Date
    var category: String
    var start: Date
    var end: Date
    var isCancelled: Bool
    var isMakeup: Bool
    var id: String { "\(child.id)-\(lessonID)-\(originalDate.timeIntervalSince1970)-\(isMakeup)" }
    var status: String { isMakeup ? "보강" : (isCancelled ? "휴강" : "수업") }
}

enum LessonSchedule {
    static let weekdays = [2, 3, 4, 5, 6, 7, 1]
    static func weekdayName(_ day: Int) -> String { ["일", "월", "화", "수", "목", "금", "토"][max(1, min(day, 7)) - 1] }
    static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }
    static func timeText(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    static func minute(_ date: Date) -> Int {
        Calendar.current.component(.hour, from: date) * 60 + Calendar.current.component(.minute, from: date)
    }
    static func time(_ minute: Int, on date: Date = Date()) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: date) ?? date
    }
    static func weekStart(_ date: Date) -> Date {
        let day = Calendar.current.startOfDay(for: date)
        let offset = (Calendar.current.component(.weekday, from: day) + 5) % 7
        return Calendar.current.date(byAdding: .day, value: -offset, to: day) ?? day
    }
    static func valid(_ lessons: [WeeklyLesson]) -> Bool {
        lessons.allSatisfy { !$0.category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.endMinute > $0.startMinute }
    }
    static func occurrences(children: [ChildProfile], week: Date) -> [LessonOccurrence] {
        let calendar = Calendar.current
        let start = weekStart(week)
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        var result: [LessonOccurrence] = []
        for child in children {
            let exceptions = child.lessonExceptions
            for offset in 0..<7 {
                let date = calendar.date(byAdding: .day, value: offset, to: start)!
                if let begins = child.lessonStartDate, date < calendar.startOfDay(for: begins) { continue }
                for lesson in child.weeklyLessons where lesson.weekday == calendar.component(.weekday, from: date) {
                    // An exception carries a snapshot of this one lesson, even if
                    // the regular timetable was subsequently edited or removed.
                    if exceptions.contains(where: { $0.lessonID == lesson.id && calendar.isDate($0.originalDate, inSameDayAs: date) }) { continue }
                    result.append(LessonOccurrence(child: child, lessonID: lesson.id, originalDate: date,
                        category: lesson.category, start: time(lesson.startMinute, on: date), end: time(lesson.endMinute, on: date),
                        isCancelled: false, isMakeup: false))
                }
            }
            for change in exceptions {
                if change.originalDate >= start && change.originalDate < end {
                    result.append(LessonOccurrence(child: child, lessonID: change.lessonID, originalDate: change.originalDate,
                        category: change.category, start: time(change.originalStartMinute, on: change.originalDate),
                        end: time(change.originalEndMinute, on: change.originalDate), isCancelled: true, isMakeup: false))
                }
                if let makeup = change.makeupStart, let finish = change.makeupEnd, makeup >= start && makeup < end {
                    result.append(LessonOccurrence(child: child, lessonID: change.lessonID, originalDate: change.originalDate,
                        category: change.category, start: makeup, end: finish, isCancelled: false, isMakeup: true))
                }
            }
        }
        return result.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }
    }
    static func overlaps(_ occurrence: LessonOccurrence, in entries: [LessonOccurrence]) -> Bool {
        !occurrence.isCancelled && entries.contains {
            !$0.isCancelled && $0.id != occurrence.id && $0.start < occurrence.end && $0.end > occurrence.start
        }
    }
}
