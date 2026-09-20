import SwiftUI
import SwiftData

struct ProgramDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let child: ChildProfile
    let program: TherapyProgram

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingAddTarget = false
    @State private var showingLevelSettings = false
    @State private var showingEditProgram = false
    @State private var showingLevelReview = false
    @State private var selectedTarget: TherapyTarget?
    @State private var reviewRefreshVersion = 0
    @State private var notice: (title: String, message: String)?
    @State private var showingListCompletion = false

    private var currentLevel: ProgramLevel? { program.currentLevel }

    private var levelReviewIssues: [String] {
        _ = reviewRefreshVersion
        return LevelProgressionService.integrityIssues(in: program)
    }

    private var taskGroups: [ProgramLibrary.TaskGroup] {
        ProgramLibrary.taskGroups(program.targets)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                header
                if let notice {
                    ABAInlineNotice(
                        title: notice.title,
                        message: notice.message,
                        systemImage: notice.title.contains("실패") ? ABASymbol.warning : ABASymbol.completed,
                        tint: notice.title.contains("실패") ? .red : .green,
                        retryTitle: notice.title.contains("실패") ? "다시 저장" : nil,
                        retry: notice.title.contains("실패") ? savePendingChanges : nil
                    )
                }
                if !levelReviewIssues.isEmpty { levelReviewBanner }
                if taskGroups.isEmpty {
                    ContentUnavailableView("등록된 과제가 없습니다", systemImage: ABASymbol.targets,
                        description: Text("과제를 추가한 뒤 List의 진행중 버튼을 눌러 반응을 기록하세요."))
                } else {
                    ForEach(taskGroups) { group in
                        ProgramTaskDisclosure(group: group, program: program, onReintroduce: reintroduceTarget) { target in
                            selectedDate = ProgramLibrary.isRecordable(target, in: program)
                                ? Calendar.current.startOfDay(for: Date())
                                : target.sessions.filter(\.hasMeaningfulData).map(\.date).max() ?? Calendar.current.startOfDay(for: Date())
                            selectedTarget = target
                        }
                    }
                }
                if currentLevel == nil { levelHeader }

            }
            .padding()
            .frame(maxWidth: ABAVisualStyle.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(ABAVisualStyle.groupedBackground)
        .navigationTitle(child.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditProgram = true
                    } label: {
                        Label("프로그램 정보 수정", systemImage: "pencil")
                    }
                    Button {
                        showingLevelSettings = true
                    } label: {
                        Label("List 설정", systemImage: ABASymbol.settings)
                    }
                } label: {
                    Label("프로그램 관리", systemImage: ABASymbol.settings)
                }

                Button {
                    showingAddTarget = true
                } label: {
                    Label("과제 추가", systemImage: ABASymbol.add)
                }
                .disabled(currentLevel == nil)
            }
        }
        .onAppear { ensureInitialLevel() }
        .navigationDestination(item: $selectedTarget) { target in
            recordingScreen(target)
        }
        .sheet(isPresented: $showingAddTarget) {
            if let currentLevel {
                AddTargetView(program: program, level: currentLevel)
            }
        }
        .sheet(isPresented: $showingLevelSettings) {
            LevelSettingsView(program: program)
        }
        .sheet(isPresented: $showingEditProgram) {
            EditProgramView(program: program)
        }
        .sheet(isPresented: $showingLevelReview) {
            LevelReviewView(program: program, issues: levelReviewIssues) {
                showingLevelReview = false
                showingLevelSettings = true
            }
        }
    }

    private var header: some View {
        programIdentity
            .frame(maxWidth: .infinity, alignment: .leading)
            .abaSurface()
    }

    private func recordingScreen(_ target: TherapyTarget) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                recordingDateControls
                ABASectionHeading(title: "정반응 기록", help: "NA → + → − → NA 순서로 바뀝니다. NA는 정반응률에서 제외하며 변경 내용은 자동 저장됩니다.")
                if ProgramLibrary.isRecordable(target, in: program) || target.sessions.contains(where: {
                    Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
                }) {
                    TargetSessionCard(target: target, selectedDate: selectedDate,
                        levelLabel: "List\(target.levelNumber)",
                        historicalEditMode: !ProgramLibrary.isRecordable(target, in: program),
                        onSessionCompleted: {
                            if ProgramLibrary.isRecordable(target, in: program) { evaluateCurrentLevel() }
                        }, onDataChanged: refreshLevelIntegrity)
                        .id(target.id)
                } else {
                    ContentUnavailableView("이 날짜에 기록이 없습니다", systemImage: ABASymbol.empty,
                        description: Text("완료·중단된 List는 기존 기록이 있는 날짜를 선택해 확인할 수 있습니다."))
                }
                if let notice {
                    Text(notice.message).font(.footnote).foregroundStyle(.secondary)
                }
                if ProgramLibrary.isRecordable(target, in: program) { levelHeader }
                if !levelReviewIssues.isEmpty {
                    Label(levelReviewIssues.joined(separator: "\n"), systemImage: ABASymbol.warning)
                        .font(.footnote).foregroundStyle(.orange)
                }
            }
            .padding()
            .frame(maxWidth: ABAVisualStyle.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(ABAVisualStyle.groupedBackground)
        .navigationTitle(target.listTitle.isEmpty ? "List\(target.levelNumber)" : target.listTitle)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("현재 List를 완료하고 다음 List를 만들까요?", isPresented: $showingListCompletion, titleVisibility: .visible) {
            Button("완료 후 다음 List 생성") { finishList(createNext: true) }
            Button("현재 List만 완료") { finishList(createNext: false) }
            Button("취소", role: .cancel) { }
        } message: {
            Text("새 List에는 이전 시행 기록을 복사하지 않습니다. 과제 추가에서 이전 과제를 불러올 수 있습니다.")
        }
    }

    private var recordingDateControls: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("기록 날짜")
            DatePicker("기록 날짜", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()
            if !Calendar.current.isDateInToday(selectedDate) {
                Button("오늘") { selectedDate = Calendar.current.startOfDay(for: Date()) }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var programIdentity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(program.name)
                .font(.title2.bold())
            Text("학습 영역: \(program.category.isEmpty ? "미등록" : program.category)").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var levelHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(currentLevel?.label ?? "List 없음")
                    .font(.title3.bold())
                ABAHelpButton(title: "List 종료 기준", message: "현재 List의 모든 진행 과제가 설정한 정반응률을 같은 기록일에 달성해야 합니다. 수업이 없는 날짜는 건너뜁니다. 설정한 연속 기록일 기준을 충족하면 현재 List을 종료하고 다음 List 생성 여부를 확인합니다.")
                Spacer()
            }

            if let level = currentLevel {
                let progress = LevelProgressionService.trailingQualifiedDays(for: level, in: program)
                ProgressView(value: Double(progress), total: Double(level.requiredDays))
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("종료 기준: 연속 기록일 \(level.requiredDays)일 모두 \(Int(level.criterionPercent))% 이상")
                        Spacer()
                        Text("\(progress)/\(level.requiredDays)일")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("종료 기준: 연속 기록일 \(level.requiredDays)일 모두 \(Int(level.criterionPercent))% 이상")
                        Text("진행 \(progress)/\(level.requiredDays)일")
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                Button("\(level.label) 완료") { evaluateCurrentLevel() }
                    .buttonStyle(.borderedProminent)
                    .disabled(progress < level.requiredDays)
            } else {
                Button("다음 List 생성") {
                    do { try LevelProgressionService.createNextList(in: program, modelContext: modelContext) }
                    catch { notice = ("저장 실패", "다음 List를 만들지 못했습니다.") }
                }.buttonStyle(.borderedProminent)
            }
        }
        .abaSurface(background: Color(uiColor: .systemBackground))
    }

    private func ensureInitialLevel() {
        guard program.levels.isEmpty else { return }
        program.levels.append(ProgramLevel(levelNumber: 1))
        savePendingChanges()
    }

    private var levelReviewBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("과거 기록 수정으로 List 판정 확인이 필요합니다", systemImage: ABASymbol.review)
                .font(.headline)
                .foregroundStyle(.orange)
            Text(levelReviewIssues.joined(separator: "\n"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("완료된 List과 이후 기록은 자동으로 되돌리지 않습니다. 검토 화면에서 근거 기록과 기준을 확인하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("판정 검토") { showingLevelReview = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .abaSurface(background: Color.orange.opacity(0.08))
    }

    private func evaluateCurrentLevel() {
        guard let level = currentLevel,
              LevelProgressionService.trailingQualifiedDays(for: level, in: program) >= level.requiredDays else { return }
        showingListCompletion = true
        reviewRefreshVersion += 1
    }

    private func finishList(createNext: Bool) {
        do {
            switch try LevelProgressionService.evaluateCurrentLevel(in: program, modelContext: modelContext, createNext: createNext) {
            case .unchanged:
                break
            case let .advanced(from, to):
                notice = ("List\(from) 완료 후 List\(to) 시작", "새 List은 정반응률을 0회 기록 상태에서 다시 집계합니다. 과제 추가 버튼으로 List\(to)의 첫 과제를 등록하세요.")
            case let .completed(number):
                notice = ("List\(number) 완료", "필요할 때 다음 List를 생성할 수 있습니다.")
            }
        } catch {
            notice = ("List 저장 실패", "판정 변경을 저장하지 못해 이전 상태로 되돌렸습니다.")
        }
        reviewRefreshVersion += 1
    }

    private func refreshLevelIntegrity() {
        reviewRefreshVersion += 1
        savePendingChanges()
    }

    private func reintroduceTarget(_ source: TherapyTarget) {
        guard let currentLevel else { return }
        let copy = TherapyTarget(
            name: source.name,
            targetDescription: source.targetDescription,
            maxTrials: source.maxTrials,
            masteryPercent: currentLevel.criterionPercent,
            masterySessions: currentLevel.requiredDays,
            levelNumber: currentLevel.levelNumber
        )
        program.targets.append(copy)
        copy.listTitle = source.listTitle
        savePendingChanges()
    }

    private func savePendingChanges() {
        do {
            try modelContext.save()
            if notice?.title.contains("실패") == true { notice = nil }
        } catch {
            modelContext.rollback()
            notice = ("저장 실패", "변경 내용을 저장하지 못해 마지막 저장 상태로 되돌렸습니다.")
        }
    }
}

private struct ProgramTaskDisclosure: View {
    let group: ProgramLibrary.TaskGroup
    let program: TherapyProgram
    let onReintroduce: (TherapyTarget) -> Void
    let onSelect: (TherapyTarget) -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { isExpanded.toggle() } label: {
                VStack(alignment: .leading, spacing: 10) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            identity
                            Spacer(minLength: 12)
                            recentDate
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            identity
                            recentDate
                        }
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.body.weight(.medium)).foregroundStyle(ABAVisualStyle.leafGreen)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(group.name), \(group.goal)")
            .accessibilityValue(isExpanded ? "펼쳐짐" : "접힘")
            .accessibilityHint("List 목록을 펼치거나 접습니다")
            if isExpanded {
                Divider().padding(.vertical, 12)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(group.targets) { target in
                        ProgramListRow(target: target, program: program) { onSelect(target) }
                            .contextMenu {
                                if !ProgramLibrary.isRecordable(target, in: program), program.currentLevel != nil {
                                    Button("현재 List에 다시 추가") { onReintroduce(target) }
                                }
                            }
                    }
                }
            }
        }
        .abaSurface()
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(group.name).font(.headline)
            if !group.goal.isEmpty {
                Text(group.goal).font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var recentDate: some View {
        Text("최근 기록 \(group.latestDate.map(LessonSchedule.dateText) ?? "없음")")
            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
    }
}

