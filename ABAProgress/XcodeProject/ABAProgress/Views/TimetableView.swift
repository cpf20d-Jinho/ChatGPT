import SwiftUI
import SwiftData

struct LessonScheduleFields: View {
    @Binding var useStartDate: Bool
    @Binding var startDate: Date
    @Binding var lessons: [WeeklyLesson]

    var body: some View {
        Section("수업 일정") {
            Toggle("수업 시작일 입력", isOn: $useStartDate)
            if useStartDate {
                DatePicker("수업 시작일", selection: $startDate, displayedComponents: .date)
            }
            ForEach($lessons) { $lesson in
                WeeklyLessonEditorRow(lesson: $lesson) {
                    let lessonID = lesson.id
                    lessons.removeAll { $0.id == lessonID }
                }
            }
            Button("수업 날짜 추가", systemImage: "plus") { lessons.append(WeeklyLesson()) }
            Text("요일과 시각은 매주 반복됩니다. 휴강·보강은 시간표에서 해당 날짜의 수업을 선택해 변경합니다.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

private struct WeeklyLessonEditorRow: View {
    @Binding var lesson: WeeklyLesson
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("요일", selection: $lesson.weekday) {
                    ForEach(LessonSchedule.weekdays, id: \.self) { day in
                        Text(LessonSchedule.weekdayName(day)).tag(day)
                    }
                }
                Button("삭제", role: .destructive, action: onDelete)
                    .buttonStyle(.borderless)
            }
            TextField("영역 (예: 인지 및 학습)", text: $lesson.category)
            DatePicker(
                "시작",
                selection: Binding(
                    get: { LessonSchedule.time(lesson.startMinute) },
                    set: { lesson.startMinute = LessonSchedule.minute($0) }
                ),
                displayedComponents: .hourAndMinute
            )
            DatePicker(
                "종료",
                selection: Binding(
                    get: { LessonSchedule.time(lesson.endMinute) },
                    set: { lesson.endMinute = LessonSchedule.minute($0) }
                ),
                displayedComponents: .hourAndMinute
            )
            if lesson.endMinute <= lesson.startMinute {
                Text("종료 시각은 시작 시각보다 늦어야 합니다.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TimetableView: View {
    let children: [ChildProfile]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var week = LessonSchedule.weekStart(Date())
    @State private var selected: LessonOccurrence?
    @State private var useList = false
    private var entries: [LessonOccurrence] { LessonSchedule.occurrences(children: children, week: week) }
    private var days: [Date] { (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: LessonSchedule.weekStart(week))! } }
    private var startHour: Int { min(8, entries.map { Calendar.current.component(.hour, from: $0.start) }.min() ?? 8) }
    private var endHour: Int { min(24, max(20, (entries.map { Calendar.current.component(.hour, from: $0.end) }.max() ?? 19) + 1)) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { moveWeek(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("이전 주")
                DatePicker("주차", selection: $week, displayedComponents: .date).labelsHidden()
                Button { moveWeek(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("다음 주")
                Spacer()
                Button("이번 주") { week = LessonSchedule.weekStart(Date()) }
            }.padding(.horizontal)
            Toggle("목록으로 보기", isOn: $useList).padding(.horizontal)
            if entries.isEmpty {
                ContentUnavailableView("이번 주 수업이 없습니다", systemImage: "calendar",
                    description: Text("아동 정보에서 수업 시작일과 매주 반복할 요일·시간·영역을 등록하세요."))
            } else if useList || dynamicTypeSize.isAccessibilitySize {
                List {
                    ForEach(days, id: \.self) { day in
                        Section(LessonSchedule.dateText(day) + " " + LessonSchedule.weekdayName(Calendar.current.component(.weekday, from: day))) {
                            ForEach(entries.filter { Calendar.current.isDate($0.start, inSameDayAs: day) }) { entry in
                                Button { selected = entry } label: { lessonLabel(entry) }
                            }
                        }
                    }
                }
            } else {
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 0) {
                            Text("시간").frame(width: 48, height: 44)
                            ForEach(startHour..<endHour, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).font(.caption2)
                                    .frame(width: 48, height: 120, alignment: .top)
                            }
                        }
                        ForEach(days, id: \.self) { day in
                            TimetableDayColumn(day: day, entries: entries.filter { Calendar.current.isDate($0.start, inSameDayAs: day) },
                                startHour: startHour, endHour: endHour, allEntries: entries, selected: $selected)
                        }
                    }.padding(.horizontal)
                }
            }
        }
        .background(ABAVisualStyle.ivory)
        .navigationTitle("시간표")
        .sheet(item: $selected) { entry in LessonOccurrenceEditor(entry: entry, children: children) }
    }
    private func moveWeek(_ delta: Int) { week = Calendar.current.date(byAdding: .day, value: delta * 7, to: week) ?? week }
    private func lessonLabel(_ entry: LessonOccurrence) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(entry.child.name) · \(entry.category)").font(.headline)
            Text("\(LessonSchedule.timeText(LessonSchedule.minute(entry.start)))–\(LessonSchedule.timeText(LessonSchedule.minute(entry.end))) · \(entry.status)")
                .font(.caption)
            if LessonSchedule.overlaps(entry, in: entries) { Text("시간 겹침").font(.caption).foregroundStyle(.orange) }
        }
        .foregroundStyle(.primary)
        .opacity(entry.isCancelled ? 0.45 : 1)
        .accessibilityElement(children: .combine)
    }
}

