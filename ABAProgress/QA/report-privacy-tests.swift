import Foundation

// Minimal input fixtures compile against the actual production serializer.
struct ReportDocument { let goals: [ReportGoal] }
struct ReportGoal {
    let name: String
    let points: [Point]
    struct Point { let date: String; let value: Double; let level: Int }
}

@main struct PrivacyChecks {
    static func main() throws {
        let document = ReportDocument(goals: [ReportGoal(name: "SECRET_NAME", points: [
            .init(date: "2026-02-02", value: 60, level: 1),
            .init(date: "2026-02-01", value: 20, level: 1),
            .init(date: "2026-02-03", value: 80, level: 2)
        ])])
        let encoded = try JSONEncoder().encode(ReportAIPayload(document: document))
        let object = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        precondition(Set(object.keys) == ["version", "series"])
        precondition(object["version"] as? Int == 1)
        precondition(object["series"] as? [[Double]] == [[20, 60], [80]])
        let text = String(decoding: encoded, as: UTF8.self)
        precondition(!text.contains("SECRET") && !text.contains("2026"))
        print("PASS: production Swift serializer excludes names/dates and separates ordered levels")
    }
}
