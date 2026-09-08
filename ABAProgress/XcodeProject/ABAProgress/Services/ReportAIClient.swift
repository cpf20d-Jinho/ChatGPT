import Foundation

struct ReportAIResult: Codable {
    let currentStatus: String
    let majorChanges: String
    let warnings: [String]
}

struct ReportAIPayload: Codable {
    struct Domain: Codable {
        let name: String
        let stoCount: Int
        let initialMean: Double
        let recentMean: Double
    }
    let templateVersion: String
    let stoCount: Int
    let masteredCount: Int
    let domains: [Domain]
    let goals: [ReportGoal]
    let confirmedObservations: String

    init(document: ReportDocument) {
        templateVersion = "geomdan-interim-v1"
        stoCount = document.stoCount
        masteredCount = document.masteredCount
        domains = document.domains.map {
            Domain(name: $0.name, stoCount: $0.count, initialMean: $0.first, recentMean: $0.recent)
        }
        goals = document.goals
        confirmedObservations = document.draft.confirmedObservations
    }
}

enum ReportAIClient {
    static func generate(payload: ReportAIPayload, endpoint: String, token: String) async throws -> ReportAIResult {
        guard let url = URL(string: endpoint), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, !token.isEmpty else {
            throw NSError(domain: "ReportAI", code: 1, userInfo: [NSLocalizedDescriptionKey:
                "인증된 HTTPS 보고서 서버 주소와 접속 토큰을 입력하세요. OpenAI API 키를 앱에 입력하지 마세요."])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "ReportAI", code: 2, userInfo: [NSLocalizedDescriptionKey:
                "AI 초안을 가져오지 못했습니다. 서버 인증·사용량·모델 설정을 확인하세요. 기존 작성 내용은 유지됩니다."])
        }
        let result = try JSONDecoder().decode(ReportAIResult.self, from: data)
        guard !result.currentStatus.isEmpty, !result.majorChanges.isEmpty,
              result.currentStatus.count <= 12000, result.majorChanges.count <= 12000 else {
            throw NSError(domain: "ReportAI", code: 3, userInfo: [NSLocalizedDescriptionKey: "AI 응답 형식이 올바르지 않습니다."])
        }
        return result
    }
}
