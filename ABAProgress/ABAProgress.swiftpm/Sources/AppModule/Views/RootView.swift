import SwiftUI
import SwiftData
import UIKit

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \ChildProfile.name) private var children: [ChildProfile]

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                CompactRootView(children: children)
            } else {
                RegularRootView(children: children)
            }
        }
        .tint(ABAVisualStyle.brand)
    }
}

private struct CompactRootView: View {
    let children: [ChildProfile]
    @State private var selection: AppDestination = .today

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayOverviewView(children: children)
            }
            .tabItem { Label(AppDestination.today.title, systemImage: AppDestination.today.systemImage) }
            .tag(AppDestination.today)

            NavigationStack {
                ChildrenListView(children: children)
            }
            .tabItem { Label(AppDestination.children.title, systemImage: AppDestination.children.systemImage) }
            .tag(AppDestination.children)

            NavigationStack {
                HistoryCalendarView(children: children)
            }
            .tabItem { Label(AppDestination.history.title, systemImage: AppDestination.history.systemImage) }
            .tag(AppDestination.history)

            NavigationStack {
                ReportHomeView(children: children)
            }
            .tabItem { Label(AppDestination.reports.title, systemImage: AppDestination.reports.systemImage) }
            .tag(AppDestination.reports)
        }
    }
}

private struct RegularRootView: View {
    let children: [ChildProfile]
    @State private var selection: AppDestination? = .today

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("워크스페이스") {
                    ForEach(AppDestination.allCases) { destination in
                        Label(destination.title, systemImage: destination.systemImage)
                            .tag(destination)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("ABA Progress")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            NavigationStack {
                switch selection ?? .today {
                case .children:
                    ChildrenListView(children: children)
                case .today:
                    TodayOverviewView(children: children)
                case .history:
                    HistoryCalendarView(children: children)
                case .reports:
                    ReportHomeView(children: children)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

private enum AppDestination: String, CaseIterable, Identifiable {
    case today
    case children
    case history
    case reports

    var id: Self { self }

    var title: String {
        switch self {
        case .today: return "오늘"
        case .children: return "아동"
        case .history: return "기록"
        case .reports: return "보고서"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return ABASymbol.today
        case .children: return ABASymbol.children
        case .history: return ABASymbol.history
        case .reports: return ABASymbol.report
        }
    }
}

struct ChildrenListView: View {
    @Environment(\.modelContext) private var modelContext
    let children: [ChildProfile]
    @State private var showingAddChild = false
    @State private var childPendingDeletion: ChildProfile?
    @State private var deletionError: String?
    @State private var searchText = ""

    private var displayedChildren: [ChildProfile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return children }
        return children.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if children.isEmpty {
                ContentUnavailableView(
                    "등록된 아동이 없습니다",
                    systemImage: ABASymbol.addChild,
                    description: Text("아동을 추가한 뒤 프로그램과 실시간 Trial 기록을 시작하세요.")
                )
            } else if displayedChildren.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                Section {
                    ForEach(displayedChildren) { child in
                        NavigationLink {
                            ChildDetailView(child: child)
                        } label: {
                            ChildSummaryRow(child: child)
                        }
                    }
                    .onDelete(perform: deleteChildren)
                }
            }
        }
        .navigationTitle("아동")
        .searchable(text: $searchText, prompt: "아동 이름 검색")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddChild = true
                } label: {
                    Label("아동 추가", systemImage: ABASymbol.add)
                }
            }
        }
        .sheet(isPresented: $showingAddChild) {
            AddChildView()
        }
        .confirmationDialog(
            "아동과 모든 치료 기록을 삭제하시겠습니까?",
            isPresented: Binding(
                get: { childPendingDeletion != nil },
                set: { if !$0 { childPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { confirmChildDeletion() }
            Button("취소", role: .cancel) { childPendingDeletion = nil }
        } message: {
            Text("아동의 프로그램·수업 기록과 저장된 보고서 초안을 삭제합니다. 이미 공유·저장한 PDF와 기기 백업은 별도로 관리해야 합니다.")
        }
        .alert("삭제 확인", isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) {
            Button("확인") { deletionError = nil }
        } message: { Text(deletionError ?? "") }
    }

    private func deleteChildren(at offsets: IndexSet) {
        guard let index = offsets.first, displayedChildren.indices.contains(index) else { return }
        childPendingDeletion = displayedChildren[index]
    }

    private func confirmChildDeletion() {
        guard let childPendingDeletion else { return }
        let childID = childPendingDeletion.id
        modelContext.delete(childPendingDeletion)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deletionError = "아동 기록을 삭제하지 못했습니다. 다시 시도하세요."
            self.childPendingDeletion = nil
            return
        }
        self.childPendingDeletion = nil
        do { try ReportDraftStore.remove(childID: childID) }
        catch { deletionError = "아동 기록은 삭제했지만 보고서 초안 정리에 실패했습니다. 기기 내 보고서 데이터 정리가 필요합니다." }
    }
}

private struct ChildSummaryRow: View {
    let child: ChildProfile