private struct ProgramListRow: View {
    let target: TherapyTarget
    let program: TherapyProgram
    let onSelect: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                title
                Spacer(minLength: 12)
                statusButton
            }
            VStack(alignment: .leading, spacing: 6) {
                title
                statusButton
            }
        }
    }

    private var title: some View {
        Text(target.listTitle.isEmpty ? "List\(target.levelNumber)" : target.listTitle)
            .font(.body).fixedSize(horizontal: false, vertical: true)
    }

    private var statusButton: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: ProgramLibrary.isRecordable(target, in: program) ? "checkmark.circle.fill" : "clock.arrow.circlepath")
                VStack(alignment: .leading, spacing: 1) {
                    if ProgramLibrary.isRecordable(target, in: program) {
                        Text("정반응률 체크")
                            .font(.subheadline.bold())
                    }
                    Text(ProgramLibrary.listStatus(target, in: program))
                        .font(ProgramLibrary.isRecordable(target, in: program) ? .caption : .subheadline.weight(.medium))
                }
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
            }
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(ProgramListActionButtonStyle(prominent: ProgramLibrary.isRecordable(target, in: program)))
        .accessibilityLabel("\(target.listTitle.isEmpty ? target.name : target.listTitle), \(ProgramLibrary.listStatus(target, in: program)), List\(target.levelNumber)")
        .accessibilityHint(ProgramLibrary.isRecordable(target, in: program) ? "정반응 기록 화면 열기" : "기존 기록 확인")
    }
}

