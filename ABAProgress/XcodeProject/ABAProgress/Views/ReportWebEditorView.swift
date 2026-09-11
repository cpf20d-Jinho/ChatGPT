import SwiftUI

struct ReportWebEditorView: View {
    @Binding var draft: ReportDraft
    @Binding var session: ReportWebSession?
    let fingerprint: String
    let endpoint: String
    @Binding var token: String
    let persist: (ReportDraft) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var agreed = false
    @State private var busy = false
    @State private var message: String?
    @State private var preview: ReportEditableText?

    var body: some View {
        NavigationStack {
            Form {
                if let session {
                    Section("편집 링크") {
                        Text("만료: \(session.expiresAt.formatted(date: .omitted, time: .shortened))")
                        Link("이 기기에서 웹 편집 열기", destination: session.link)
                        ShareLink(item: session.link) { Label("다른 기기로 편집 링크 전달", systemImage: "square.and.arrow.up") }
                        Text("링크를 가진 사람은 이 보고서의 서술을 읽고 수정할 수 있습니다.").font(.footnote)
                    }
                    Section {
                        Button("웹 수정본 검토", action: fetch).disabled(busy)
                        Button("링크 종료 및 임시본 삭제", role: .destructive, action: close).disabled(busy)
                    }
                } else {
                    Section("서버 접속") {
                        LabeledContent("수신 서버", value: URL(string: endpoint)?.host ?? "설정 필요")
                        SecureField("보고서 서버 접속 토큰", text: $token)
                            .textInputAutocapitalization(.never).autocorrectionDisabled().privacySensitive()
                    }
                    Section("전송 전 확인") {
                        Text(ReportWebEditing.notice)
                        DisclosureGroup("전송할 여섯 항목 보기") {
                            textRows(ReportEditableText(draft))
                        }
                        Toggle("전송 범위와 링크 접근 권한을 확인했으며 동의합니다", isOn: $agreed)
                        Button("동의하고 편집 링크 만들기", action: create)
                            .disabled(!agreed || busy || token.isEmpty || endpoint.isEmpty)
                    }
                }
                if let preview {
                    Section("적용 전 웹 수정본 검토") {
                        textRows(preview)
                        Button("검토한 여섯 항목 적용", action: apply).disabled(busy)
                        Button("수정본 닫기") { self.preview = nil }
                    }
                }
                if busy { ProgressView("처리 중…") }
                if let message { Section { Text(message).accessibilityAddTraits(.updatesFrequently) } }
            }
            .navigationTitle("보고서 웹 편집")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("닫기") { dismiss() }.disabled(busy) } }
            .interactiveDismissDisabled(busy)
        }
    }

    private func textRows(_ text: ReportEditableText) -> some View {
        ForEach(text.rows, id: \.0) { title, content in
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(content.isEmpty ? "작성 내용 없음" : content).textSelection(.enabled)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
        }
    }
    private func create() {
        let text = ReportEditableText(draft), source = fingerprint
        let serverToken = token
        busy = true; message = nil
        Task { @MainActor in
            defer { busy = false }
            do { session = try await ReportWebEditing.create(text: text, fingerprint: source, endpoint: endpoint, token: serverToken) }
            catch { message = error.localizedDescription }
        }
    }
    private func fetch() {
        guard let session else { return }
        busy = true; message = nil
        Task { @MainActor in
            defer { busy = false }
            do { preview = try await ReportWebEditing.fetch(session) }
            catch { message = error.localizedDescription }
        }
    }
    private func apply() {
        guard let session, let preview else { return }
        guard session.fingerprint == fingerprint, session.original == ReportEditableText(draft) else {
            message = "링크 생성 후 앱의 기록이나 서술이 변경되었습니다. 덮어쓰지 않았습니다. 필요한 웹 문장을 복사해 직접 반영하거나 새 링크를 만드세요."
            return
        }
        let updated = preview.applying(to: draft)
        do { try persist(updated) }
        catch { message = "기기에 저장하지 못해 적용을 중단했습니다. \(error.localizedDescription)"; return }
        draft = updated
        self.preview = nil
        message = "서술을 적용했습니다. 앱에서 전체 보고서를 다시 검토하고 PDF를 생성하세요. 링크를 종료하면 임시본이 삭제됩니다."
    }
    private func close() {
        guard let session else { return }
        busy = true
        Task { @MainActor in
            defer { busy = false }
            do {
                try await ReportWebEditing.close(session)
                self.session = nil; preview = nil; agreed = false
                message = "링크를 종료했습니다. 앱의 보고서는 유지됩니다."
            } catch { message = "종료를 확인하지 못했습니다. 링크는 만료 시 사용할 수 없게 됩니다. \(error.localizedDescription)" }
        }
    }
}
