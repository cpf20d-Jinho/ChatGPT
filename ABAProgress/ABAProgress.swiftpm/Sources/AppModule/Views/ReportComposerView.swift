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
    @State private var groqKey = ""
    @State private var aiResult: ReportAIResult?
    @State private var aiFingerprint = ""
    @State private var isBusy = false
    @State private var consentRequest: ReportConsentRequest?
    @State private var connectionStatus: String?
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
            DisclosureGroup("참고용 관찰 기록 · 기기에만 보관") {
                field("직접 작성 참고 메모 · AI 전송 제외", $draft.confirmedObservations)
                Text("이 메모는 AI에 전송되지 않습니다. AI는 학습 반응 수치만 설명하며 원인·기능·촉구 수준을 추측하지 않습니다.")
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
            shareURL = nil
            do { try ReportDraftStore.save(draft, childID: child.id, start: startDate, end: endDate) }
            catch { self.error = "보고서 저장 실패: \(error.localizedDescription)" }
        }
        .onChange(of: document.fingerprint) {
            reviewed = false
            shareURL = nil
        }
        .sheet(item: $consentRequest) { request in
            ReportConsentSheet(request: request) {
                consentRequest = nil
                generate(request)
            }
        }
    }

    private var seriesLegend: String {
        let labels = document.goals.flatMap { goal in
            Set(goal.points.map(\.level)).sorted().map { level in
                "\(goal.name) · L\(level)"
            }
        }
        return labels.enumerated().map { "계열 \($0.offset + 1): \($0.element)" }.joined(separator: "\n")
    }

    private var aiControls: some View {
        DisclosureGroup("AI 초안 작성 · 서버 연결 필요") {
            Text("Groq의 GPT-OSS 120B가 번호로 구분한 수치 요약만 해석합니다. 최초 한 번 본인의 API 키를 등록하면 이후 요청에 자동으로 사용됩니다.")
                .font(.footnote).foregroundStyle(.secondary)
            Link("Groq 계정 로그인 · API 키 만들기", destination: URL(string: "https://console.groq.com/keys")!)
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
            Text("키는 이 기기의 Keychain에 저장합니다. 삭제는 기기에서 키를 지우며, 발급된 키 자체를 폐기하려면 Groq Console을 이용하세요.")
                .font(.caption).foregroundStyle(.secondary)
            Text(endpoint.isEmpty ? "운영 서버 설정이 필요합니다." : "연결 서버: \(endpoint)")
                .font(.footnote).textSelection(.enabled)
            SecureField("보고서 서버 접속 토큰 (Groq 키 아님)", text: $token)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("서버 연결 확인 · 학습 데이터 전송 없음") {
                isBusy = true
                Task { @MainActor in
                    defer { isBusy = false }
                    do {
                        try await ReportAIClient.checkConnection(endpoint: endpoint, token: token)
                        connectionStatus = "서버 인증·통신 확인 완료. Groq 호출은 아직 수행하지 않았습니다."
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
            DisclosureGroup("계열 번호 대응표 · 기기에만 표시") {
                Text(seriesLegend).font(.footnote).textSelection(.enabled)
            }
            Button("현황 · 주요 변화 초안 요청") {
                consentRequest = ReportConsentRequest(document: document, endpoint: endpoint, token: token, groqKey: groqKey)
            }
                .disabled(isBusy || !loaded || endpoint.isEmpty || token.isEmpty || groqKey.isEmpty || document.goals.isEmpty)
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
                    Set(goal.points.map(\.level)).sorted().map { "\(goal.name) · L\($0)" }
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

private struct ReportConsentRequest: Identifiable {
    let id = UUID()
    let document: ReportDocument
    let endpoint: String
    let token: String
    let groqKey: String
}

private struct ReportConsentSheet: View {
    let request: ReportConsentRequest
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var agreed = false
    static let privacyNotice = """
아동명·생년월일·기관명·프로그램명·날짜·메모·치료사 소견·서명은 AI 전송에서 제외합니다. 이름을 가린 문서나 PDF도 전송하지 않습니다.

학습별·단계별 반응률 배열만 보고서 서버에 보내고, 서버는 번호·관측 수·초기/최근 평균·차이·범위·비교 구간 중복 여부만 Groq에 전달합니다. 숫자만으로 완전한 익명성을 보장하지는 않습니다.

목적은 학습 반응 데이터에 근거한 현황과 주요 변화의 초안 작성입니다. 진단·치료 효과·행동 원인을 판단하지 않습니다. 치료사 소견 이후는 직접 작성하며 초안은 사용자가 검토·적용합니다.

연결에는 서버 접속 토큰과 Groq 키가 사용됩니다. 앱은 키를 Keychain에 저장하며, 제공된 서버 코드는 요청 본문과 키를 저장하거나 로그하지 않습니다. 운영 프록시와 Groq의 보존·처리 정책은 별도로 적용됩니다.

Groq는 사용량 메타데이터를 보관합니다. 일반 추론 입력·출력은 기본적으로 보관하지 않지만 장애 조사·오남용 대응 시 최대 30일 보관할 수 있습니다. 보관되는 고객 데이터의 위치는 미국이며, 계정의 데이터 제어 설정에 따라 달라집니다.

매 요청마다 동의를 확인합니다. 취소해도 기록·수동 보고서 작성은 사용할 수 있습니다. 취소 시 학습 데이터와 Groq 키를 보내지 않습니다. 전송 이후에는 이미 처리된 정보를 소급하여 회수할 수 없습니다.
"""

    var body: some View {
        NavigationStack {
            Form {
                Section("수신처 및 목적") {
                    Text("보고서 서버: \(request.endpoint)")
                    Text("AI 처리자: Groq · 학습 반응 수치 보고서 초안")
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