private struct ProgramListActionButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(prominent ? Color.white : ABAVisualStyle.leafGreen)
            .background(
                prominent
                    ? ABAVisualStyle.leafGreen.opacity(configuration.isPressed ? 0.78 : 1)
                    : ABAVisualStyle.ivory.opacity(configuration.isPressed ? 0.7 : 1),
                in: Capsule()
            )
            .overlay {
                Capsule().strokeBorder(ABAVisualStyle.leafGreen, lineWidth: prominent ? 0 : 1.5)
            }
            .shadow(color: prominent ? ABAVisualStyle.leafGreen.opacity(0.22) : .clear, radius: 5, y: 2)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private enum SessionMutationSnapshot {
    case trial(number: Int, previous: TrialResponse)
    case bulk(previous: [Int: TrialResponse])
}

struct TargetSessionCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let target: TherapyTarget
    let selectedDate: Date
    let levelLabel: String
    let historicalEditMode: Bool
    let onSessionCompleted: () -> Void
    let onDataChanged: () -> Void

    @State private var showingNote = false
    @State private var showingEditTarget = false
    @State private var showingCompletionConfirmation = false
    @State private var lastMutation: SessionMutationSnapshot?
    @State private var saveError: String?

    init(
        target: TherapyTarget,
        selectedDate: Date,
        levelLabel: String,
        historicalEditMode: Bool = false,
        onSessionCompleted: @escaping () -> Void,
        onDataChanged: @escaping () -> Void = {}
    ) {
        self.target = target
        self.selectedDate = selectedDate
        self.levelLabel = levelLabel
        self.historicalEditMode = historicalEditMode
        self.onSessionCompleted = onSessionCompleted
        self.onDataChanged = onDataChanged
    }

    private var session: TherapySession? {
        target.sessions.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var effectiveTrialCount: Int {
        if let session {
            let recordedMaximum = session.trials.map(\.trialNumber).max() ?? 0
            if recordedMaximum > 0 { return min(max(recordedMaximum, 1), 10) }
            return target.maxTrials
        }
        return target.maxTrials
    }

    private var displayResponses: [TrialResponse] {
        (1...effectiveTrialCount).map { number in
            trial(number: number)?.response ?? .notApplicable
        }
    }

    private var correctCount: Int { displayResponses.filter { $0 == .correct }.count }
    private var promptedCount: Int { displayResponses.filter { $0 == .prompted }.count }
    private var naCount: Int { displayResponses.filter { $0 == .notApplicable }.count }
    private var attemptedCount: Int { correctCount + promptedCount }
    private var accuracy: Double? {
        guard attemptedCount > 0 else { return nil }
        return Double(correctCount) / Double(attemptedCount) * 100
    }

    @State private var pendingBulkResponse: TrialResponse?
    @State private var showingBulkConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let saveError {
                ABAInlineNotice(
                    title: "자동 저장 실패",
                    message: saveError,
                    systemImage: ABASymbol.warning,
                    tint: .red,
                    retryTitle: "다시 저장",
                    retry: retrySave
                )
            }
            if historicalEditMode {
                Label("과거 기록 수정 모드", systemImage: ABASymbol.editHistory)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    targetIdentity
                    Spacer(minLength: 12)
                    accuracySummary
                }
                VStack(alignment: .leading, spacing: 10) {
                    targetIdentity
                    accuracySummary
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 64 : 76, maximum: 110), spacing: 10)],
                spacing: 10
            ) {
                ForEach(1...effectiveTrialCount, id: \.self) { number in
                    VStack(spacing: 4) {
                        Text("\(number)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TrialResponseButton(trialNumber: number, response: displayResponses[number - 1]) {
                            cycleTrial(number: number)
                        } resetAction: {
                            resetTrial(number: number)
                        }
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    bulkButtons
                    Spacer()
                    Text("전체 입력은 확인 후 적용")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) { bulkButtons }
                    Text("전체 입력은 확인 후 적용")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) { secondaryActions }

            if let session {
                Button {
                    requestCompletionToggle()
                } label: {
                    Label(
                        session.completed ? "완료 취소" : "기록 완료",
                        systemImage: session.completed ? ABASymbol.reopen : ABASymbol.completed
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!session.completed && attemptedCount == 0)
            }
        }
        .abaSurface()
        .sheet(isPresented: $showingNote) {
            SessionNoteView(session: ensureSession()) {
                onDataChanged()
            }
        }
        .sheet(isPresented: $showingEditTarget) {
            EditTargetView(target: target)
        }
        .confirmationDialog(
            "모든 Trial을 \(bulkLabel)로 변경하시겠습니까?",
            isPresented: $showingBulkConfirmation,
            titleVisibility: .visible
        ) {
            Button("전체 적용") { applyBulkResponse() }
            Button("취소", role: .cancel) { pendingBulkResponse = nil }
        } message: {
            Text("현재 입력된 \(effectiveTrialCount)개 Trial 값이 모두 변경됩니다.")
        }
        .confirmationDialog(
            "NA가 \(naCount)개 남아 있습니다. 기록을 완료하시겠습니까?",
            isPresented: $showingCompletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("완료 처리") { completeSession() }
            Button("계속 기록", role: .cancel) { }
        } message: {
            Text("NA는 정반응률 계산에서 제외됩니다. 의도적으로 미시행한 Trial이면 그대로 완료할 수 있습니다.")
        }
        .onChange(of: selectedDate) {
            lastMutation = nil
            pendingBulkResponse = nil
            showingBulkConfirmation = false
            showingCompletionConfirmation = false
        }
    }

    @ViewBuilder
    private var bulkButtons: some View {
        Button { requestBulk(.correct) } label: {
            Label("+ 전체", systemImage: ABASymbol.correct)
        }
        .buttonStyle(.bordered)

        Button { requestBulk(.prompted) } label: {
            Label("- 전체", systemImage: ABASymbol.prompted)
        }
        .buttonStyle(.bordered)

        Button { requestBulk(.notApplicable) } label: {
            Label("NA 전체", systemImage: ABASymbol.reset)
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private var statBadges: some View {
        StatBadge(title: "+", value: correctCount)
        StatBadge(title: "-", value: promptedCount)
        StatBadge(title: "NA", value: naCount)
    }

    @ViewBuilder
    private var secondaryActions: some View {
        Button {
            showingNote = true
        } label: {
            Label("메모", systemImage: ABASymbol.note)
        }
        .buttonStyle(.bordered)

        if lastMutation != nil {
            Button {
                undoLastMutation()
            } label: {
                Label("실행 취소", systemImage: ABASymbol.undo)
            }
            .buttonStyle(.bordered)
        }

        if !historicalEditMode {
            Button {
                showingEditTarget = true
            } label: {
                Label("과제 수정", systemImage: "pencil")
            }
            .buttonStyle(.bordered)

            Menu {
                ForEach(TargetStatus.allCases) { status in
                    Button(status.rawValue) {
                        target.status = status
                        persistChanges()
                    }
                }
            } label: {
                Label("상태", systemImage: ABASymbol.more)
            }
            .buttonStyle(.bordered)
        }
    }

    private var targetIdentity: some View {
        VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    Text(target.displayName)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    sessionStatusBadge
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(target.displayName)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    sessionStatusBadge
                }
            }
            if !target.targetDescription.isEmpty {
                HStack(spacing: 4) {
                    Text("목표").font(.subheadline).foregroundStyle(.secondary)
                    ABAHelpButton(title: target.name, message: target.targetDescription)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var levelBadge: some View {
        Text(levelLabel)
            .font(.caption.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
    }

    private var sessionStatusBadge: some View {
        ABAStatusPill(
            title: sessionStatusText,
            systemImage: sessionStatusIcon,
            tint: sessionStatusColor
        )
    }

    private var accuracySummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            accuracyValue
            HStack(spacing: 8) { statBadges }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("현재 반응 개수")
                .accessibilityValue("정반응 \(correctCount)개, 촉구반응 \(promptedCount)개, 미기록 \(naCount)개")
        }
    }

    @ViewBuilder
    private var accuracyValue: some View {
        if let accuracy {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(accuracy, format: .number.precision(.fractionLength(0...1)))%")
                    .font(.title2.bold())
                    .monospacedDigit()
                Text("현재 정반응률")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("—")
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
                Text("아직 기록 없음")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sessionStatusText: String {
        if session?.completed == true { return "완료" }
        if attemptedCount > 0 { return "진행 \(attemptedCount)/\(effectiveTrialCount)" }
        if let session, !session.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "메모만" }
        return "미시작"
    }

    private var sessionStatusColor: Color {
        if session?.completed == true { return .green }
        if attemptedCount > 0 { return .orange }
        return .secondary
    }

    private var sessionStatusIcon: String {
        if session?.completed == true { return ABASymbol.completed }
        if attemptedCount > 0 { return ABASymbol.inProgress }
        if let session, !session.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ABASymbol.note
        }
        return ABASymbol.empty
    }

    private var bulkLabel: String {
        guard let pendingBulkResponse else { return "선택 상태" }
        switch pendingBulkResponse {
        case .correct: return "+ (정반응)"
        case .prompted: return "- (촉구반응)"
        case .notApplicable: return "NA"
        }
    }

    private func requestBulk(_ response: TrialResponse) {
        pendingBulkResponse = response
        showingBulkConfirmation = true
    }

    private func applyBulkResponse() {
        guard let response = pendingBulkResponse else { return }
        let currentSession = ensureSession()
        var previous: [Int: TrialResponse] = [:]

        for number in 1...effectiveTrialCount {
            let record = ensureTrial(number: number)
            previous[number] = record.response
            record.response = response
        }

        lastMutation = .bulk(previous: previous)
        pendingBulkResponse = nil
        markSessionChanged(currentSession)
    }

    private func trial(number: Int) -> TrialRecord? {
        session?.trials.first { $0.trialNumber == number }
    }

    @discardableResult
    private func ensureSession() -> TherapySession {
        if let session { return session }
        let newSession = TherapySession(date: selectedDate)
        for number in 1...target.maxTrials {
            newSession.trials.append(TrialRecord(trialNumber: number))
        }
        target.sessions.append(newSession)
        return newSession
    }

    private func ensureTrial(number: Int) -> TrialRecord {
        let currentSession = ensureSession()
        if let existing = currentSession.trials.first(where: { $0.trialNumber == number }) {
            return existing
        }
        let newTrial = TrialRecord(trialNumber: number)
        currentSession.trials.append(newTrial)
        return newTrial
    }

    private func cycleTrial(number: Int) {
        let record = ensureTrial(number: number)
        let previous = record.response
        record.response = previous.next
        lastMutation = .trial(number: number, previous: previous)
        markSessionChanged(ensureSession())
    }

    private func resetTrial(number: Int) {
        let record = ensureTrial(number: number)
        guard record.response != .notApplicable else { return }
        let previous = record.response
        record.response = .notApplicable
        lastMutation = .trial(number: number, previous: previous)
        markSessionChanged(ensureSession())
    }

    private func undoLastMutation() {
        guard let lastMutation else { return }
        let currentSession = ensureSession()

        switch lastMutation {
        case let .trial(number, previous):
            ensureTrial(number: number).response = previous
        case let .bulk(previous):
            for (number, response) in previous {
                ensureTrial(number: number).response = response
            }
        }

        self.lastMutation = nil
        markSessionChanged(currentSession)
    }

    private func requestCompletionToggle() {
        guard let session else { return }
        if session.completed {
            session.completed = false
            markSessionChanged(session)
            return
        }

        if naCount > 0 {
            showingCompletionConfirmation = true
        } else {
            completeSession()
        }
    }

    private func completeSession() {
        let currentSession = ensureSession()
        currentSession.completed = true
        markSessionChanged(currentSession)
        onSessionCompleted()
    }

    private func markSessionChanged(_ session: TherapySession) {
        session.updatedAt = Date()
        persistChanges()
    }

    private func persistChanges() {
        do {
            try modelContext.save()
            saveError = nil
            onDataChanged()
        } catch {
            modelContext.rollback()
            lastMutation = nil
            saveError = "입력은 저장되지 않았고 마지막 저장 상태로 복구했습니다. 저장 공간과 기기 상태를 확인한 뒤 다시 입력하거나 재시도하세요."
        }
    }

    private func retrySave() {
        do {
            try modelContext.save()
            saveError = nil
            onDataChanged()
        } catch {
            saveError = "아직 저장할 수 없습니다. 기록은 마지막으로 성공한 저장 상태에 있습니다."
        }
    }
}

private struct TrialResponseButton: View {
    let trialNumber: Int
    let response: TrialResponse
    let action: () -> Void
    let resetAction: () -> Void

    @State private var longPressTriggered = false
    @State private var feedbackTrigger = 0
    @ScaledMetric(relativeTo: .title2) private var minimumHeight: CGFloat = 64
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        Button {
            if longPressTriggered {
                longPressTriggered = false
                return
            }
            feedbackTrigger += 1
            action()
        } label: {
            VStack(spacing: 2) {
                Text(response.rawValue)
                    .font(.title2.bold())
                Text(response.compactLabel)
                    .font(.caption2.weight(.medium))
            }
                .frame(maxWidth: .infinity)
                .frame(minHeight: minimumHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            TrialButtonStyle(
                response: response,
                increasedContrast: colorSchemeContrast == .increased
            )
        )
        .sensoryFeedback(.selection, trigger: feedbackTrigger)
        .onLongPressGesture(minimumDuration: 0.55) {
            longPressTriggered = true
            feedbackTrigger += 1
            resetAction()
        }
        .accessibilityIdentifier("trial-\(trialNumber)")
        .accessibilityLabel("Trial \(trialNumber), \(response.accessibilityLabel)")
        .accessibilityValue(response.rawValue)
        .accessibilityHint("탭하여 NA, 정반응, 촉구반응 순서로 변경합니다. 길게 누르면 NA로 초기화합니다.")
        .accessibilityAction(named: "NA로 초기화") {
            feedbackTrigger += 1
            resetAction()
        }
    }
}

private struct TrialButtonStyle: ButtonStyle {
    let response: TrialResponse
    let increasedContrast: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(background.opacity(configuration.isPressed ? 0.65 : 1))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(border, lineWidth: increasedContrast ? 2.5 : 1.5)
            }
            .compositingGroup()
            .clipShape(.rect(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }

    private var background: Color {
        switch response {
        case .notApplicable: return Color(uiColor: .secondarySystemBackground)
        case .correct: return Color.green.opacity(increasedContrast ? 0.25 : 0.16)
        case .prompted: return Color.orange.opacity(increasedContrast ? 0.25 : 0.16)
        }
    }

    private var foreground: Color {
        switch response {
        case .notApplicable: return .secondary
        case .correct: return .green
        case .prompted: return .orange
        }
    }

    private var border: Color {
        switch response {
        case .notApplicable: return .gray.opacity(0.35)
        case .correct: return .green.opacity(0.7)
        case .prompted: return .orange.opacity(0.7)
        }
    }
}

private struct StatBadge: View {
    let title: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(title).fontWeight(.semibold)
            Text("\(value)")
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

private extension TrialResponse {
    var compactLabel: String {
        switch self {
        case .notApplicable: return "미기록"
        case .correct: return "정반응"
        case .prompted: return "촉구"
        }
    }
}

private struct SessionNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let session: TherapySession
    let onSaved: () -> Void

    @State private var note: String
    @State private var saveError: String?

    init(session: TherapySession, onSaved: @escaping () -> Void) {
        self.session = session
        self.onSaved = onSaved
        _note = State(initialValue: session.note)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("세션 메모", text: $note, axis: .vertical)
                    .lineLimit(4...10)
            }
            .navigationTitle("세션 메모")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
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
        guard session.note != note else { dismiss(); return }
        session.note = note
        session.updatedAt = Date()
        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = "메모를 저장하지 못했습니다. 작성한 내용은 이 화면에 남아 있습니다."
        }
    }
}

