import SwiftUI
import SwiftData
import Charts

struct ProgramDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let child: ChildProfile
    let program: TherapyProgram

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showingAddTarget = false
    @State private var showingLevelSettings = false
    @State private var showingEditProgram = false
    @State private var showingLevelReview = false
    @State private var showClosedTargets = false
    @State private var reviewRefreshVersion = 0
    @State private var notice: (title: String, message: String)?

    private var currentLevel: ProgramLevel? { program.currentLevel }

    private var levelReviewIssues: [String] {
        _ = reviewRefreshVersion
        return LevelProgressionService.integrityIssues(in: program)
    }

    private var activeTargets: [TherapyTarget] {
        guard let level = currentLevel else { return [] }
        return program.targets
            .filter { $0.levelNumber == level.levelNumber && $0.status == .active }
            .sorted { $0.startDate < $1.startDate }
    }

    private var closedTargets: [TherapyTarget] {
        program.targets
            .filter { $0.status != .active }
            .sorted {
                if $0.levelNumber == $1.levelNumber { return $0.startDate < $1.startDate }
                return $0.levelNumber < $1.levelNumber
            }
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
                levelHeader
                if !levelReviewIssues.isEmpty { levelReviewBanner }

                if activeTargets.isEmpty {
                    ContentUnavailableView(
                        "현재 레벨에 진행 과제가 없습니다",
                        systemImage: ABASymbol.targets,
                        description: Text("과제를 추가하면 현재 \(currentLevel?.label ?? "레벨")에 귀속되고 즉시 Trial을 기록할 수 있습니다.")
                    )
                    .padding(.top, 24)
                } else {
                    ForEach(activeTargets) { target in
                        TargetSessionCard(
                            target: target,
                            selectedDate: selectedDate,
                            levelLabel: currentLevel?.label ?? "",
                            onSessionCompleted: evaluateCurrentLevel,
                            onDataChanged: refreshLevelIntegrity
                        )
                    }
                }

                if !closedTargets.isEmpty {
                    DisclosureGroup("종결 과제 \(closedTargets.count)개", isExpanded: $showClosedTargets) {
                        VStack(spacing: 10) {
                            ForEach(closedTargets) { target in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(target.name).font(.headline)
                                        Text("L\(target.levelNumber) · \(target.status.rawValue)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("현재 레벨에 다시 추가") {
                                        reintroduceTarget(target)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(currentLevel == nil)
                                }
                                .abaSurface(padding: 12, background: ABAVisualStyle.tertiarySurface)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .abaSurface(background: Color(uiColor: .systemBackground))
                }
            }
            .padding()
            .frame(maxWidth: ABAVisualStyle.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .background(ABAVisualStyle.groupedBackground)
        .navigationTitle(program.name)
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
                        Label("레벨 설정", systemImage: ABASymbol.settings)
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
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    programIdentity
                    Spacer()
                    HStack(spacing: 8) {
                        DatePicker(
                            "기록 날짜",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        if !Calendar.current.isDateInToday(selectedDate) {
                            Button("오늘") { selectedDate = Calendar.current.startOfDay(for: Date()) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    programIdentity
                    HStack(spacing: 8) {
                        DatePicker(
                            "기록 날짜",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        if !Calendar.current.isDateInToday(selectedDate) {
                            Button("오늘") { selectedDate = Calendar.current.startOfDay(for: Date()) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }

            ABASectionHeading(title: "반응 기록", help: "버튼을 누르면 NA → + → − → NA 순서로 바뀝니다. +는 독립 정반응, −는 촉구반응입니다. NA는 미실시·미기록이며 정반응률 계산에서 제외합니다. 길게 누르면 NA로 초기화합니다. 변경 내용은 자동 저장됩니다.")
        }
        .abaSurface()
    }

    private var programIdentity: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(child.name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(program.name)
                .font(.title2.bold())
        }
    }

    private var levelHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(currentLevel?.label ?? "레벨 없음")
                    .font(.title3.bold())
                Spacer()
                ABAHelpButton(title: "레벨 종료 기준", message: "현재 레벨의 모든 진행 과제가 설정한 정반응률을 같은 기록일에 달성해야 합니다. 수업이 없는 날짜는 건너뜁니다. 설정한 연속 기록일 기준을 충족하면 현재 레벨을 종료하고 다음 레벨을 자동 생성합니다.")
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
            Label("과거 기록 수정으로 레벨 판정 확인이 필요합니다", systemImage: ABASymbol.review)
                .font(.headline)
                .foregroundStyle(.orange)
            Text(levelReviewIssues.joined(separator: "\n"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("완료된 레벨과 이후 기록은 자동으로 되돌리지 않습니다. 검토 화면에서 근거 기록과 기준을 확인하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("판정 검토") { showingLevelReview = true }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .abaSurface(background: Color.orange.opacity(0.08))
    }

    private func evaluateCurrentLevel() {
        do {
            switch try LevelProgressionService.evaluateCurrentLevel(in: program, modelContext: modelContext) {
            case .unchanged:
                break
            case let .advanced(from, to):
                notice = ("L\(from) 완료 · L\(to) 시작", "새 레벨은 정반응률을 0회 기록 상태에서 다시 집계합니다. 과제 추가 버튼으로 L\(to)의 첫 과제를 등록하세요.")
            }
        } catch {
            notice = ("레벨 저장 실패", "판정 변경을 저장하지 못해 이전 상태로 되돌렸습니다.")
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

    private var recentEntries: [MiniProgressPoint] {
        let sessions = target.sessions
            .filter { $0.completed && $0.accuracy != nil }
            .sorted { $0.date < $1.date }
            .suffix(5)
        return sessions.enumerated().map { index, session in
            MiniProgressPoint(id: session.id, index: index, date: session.date, accuracy: session.accuracy ?? 0)
        }
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

            if recentEntries.count >= 2 {
                MiniProgressChart(entries: recentEntries, criterion: target.masteryPercent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    statBadges
                    Spacer()
                    secondaryActions
                }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) { statBadges }
                    HStack(spacing: 8) { secondaryActions }
                }
            }

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
                    levelBadge
                    Text(target.name)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    sessionStatusBadge
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        levelBadge
                        Text(target.name)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    sessionStatusBadge
                }
            }
            if !target.targetDescription.isEmpty {
                HStack {
                    Text("과제 안내").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    ABAHelpButton(title: target.name, message: target.targetDescription)
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

    @ViewBuilder
    private var accuracySummary: some View {
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

private struct MiniProgressPoint: Identifiable {
    let id: UUID
    let index: Int
    let date: Date
    let accuracy: Double
}

private struct MiniProgressChart: View {
    let entries: [MiniProgressPoint]
    let criterion: Double

    var body: some View {
        Chart(entries) { point in
            LineMark(
                x: .value("세션", point.index),
                y: .value("정반응률", point.accuracy)
            )
            .lineStyle(StrokeStyle(lineWidth: 2))

            PointMark(
                x: .value("세션", point.index),
                y: .value("정반응률", point.accuracy)
            )
            .symbolSize(18)

            RuleMark(y: .value("기준", criterion))
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityLabel("최근 \(entries.count)회 경과 그래프")
        .accessibilityValue("최근 정반응률 \(Int(entries.last?.accuracy.rounded() ?? 0))퍼센트, 습득 기준 \(Int(criterion.rounded()))퍼센트")
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

    @State private var name = ""
    @State private var description = ""
    @State private var maxTrials = 10
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("과제") {
                    LabeledContent("귀속 레벨", value: level.label)
                    TextField("과제명", text: $name)
                    TextField("설명 (선택)", text: $description, axis: .vertical)
                }

                Section("기록") {
                    Stepper("최대 시행 횟수: \(maxTrials)", value: $maxTrials, in: 1...10)
                    ABASectionHeading(title: "기록 방식", help: "NA → + → − 순서로 눌러 기록합니다. +는 독립 정반응, −는 촉구반응입니다. NA는 정반응률 계산에서 제외됩니다.")
                }

                Section("레벨 종료 기준") {
                    LabeledContent("정반응률", value: "\(Int(level.criterionPercent))%")
                    LabeledContent("연속 기록일", value: "\(level.requiredDays)일")
                    ABASectionHeading(title: "판정 방법", help: "과제별 개별 기준 대신 \(level.label)의 공통 기준을 사용합니다. 같은 레벨의 모든 진행 과제가 같은 기록일에 기준을 달성해야 합니다. 수업이 없는 날짜는 건너뜁니다.")
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
                    ABASectionHeading(title: "레벨 종료 안내", help: "현재 레벨에서 모든 진행 과제가 같은 기록일에 기준 정반응률을 달성하고, 그 상태가 설정한 기록일 수만큼 연속되면 레벨이 자동 종료됩니다. 이후 다음 레벨이 자동 생성됩니다.")
                }
            }
            .navigationTitle("레벨 설정")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        do {
                            try modelContext.save()
                            dismiss()
                        } catch {
                            modelContext.rollback()
                            saveError = "레벨 설정을 저장하지 못했습니다. 이전 설정으로 복구했습니다."
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
                    TextField("설명", text: $description, axis: .vertical)
                }
            }
            .navigationTitle("프로그램 수정")
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
        program.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        program.category = category
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
    @State private var maxTrials: Int
    @State private var saveError: String?

    init(target: TherapyTarget) {
        self.target = target
        _name = State(initialValue: target.name)
        _description = State(initialValue: target.targetDescription)
        _maxTrials = State(initialValue: target.maxTrials)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("과제 정보") {
                    TextField("과제명", text: $name)
                    TextField("설명", text: $description, axis: .vertical)
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
                    Text("과거 기록 수정 전의 완료 상태와 이후 레벨은 유지됩니다. 앱이 뒤 레벨을 삭제하거나 자동으로 과거 판정을 되돌리지 않습니다.")
                    Button("레벨 기준 보기", action: openSettings)
                }
                Section("권장 확인") {
                    Text("완료일 전 기록, 해당 레벨의 모든 과제, 연속 기록일 수와 정반응률 기준을 차례로 확인하세요.")
                }
            }
            .navigationTitle("레벨 판정 검토")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("닫기") { dismiss() } } }
        }
    }
}
