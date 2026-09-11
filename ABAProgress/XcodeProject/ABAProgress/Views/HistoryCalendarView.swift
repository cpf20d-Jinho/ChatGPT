import SwiftUI
import SwiftData

struct HistoryCalendarView: View {
    let children: [ChildProfile]

    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var childSearchText = ""

    private var recordedDates: Set<Date> {
        let calendar = Calendar.current
        return Set(
            children
                .flatMap(\.programs)
                .flatMap(\.targets)
                .flatMap(\.sessions)
                .filter(\.hasMeaningfulData)
                .map { calendar.startOfDay(for: $0.date) }
        )
    }

    private var childrenForSelectedDate: [ChildProfile] {
        children
            .filter { child in
                child.programs
                    .flatMap(\.targets)
                    .flatMap(\.sessions)
                    .contains { $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var displayedChildrenForSelectedDate: [ChildProfile] {
        let query = childSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return childrenForSelectedDate }
        return childrenForSelectedDate.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var sessionCount: Int {
        childrenForSelectedDate
            .flatMap(\.programs)
            .flatMap(\.targets)
            .flatMap(\.sessions)
            .filter { $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .count
    }

    private var programCount: Int {
        childrenForSelectedDate.reduce(0) { total, child in
            total + child.programs.filter { program in
                program.targets.flatMap(\.sessions).contains {
                    $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
                }
            }.count
        }
    }

    private var incompleteSessionCount: Int {
        childrenForSelectedDate
            .flatMap(\.programs)
            .flatMap(\.targets)
            .flatMap(\.sessions)
            .filter {
                $0.hasMeaningfulData && !$0.completed && Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
            }
            .count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                MonthCalendar(
                    displayedMonth: $displayedMonth,
                    selectedDate: $selectedDate,
                    recordedDates: recordedDates
                )

                selectedDateSummary

                if childrenForSelectedDate.isEmpty {
                    ContentUnavailableView(
                        "이 날짜에는 기록이 없습니다",
                        systemImage: ABASymbol.noRecords,
                        description: Text("기록이 작성된 날짜에는 캘린더에 점이 표시됩니다.")
                    )
                    .padding(.top, 12)
                } else if displayedChildrenForSelectedDate.isEmpty {
                    ContentUnavailableView(
                        "검색 결과가 없습니다",
                        systemImage: ABASymbol.search,
                        description: Text("‘\(childSearchText)’와 일치하는 아동이 없습니다.")
                    )
                    .padding(.top, 12)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(displayedChildrenForSelectedDate) { child in
                            NavigationLink {
                                ChildDateRecordsView(child: child, date: selectedDate)
                            } label: {
                                ChildDateSummaryCard(child: child, date: selectedDate)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(ABAVisualStyle.groupedBackground)
        .navigationTitle("기록 캘린더")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $childSearchText, prompt: "이 날짜의 아동 검색")
    }

    private var selectedDateSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate.formatted(.dateTime.year().month().day().weekday(.wide)))
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 12)],
                spacing: 10
            ) {
                CalendarMetric(title: "기록 아동", value: "\(childrenForSelectedDate.count)명")
                CalendarMetric(title: "프로그램", value: "\(programCount)개")
                CalendarMetric(title: "Session", value: "\(sessionCount)개")
                CalendarMetric(title: "미완료", value: "\(incompleteSessionCount)개")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .abaSurface()
    }
}

private struct WeekdayHeader: Identifiable {
    let id: Int
    let symbol: String
}

private struct CalendarDaySlot: Identifiable {
    let id: String
    let date: Date?
}

private struct MonthCalendar: View {
    @Binding var displayedMonth: Date
    @Binding var selectedDate: Date
    let recordedDates: Set<Date>

    private let calendar = Calendar.current
    private var weekdayHeaders: [WeekdayHeader] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { offset in
            let weekday = ((calendar.firstWeekday - 1 + offset) % 7) + 1
            return WeekdayHeader(id: weekday, symbol: symbols[weekday - 1])
        }
    }

    private var days: [CalendarDaySlot] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [] }

        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        let monthKey = "\(components.year ?? 0)-\(components.month ?? 0)"
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [CalendarDaySlot] = []
        for index in 0..<leading {
            result.append(CalendarDaySlot(id: "\(monthKey)-leading-\(index)", date: nil))
        }
        for day in dayRange {
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
            result.append(CalendarDaySlot(id: "\(monthKey)-day-\(day)", date: date))
        }
        var trailing = 0
        while result.count % 7 != 0 {
            result.append(CalendarDaySlot(id: "\(monthKey)-trailing-\(trailing)", date: nil))
            trailing += 1
        }
        return result
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { changeMonth(-1) } label: {
                    Image(systemName: ABASymbol.previous)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("이전 달")
                Spacer()
                Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                    .font(.title3.bold())
                Spacer()
                Button { changeMonth(1) } label: {
                    Image(systemName: ABASymbol.next)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("다음 달")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(weekdayHeaders) { weekday in
                    Text(weekday.symbol)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(days) { slot in
                    if let date = slot.date {
                        DayCell(
                            date: date,
                            selected: calendar.isDate(date, inSameDayAs: selectedDate),
                            hasRecord: recordedDates.contains(calendar.startOfDay(for: date))
                        ) {
                            selectedDate = calendar.startOfDay(for: date)
                        }
                    } else {
                        Color.clear.frame(height: 48)
                    }
                }
            }
        }
        .abaSurface(background: Color(uiColor: .systemBackground))
    }

