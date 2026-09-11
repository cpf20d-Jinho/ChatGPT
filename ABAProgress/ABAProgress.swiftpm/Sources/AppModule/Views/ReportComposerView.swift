import SwiftUI

private enum ReportComposerStep: String, CaseIterable, Identifiable {
    case details = "1 기본"
    case narratives = "2 서술"
    case review = "3 검토"
    var id: Self { self }
}

struct ReportComposerView: View {
    let child: ChildProfile
    let startDate: Date
    let endDate: Date
    let programs: [TherapyProgram]
    @State private var draft = ReportDraft()
    @State private var narrativeEditor: NarrativeEditorSelection?
    @State private var templateStatus: String?
    @State private var pendingTemplate: ReportBasicTemplate?
    @State private var confirmTemplateLoad = false
    @State private var loaded = false
    @State private var error: String?
    @State private var endpoint = ""
    @State private var token = ""
    @State private var groqKey = ""
    @State private var aiResult: ReportAIResult?
    @State private var aiFingerprint = ""
    @State private var isBusy = false
    @State private var consentRequest: ReportConsentRequest?
    @State private var connectionStatus: String?
    @State private var shareURL: URL?
    @State private var reviewed = false
    @State private var webEditorPresented = false
    @State private var webSession: ReportWebSession?
    @State private var step: ReportComposerStep = .details
    @State private var draftSaveTask: Task<Void, Never>?
    @State private var saveStatus = "자동 저장 대기"
    @FocusState private var focusedField: String?

    private var document: ReportDocument {
        ReportDocument.build(child: child, start: startDate, end: endDate, programs: programs, draft: draft)
    }

