import SwiftUI
import SwiftData

struct ChildDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let child: ChildProfile

    @State private var showingAddProgram = false
    @State private var showingEditChild = false
    @State private var programPendingDeletion: TherapyProgram?
    @State private var saveError: String?

    private var programs: [TherapyProgram] {
        child.programs.sorted { $0.createdAt < $1.createdAt }
    }

    private var recordablePrograms: [TherapyProgram] {
        programs.filter { program in
            guard let level = program.currentLevel else { return false }
            return program.targets.contains {
                $0.levelNumber == level.levelNumber && $0.status == .active
            }
        }
    }

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var todayCompletedProgramCount: Int {
        recordablePrograms.filter { program in
            guard let level = program.currentLevel else { return false }
            let activeTargets = program.targets.filter {
                $0.levelNumber == level.levelNumber && $0.status == .active
            }
            guard !activeTargets.isEmpty else { return false }
            return activeTargets.allSatisfy { target in
                target.sessions.contains { session in
                    session.completed && Calendar.current.isDate(session.date, inSameDayAs: today)
                }
            }
        }.count
    }

    private var todayAccuracies: [Double] {
        programs
            .flatMap(\.targets)
            .flatMap(\.sessions)
            .filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
            .compactMap(\.accuracy)
    }

    private var todayAverageAccuracy: Double? {
        guard !todayAccuracies.isEmpty else { return nil }
        return todayAccuracies.reduce(0, +) / Double(todayAccuracies.count)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) { childIdentity }
                        VStack(alignment: .leading, spacing: 4) { childIdentity }
                    }
                    if let start = child.lessonStartDate {
                        Text("수업 시작 \(LessonSchedule.dateText(start))").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ForEach(child.weeklyLessons) { lesson in
                        Text("\(LessonSchedule.weekdayName(lesson.weekday)) \(LessonSchedule.timeText(lesson.startMinute))–\(LessonSchedule.timeText(lesson.endMinute)) · \(lesson.category)")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if !child.memo.isEmpty {
                        Text(child.memo)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                .accessibilityElement(children: .combine)
            }

            Section("오늘 현황") {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) {
                        todayCompletionMetric
                        Divider()
                        todayAccuracyMetric
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        todayCompletionMetric
                        Divider()
                        todayAccuracyMetric
                    }
                }
                .padding(.vertical, 6)

            }

            Section("프로그램") {
                if programs.isEmpty {
                    ContentUnavailableView(
                        "등록된 프로그램이 없습니다",
                        systemImage: ABASymbol.program,
                        description: Text("아동에게 사용할 프로그램을 자유롭게 추가하세요.")
                    )
                } else {
                    ForEach(programs) { program in
                        NavigationLink {
                            ProgramDetailView(child: child, program: program)
                        } label: {
                            ProgramRow(program: program)
                        }
                    }
                    .onDelete(perform: deletePrograms)
                }
            }

            Section("보고서") {
                NavigationLink {
                    ReportView(child: child)
                } label: {
                    Label("사용자 지정 기간 경과 보고서", systemImage: ABASymbol.report)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingEditChild = true
                } label: {
                    Label("아동 정보 수정", systemImage: "pencil")
                }
                Button {
                    showingAddProgram = true
                } label: {
                    Label("프로그램 추가", systemImage: ABASymbol.add)
                }
            }
        }
        .sheet(isPresented: $showingAddProgram) {
            AddProgramView(child: child)
        }
        .sheet(isPresented: $showingEditChild) {
            EditChildView(child: child)
        }
        .confirmationDialog(
            "프로그램과 모든 기록을 삭제하시겠습니까?",
            isPresented: Binding(
                get: { programPendingDeletion != nil },
                set: { if !$0 { programPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { confirmProgramDeletion() }
            Button("취소", role: .cancel) { programPendingDeletion = nil }
        } message: {
            Text("이 작업은 프로그램의 모든 List, 과제, Session, Trial 기록을 삭제합니다.")
        }
        .alert("저장 실패", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("다시 시도") { confirmProgramDeletion() }
            Button("취소", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    @ViewBuilder private var childIdentity: some View {
        Text(child.name).font(.title2.bold())
        if let birthDate = child.birthDate {
            Text(LessonSchedule.dateText(birthDate)).foregroundStyle(.secondary)
                .accessibilityLabel("생년월일 \(LessonSchedule.dateText(birthDate))")
        }
    }

    private var todayCompletionMetric: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("완료 프로그램")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(todayCompletedProgramCount) / \(recordablePrograms.count)")
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var todayAccuracyMetric: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("오늘 입력 평균")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let todayAverageAccuracy {
                Text("\(todayAverageAccuracy, format: .number.precision(.fractionLength(0...1)))%")
                    .font(.title3.bold())
                    .monospacedDigit()
            } else {
                Text("기록 없음")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deletePrograms(at offsets: IndexSet) {
        guard let index = offsets.first, programs.indices.contains(index) else { return }
        programPendingDeletion = programs[index]
    }

    private func confirmProgramDeletion() {
        guard let programPendingDeletion else { return }
        modelContext.delete(programPendingDeletion)
        do {
            try modelContext.save()
            self.programPendingDeletion = nil
        } catch {
            modelContext.rollback()
            saveError = "프로그램을 삭제하지 못했습니다. 기록은 그대로 보존되었습니다."
        }
    }
}

private struct ProgramRow: View {
    let program: TherapyProgram

    private var latestDate: Date? {
        program.targets.flatMap(\.sessions).filter { $0.attemptedCount > 0 }.map(\.date).max()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                identity
                Spacer(minLength: 12)
                recentLesson
            }
            VStack(alignment: .leading, spacing: 10) {
                identity
                recentLesson
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(program.name).font(.headline)
            Text("학습 영역: \(program.category.isEmpty ? "미등록" : program.category)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var recentLesson: some View {
        HStack(spacing: 8) {
            Text("최근 수업")
            Text(latestDate.map(LessonSchedule.dateText) ?? "기록 없음").monospacedDigit()
        }
        .font(.caption)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .overlay { Capsule().stroke(ABAVisualStyle.leafGreen.opacity(0.6), lineWidth: 1) }
    }
}

private struct AddProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChildProfile.name) private var allChildren: [ChildProfile]
    let child: ChildProfile
    @State private var name = ""
    @State private var category = ""
    @State private var goal = ""
    @State private var taskName = ""
    @State private var listTitle = ""
    @State private var firstMaxTrials = 10
    @State private var saveError: String?

    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (listTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("프로그램") {
                    if allChildren.contains(where: { !$0.programs.isEmpty }) {
                        DisclosureGroup("이전 프로그램·영역 불러오기") {
                            ForEach(allChildren.filter { !$0.programs.isEmpty }) { sourceChild in
                                DisclosureGroup(sourceChild.name) {
                                    ForEach(sourceChild.programs.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { source in
                                        Button {
                                            name = source.name
                                            category = source.category
                                            goal = source.programDescription
                                        } label: {
                                            VStack(alignment: .leading) {
                                                Text(source.name)
                                                Text(source.category).font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    TextField("프로그램명", text: $name)
                    TextField("영역 (필수)", text: $category)
                    TextField("목표", text: $goal, axis: .vertical)
                }
                Section("첫 과제") {
                    DisclosureGroup("이 프로그램의 이전 과제 불러오기") {
                        ForEach(ProgramLibrary.templates(name: name, category: category, programs: allChildren.flatMap(\.programs))) { source in
                            Button(source.displayName) {
                                taskName = source.name
                                goal = source.targetDescription
                                listTitle = source.listTitle
                                firstMaxTrials = source.maxTrials
                            }
                        }
                    }
                    TextField("과제 (예: 블럭모방)", text: $taskName)
                    TextField("List1 제목 (예: 자동차 모양)", text: $listTitle)
                    Text("과제를 함께 등록하거나, 프로그램을 만든 뒤 추가할 수 있습니다.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("프로그램 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("추가") { save() }.disabled(!valid) }
            }
            .alert("저장 실패", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("확인", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }
    private func save() {
        let program = TherapyProgram(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines), programDescription: goal)
        let trimmedTask = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTask.isEmpty {
            let target = TherapyTarget(name: trimmedTask, targetDescription: goal, maxTrials: firstMaxTrials,
                masteryPercent: program.levels[0].criterionPercent, masterySessions: program.levels[0].requiredDays)
            target.listTitle = listTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            program.targets.append(target)
        }
        child.programs.append(program)
        do { try modelContext.save(); dismiss() }
        catch { modelContext.rollback(); saveError = "프로그램을 저장하지 못했습니다. 입력 내용은 화면에 남아 있습니다." }
    }
}

private struct EditChildView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let child: ChildProfile

    @State private var name: String
    @State private var useBirthDate: Bool
    @State private var birthDate: Date
    @State private var memo: String
    @State private var useStartDate: Bool
    @State private var lessonStartDate: Date
    @State private var lessons: [WeeklyLesson]
    @State private var saveError: String?

    init(child: ChildProfile) {
        self.child = child
        _name = State(initialValue: child.name)
        _useBirthDate = State(initialValue: child.birthDate != nil)
        _birthDate = State(initialValue: child.birthDate ?? Date())
        _memo = State(initialValue: child.memo)
        _useStartDate = State(initialValue: child.lessonStartDate != nil)
        _lessonStartDate = State(initialValue: child.lessonStartDate ?? Date())
        _lessons = State(initialValue: child.weeklyLessons)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("이름", text: $name)
                    Toggle("생년월일 입력", isOn: $useBirthDate)
                    if useBirthDate {
                        DatePicker("생년월일", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                    }
                    TextField("메모", text: $memo, axis: .vertical)
                }
                LessonScheduleFields(useStartDate: $useStartDate, startDate: $lessonStartDate, lessons: $lessons)
            }
            .navigationTitle("아동 정보 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !LessonSchedule.valid(lessons))
                }
            }
            .alert("저장 실패", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("확인", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }

    private func save() {
        child.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        child.birthDate = useBirthDate ? birthDate : nil
        child.memo = memo
        child.lessonStartDate = useStartDate ? lessonStartDate : nil
        child.weeklyLessons = lessons
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "아동 정보를 저장하지 못했습니다. 기존 정보는 보존되었습니다."
        }
    }
}