private struct AddTargetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let program: TherapyProgram
    let level: ProgramLevel
    @Query private var allPrograms: [TherapyProgram]

    @State private var name = ""
    @State private var description = ""
    @State private var listTitle = ""
    @State private var templateSearch = ""
    @State private var maxTrials = 10
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("과제") {
                    DisclosureGroup("이 프로그램의 이전 과제 불러오기") {
                        TextField("과제 검색", text: $templateSearch)
                        ForEach(ProgramLibrary.templates(name: program.name, category: program.category, programs: allPrograms).filter {
                            templateSearch.isEmpty || $0.displayName.localizedCaseInsensitiveContains(templateSearch)
                        }) { source in
                            Button(source.displayName) {
                                name = source.name
                                description = source.targetDescription
                                listTitle = source.listTitle
                                maxTrials = source.maxTrials
                            }
                        }
                    }
                    TextField("과제명", text: $name)
                    TextField("목표", text: $description, axis: .vertical)
                    TextField("\(level.label) 제목", text: $listTitle)
                }

                Section {
                    Stepper("최대 시행 횟수: \(maxTrials)", value: $maxTrials, in: 1...10)
                } header: {
                    ABASectionHeading(title: "기록", help: "NA → + → − 순서로 눌러 기록합니다. +는 독립 정반응, −는 촉구반응입니다. NA는 정반응률 계산에서 제외됩니다.")
                }

                Section {
                    LabeledContent("정반응률", value: "\(Int(level.criterionPercent))%")
                    LabeledContent("연속 기록일", value: "\(level.requiredDays)일")
                } header: {
                    ABASectionHeading(title: "List 종료 기준", help: "과제별 개별 기준 대신 \(level.label)의 공통 기준을 사용합니다. 같은 List의 모든 진행 과제가 같은 기록일에 기준을 달성해야 합니다. 수업이 없는 날짜는 건너뜁니다.")
                }
            }
            .navigationTitle("과제 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        let target = TherapyTarget(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            targetDescription: description,
                            maxTrials: maxTrials,
                            masteryPercent: level.criterionPercent,
                            masterySessions: level.requiredDays,
                            levelNumber: level.levelNumber
                        )
                        program.targets.append(target)
                        target.listTitle = listTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        do {
                            try modelContext.save()
                            dismiss()
                        } catch {
                            modelContext.rollback()
                            saveError = "과제를 저장하지 못했습니다. 입력 내용은 화면에 남아 있습니다."
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

private struct LevelSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let program: TherapyProgram
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                ForEach(program.orderedLevels) { level in
                    LevelSettingsSection(level: level)
                }

                Section {
                    Text("현재 List의 모든 진행 과제가 기준을 충족하면 완료할 수 있습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    ABASectionHeading(title: "List 종료 안내", help: "현재 List에서 모든 진행 과제가 같은 기록일에 기준 정반응률을 달성하고, 그 상태가 설정한 기록일 수만큼 연속되면 List 완료 기준을 충족합니다. 완료할 때 다음 List 생성 여부를 확인합니다.")
                }
            }
            .navigationTitle("List 설정")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        do {
                            try modelContext.save()
                            dismiss()
                        } catch {
                            modelContext.rollback()
                            saveError = "List 설정을 저장하지 못했습니다. 이전 설정으로 복구했습니다."
                        }
                    }
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

