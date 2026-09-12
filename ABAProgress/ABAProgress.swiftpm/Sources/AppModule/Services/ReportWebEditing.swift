import Foundation
import CryptoKit

struct ReportEditableText: Codable, Equatable {
    var behavior: String
    var currentStatus: String
    var majorChanges: String
    var therapistOpinion: String
    var homePractice: String
    var nextGoals: String

    init(_ draft: ReportDraft) {
        behavior = draft.behavior; currentStatus = draft.currentStatus
        majorChanges = draft.majorChanges; therapistOpinion = draft.therapistOpinion
        homePractice = draft.homePractice; nextGoals = draft.nextGoals
    }
    var rows: [(String, String)] {
        [("도전적 행동 변화", behavior), ("종합 현황", currentStatus), ("강점과 주요 변화", majorChanges),
         ("치료사 종합 소견", therapistOpinion), ("가정에서 함께 하기", homePractice), ("다음 목표", nextGoals)]
    }
    func validate() throws {
        guard rows.allSatisfy({ $0.1.utf16.count <= 12000 }) else {
            throw ReportWebEditing.failure("각 서술 항목은 12,000자 이내로 작성하세요.")
        }
    }
    func applying(to original: ReportDraft) -> ReportDraft {
        var result = original
        result.behavior = behavior; result.currentStatus = currentStatus
        result.majorChanges = majorChanges; result.therapistOpinion = therapistOpinion
        result.homePractice = homePractice; result.nextGoals = nextGoals
        result.reviewedFingerprint = ""
        return result
    }
}

struct ReportWebSession {
    let id: String
    let capability: String
    let key: SymmetricKey
    var expiresAt: Date
    let baseURL: URL
    let original: ReportEditableText
    let fingerprint: String
    var link: URL {
        var parts = URLComponents(url: baseURL.appendingPathComponent("editor"), resolvingAgainstBaseURL: false)!
        let raw = key.withUnsafeBytes { Data($0).base64EncodedString() }
        var fragment = URLComponents()
        fragment.queryItems = [URLQueryItem(name: "id", value: id), URLQueryItem(name: "cap", value: capability), URLQueryItem(name: "key", value: raw)]
        // URLSearchParams interprets a literal '+' as a space.
        parts.percentEncodedFragment = fragment.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return parts.url!
    }
}

