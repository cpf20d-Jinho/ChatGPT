import SwiftUI

struct ReportComposerView: View {
    let child: ChildProfile
    let startDate: Date
    let endDate: Date
    let programs: [TherapyProgram]
    @State private var draft = ReportDraft()
    @State private var loaded = false
    @State private var error: String?
    @State private var endpoint = ""
    @State private var token = ""
    @State private var aiResult: ReportAIResult?
    @State private var aiFingerprint = ""
    @State private var isBusy = false
    @State private var showConsent = false
    @State private var shareURL: URL?
    @State private var reviewed = false

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
            Label("중간보고서 기본 양식", systemImage: ABASymbol.pdf).font(.title3.bold())
            Text("STO는 프로그램의 기록된 레벨 단위로 집계합니다. 서술은 아동·보고기간별로 기기에 자동 저장됩니다.")
                .font(.footnote).foregroundStyle(.secondary)
            DisclosureGroup("표지 · 기관 · 서명 정보") {
                field("기관명", $draft.institution)
                field("담당 치료사", $draft.therapist)
                field("소속반", $draft.className)
                field("프로그램 분류 표시", $draft.programFamily)
                field("주 횟수", $draft.schedule)
                field("회기 시간", $draft.duration)
                field("기관장", $draft.director)
                field("기관장 자격 정보", $draft.directorCredential)
                field("서명 일자", $draft.signedDate)
                field("하단 저작권 · 출처 문구", $draft.copyright)
            }
            DisclosureGroup("평가군 분류") {
                ForEach(programs) { program in
                    TextField(program.name, text: Binding(
                        get: { draft.groupByProgram[program.id.uuidString] ?? "기타 목표" },
                        set: { draft.groupByProgram[program.id.uuidString] = $0 }
                    )).textFieldStyle(.roundedBorder)
                    .accessibilityLabel("\(program.name) 평가군: ELCAR 평가 또는 기타 목표")
                }
            }
            field("도전적 행동 변화 · 직접 작성", $draft.behavior)
            DisclosureGroup("AI에 제공할 확인된 관찰 기록") {
                field("관찰 사실만 입력 · 이름 등 개인정보 제외", $draft.confirmedObservations)
                Text("원인·기능·촉구 수준은 측정값으로 추측하지 않습니다. 필요할 때만 확인된 관찰을 입력하세요.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            field("종합 현황 · AI 초안 또는 직접 작성", $draft.currentStatus)
            field("이번 기간의 강점과 주요 변화 · AI 초안 또는 직접 작성", $draft.majorChanges)
            aiControls
            Divider()
            Text("이하 항목은 AI가 작성하거나 덮어쓰지 않습니다.").font(.footnote).foregroundStyle(.secondary)
            field("치료사 종합 소견", $draft.therapistOpinion)
            field("가정에서 함께 하기", $draft.homePractice)
            field("다음 목표", $draft.nextGoals)
            Toggle("집계 기준·그래프·서술 내용을 검토했습니다", isOn: $reviewed)
            Button {
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
                        shareURL = url
                    }
                    catch { self.error = error.localizedDescription }
                }
            } label: {
                Label(isBusy ? "처리 중…" : "기본 양식 PDF 생성", systemImage: ABASymbol.pdf)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(isBusy || !reviewed || !loaded || document.goals.isEmpty)
            if let shareURL {
                ShareLink(item: shareURL) { Label("PDF 공유 / 저장", systemImage: ABASymbol.share) }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .abaSurface()
        .task {
            do {
                draft = try ReportDraftStore.load(childID: child.id, start: startDate, end: endDate)
                loaded = true
            } catch {
                self.error = "저장된 보고서를 읽지 못했습니다. 기존 파일을 보호하기 위해 편집 저장을 중단합니다. \(error.localizedDescription)"
            }
        }
        .onChange(of: draft) {
            guard loaded else { return }
            reviewed = false
            shareURL = nil
            do { try ReportDraftStore.save(draft, childID: child.id, start: startDate, end: endDate) }
            catch { self.error = "보고서 저장 실패: \(error.localizedDescription)" }
        }
        .onChange(of: document.fingerprint) {
            reviewed = false
            shareURL = nil
        }
        .confirmationDialog("선택한 서버와 OpenAI API로 전송할까요?", isPresented: $showConsent) {
            Button("전송 내용 확인 완료 · AI 초안 요청") { generate() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("전송 전 아래 JSON을 확인하세요. 아동명·생년월일·서명은 제외되지만 프로그램명과 관찰 기록에 개인정보가 남아 있을 수 있습니다. 동의·기관 정책을 확인한 경우에만 전송하세요.")
        }
    }

    private var aiControls: some View {
        DisclosureGroup("AI 초안 작성 · 서버 연결 필요") {
            TextField("HTTPS 보고서 서버 주소", text: $endpoint)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("보고서 서버 접속 토큰 (OpenAI 키 아님)", text: $token)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            DisclosureGroup("전송할 데이터 검토") {
                Text(payloadPreview).font(.caption.monospaced()).textSelection(.enabled)
            }
            Button("현황 · 주요 변화 초안 요청") { showConsent = true }
                .disabled(isBusy || !loaded || endpoint.isEmpty || token.isEmpty || document.goals.isEmpty)
            if let result = aiResult {
                Text("AI 초안 · 검토 전").font(.headline)
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
        }
    }

    private func field(_ title: String, _ value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.medium))
            TextField(title, text: value, axis: .vertical)
                .lineLimit(2...12).textFieldStyle(.roundedBorder)
                .disabled(!loaded)
        }
    }

    private func generate() {
        let snapshot = document
        let payload = ReportAIPayload(document: snapshot)
        isBusy = true
        Task { @MainActor in
            defer { isBusy = false }
            do {
                let result = try await ReportAIClient.generate(payload: payload, endpoint: endpoint, token: token)
                guard snapshot.fingerprint == document.fingerprint else {
                    error = "생성 중 데이터가 변경되었습니다. 초안을 다시 요청하세요."
                    return
                }
                aiFingerprint = snapshot.fingerprint
                aiResult = result
            } catch { self.error = error.localizedDescription }
        }
    }
}