private struct LevelSettingsSection: View {
    @Bindable var level: ProgramLevel

    var body: some View {
        Section(level.label) {
            LabeledContent("상태", value: level.status.rawValue)
            Stepper(
                "종료 기준 일수: \(level.requiredDays)일",
                value: $level.requiredDays,
                in: 2...30
            )
            LabeledContent("정반응률 기준", value: "\(Int(level.criterionPercent))%")
            if level.status == .completed, let completedAt = level.completedAt {
                LabeledContent("완료일", value: completedAt.formatted(date: .numeric, time: .omitted))
            }
        }
        .disabled(level.status == .completed)
    }
}

private struct EditProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let program: TherapyProgram
    @State private var name: String
    @State private var category: String
    @State private var description: String
    @State private var saveError: String?

    init(program: TherapyProgram) {
        self.program = program
        _name = State(initialValue: program.name)
        _category = State(initialValue: program.category)
        _description = State(initialValue: program.programDescription)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("프로그램 정보") {
                    TextField("프로그램명", text: $name)
                    TextField("영역", text: $category)
                    TextField("목표", text: $description, axis: .vertical)
                }
            }
            .navigationTitle("프로그램 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("저장 실패", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) { Button("확인", role: .cancel) { saveError = nil } }
            message: { Text(saveError ?? "") }
        }
    }

    private func save() {
        program.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        program.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        program.programDescription = description
        do { try modelContext.save(); dismiss() }
        catch { modelContext.rollback(); saveError = "프로그램 정보를 저장하지 못했습니다. 기존 정보는 보존되었습니다." }
    }
}

