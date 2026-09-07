import SwiftUI
import SwiftData

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
    }
}

private struct CompactRootView: View {
    let children: [ChildProfile]

    var body: some View {
        TabView {
            NavigationStack {
                ChildrenListView(children: children)
            }
            .tabItem { Label("아동", systemImage: "person.2") }

            NavigationStack {
                TodayOverviewView(children: children)
            }
            .tabItem { Label("오늘", systemImage: "checkmark.circle") }

            NavigationStack {
                HistoryCalendarView(children: children)
            }
            .tabItem { Label("기록", systemImage: "calendar") }

            NavigationStack {
                ReportHomeView(children: children)
            }
            .tabItem { Label("보고서", systemImage: "chart.xyaxis.line") }
        }
    }
}

private struct RegularRootView: View {
    let children: [ChildProfile]
    @State private var selection: SidebarDestination? = .children

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("워크스페이스") {
                    Label("아동", systemImage: "person.2")
                        .tag(SidebarDestination.children)
                    Label("오늘", systemImage: "checkmark.circle")
                        .tag(SidebarDestination.today)
                    Label("기록 캘린더", systemImage: "calendar")
                        .tag(SidebarDestination.history)
                    Label("보고서", systemImage: "chart.xyaxis.line")
                        .tag(SidebarDestination.reports)
                }
            }
            .navigationTitle("ABA Progress")
        } detail: {
            NavigationStack {
                switch selection ?? .children {
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
    }
}

private enum SidebarDestination: Hashable {
    case children
    case today
    case history
    case reports
}

struct ChildrenListView: View {
    @Environment(\.modelContext) private var modelContext
    let children: [ChildProfile]
    @State private var showingAddChild = false
    @State private var childPendingDeletion: ChildProfile?

    var body: some View {
        List {
            if children.isEmpty {
                ContentUnavailableView(
                    "등록된 아동이 없습니다",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("아동을 추가한 뒤 프로그램과 실시간 Trial 기록을 시작하세요.")
                )
            } else {
                Section {
                    ForEach(children) { child in
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddChild = true
                } label: {
                    Label("아동 추가", systemImage: "plus")
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
            Text("이 작업은 해당 아동의 프로그램, Level, Session, Trial 기록을 모두 삭제합니다.")
        }
    }

    private func deleteChildren(at offsets: IndexSet) {
        guard let index = offsets.first, children.indices.contains(index) else { return }
        childPendingDeletion = children[index]
    }

    private func confirmChildDeletion() {
        guard let childPendingDeletion else { return }
        modelContext.delete(childPendingDeletion)
        self.childPendingDeletion = nil
        try? modelContext.save()
    }
}

private struct ChildSummaryRow: View {
    let child: ChildProfile

    private var latestSessionDate: Date? {
        child.programs.flatMap(\.targets).flatMap(\.sessions).filter(\.hasMeaningfulData).map(\.date).max()
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)

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
                        systemImage: "calendar.badge.plus",
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
                NavigationLink("열기") { ChildDetailView(child: child) }
                    .buttonStyle(.bordered)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
                spacing: 12
            ) {
                MetricTile(title: "완료 프로그램", value: "\(completedProgramCount)/\(recordablePrograms.count)", systemImage: "checkmark.circle")
                MetricTile(title: "평균 정반응률", value: average.map { String(format: "%.0f%%", $0) } ?? "—", systemImage: "percent")
            }

            if !programs.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                        NavigationLink {
                            ProgramDetailView(child: child, program: program)
                        } label: {
                            TodayProgramStatusCompact(program: program, today: today)
                        }
                        .buttonStyle(.plain)
                        if index < programs.count - 1 { Divider() }
                    }
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
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
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: completedCount == activeTargets.count && !activeTargets.isEmpty ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(completedCount == activeTargets.count && !activeTargets.isEmpty ? .green : .secondary)
            Text(program.name)
            Spacer()
            if let level = program.currentLevel {
                Text(level.label).font(.caption.bold()).foregroundStyle(.secondary)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(completedCount)/\(activeTargets.count)")
                    .font(.subheadline.monospacedDigit())
                Text(statusText)
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 9)
    }
}

struct ReportHomeView: View {
    let children: [ChildProfile]

    var body: some View {
        List {
            if children.isEmpty {
                ContentUnavailableView(
                    "보고서 대상이 없습니다",
                    systemImage: "chart.xyaxis.line",
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