    private var payloadPreview: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? String(data: encoder.encode(ReportAIPayload(document: document)), encoding: .utf8)) ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ABASectionHeading(title: "보고서", help: "STO는 프로그램의 기록된 레벨 단위로 집계합니다. 서술은 아동과 보고기간별로 기기에 자동 저장됩니다. AI 초안은 종합 현황과 주요 변화 두 항목에만 적용됩니다. PDF를 생성하기 전에 그래프와 서술을 검토하세요.")
            Picker("보고서 작성 단계", selection: $step) {
                ForEach(ReportComposerStep.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("report-composer-step")

            switch step {
            case .details: detailsStep
            case .narratives: narrativesStep
            case .review: reviewStep
            }

            Text(saveStatus)
                .font(.caption)
                .foregroundStyle(saveStatus.contains("실패") ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .abaSurface()
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("입력 완료") { focusedField = nil }
            }
        }
        .task {
            do {
                draft = try ReportDraftStore.load(childID: child.id, start: startDate, end: endDate)
                groqKey = ReportAIClient.savedGroqKey()
                endpoint = ReportAIClient.configuredEndpoint
                loaded = true
            } catch {
                self.error = "저장된 보고서를 읽지 못했습니다. 기존 파일을 보호하기 위해 편집 저장을 중단합니다. \(error.localizedDescription)"
            }
        }
        .onChange(of: draft) {
            guard loaded else { return }
            reviewed = false
            removeShareFile()
            scheduleDraftSave()
        }
        .onChange(of: document.fingerprint) {
            reviewed = false
            removeShareFile()
        }
        .onDisappear {
            draftSaveTask?.cancel()
            if loaded { storeDraft(draft) }
            removeShareFile()
        }
        .confirmationDialog("현재 기본 정보를 저장된 양식으로 바꿀까요?", isPresented: $confirmTemplateLoad, titleVisibility: .visible) {
            Button("불러오기") {
                if let pendingTemplate { draft = pendingTemplate.applying(to: draft) }
                pendingTemplate = nil
                templateStatus = "기본 양식을 불러왔습니다."
            }
            Button("취소", role: .cancel) { pendingTemplate = nil }
        } message: {
            Text("서명 일자, 평가군 분류와 서술 내용은 유지됩니다.")
        }
        .sheet(item: $narrativeEditor) { selection in
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("입력 내용은 자동 저장됩니다.")
                        .font(.footnote).foregroundStyle(.secondary)
                    TextEditor(text: selection.value)
                        .accessibilityLabel(selection.title)
                        .padding(8)
                        .background(.background)
                        .clipShape(.rect(cornerRadius: 12))
                }
                .padding()
                .navigationTitle(selection.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("완료") { narrativeEditor = nil }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .sheet(item: $consentRequest) { request in
            ReportConsentSheet(request: request) {
                consentRequest = nil
                generate(request)
            }
        }
        .sheet(isPresented: $webEditorPresented) {
            ReportWebEditorView(draft: $draft, session: $webSession, fingerprint: document.fingerprint, endpoint: endpoint, token: $token) { updated in
                try ReportDraftStore.save(updated, childID: child.id, start: startDate, end: endDate)
            }
        }
    }

    @ViewBuilder
    private var detailsStep: some View {
        ABASectionHeading(title: "기본 양식", help: "기관명, 담당 치료사, 소속반, 프로그램 분류 표시, 주 횟수, 회기 시간, 기관장, 자격 정보와 하단 문구를 이 기기에 저장합니다. 새 아동이나 새 보고 기간의 보고서에 자동 적용합니다. 기존 보고서에는 불러오기를 눌렀을 때만 적용됩니다. 서명 일자, 평가군 분류와 서술은 양식에 저장하지 않습니다. 다시 저장하면 이전 기본 양식을 대체합니다.")
        HStack {
            Button("기본 양식 저장") {
                do {
                    try ReportBasicTemplate(draft).save()
                    templateStatus = "기본 양식을 저장했습니다."
                } catch { self.error = "기본 양식 저장 실패: \(error.localizedDescription)" }
            }
            Button("불러오기") {
                do {
                    if let template = try ReportBasicTemplate.load() {
                        pendingTemplate = template
                        confirmTemplateLoad = true
                    } else { templateStatus = "저장된 기본 양식이 없습니다." }
                } catch { self.error = "기본 양식 불러오기 실패: \(error.localizedDescription)" }
            }
        }
        .buttonStyle(.bordered)
        .disabled(!loaded)
        if let templateStatus { Text(templateStatus).font(.footnote).foregroundStyle(.secondary) }
        VStack(alignment: .leading, spacing: 12) {
            singleLineField("기관명", $draft.institution)
            singleLineField("담당 치료사", $draft.therapist)
            singleLineField("소속반", $draft.className)
            singleLineField("프로그램 분류 표시", $draft.programFamily)
            singleLineField("주 횟수", $draft.schedule)
            singleLineField("회기 시간", $draft.duration)
            singleLineField("기관장", $draft.director)
            singleLineField("기관장 자격 정보", $draft.directorCredential)
            singleLineField("서명 일자", $draft.signedDate)
            singleLineField("하단 저작권과 출처 문구", $draft.copyright)
        }

        DisclosureGroup("평가군 분류") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(programs) { program in
                    ABAAlignedField(title: program.name) {
                        TextField("ELCAR 평가 또는 기타 목표", text: Binding(
                            get: { draft.groupByProgram[program.id.uuidString] ?? "기타 목표" },
                            set: { draft.groupByProgram[program.id.uuidString] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("\(program.name) 평가군")
                    }
                }
            }
            .padding(.top, 8)
        }

        Button("다음") { step = .narratives }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private var narrativesStep: some View {
        Toggle("AI로 작성", isOn: Binding(
            get: { draft.aiWritingEnabled ?? false },
            set: { draft.aiWritingEnabled = $0 }
        )).disabled(!loaded || isBusy)
        field("도전적 행동 변화", $draft.behavior, help: "서술은 아동과 보고 기간별로 이 기기에 자동 저장됩니다. AI에는 반응률 수치만 보내며, 행동 관찰과 직접 작성한 문장은 보내지 않습니다. 현재 AI는 행동 변화를 생성하지 않으므로 직접 작성한 내용이 유지됩니다. AI 작성 여부와 관계없이 직접 편집할 수 있습니다. PDF 공유 시 이 항목이 포함됩니다.")
        field("종합 현황", $draft.currentStatus, help: narrativeStorageHelp, aiManaged: true)
        field("강점과 주요 변화", $draft.majorChanges, help: narrativeStorageHelp, aiManaged: true)
        DisclosureGroup("참고 메모") {
            field("관찰 메모", $draft.confirmedObservations, help: "아동과 보고 기간별로 이 기기에 자동 저장하는 작성 참고 자료입니다. AI 요청, 웹 편집과 최종 PDF에는 포함하지 않습니다. 앱 데이터 삭제 시 메모도 삭제될 수 있습니다.")
        }
        if draft.aiWritingEnabled == true { aiControls }
        Divider()
        ABASectionHeading(title: "치료사 작성", help: "아래 소견, 가정 안내와 다음 목표는 직접 작성합니다. AI 초안을 적용해도 이 항목들은 바뀌지 않습니다.")
        field("치료사 종합 소견", $draft.therapistOpinion)
        field("가정에서 함께 하기", $draft.homePractice)
        field("다음 목표", $draft.nextGoals)
        HStack {
            Button("이전") { step = .details }.buttonStyle(.bordered)
            Spacer()
            Button("다음") { step = .review }.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var reviewStep: some View {
        ABAInlineNotice(
            title: "내보내기 전 확인",
            message: "기간 \(ReportDocument.date(startDate)) ~ \(ReportDocument.date(endDate)), 프로그램 \(programs.count)개와 STO \(document.stoCount)개를 사용합니다. 그래프의 빈 표식은 일부 과제만 기록된 날짜입니다.",
            systemImage: ABASymbol.review,
            tint: .blue
        )
        DisclosureGroup("보고서 서술 확인") {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(ReportEditableText(draft).rows.enumerated()), id: \.offset) { _, field in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(field.0).font(.headline)
                        Text(field.1.isEmpty ? "작성된 내용이 없습니다." : field.1)
                            .textSelection(.enabled)
                    }
                }
            }
        }
            if let result = aiResult {
                Text("검토 전 AI 초안").font(.headline)
                Text(result.currentStatus).textSelection(.enabled)
                Text(result.majorChanges).textSelection(.enabled)
                Text(result.warnings.joined(separator: "\n")).font(.footnote).foregroundStyle(.orange)
                Button("검토한 AI 초안을 두 항목에 적용") {
                    guard aiFingerprint == document.fingerprint else {
                        error = "데이터가 변경되었습니다. 초안을 다시 생성하세요."
                        return
                    }
                    draft.currentStatus = result.currentStatus
                    draft.majorChanges = result.majorChanges
                    draft.reviewedFingerprint = aiFingerprint
                    aiResult = nil
                }
            }
        Button { webEditorPresented = true } label: {
            Label(webSession == nil ? "보고서 웹 편집" : "웹 수정본 가져오기", systemImage: "rectangle.and.pencil.and.ellipsis")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered).controlSize(.large).disabled(!loaded || isBusy)
        Toggle("집계 기준, 그래프와 서술 내용을 검토했습니다", isOn: $reviewed)
        Button(action: exportPDF) {
            Label(isBusy ? "처리 중…" : "기본 양식 PDF 생성", systemImage: ABASymbol.pdf)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        .disabled(isBusy || !reviewed || !loaded || document.goals.isEmpty)
        if let shareURL {
            ShareLink(item: shareURL) { Label("PDF 공유 / 저장", systemImage: ABASymbol.share) }
        }
        Button("이전") { step = .narratives }.buttonStyle(.bordered)
    }

    private var seriesLegend: String {
        let labels = document.goals.flatMap { goal in
            Set(goal.points.map(\.level)).sorted().map { level in
                "\(goal.name) L\(level)"
            }
        }
        return labels.enumerated().map { "계열 \($0.offset + 1): \($0.element)" }.joined(separator: "\n")
    }

    private var aiControls: some View {
        DisclosureGroup("AI 초안 작성") {
            VStack(alignment: .leading, spacing: 16) {
            ABASectionHeading(title: "AI 연결", help: "Groq의 GPT-OSS 120B가 번호로 구분한 수치 요약만 해석합니다. 본인의 Groq 키와 보고서 서버 접속 토큰이 필요합니다. 요청할 때마다 실제 전송 내용을 확인하고 동의합니다.")
            Link("Groq 계정 로그인 후 API 키 만들기", destination: URL(string: "https://console.groq.com/keys")!)
            SecureField("본인의 Groq API 키 (gsk_…)", text: $groqKey)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .privacySensitive()
            Button("이 기기에 Groq 키 저장") {
                do {
                    try ReportAIClient.saveGroqKey(groqKey)
                    error = nil
                } catch { self.error = error.localizedDescription }
            }
            .disabled(!groqKey.hasPrefix("gsk_") || groqKey.count < 24)
            Button("이 기기에 저장한 Groq 키 삭제", role: .destructive) {
                do { try ReportAIClient.deleteGroqKey(); groqKey = ""; error = nil }
                catch { self.error = error.localizedDescription }
            }
            ABASectionHeading(title: "서버 연결", help: "\(endpoint.isEmpty ? "운영 서버 설정이 필요합니다." : endpoint)\n\nGroq 키는 이 기기의 Keychain에 저장합니다. 키 삭제는 기기에서만 적용되며 키 자체의 폐기는 Groq Console에서 진행하세요. 연결 확인은 학습 데이터와 Groq 키를 전송하지 않습니다.")
            SecureField("보고서 서버 접속 토큰 (Groq 키 아님)", text: $token)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("서버 연결 확인") {
                isBusy = true
                Task { @MainActor in
                    defer { isBusy = false }
                    do {
                        try await ReportAIClient.checkConnection(endpoint: endpoint, token: token)
                        connectionStatus = "서버 인증과 통신 확인을 완료했습니다. Groq 호출은 아직 수행하지 않았습니다."
                    } catch { connectionStatus = error.localizedDescription }
                }
            }.disabled(isBusy || endpoint.isEmpty || token.isEmpty)
            if let connectionStatus { Text(connectionStatus).font(.footnote) }
            DisclosureGroup("개인정보 처리 및 AI 전송 안내") {
                Text(ReportConsentSheet.privacyNotice).font(.footnote).textSelection(.enabled)
                Link("Groq 데이터 처리 정책", destination: URL(string: "https://console.groq.com/docs/your-data")!)
            }
            DisclosureGroup("전송할 데이터 검토") {
                Text(payloadPreview).font(.caption.monospaced()).textSelection(.enabled)
            }
            DisclosureGroup("기기에만 표시하는 계열 번호 대응표") {
                Text(seriesLegend).font(.footnote).textSelection(.enabled)
            }
            Button("현황과 주요 변화 초안 요청") {
                consentRequest = ReportConsentRequest(document: document, endpoint: endpoint, token: token, groqKey: groqKey)
            }
                .disabled(isBusy || !loaded || endpoint.isEmpty || token.isEmpty || groqKey.isEmpty || document.goals.isEmpty)
            if aiResult != nil {
                Button("보고서에서 AI 초안 검토") { step = .review }
            }
            }.padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var narrativeStorageHelp: String {
        "서술은 아동과 보고 기간별로 이 기기에 자동 저장됩니다. AI 요청에는 직접 작성한 문장 대신 반응률 수치만 전송합니다. AI로 작성 중에는 수동 편집을 잠그고 적용된 내용은 보고서에서 확인합니다. 기능을 꺼도 기존 문장은 유지됩니다. 웹 편집을 요청하면 선택한 보고서의 여섯 서술 항목을 전송하며, PDF 공유 시 작성한 서술이 포함됩니다. 참고 메모는 AI, 웹 편집과 PDF에 포함하지 않습니다."
    }

    private func field(_ title: String, _ value: Binding<String>, help: String? = nil, aiManaged: Bool = false) -> some View {
        let locked = aiManaged && draft.aiWritingEnabled == true
        return ABAAlignedField(title: title, help: help ?? narrativeStorageHelp) {
            Button {
                narrativeEditor = NarrativeEditorSelection(title: title, value: value)
            } label: {
                HStack {
                    Text(locked ? "보고서에서 확인" : (value.wrappedValue.isEmpty ? "내용 작성" : "내용 수정"))
                    Spacer()
                    Image(systemName: locked ? "lock" : "square.and.pencil")
                }
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("\(title) \(locked ? "보고서에서 확인" : "편집")")
            .accessibilityIdentifier(title)
            .disabled(!loaded || locked)
        }
    }

    private func singleLineField(_ title: String, _ value: Binding<String>) -> some View {
        ABAAlignedField(title: title) {
            TextField("내용 입력", text: value)
                .lineLimit(1)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
                .accessibilityIdentifier(title)
                .focused($focusedField, equals: title)
                .disabled(!loaded)
        }
    }

    private func scheduleDraftSave() {
        draftSaveTask?.cancel()
        saveStatus = "저장 대기 중…"
        let snapshot = draft
        draftSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            storeDraft(snapshot)
        }
    }

    private func storeDraft(_ snapshot: ReportDraft) {
        do {
            try ReportDraftStore.save(snapshot, childID: child.id, start: startDate, end: endDate)
            saveStatus = "기기에 저장됨"
            if error?.hasPrefix("보고서 저장 실패") == true { error = nil }
        } catch {
            saveStatus = "자동 저장 실패"
            self.error = "보고서 저장 실패: \(error.localizedDescription)"
        }
    }

    private func removeShareFile() {
        if let shareURL { try? FileManager.default.removeItem(at: shareURL) }
        shareURL = nil
    }

    private func exportPDF() {
        let snapshot = document
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            do {
                let url = try await ReportTemplateExporter.export(snapshot)
                guard snapshot.fingerprint == document.fingerprint, snapshot.draft == draft else {
                    try? FileManager.default.removeItem(at: url)
                    self.error = "생성 중 보고서가 변경되었습니다. 내용을 검토한 뒤 다시 생성하세요."
                    return
                }
                removeShareFile()
                shareURL = url
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func generate(_ consent: ReportConsentRequest) {
        let snapshot = consent.document
        guard snapshot.fingerprint == document.fingerprint else {
            error = "동의 화면을 연 뒤 자료가 변경되었습니다. 전송 내용을 다시 확인하세요."
            return
        }
        let payload = ReportAIPayload(document: snapshot)
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            do {
                let result = try await ReportAIClient.generate(payload: payload, endpoint: consent.endpoint, token: consent.token, groqKey: consent.groqKey)
                guard snapshot.fingerprint == document.fingerprint else {
                    error = "생성 중 데이터가 변경되었습니다. 초안을 다시 요청하세요."
                    return
                }
                aiFingerprint = snapshot.fingerprint
                // Restore meaningful labels locally, after the numeric-only response has arrived.
                let labels = snapshot.goals.flatMap { goal in
                    Set(goal.points.map(\.level)).sorted().map { "\(goal.name) L\($0)" }
                }
                aiResult = ReportAIResult(currentStatus: localLabels(result.currentStatus, labels),
                                          majorChanges: localLabels(result.majorChanges, labels),
                                          warnings: result.warnings.map { localLabels($0, labels) })
            } catch { self.error = error.localizedDescription }
        }
    }

    private func localLabels(_ text: String, _ labels: [String]) -> String {
        guard let regex = try? NSRegularExpression(pattern: "계열\\s*(\\d+)(?!\\d)") else { return text }
        var output = text
        let original = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: original.length)).reversed() {
            guard let number = Int(original.substring(with: match.range(at: 1))), labels.indices.contains(number - 1),
                  let range = Range(match.range, in: output) else { continue }
            output.replaceSubrange(range, with: labels[number - 1])
        }
        return output
    }
}

private struct NarrativeEditorSelection: Identifiable {
    let id = UUID()
    let title: String
    let value: Binding<String>
}

private struct ReportConsentRequest: Identifiable {
    let id = UUID()
    let document: ReportDocument
    let endpoint: String
    let token: String
    let groqKey: String
}

struct ReportPrivacyView: View {
    var body: some View {
        Form {
            Section("기기 내 보관") {
                Text("아동 프로필, 치료 기록과 수동 작성 보고서는 앱의 기기 저장소에 보관합니다. AI 기능을 사용하지 않아도 직접 보고서를 작성할 수 있습니다. PDF를 공유하면 선택한 공유 대상에게 보고서 내용이 전달됩니다.")
            }
            Section("AI 전송 안내") { Text(ReportConsentSheet.privacyNotice) }
            Section("선택적 보고서 웹 편집") { Text(ReportWebEditing.notice) }
            Section("제공자 정책") {
                Link("Groq 데이터 처리 정책", destination: URL(string: "https://console.groq.com/docs/your-data")!)
            }
        }
        .navigationTitle("개인정보 안내")
    }
}

private struct ReportConsentSheet: View {
    let request: ReportConsentRequest
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var agreed = false
    static let privacyNotice = """
아동명, 생년월일, 기관명, 프로그램명, 날짜, 메모, 치료사 소견과 서명은 AI 전송에서 제외합니다. 이름을 가린 문서나 PDF도 전송하지 않습니다.

학습별 및 단계별 반응률 배열만 보고서 서버에 보내고, 서버는 번호, 관측 수, 초기 평균, 최근 평균, 차이, 범위와 비교 구간 중복 여부만 Groq에 전달합니다. 숫자만으로 완전한 익명성을 보장하지는 않습니다.

목적은 학습 반응 데이터에 근거한 현황과 주요 변화의 초안 작성입니다. 진단, 치료 효과 또는 행동 원인을 판단하지 않습니다. 치료사 소견 이후는 직접 작성하며 초안은 사용자가 검토한 후 적용합니다.

연결에는 서버 접속 토큰과 Groq 키가 사용됩니다. 앱은 키를 Keychain에 저장하며, 제공된 서버 코드는 요청 본문과 키를 저장하거나 로그하지 않습니다. 운영 프록시와 Groq의 보존 및 처리 정책은 별도로 적용됩니다.

Groq는 사용량 메타데이터를 보관합니다. 일반 추론 입력과 출력은 기본적으로 보관하지 않지만 장애 조사나 오남용 대응 시 최대 30일 보관할 수 있습니다. 보관되는 고객 데이터의 위치는 미국이며, 계정의 데이터 제어 설정에 따라 달라집니다.

매 요청마다 동의를 확인합니다. 취소해도 기록과 수동 보고서 작성은 사용할 수 있습니다. 취소 시 학습 데이터와 Groq 키를 보내지 않습니다. 전송 이후에는 이미 처리된 정보를 소급하여 회수할 수 없습니다.
"""

    var body: some View {
        NavigationStack {
            Form {
                Section("수신처 및 목적") {
                    Text("보고서 서버: \(request.endpoint)")
                    Text("AI 처리자: Groq, 처리 목적: 학습 반응 수치 보고서 초안")
                }
                Section("전송 제외 및 처리 안내") { Text(Self.privacyNotice).font(.footnote) }
                Section("이번 요청의 실제 전송 데이터") {
                    let encoder = JSONEncoder()
                    Text((try? String(data: encoder.encode(ReportAIPayload(document: request.document)), encoding: .utf8)) ?? "데이터 확인 실패")
                        .font(.caption.monospaced()).textSelection(.enabled)
                }
                Section {
                    Toggle("전송 범위와 수신처를 확인했으며 이번 요청에 동의합니다", isOn: $agreed)
                    Button("동의하고 초안 작성", action: onConfirm).disabled(!agreed)
                    Button("동의하지 않고 취소", role: .cancel) { dismiss() }
                }
            }
            .navigationTitle("AI 데이터 전송 동의")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } } }
        }
    }
}