enum ReportWebEditing {
    static let notice = """
선택한 보고서의 도전적 행동 변화, 종합 현황, 주요 변화, 치료사 소견, 가정 안내와 다음 목표만 편집합니다. 아동 프로필, 생년월일, 시행 기록, 그래프, 표지, 서명과 참고 메모는 포함하지 않습니다. 문장에 직접 적은 개인정보는 자동으로 제거되지 않으므로 전송 전에 삭제하세요.

여섯 항목을 기기에서 암호화한 뒤 Render 보고서 서버(싱가포르)의 메모리에 처음 1시간 임시 보관합니다. 웹에서 30분씩 연장할 수 있지만 계정 만료 시각을 넘길 수 없습니다. AI에는 보내지 않습니다. 무료 서버가 중지되거나 재시작되면 더 일찍 사라질 수 있습니다. 서버 저장은 백업이 아니며, 앱 원본은 유지됩니다. 연결 과정에서 서비스 제공자가 IP 등 접속 정보를 처리할 수 있습니다.

전용 링크를 가진 사람은 해당 서술을 읽고 수정할 수 있습니다. 신뢰하는 기기에서만 열고 공유 대상에 주의하세요. 편집 후 앱에서 가져와 검토하고 반영해야 합니다. 앱을 종료하면 링크를 복구할 수 없으며 새 링크를 만들어야 합니다. 취소해도 기기 내 수동 작성은 계속 사용할 수 있습니다.
"""
    static func failure(_ message: String) -> NSError {
        NSError(domain: "ReportWebEditing", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
    static func seal(_ text: ReportEditableText, key: SymmetricKey) throws -> String {
        try text.validate()
        let box = try AES.GCM.seal(JSONEncoder().encode(text), using: key)
        guard let data = box.combined else { throw failure("암호화하지 못했습니다.") }
        return data.base64EncodedString()
    }
    static func open(_ ciphertext: String, key: SymmetricKey) throws -> ReportEditableText {
        guard ciphertext.count <= 590000, let data = Data(base64Encoded: ciphertext) else { throw failure("수정본 형식이 올바르지 않습니다.") }
        let plain = try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
        guard let object = try JSONSerialization.jsonObject(with: plain) as? [String: Any],
              Set(object.keys) == Set(["behavior", "currentStatus", "majorChanges", "therapistOpinion", "homePractice", "nextGoals"]) else {
            throw failure("허용되지 않은 수정 항목입니다.")
        }
        let text = try JSONDecoder().decode(ReportEditableText.self, from: plain)
        try text.validate()
        return text
    }
    static func create(text: ReportEditableText, fingerprint: String, endpoint: String, token: String) async throws -> ReportWebSession {
        let approvedHost = Bundle.main.object(forInfoDictionaryKey: "ABAReportServerHost") as? String
        let base = try ReportAIClient.validatedURL(endpoint, approvedHost: approvedHost).deletingLastPathComponent()
        let key = SymmetricKey(size: .bits256)
        let body: [String: Any] = ["ciphertext": try seal(text, key: key), "revision": 0]
        let data = try await request(base.appendingPathComponent("edit-sessions"), method: "POST", headers: ["Authorization": "Bearer \(token)", "X-ABA-Consent": "encrypted-edit-v1"], body: body)
        struct Created: Decodable { let id: String; let capability: String; let expiresAt: Double }
        let created = try JSONDecoder().decode(Created.self, from: data)
        guard created.id.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil,
              created.capability.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else { throw failure("서버 응답이 올바르지 않습니다.") }
        return ReportWebSession(id: created.id, capability: created.capability, key: key,
            expiresAt: Date(timeIntervalSince1970: created.expiresAt / 1000), baseURL: base, original: text, fingerprint: fingerprint)
    }
    static func fetch(_ session: ReportWebSession) async throws -> (text: ReportEditableText, expiresAt: Date) {
        let data = try await request(session.baseURL.appendingPathComponent("edit-sessions/\(session.id)"), method: "GET", headers: ["X-ABA-Edit-Capability": session.capability])
        struct Envelope: Decodable { let ciphertext: String; let expiresAt: Double }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return (try open(envelope.ciphertext, key: session.key), Date(timeIntervalSince1970: envelope.expiresAt / 1000))
    }
    static func close(_ session: ReportWebSession) async throws {
        _ = try await request(session.baseURL.appendingPathComponent("edit-sessions/\(session.id)"), method: "DELETE", headers: ["X-ABA-Edit-Capability": session.capability], allowMissing: true)
    }
    private static func request(_ url: URL, method: String, headers: [String: String], body: [String: Any]? = nil, allowMissing: Bool = false) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method; request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let connection = URLSession(configuration: .ephemeral, delegate: ReportNoRedirect(), delegateQueue: nil)
        defer { connection.invalidateAndCancel() }
        let (data, response) = try await connection.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 || status == 201 || (allowMissing && status == 404) else {
            switch status {
            case 401: throw failure("서버 접속 토큰을 확인하세요.")
            case 404: throw failure("편집 링크가 만료되었거나 서버가 재시작되었습니다. 앱 원본은 유지됩니다.")
            case 429: throw failure("편집 요청이 많습니다. 기존 링크를 종료하거나 잠시 후 다시 시도하세요.")
            default: throw failure("웹 편집 서버에 연결하지 못했습니다. 앱 원본은 유지됩니다.")
            }
        }
        return data
    }
}