private struct TimetableDayColumn: View {
    let day: Date
    let entries: [LessonOccurrence]
    let startHour: Int
    let endHour: Int
    let allEntries: [LessonOccurrence]
    @Binding var selected: LessonOccurrence?

    // Put simultaneous lessons in separate lanes rather than covering a card.
    private var placement: [TimetablePlacement] {
        var ends: [Date] = []
        var result: [TimetablePlacement] = []
        for entry in entries {
            let lane = ends.firstIndex { $0 <= entry.start } ?? ends.count
            let visibleEnd = max(entry.end, entry.start.addingTimeInterval(30 * 60))
            if lane == ends.count { ends.append(visibleEnd) } else { ends[lane] = visibleEnd }
            result.append(TimetablePlacement(entry: entry, lane: lane))
        }
        return result
    }
    private var laneCount: Int { (placement.map(\.lane).max() ?? 0) + 1 }
    private var width: CGFloat { CGFloat(laneCount) * 142 }
    var body: some View {
        VStack(spacing: 0) {
            Text("\(LessonSchedule.weekdayName(Calendar.current.component(.weekday, from: day))) \(Calendar.current.component(.day, from: day))")
                .font(.subheadline.bold()).frame(width: width, height: 44)
                .background(Calendar.current.isDateInToday(day) ? ABAVisualStyle.butterYellow : ABAVisualStyle.ivory)
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(startHour..<endHour, id: \.self) { _ in
                        Rectangle().fill(.clear).frame(height: 120)
                            .overlay(alignment: .top) { Rectangle().fill(ABAVisualStyle.separator).frame(height: 0.5) }
                    }
                }
                ForEach(placement) { item in
                    let entry = item.entry
                    let height = max(60, CGFloat(entry.end.timeIntervalSince(entry.start) / 60) * 2)
                    Button { selected = entry } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.category).font(.caption2).lineLimit(1)
                            Text(entry.child.name).font(.caption.bold()).lineLimit(1)
                            Text("\(LessonSchedule.timeText(LessonSchedule.minute(entry.start)))–\(LessonSchedule.timeText(LessonSchedule.minute(entry.end)))")
                                .font(.caption2).lineLimit(1)
                            if entry.isCancelled || entry.isMakeup { Text(entry.status).font(.caption2.bold()) }
                            if LessonSchedule.overlaps(entry, in: allEntries) { Image(systemName: "exclamationmark.triangle").font(.caption2) }
                        }
                        .padding(5).frame(width: 136, height: height - 3, alignment: .topLeading)
                        .foregroundStyle(.primary)
                        .background(entry.isMakeup ? ABAVisualStyle.butterYellow.opacity(0.6) : ABAVisualStyle.leafGreen.opacity(0.2), in: .rect(cornerRadius: 6))
                        .overlay { RoundedRectangle(cornerRadius: 6).stroke(ABAVisualStyle.leafGreen, style: StrokeStyle(lineWidth: 1, dash: entry.isCancelled ? [4, 3] : [])) }
                        .opacity(entry.isCancelled ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(entry.child.name), \(entry.category), \(entry.start.formatted(date: .omitted, time: .shortened)), \(entry.status)")
                    .offset(x: CGFloat(item.lane) * 142 + 3, y: CGFloat(LessonSchedule.minute(entry.start) - startHour * 60) * 2)
                }
            }
            .frame(width: width, height: CGFloat(endHour - startHour) * 120)
            .overlay(alignment: .leading) { Rectangle().fill(ABAVisualStyle.separator).frame(width: 0.5) }
        }
    }
}