private struct EditTargetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let target: TherapyTarget
    @State private var name: String
    @State private var description: String
    @State private var listTitle: String
    @State private var maxTrials: Int
    @State private var saveError: String?

    init(target: TherapyTarget) {
        self.target = target
        _name = State(initialValue: target.name)
        _description = State(initialValue: target.targetDescription)
        _listTitle = State(initialValue: target.listTitle)
        _maxTrials = State(initialValue: target.maxTrials)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("과제 정보") {
                    TextField("과제명", text: $name)
                    TextField("목표", text: $description, axis: .vertical)
                    TextField("List\(target.levelNumber) 제목", text: $listTitle)
                    Stepper("앞으로 사용할 시행 횟수: \(maxTrials)", value: $maxTrials, in: 1...10)
                }
                Section {
                    Text("시행 횟수 변경은 새 Session부터 적용됩니다. 기존 Session의 Trial 수와 정반응률은 바뀌지 않습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("과제 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("저장 실패", isPresented: Binding(
                get: { saveError != nil }, set: { if !$0 { saveError = nil } }
            )) { Button("확인", role: .cancel) { saveError = nil } }
            message: { Text(saveError ?? "") }
        }
    }

    private func save() {
        target.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        target.targetDescription = description
        target.listTitle = listTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        target.maxTrials = maxTrials
        do { try modelContext.save(); dismiss() }
        catch { modelContext.rollback(); saveError = "과제 정보를 저장하지 못했습니다. 기존 정보는 보존되었습니다." }
    }
}

private struct LevelReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let program: TherapyProgram
    let issues: [String]
    let openSettings: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("확인된 차이") {
                    ForEach(issues, id: \.self) { issue in
                        Label(issue, systemImage: ABASymbol.review)
                    }
                }
                Section("안전한 처리") {
                    Text("과거 기록 수정 전의 완료 상태와 이후 List은 유지됩니다. 앱이 뒤 List을 삭제하거나 자동으로 과거 판정을 되돌리지 않습니다.")
                    Button("List 기준 보기", action: openSettings)
                }
                Section("권장 확인") {
                    Text("완료일 전 기록, 해당 List의 모든 과제, 연속 기록일 수와 정반응률 기준을 차례로 확인하세요.")
                }
            }
            .navigationTitle("List 판정 검토")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
        }
    }
}