    private var latestSessionDate: Date? {
        child.programs.flatMap(\.targets).flatMap(\.sessions).filter(\.hasMeaningfulData).map(\.date).max()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: ABASymbol.child)
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(child.name).font(.headline)
                HStack(spacing: 8) {
                    Text("프로그램 \(child.programs.count)개")
                    if let latestSessionDate {
                        Text("최근 \(latestSessionDate.formatted(.dateTime.month().day()))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct TodayOverviewView: View {
    let children: [ChildProfile]
    private let today = Calendar.current.startOfDay(for: Date())

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if children.isEmpty {
                    ContentUnavailableView(
                        "오늘 기록할 아동이 없습니다",
                        systemImage: ABASymbol.startSession,
                        description: Text("먼저 아동을 등록하세요.")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(children) { child in
                        TodayChildCard(child: child, today: today)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(ABAVisualStyle.groupedBackground)
        .navigationTitle("오늘")
    }
}

private struct TodayChildCard: View {
    let child: ChildProfile
    let today: Date

    private var programs: [TherapyProgram] { child.programs.sorted { $0.createdAt < $1.createdAt } }

    private var recordablePrograms: [TherapyProgram] {
        programs.filter { program in
            guard let level = program.currentLevel else { return false }
            return program.targets.contains {
                $0.levelNumber == level.levelNumber && $0.status == .active
            }
        }
    }

    private var completedProgramCount: Int {
        recordablePrograms.filter { program in
            guard let level = program.currentLevel else { return false }
            let targets = program.targets.filter { $0.levelNumber == level.levelNumber && $0.status == .active }
            guard !targets.isEmpty else { return false }
            return targets.allSatisfy { target in
                target.sessions.contains { $0.completed && Calendar.current.isDate($0.date, inSameDayAs: today) }
            }
        }.count
    }

    private var todayAccuracies: [Double] {
        child.programs.flatMap(\.targets).flatMap(\.sessions)
            .filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
            .compactMap(\.accuracy)
    }

    private var average: Double? {
        guard !todayAccuracies.isEmpty else { return nil }
        return todayAccuracies.reduce(0, +) / Double(todayAccuracies.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name).font(.title3.bold())
                    Text("오늘 진행 현황")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink {
                    ChildDetailView(child: child)
                } label: {
                    Label("아동 열기", systemImage: ABASymbol.open)
                }
                    .buttonStyle(.bordered)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                spacing: 12
            ) {
                MetricTile(title: "완료 프로그램", value: "\(completedProgramCount)/\(recordablePrograms.count)", systemImage: ABASymbol.today)
                MetricTile(title: "평균 정반응률", value: average.map { String(format: "%.0f%%", $0) } ?? "—", systemImage: ABASymbol.accuracy)
            }

            if !programs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                        NavigationLink {
                            ProgramDetailView(child: child, program: program)
                        } label: {
                            TodayProgramStatusCompact(program: program, today: today)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < programs.count - 1 { Divider() }
                    }
                }
            }
        }
        .abaSurface()
        .accessibilityElement(children: .contain)
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(12)
        .background(ABAVisualStyle.tertiarySurface, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

private struct TodayProgramStatusCompact: View {
    let program: TherapyProgram
    let today: Date

    private var activeTargets: [TherapyTarget] {
        guard let level = program.currentLevel else { return [] }
        return program.targets.filter { $0.levelNumber == level.levelNumber && $0.status == .active }
    }

    private var completedCount: Int {
        activeTargets.filter { target in
            target.sessions.contains { $0.completed && Calendar.current.isDate($0.date, inSameDayAs: today) }
        }.count
    }

    private var inProgressCount: Int {
        activeTargets.filter { target in
            target.sessions.contains {
                $0.hasMeaningfulData && !$0.completed && Calendar.current.isDate($0.date, inSameDayAs: today)
            }
        }.count
    }

    private var statusText: String {
        if !activeTargets.isEmpty && completedCount == activeTargets.count { return "완료" }
        if inProgressCount > 0 || completedCount > 0 { return "진행 중" }
        if activeTargets.isEmpty { return "과제 없음" }
        return "미기록"
    }

    private var statusIcon: String {
        if !activeTargets.isEmpty && completedCount == activeTargets.count { return ABASymbol.completed }
        if inProgressCount > 0 || completedCount > 0 { return ABASymbol.inProgress }
        if activeTargets.isEmpty { return ABASymbol.warning }
        return ABASymbol.empty
    }

    private var statusTint: Color {
        if !activeTargets.isEmpty && completedCount == activeTargets.count { return .green }
        if inProgressCount > 0 || completedCount > 0 { return .orange }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(program.name)
            Spacer()
            if let level = program.currentLevel {
                Text(level.label).font(.caption.bold()).foregroundStyle(.secondary)
            }
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(completedCount)/\(activeTargets.count)")
                    .font(.subheadline.monospacedDigit())
                ABAStatusPill(title: statusText, systemImage: statusIcon, tint: statusTint)
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }
}

struct ReportHomeView: View {
    let children: [ChildProfile]

    var body: some View {
        List {
            if children.isEmpty {
                ContentUnavailableView(
                    "보고서 대상이 없습니다",
                    systemImage: ABASymbol.report,
                    description: Text("아동과 기록을 추가하면 사용자 지정 기간 보고서를 만들 수 있습니다.")
                )
            } else {
                Section("아동 선택") {
                    ForEach(children) { child in
                        NavigationLink {
                            ReportView(child: child)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(child.name).font(.headline)
                                Text("프로그램 \(child.programs.count)개")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("보고서")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("개인정보 안내") { ReportPrivacyView() }
            }
        }
    }
}

struct AddChildView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var useBirthDate = false
    @State private var birthDate = Date()
    @State private var memo = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("이름", text: $name)
                    Toggle("생년월일 입력", isOn: $useBirthDate)
                    if useBirthDate {
                        DatePicker("생년월일", selection: $birthDate, displayedComponents: .date)
                    }
                    TextField("메모", text: $memo, axis: .vertical)
                }
            }
            .navigationTitle("아동 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        let child = ChildProfile(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            birthDate: useBirthDate ? birthDate : nil,
                            memo: memo
                        )
                        modelContext.insert(child)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// Semantic SF Symbols shared by every screen. Keep names compatible with iOS 17.
enum ABASymbol {
    static let today = "checkmark.circle"
    static let children = "person.2"
    static let history = "calendar"
    static let report = "chart.xyaxis.line"
    static let add = "plus"
    static let addChild = "person.crop.circle.badge.plus"
    static let child = "person.crop.circle.fill"
    static let startSession = "calendar.badge.plus"
    static let open = "arrow.right"
    static let accuracy = "percent"
    static let completed = "checkmark.circle.fill"
    static let inProgress = "clock.fill"
    static let empty = "circle.dashed"
    static let warning = "exclamationmark.circle"
    static let review = "exclamationmark.triangle.fill"
    static let targets = "checklist"
    static let program = "list.bullet.rectangle"
    static let settings = "slider.horizontal.3"
    static let trial = "hand.tap"
    static let editHistory = "clock.arrow.circlepath"
    static let reopen = "arrow.uturn.backward.circle"
    static let correct = "checkmark"
    static let prompted = "hand.raised"
    static let reset = "arrow.counterclockwise"
    static let note = "note.text"
    static let undo = "arrow.uturn.backward"
    static let more = "ellipsis.circle"
    static let previous = "chevron.left"
    static let next = "chevron.right"
    static let noRecords = "calendar.badge.exclamationmark"
    static let search = "magnifyingglass"
    static let delete = "trash"
    static let pdf = "doc.richtext"
    static let share = "square.and.arrow.up"
    static let active = "play.circle.fill"
    static let mastered = "checkmark.seal.fill"
    static let discontinued = "pause.circle.fill"
}

enum ABAVisualStyle {
    // Pink is reserved for navigation/actions; clinical green/orange remain semantic.
    static let brand = Color(uiColor: UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 1.0, green: 0.54, blue: 0.72, alpha: 1)
        }
        return UIColor(red: 0.70, green: 0.12, blue: 0.36, alpha: 1)
    })

    static let cornerRadius: CGFloat = 16
    static let contentMaxWidth: CGFloat = 980
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let secondarySurface = Color(uiColor: .secondarySystemGroupedBackground)
    static let tertiarySurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator).opacity(0.18)
}

private struct ABASurfaceModifier: ViewModifier {
    let padding: CGFloat
    let background: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background, in: .rect(cornerRadius: ABAVisualStyle.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: ABAVisualStyle.cornerRadius)
                    .strokeBorder(ABAVisualStyle.separator, lineWidth: 0.5)
            }
    }
}

