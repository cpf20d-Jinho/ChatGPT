import Foundation
import Security

struct ReportAIResult: Codable {
    let currentStatus: String
    let majorChanges: String
    let warnings: [String]
}

struct ReportAIPayload: Codable {
    let version = 1
    let series: [[Double]]

    init(document: ReportDocument) {
        // Labels, IDs, notes and calendar dates never enter the encoded payload.
        series = document.goals.flatMap { goal in
            Set(goal.points.map(\.level)).sorted().map { level in
                goal.points.filter { $0.level == level }
                    .sorted { $0.date < $1.date }.map(\.value)
            }
        }
    }

}

enum ReportAIClient {
    static let consentVersion = "numeric-v1"
    static var configuredEndpoint: String {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "ABAReportServerHost") as? String,
              !host.isEmpty, !host.hasSuffix(".invalid") else { return "" }
        return "https://\(host)/report/narrative"
    }

    static func validatedURL(_ endpoint: String, approvedHost: String?) throws -> URL {
        guard let host = approvedHost, !host.isEmpty, !host.hasSuffix(".invalid"),
              let url = URL(string: endpoint), url.scheme == "https", url.host == host,
              url.port == nil || url.port == 443, url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, url.path == "/report/narrative" else {
            throw NSError(domain: "ReportAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "등록된 HTTPS 보고서 서버 설정을 확인하세요."])
        }
        return url
    }

    static func checkConnection(endpoint: String, token: String) async throws {
        let url = try validatedURL(endpoint, approvedHost: Bundle.main.object(forInfoDictionaryKey: "ABAReportServerHost") as? String)
        var request = URLRequest(url: url.deletingLastPathComponent().appendingPathComponent("health"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15
        let session = URLSession(configuration: .ephemeral, delegate: ReportNoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              body["contract"] as? String == consentVersion else {
            throw NSError(domain: "ReportAI", code: 6, userInfo: [NSLocalizedDescriptionKey: "서버 연결 또는 인증에 실패했습니다."])
        }
    }

    static func generate(payload: ReportAIPayload, endpoint: String, token: String, groqKey: String) async throws -> ReportAIResult {
        let approvedHost = Bundle.main.object(forInfoDictionaryKey: "ABAReportServerHost") as? String
        let url = try validatedURL(endpoint, approvedHost: approvedHost)
        guard !token.isEmpty,
              groqKey.hasPrefix("gsk_"), groqKey.count >= 24 else {
            throw NSError(domain: "ReportAI", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "배포 빌드에 등록된 HTTPS 보고서 서버 주소, 접속 토큰과 본인의 Groq API 키를 확인하세요."])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(groqKey, forHTTPHeaderField: "X-Groq-API-Key")
        request.setValue(consentVersion, forHTTPHeaderField: "X-ABA-Consent")
        request.httpBody = try JSONEncoder().encode(payload)
        let session = URLSession(configuration: .ephemeral, delegate: ReportNoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode
            let message: String
            switch status {
            case 401: message = "보고서 서버 접속 토큰을 확인하세요."
            case 422: message = "Groq API 키를 등록하거나 다시 발급하세요."
            case 428: message = "전송 범위를 다시 확인하고 동의하세요."
            case 429: message = "요청이 몰리거나 Groq 무료 한도에 도달했습니다. 잠시 후 다시 요청하세요. 자동 재시도는 하지 않습니다."
            case 413: message = "전송 자료가 너무 큽니다. 보고서 기간이나 프로그램 수를 줄여 다시 요청하세요."
            case 503: message = "Groq API 키와 모델 접근 권한을 확인하세요."
            default: message = "AI 초안을 가져오지 못했습니다. 서버 연결과 모델 설정을 확인하세요."
            }
            throw NSError(domain: "ReportAI", code: 2, userInfo: [NSLocalizedDescriptionKey:
                message + " 기존 작성 내용은 유지됩니다."])
        }
        let result = try JSONDecoder().decode(ReportAIResult.self, from: data)
        guard !result.currentStatus.isEmpty, !result.majorChanges.isEmpty,
              result.currentStatus.count <= 12000, result.majorChanges.count <= 12000 else {
            throw NSError(domain: "ReportAI", code: 3, userInfo: [NSLocalizedDescriptionKey: "AI 응답 형식이 올바르지 않습니다."])
        }
        return result
    }

    static func savedGroqKey() -> String {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "kr.abaprogress.groq", kSecAttrAccount as String: "api-key",
            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func saveGroqKey(_ key: String) throws {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.hasPrefix("gsk_"), clean.count >= 24 else {
            throw NSError(domain: "ReportAI", code: 4, userInfo: [NSLocalizedDescriptionKey: "올바른 Groq API 키를 입력하세요."])
        }
        let identity: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "kr.abaprogress.groq", kSecAttrAccount as String: "api-key"]
        let attributes: [String: Any] = [kSecValueData as String: Data(clean.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let update = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else {
            throw NSError(domain: "ReportAI", code: 5, userInfo: [NSLocalizedDescriptionKey: "기존 키를 유지했습니다. 키 변경에 실패했습니다."])
        }
        var item = identity
        item[kSecValueData as String] = Data(clean.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: "ReportAI", code: 5, userInfo: [NSLocalizedDescriptionKey: "Groq 키를 기기에 안전하게 저장하지 못했습니다."])
        }
    }

    static func deleteGroqKey() throws {
        let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "kr.abaprogress.groq", kSecAttrAccount as String: "api-key"] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "ReportAI", code: 5, userInfo: [NSLocalizedDescriptionKey: "기기에 저장된 키를 삭제하지 못했습니다."])
        }
    }
}

final class ReportNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Custom key headers must never follow redirects, even to another HTTPS host.
        completionHandler(nil)
    }
}
