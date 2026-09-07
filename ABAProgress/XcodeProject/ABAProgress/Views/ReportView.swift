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
                    Label("선택 기간에 미완료 Session이 \(incompleteSessionCount)개 있습니다. 미완료 기록은 보고서 통계와 그래프에서 제외됩니다.", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }

                ForEach(selectedPrograms) { program in
                    ProgramReportSection(program: program, startDate: startDate, endDate: endDate)
                }

                if !selectedPrograms.isEmpty {
                    exportSection
                }
            }
            .padding()
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
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
            Text(child.name)
                .font(.title2.bold())

            ViewThatFits(in: .horizontal) {
                HStack {
                    DatePicker("시작일", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    DatePicker("종료일", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                }
                VStack(alignment: .leading, spacing: 10) {
                    DatePicker("시작일", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    DatePicker("종료일", selection: $endDate, in: startDate...Date(), displayedComponents: .date)
                }
            }

            Text("프로그램 선택")
                .font(.headline)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
                spacing: 8
            ) {
                ForEach(programs) { program in
                    Toggle(program.name, isOn: Binding(
                        get: { selectedProgramIDs.contains(program.id) },
                        set: { selected in
                            if selected { selectedProgramIDs.insert(program.id) }
                            else { selectedProgramIDs.remove(program.id) }
                        }
                    ))
                    .toggleStyle(.button)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
                Label("PDF 생성", systemImage: "doc.richtext")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let shareURL {
                ShareLink(item: shareURL) {
                    Label("PDF 공유 / 저장", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProgramReportSection: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(program.name)
                .font(.title3.bold())

            if !levelReviewIssues.isEmpty {
                Label("레벨 판정 검토 필요", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.orange)
            }

            if targets.isEmpty {
                Text("선택한 기간에 기록된 과제가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(targets) { target in
                    TargetReportCard(target: target, entries: chartEntries(for: target))
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(.quaternary)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("L\(target.levelNumber) · \(target.name)").font(.headline)
                    Text("세션 \(entries.count)회 · 평균 \(average, format: .number.precision(.fractionLength(0...1)))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(target.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.thinMaterial, in: Capsule())
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
            .frame(height: 240)
            .accessibilityLabel("\(target.name) 경과 그래프")
            .accessibilityValue("세션 \(entries.count)회, 평균 정반응률 \(average.formatted(.number.precision(.fractionLength(0...1)))) 퍼센트")
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