extension View {
    func abaSurface(
        padding: CGFloat = 16,
        background: Color = ABAVisualStyle.secondarySurface
    ) -> some View {
        modifier(ABASurfaceModifier(padding: padding, background: background))
    }
}

/// Consistent, accessible help. Important consent and error states remain visible.
struct ABAHelpButton: View {
    let title: String
    let message: String
    @State private var presented = false
    var body: some View {
        Button { presented = true } label: {
            Image(systemName: "questionmark.circle")
                .font(.body)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(title) 도움말")
        .accessibilityIdentifier("help-\(title)")
        .popover(isPresented: $presented) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        Text(title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        Button("닫기") { presented = false }.frame(minHeight: 44)
                    }
                    Text(message).fixedSize(horizontal: false, vertical: true)
                }.padding(24)
            }
            .frame(idealWidth: 360, idealHeight: 280)
            .presentationDetents([.medium, .large])
        }
    }
}

struct ABASectionHeading: View {
    let title: String
    let help: String
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            ABAHelpButton(title: title, message: help)
        }
    }
}

struct ABAStatusPill: View {
    @Environment(\.colorSchemeContrast) private var contrast
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(contrast == .increased ? 0.22 : 0.12), in: Capsule())
            .overlay {
                Capsule().strokeBorder(tint.opacity(contrast == .increased ? 1 : 0), lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
    }
}
