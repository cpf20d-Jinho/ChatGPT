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
                    Text(child.name)
                        .font(.title2.bold())
                    if let birthDate = child.birthDate {
                        Text("생년월일 \(birthDate.formatted(date: .numeric, time: .omitted))")
                            .foregroundStyle(.secondary)
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
                            TodayProgramStatusRow(program: program, today: today)
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
        .navigationTitle(child.name)
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
            Text("이 작업은 프로그램의 모든 Level, 과제, Session, Trial 기록을 삭제합니다.")
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

private struct TodayProgramStatusRow: View {
    let program: TherapyProgram
    let today: Date

    private var activeTargets: [TherapyTarget] {
        guard let level = program.currentLevel else { return [] }
        return program.targets.filter {
            $0.levelNumber == level.levelNumber && $0.status == .active
        }
    }

    private var completedCount: Int {
        activeTargets.filter { target in
            target.sessions.contains { session in
                session.completed && Calendar.current.isDate(session.date, inSameDayAs: today)
            }
        }.count
    }

    private var isComplete: Bool {
        !activeTargets.isEmpty && completedCount == activeTargets.count
    }

    private var statusTitle: String {
        if isComplete { return "완료" }
        if completedCount > 0 { return "진행 중" }
        return "미기록"
    }

    private var statusIcon: String {
        if isComplete { return ABASymbol.completed }
        if completedCount > 0 { return ABASymbol.inProgress }
        return ABASymbol.empty
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                Text("과제 \(completedCount)/\(activeTargets.count) 완료")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let level = program.currentLevel {
                Text(level.label)
                    .font(.caption.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
            }
            ABAStatusPill(
                title: statusTitle,
                systemImage: statusIcon,
                tint: isComplete ? .green : (completedCount > 0 ? .orange : .secondary)
            )
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProgramRow: View {
    let program: TherapyProgram

    private var activeTargets: Int {
        program.targets.filter { $0.status == .active }.count
    }

    private var latestDate: Date? {
        program.targets.flatMap(\.sessions).filter(\.hasMeaningfulData).map(\.date).max()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(program.name)
                .font(.headline)
            HStack(spacing: 12) {
                if let level = program.currentLevel { Text("\(level.label) · 진행 과제 \(activeTargets)개") }
                else { Text("진행 과제 \(activeTargets)개") }
                if let latestDate {
                    Text("최근 기록 \(latestDate.formatted(date: .numeric, time: .omitted))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct AddProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let child: ChildProfile

    @State private var name = ""
    @State private var category = ""
    @State private var description = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("프로그램") {
                    TextField("프로그램명", text: $name)
                    TextField("영역 (선택)", text: $category)
                    TextField("설명 (선택)", text: $description, axis: .vertical)
                }
            }
            .navigationTitle("프로그램 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        let program = TherapyProgram(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            programDescription: description
                        )
                        child.programs.append(program)
                        do {
                            try modelContext.save()
                            dismiss()
                        } catch {
                            modelContext.rollback()
                            saveError = "프로그램을 저장하지 못했습니다. 입력 내용은 화면에 남아 있습니다."
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
}

private struct EditChildView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let child: ChildProfile

    @State private var name: String
    @State private var useBirthDate: Bool
    @State private var birthDate: Date
    @State private var memo: String
    @State private var saveError: String?

    init(child: ChildProfile) {
        self.child = child
        _name = State(initialValue: child.name)
        _useBirthDate = State(initialValue: child.birthDate != nil)
        _birthDate = State(initialValue: child.birthDate ?? Date())
        _memo = State(initialValue: child.memo)
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
            }
            .navigationTitle("아동 정보 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "아동 정보를 저장하지 못했습니다. 기존 정보는 보존되었습니다."
        }
    }
}
