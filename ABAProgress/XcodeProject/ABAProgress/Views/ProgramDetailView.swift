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
    @State private var showClosedTargets = false
    @State private var reviewRefreshVersion = 0

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
                Button {
                    showingLevelSettings = true
                } label: {
                    Label("레벨 설정", systemImage: ABASymbol.settings)
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
        try? modelContext.save()
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
            Text("완료된 레벨은 자동으로 되돌리지 않습니다. 원본 기록과 완료 기준을 확인한 뒤 필요한 경우 레벨 설정을 수정하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .abaSurface(background: Color.orange.opacity(0.08))
    }

    private func evaluateCurrentLevel() {
        _ = LevelProgressionService.evaluateCurrentLevel(in: program, modelContext: modelContext)
        reviewRefreshVersion += 1
    }

    private func refreshLevelIntegrity() {
        reviewRefreshVersion += 1
        try? modelContext.save()
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
        try? modelContext.save()
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
    @State private var showingCompletionConfirmation = false
    @State private var lastMutation: SessionMutationSnapshot?

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
            Menu {
                ForEach(TargetStatus.allCases) { status in
                    Button(status.rawValue) {
                        target.status = status
                        try? modelContext.save()
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
        try? modelContext.save()
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
        try? modelContext.save()
        onDataChanged()
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
    @Bindable var session: TherapySession
    let onSaved: () -> Void

    @State private var initialNote = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("세션 메모", text: $session.note, axis: .vertical)
                    .lineLimit(4...10)
            }
            .navigationTitle("세션 메모")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .onAppear { initialNote = session.note }
        .onDisappear { saveIfNeeded() }
    }

    private func saveIfNeeded() {
        guard session.note != initialNote else { return }
        session.updatedAt = Date()
        try? modelContext.save()
        onSaved()
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
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct LevelSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let program: TherapyProgram

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
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
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