private struct TimetablePlacement: Identifiable {
    let entry: LessonOccurrence
    let lane: Int
    var id: String { entry.id }
}

private struct LessonOccurrenceEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let entry: LessonOccurrence
    let children: [ChildProfile]
    @State private var cancelled: Bool
    @State private var useMakeup: Bool
    @State private var makeupStart: Date
    @State private var makeupEnd: Date
    @State private var error: String?

    init(entry: LessonOccurrence, children: [ChildProfile]) {
        self.entry = entry
        self.children = children
        let change = entry.child.lessonExceptions.first { $0.lessonID == entry.lessonID && Calendar.current.isDate($0.originalDate, inSameDayAs: entry.originalDate) }
        let proposed = change?.makeupStart ?? Calendar.current.date(byAdding: .day, value: 1, to: entry.start) ?? entry.start
        _cancelled = State(initialValue: change != nil)
        _useMakeup = State(initialValue: change?.makeupStart != nil)
        _makeupStart = State(initialValue: proposed)
        _makeupEnd = State(initialValue: change?.makeupEnd ?? proposed.addingTimeInterval(entry.end.timeIntervalSince(entry.start)))
    }
    private var valid: Bool {
        !cancelled || !useMakeup || (makeupEnd > makeupStart && Calendar.current.isDate(makeupStart, inSameDayAs: makeupEnd))
    }
    private var makeupConflicts: Bool {
        let entries = LessonSchedule.occurrences(children: children, week: makeupStart)
        return entries.contains { !$0.isCancelled && $0.id != entry.id &&
            !($0.child.id == entry.child.id && $0.lessonID == entry.lessonID && $0.originalDate == entry.originalDate) &&
            $0.start < makeupEnd && $0.end > makeupStart }
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(entry.child.name).font(.headline)
                    Text(entry.category)
                    LabeledContent("원래 수업일", value: LessonSchedule.dateText(entry.originalDate))
                }
                Section("이 날짜의 수업") {
                    Toggle("휴강", isOn: $cancelled)
                    if cancelled {
                        Toggle("보강 날짜 지정", isOn: $useMakeup)
                        if useMakeup {
                            DatePicker("보강 시작", selection: $makeupStart)
                            DatePicker("보강 종료", selection: $makeupEnd)
                            if !valid { Text("같은 날짜 안에서 시작보다 늦은 종료 시각을 지정하세요.").foregroundStyle(.red) }
                            if makeupConflicts { Label("다른 수업과 시간이 겹칩니다.", systemImage: ABASymbol.warning).foregroundStyle(.orange) }
                        }
                    }
                    Text("선택한 날짜에만 적용됩니다. 휴강을 해제하면 연결된 보강도 제거됩니다.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("수업 일정 변경")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { save() }.disabled(!valid) }
            }
            .alert("저장 실패", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("확인", role: .cancel) { error = nil }
            } message: { Text(error ?? "") }
        }
    }
    private func save() {
        var changes = entry.child.lessonExceptions
        let previous = changes.first { $0.lessonID == entry.lessonID && Calendar.current.isDate($0.originalDate, inSameDayAs: entry.originalDate) }
        changes.removeAll { $0.lessonID == entry.lessonID && Calendar.current.isDate($0.originalDate, inSameDayAs: entry.originalDate) }
        if cancelled {
            var change = previous ?? LessonException(lessonID: entry.lessonID, originalDate: entry.originalDate,
                category: entry.category, originalStartMinute: LessonSchedule.minute(entry.start), originalEndMinute: LessonSchedule.minute(entry.end))
            change.makeupStart = useMakeup ? makeupStart : nil
            change.makeupEnd = useMakeup ? makeupEnd : nil
            changes.append(change)
        }
        entry.child.lessonExceptions = changes
        do { try modelContext.save(); dismiss() }
        catch { modelContext.rollback(); error = "일정을 저장하지 못했습니다. 기존 일정은 보존되었습니다." }
    }
}