    private func changeMonth(_ offset: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = calendar.startOfMonth(for: newMonth)
        selectedDate = calendar.startOfMonth(for: newMonth)
    }
}

private struct DayCell: View {
    let date: Date
    let selected: Bool
    let hasRecord: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.body.weight(selected ? .bold : .regular))
                Circle()
                    .fill(hasRecord ? Color.accentColor : Color.clear)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(selected ? Color.accentColor.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(hasRecord ? "기록 있음" : "기록 없음")
        .accessibilityHint("이 날짜의 치료 기록을 확인합니다.")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct CalendarMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct ChildDateSummaryCard: View {
    let child: ChildProfile
    let date: Date

    private var recordedPrograms: [TherapyProgram] {
        child.programs.filter { program in
            program.targets.flatMap(\.sessions).contains { $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: date) }
        }
    }

    private var sessions: [TherapySession] {
        recordedPrograms.flatMap(\.targets).flatMap(\.sessions).filter { $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var average: Double? {
        let values = sessions.compactMap(\.accuracy)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: ABASymbol.child)
                .font(.title)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(child.name).font(.headline)
                Text("프로그램 \(recordedPrograms.count)개, Session \(sessions.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let average {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(average, format: .number.precision(.fractionLength(0...1)))%")
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("평균 정반응률")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Image(systemName: ABASymbol.next)
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .abaSurface()
        .accessibilityElement(children: .combine)
    }
}

struct ChildDateRecordsView: View {
    let child: ChildProfile
    let date: Date

    private var recordedPrograms: [TherapyProgram] {
        child.programs
            .filter { program in
                program.targets.flatMap(\.sessions).contains { $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: date) }
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("아동", value: child.name)
                LabeledContent("치료일", value: date.formatted(date: .long, time: .omitted))
            }

            ForEach(recordedPrograms) { program in
                Section {
                    let targets = program.targets.filter { target in
                        target.sessions.contains { $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: date) }
                    }
                    ForEach(targets) { target in
                        NavigationLink {
                            HistoricalTargetEditView(child: child, program: program, target: target, date: date)
                        } label: {
                            HistoricalTargetRow(target: target, date: date)
                        }
                    }
                } header: {
                    HStack {
                        Text(program.name)
                        Spacer()
                        let labels = levelLabels(program: program)
                        if !labels.isEmpty {
                            Text(labels.joined(separator: ", "))
                        }
                    }
                }
            }
        }
        .navigationTitle(child.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func levelLabels(program: TherapyProgram) -> [String] {
        let levels = Set(program.targets.compactMap { target -> Int? in
            let hasRecord = target.sessions.contains {
                $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: date)
            }
            return hasRecord ? target.levelNumber : nil
        })
        return levels.sorted().map { "L\($0)" }
    }
}

