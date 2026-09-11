import SwiftUI
import Charts

struct ReportView: View {
    let child: ChildProfile

    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedProgramIDs: Set<UUID> = []
    @State private var shareURL: URL?
    @State private var exportError: String?

    private var programs: [TherapyProgram] {
        child.programs.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var selectedPrograms: [TherapyProgram] {
        programs.filter { selectedProgramIDs.contains($0.id) }
    }

    private var incompleteSessionCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        return selectedPrograms
            .flatMap(\.targets)
            .flatMap(\.sessions)
            .filter { $0.hasMeaningfulData && !$0.completed && $0.date >= start && $0.date < endExclusive }
            .count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                controls

                if incompleteSessionCount > 0 {
                    Label("선택 기간에 미완료 Session이 \(incompleteSessionCount)개 있습니다. 미완료 기록은 보고서 통계와 그래프에서 제외됩니다.", systemImage: ABASymbol.warning)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .abaSurface(background: Color.orange.opacity(0.08))
                }

                if programs.isEmpty {
                    ContentUnavailableView(
                        "보고서에 포함할 프로그램이 없습니다",
                        systemImage: ABASymbol.report,
                        description: Text("아동에게 프로그램과 완료된 치료 기록을 추가하세요.")
                    )
                } else if selectedPrograms.isEmpty {
                    ContentUnavailableView(
                        "프로그램을 선택하세요",
                        systemImage: ABASymbol.targets,
                        description: Text("한 개 이상의 프로그램을 선택하면 경과 그래프를 확인할 수 있습니다.")
                    )
                } else {
                    ForEach(selectedPrograms) { program in
                        ProgramReportSection(child: child, program: program, startDate: startDate, endDate: endDate)
                    }
                }

                if !selectedPrograms.isEmpty {
                    ReportComposerView(child: child, startDate: startDate, endDate: endDate, programs: selectedPrograms)
                        .id("\(child.id)-\(ReportDocument.date(startDate))-\(ReportDocument.date(endDate))")
                }
            }
            .padding()
            .safeAreaPadding(.bottom, 72)
            .frame(maxWidth: ABAVisualStyle.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ABAVisualStyle.groupedBackground)
        .navigationTitle("경과 보고서")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedProgramIDs.isEmpty {
                selectedProgramIDs = Set(programs.map(\.id))
            }
        }
        .onChange(of: startDate) {
            if endDate < startDate { endDate = startDate }
        }
        .alert("PDF 생성 실패", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("확인", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "알 수 없는 오류")
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("데이터 선택")
                .font(.title2.bold())

            ABAAlignedField(title: "시작일") {
                DatePicker("시작일", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
            }
            ABAAlignedField(title: "종료일") {
                DatePicker("종료일", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                    .labelsHidden()
            }

            ABASectionHeading(title: "프로그램 선택", help: "선택한 프로그램의 완료된 치료 기록을 지정 기간에 맞춰 집계합니다. 그래프에는 실제 기록일만 표시합니다. 프로그램을 누르면 보고서 포함 여부가 바뀝니다.")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 8) {
                    ForEach(programs) { program in
                        let selected = selectedProgramIDs.contains(program.id)
                        Button {
                            if selected { selectedProgramIDs.remove(program.id) }
                            else { selectedProgramIDs.insert(program.id) }
                        } label: {
                            Text(program.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selected ? ABAVisualStyle.brand : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(selected ? ABAVisualStyle.brand.opacity(0.14) : ABAVisualStyle.tertiarySurface)
                                .clipShape(Capsule())
                                .overlay { Capsule().stroke(selected ? ABAVisualStyle.brand.opacity(0.28) : .clear) }
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                        .accessibilityLabel(program.name)
                        .accessibilityHint("보고서에 이 프로그램을 포함하거나 제외합니다.")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                .scrollTargetLayout()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.visible)
            .contentMargins(.horizontal, 0)
            Text("좌우로 밀어 프로그램 보기")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .abaSurface()
    }

    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                do {
                    shareURL = try ReportPDFExporter.export(
                        child: child,
                        startDate: startDate,
                        endDate: endDate,
                        programs: selectedPrograms
                    )
                } catch {
                    exportError = error.localizedDescription
                }
            } label: {
                Label("PDF 생성", systemImage: ABASymbol.pdf)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let shareURL {
                ShareLink(item: shareURL) {
                    Label("PDF 공유 / 저장", systemImage: ABASymbol.share)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .abaSurface(background: Color(uiColor: .systemBackground))
    }
}

private struct ProgramReportSection: View {
    let child: ChildProfile
    let program: TherapyProgram
    let startDate: Date
    let endDate: Date

    private var targets: [TherapyTarget] {
        program.targets.filter { target in
            !chartEntries(for: target).isEmpty
        }
        .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var levelReviewIssues: [String] {
        LevelProgressionService.integrityIssues(in: program)
    }

    private var goal: ReportGoal? {
        ReportDocument.build(
            child: child,
            start: startDate,
            end: endDate,
            programs: [program],
            draft: ReportDraft()
        ).goals.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !levelReviewIssues.isEmpty {
                Label("레벨 판정 검토 필요", systemImage: ABASymbol.review)
                    .font(.footnote.bold())
                    .foregroundStyle(.orange)
            }

            if targets.isEmpty {
                Text("선택한 기간에 기록된 과제가 없습니다.")
                    .foregroundStyle(.secondary)
            } else if let goal {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ABAVisualStyle.brand.opacity(0.55))
                        .frame(width: 3, height: 24)
                    Text(goal.group)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                ProgramLevelProgressChart(child: child, program: program, goal: goal)
            }
        }
    }

    private func chartEntries(for target: TherapyTarget) -> [ReportPoint] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate
        return target.sessions
            .filter { $0.completed && $0.hasMeaningfulData && $0.date >= start && $0.date < end && $0.accuracy != nil }
            .sorted { $0.date < $1.date }
            .enumerated()
            .map { index, session in
                ReportPoint(id: session.id, index: index, date: session.date, accuracy: session.accuracy ?? 0)
            }
    }
}

private struct ProgramChartPoint: Identifiable {
    let id: String
    let index: Int
    let date: String
    let value: Double
    let level: Int
    let recordedCount: Int
    let applicableCount: Int

    var coverageLabel: String {
        recordedCount == applicableCount && applicableCount > 0 ? "전체 과제" : "일부 과제"
    }
}

private struct ProgramLevelSeries: Identifiable {
    let level: Int
    let points: [ProgramChartPoint]
    var id: Int { level }
    var label: String { "L\(level)" }
}

private struct ProgramLevelProgressChart: View {
    let child: ChildProfile
    let program: TherapyProgram
    let goal: ReportGoal

    private var points: [ProgramChartPoint] {
        goal.points.enumerated().map { index, point in
            ProgramChartPoint(
                id: point.id,
                index: index,
                date: point.date,
                value: point.value,
                level: point.level,
                recordedCount: point.recordedCount,
                applicableCount: point.applicableCount
            )
        }
    }

    private var series: [ProgramLevelSeries] {
        Dictionary(grouping: points, by: \.level)
            .map { ProgramLevelSeries(level: $0.key, points: $0.value.sorted { $0.index < $1.index }) }
            .sorted { $0.level < $1.level }
    }

    private var transitions: [ProgramChartPoint] {
        series.dropFirst().compactMap(\.points.first)
    }

    private var visibleAxisIndices: [Int] {
        guard points.count > 6 else { return points.map(\.index) }
        let step = max(1, Int(ceil(Double(points.count - 1) / 5.0)))
        var values = Array(stride(from: 0, to: points.count, by: step))
        if let last = points.last?.index, values.last != last { values.append(last) }
        return values
    }

    private var levels: [Int] { series.map(\.level) }

    private var masteryRules: [Double] {
        Array(Set(goal.criteria.values)).sorted()
    }

    private var isCompleted: Bool {
        !levels.isEmpty && levels.allSatisfy { goal.masteredLevels.contains($0) }
    }

    private var dataDescription: String {
        goal.domain == "미분류" ? "기록일별 정반응률" : "\(goal.domain) 정반응률"
    }

    private func levelColor(_ level: Int) -> Color {
        switch (level - 1) % 5 {
        case 0: return Color(red: 0.96, green: 0.29, blue: 0.30)
        case 1: return Color(red: 0.98, green: 0.49, blue: 0.18)
        case 2: return Color(red: 0.64, green: 0.43, blue: 0.79)
        case 3: return Color(red: 0.16, green: 0.57, blue: 0.64)
        default: return ABAVisualStyle.brand
        }
    }

    private func displayDate(_ value: String) -> String {
        let parts = value.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return value }
        return "\(month).\(day)"
    }

    private func learningText(for level: Int) -> String {
        let text = goal.learning[String(level)] ?? ""
        return text.isEmpty ? "등록된 학습 내용이 없습니다." : text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.headline)
                    Text(dataDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ABAStatusPill(
                    title: isCompleted ? "완료" : "진행중",
                    systemImage: isCompleted ? ABASymbol.mastered : ABASymbol.active,
                    tint: isCompleted ? .green : .blue
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                if let firstLevel = levels.first {
                    Text("L\(firstLevel)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 34)
                }

                Chart {
                    ForEach(series) { levelSeries in
                        let color = levelColor(levelSeries.level)
                        ForEach(levelSeries.points) { point in
                            LineMark(
                                x: .value("기록 순서", point.index),
                                y: .value("정반응률", point.value),
                                series: .value("레벨 계열", levelSeries.label)
                            )
                            .foregroundStyle(color)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            PointMark(
                                x: .value("기록 순서", point.index),
                                y: .value("정반응률", point.value)
                            )
                            .foregroundStyle(color)
                            .symbol {
                                Circle()
                                    .fill(point.recordedCount < point.applicableCount ? Color(uiColor: .systemBackground) : color)
                                    .stroke(color, lineWidth: 1.5)
                                    .frame(width: 7, height: 7)
                            }
                        }
                    }

                    ForEach(transitions) { point in
                        RuleMark(x: .value("레벨 전환", point.index))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .annotation(position: .top, alignment: .leading) {
                                Text("L\(point.level)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                    }

                    ForEach(masteryRules, id: \.self) { criterion in
                        RuleMark(y: .value("숙달 기준", criterion))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                            .foregroundStyle(.green)
                            .annotation(position: .top, alignment: .trailing) {
                                Text("숙달 \(criterion, format: .number.precision(.fractionLength(0)))%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: visibleAxisIndices) { value in
                        AxisValueLabel {
                            if let index = value.as(Int.self), points.indices.contains(index) {
                                Text(displayDate(points[index].date))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 20, 40, 60, 80, 100]) {
                        AxisGridLine().foregroundStyle(Color.secondary.opacity(0.18))
                        AxisValueLabel()
                    }
                }
                .chartLegend(.hidden)
                .chartPlotStyle { plot in
                    plot.background(Color(uiColor: .systemBackground).opacity(0.7))
                }
                .frame(height: 220)
                .accessibilityLabel("\(goal.name) 기록일별 정반응률 그래프")
                .accessibilityValue("레벨 \(series.count)개, 실제 기록일 \(points.count)개. 가로 점선은 숙달 기준이고 세로 점선은 다음 레벨의 새 집계 시작입니다.")
            }
            .padding(12)
            .background(ABAVisualStyle.tertiarySurface)
            .clipShape(.rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 10) {
                Text("학습 내용")
                    .font(.subheadline.weight(.semibold))
                ForEach(levels, id: \.self) { level in
                    HStack(alignment: .top, spacing: 10) {
                        Text("L\(level)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(levelColor(level))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .overlay { Capsule().stroke(levelColor(level), lineWidth: 1) }
                        Text(learningText(for: level))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                NavigationLink {
                    ProgramDetailView(child: child, program: program)
                } label: {
                    Label("학습 내용 입력 및 수정", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                }
                .accessibilityHint("프로그램 과제명과 설명을 수정하면 보고서의 학습 내용에 반영됩니다.")
            }
            .padding(12)
            .background(ABAVisualStyle.tertiarySurface)
            .clipShape(.rect(cornerRadius: 12))
        }
        .abaSurface(padding: 14, background: Color(uiColor: .systemBackground))
    }
}

struct ReportPoint: Identifiable {
    let id: UUID
    let index: Int
    let date: Date
    let accuracy: Double
}

private struct TargetReportCard: View {
    let target: TherapyTarget
    let entries: [ReportPoint]

    private var average: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.accuracy).reduce(0, +) / Double(entries.count)
    }

    private var visibleAxisIndices: [Int] {
        guard entries.count > 6 else { return entries.map(\.index) }
        let step = max(1, Int(ceil(Double(entries.count - 1) / 5.0)))
        var values = Array(stride(from: 0, to: entries.count, by: step))
        if let last = entries.last?.index, values.last != last { values.append(last) }
        return values
    }

    private var statusIcon: String {
        switch target.status {
        case .active: return ABASymbol.active
        case .mastered: return ABASymbol.mastered
        case .discontinued: return ABASymbol.discontinued
        }
    }

    private var statusTint: Color {
        switch target.status {
        case .active: return .blue
        case .mastered: return .green
        case .discontinued: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("L\(target.levelNumber) \(target.name)").font(.headline)
                    Text("세션 \(entries.count)회, 평균 \(average, format: .number.precision(.fractionLength(0...1)))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ABAStatusPill(
                    title: target.status.rawValue,
                    systemImage: statusIcon,
                    tint: statusTint
                )
            }

            Chart(entries) { point in
                LineMark(
                    x: .value("세션", point.index),
                    y: .value("정반응률", point.accuracy)
                )
                PointMark(
                    x: .value("세션", point.index),
                    y: .value("정반응률", point.accuracy)
                )

                RuleMark(y: .value("습득 기준", target.masteryPercent))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(.secondary)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: visibleAxisIndices) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let index = value.as(Int.self),
                           let point = entries.first(where: { $0.index == index }) {
                            Text(point.date, format: .dateTime.month().day())
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 20, 40, 60, 80, 100]) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.background(ABAVisualStyle.tertiarySurface.opacity(0.55))
            }
            .frame(height: 240)
            .accessibilityLabel("\(target.name) 경과 그래프")
            .accessibilityValue("세션 \(entries.count)회, 평균 정반응률 \(average.formatted(.number.precision(.fractionLength(0...1)))) 퍼센트")
        }
        .abaSurface(padding: 14)
    }
}