private struct HistoricalTargetRow: View {
    let target: TherapyTarget
    let date: Date

    private var session: TherapySession? {
        target.sessions.first { $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(target.name)
                Text("L\(target.levelNumber), 정반응 \(session?.correctCount ?? 0) / 촉구반응 \(session?.promptedCount ?? 0) / 미기록 \(session?.naCount ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let session {
                    HStack(spacing: 6) {
                        Text(session.completed ? "완료" : "미완료")
                        if session.wasEditedAfterCreation {
                            Text("수정됨")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(session.completed ? .green : .orange)
                }
            }
            Spacer()
            if let accuracy = session?.accuracy {
                Text("\(accuracy, format: .number.precision(.fractionLength(0...1)))%")
                    .font(.headline.monospacedDigit())
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HistoricalTargetEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let child: ChildProfile
    let program: TherapyProgram
    let target: TherapyTarget
    let date: Date

    @State private var showingDeleteConfirmation = false
    @State private var reviewRefreshVersion = 0
    @State private var saveError: String?

    private var session: TherapySession? {
        target.sessions.first { $0.hasMeaningfulData && Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    private var levelReviewIssues: [String] {
        _ = reviewRefreshVersion
        return LevelProgressionService.integrityIssues(in: program)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let saveError {
                    ABAInlineNotice(title: "저장 실패", message: saveError, systemImage: ABASymbol.warning, tint: .red)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Label("과거 기록 수정", systemImage: ABASymbol.editHistory)
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Text("아동 \(child.name), 프로그램 \(program.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(date.formatted(date: .long, time: .omitted))
                        .font(.title3.bold())
                    if let session {
                        Text("마지막 수정: \(session.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("기존 치료 기록을 실시간 입력 화면과 동일한 방식으로 수정합니다. 변경 내용은 즉시 저장되며 그래프와 보고서 원본 데이터에도 반영됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .abaSurface()

                if !levelReviewIssues.isEmpty {
                    Label(levelReviewIssues.joined(separator: "\n"), systemImage: ABASymbol.review)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .abaSurface(background: Color.orange.opacity(0.08))
                }

                TargetSessionCard(
                    target: target,
                    selectedDate: date,
                    levelLabel: "L\(target.levelNumber)",
                    historicalEditMode: true,
                    onSessionCompleted: {
                        do { _ = try LevelProgressionService.evaluateCurrentLevel(in: program, modelContext: modelContext) }
                        catch { saveError = "레벨 판정을 저장하지 못해 이전 상태로 복구했습니다." }
                        reviewRefreshVersion += 1
                    },
                    onDataChanged: refreshLevelIntegrity
                )
            }
            .padding()
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(ABAVisualStyle.groupedBackground)
        .navigationTitle(target.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("이 기록 삭제", systemImage: ABASymbol.delete)
                }
            }
        }
        .confirmationDialog(
            "이 날짜의 과제 기록을 삭제하시겠습니까?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("기록 삭제", role: .destructive) { deleteSession() }
            Button("취소", role: .cancel) { }
        } message: {
            Text("Trial과 세션 메모가 삭제됩니다. 완료된 레벨의 근거였던 기록이면 레벨 검토 경고가 표시될 수 있습니다.")
        }
    }

    private func refreshLevelIntegrity() {
        reviewRefreshVersion += 1
        do { try modelContext.save(); saveError = nil }
        catch { modelContext.rollback(); saveError = "과거 기록을 저장하지 못해 마지막 저장 상태로 복구했습니다." }
    }

    private func deleteSession() {
        guard let session else { return }
        modelContext.delete(session)
        do {
            try modelContext.save()
            reviewRefreshVersion += 1
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "기록을 삭제하지 못했습니다. 원본 기록은 그대로 보존되었습니다."
        }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}
