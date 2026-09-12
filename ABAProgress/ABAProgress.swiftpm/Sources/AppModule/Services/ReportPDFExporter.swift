import Foundation
import UIKit

struct ReportPDFExporter {
    enum ExportError: LocalizedError {
        case noPrograms

        var errorDescription: String? {
            switch self {
            case .noPrograms: return "보고서에 포함할 프로그램을 하나 이상 선택하세요."
            }
        }
    }

    static func export(
        child: ChildProfile,
        startDate: Date,
        endDate: Date,
        programs: [TherapyProgram]
    ) throws -> URL {
        guard !programs.isEmpty else { throw ExportError.noPrograms }

        let stamp = DateFormatter()
        stamp.locale = Locale(identifier: "en_US_POSIX")
        stamp.dateFormat = "yyyyMMdd_HHmmss_SSS"
        let suffix = UUID().uuidString.prefix(8)
        let fileName = "\(safeName(child.name))_경과보고서_\(compactDate(startDate))_\(compactDate(endDate))_\(stamp.string(from: Date()))_\(suffix).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)

        try renderer.writePDF(to: url) { context in
            let margin: CGFloat = 42
            let contentWidth = page.width - margin * 2
            var y: CGFloat = margin

            func newPage() {
                context.beginPage()
                y = margin
            }

            func ensureSpace(_ needed: CGFloat) {
                if y + needed > page.height - margin { newPage() }
            }

            newPage()
            drawText("치료 경과 보고서", at: CGRect(x: margin, y: y, width: contentWidth, height: 30), font: .boldSystemFont(ofSize: 22))
            y += 34
            drawText("아동: \(child.name)", at: CGRect(x: margin, y: y, width: contentWidth, height: 22), font: .systemFont(ofSize: 13))
            y += 20
            drawText("기간: \(displayDate(startDate)) ~ \(displayDate(endDate))", at: CGRect(x: margin, y: y, width: contentWidth, height: 22), font: .systemFont(ofSize: 13))
            y += 30

            for program in programs {
                let targets = program.targets
                    .map { ($0, reportEntries(target: $0, startDate: startDate, endDate: endDate)) }
                    .filter { !$0.1.isEmpty }
                guard !targets.isEmpty else { continue }
                ensureSpace(40)
                drawText(program.name, at: CGRect(x: margin, y: y, width: contentWidth, height: 26), font: .boldSystemFont(ofSize: 17))
                y += 32

                for (target, entries) in targets {
                    ensureSpace(255)
                    drawText(target.name, at: CGRect(x: margin, y: y, width: contentWidth, height: 22), font: .boldSystemFont(ofSize: 13))
                    y += 20
                    let avg = entries.map(\.accuracy).reduce(0, +) / Double(entries.count)
                    let latest = entries.last?.accuracy ?? 0
                    drawText("세션 \(entries.count)회  |  평균 \(String(format: "%.1f", avg))%  |  최근 \(String(format: "%.1f", latest))%  |  상태 \(target.status.rawValue)", at: CGRect(x: margin, y: y, width: contentWidth, height: 18), font: .systemFont(ofSize: 10))
                    y += 22
                    let graphRect = CGRect(x: margin, y: y, width: contentWidth, height: 175)
                    drawGraph(entries: entries, mastery: target.masteryPercent, in: graphRect, context: context.cgContext)
                    y += 186
                    let dates = entries.map { "\(displayShortDate($0.date)) \(Int($0.accuracy.rounded()))%" }.joined(separator: "   ")
                    drawText(dates, at: CGRect(x: margin, y: y, width: contentWidth, height: 28), font: .systemFont(ofSize: 8), color: .darkGray)
                    y += 34
                }
                y += 6
            }
        }
        return url
    }

    private struct Entry { let date: Date; let accuracy: Double }

    private static func reportEntries(target: TherapyTarget, startDate: Date, endDate: Date) -> [Entry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let endExclusive = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: endDate)) ?? endDate
        return target.sessions
            .filter { $0.completed && $0.hasMeaningfulData && $0.date >= start && $0.date < endExclusive && $0.accuracy != nil }
            .sorted { $0.date < $1.date }
            .map { Entry(date: $0.date, accuracy: $0.accuracy ?? 0) }
    }

    private static func drawGraph(entries: [Entry], mastery: Double, in rect: CGRect, context: CGContext) {
        context.saveGState(); defer { context.restoreGState() }
        let left: CGFloat = 32, right: CGFloat = 10, top: CGFloat = 12, bottom: CGFloat = 28
        let plot = CGRect(x: rect.minX + left, y: rect.minY + top, width: rect.width - left - right, height: rect.height - top - bottom)
        context.setStrokeColor(UIColor.systemGray4.cgColor); context.setLineWidth(0.6)
        for pct in stride(from: 0, through: 100, by: 20) {
            let y = plot.maxY - CGFloat(pct) / 100 * plot.height
            context.move(to: CGPoint(x: plot.minX, y: y)); context.addLine(to: CGPoint(x: plot.maxX, y: y)); context.strokePath()
            drawText("\(pct)", at: CGRect(x: rect.minX, y: y - 6, width: left - 5, height: 12), font: .systemFont(ofSize: 7), color: .gray, alignment: .right)
        }
        let criterionY = plot.maxY - CGFloat(mastery / 100) * plot.height
        context.setStrokeColor(UIColor.systemGray.cgColor); context.setLineDash(phase: 0, lengths: [4, 3])
        context.move(to: CGPoint(x: plot.minX, y: criterionY)); context.addLine(to: CGPoint(x: plot.maxX, y: criterionY)); context.strokePath(); context.setLineDash(phase: 0, lengths: [])
        guard !entries.isEmpty else { return }
        let spacing = entries.count > 1 ? plot.width / CGFloat(entries.count - 1) : 0
        let points: [CGPoint] = entries.enumerated().map { index, entry in CGPoint(x: entries.count == 1 ? plot.midX : plot.minX + CGFloat(index) * spacing, y: plot.maxY - CGFloat(entry.accuracy / 100) * plot.height) }
        context.setStrokeColor(UIColor.systemBlue.cgColor); context.setLineWidth(1.6)
        if let first = points.first { context.move(to: first); for point in points.dropFirst() { context.addLine(to: point) }; context.strokePath() }
        context.setFillColor(UIColor.systemBlue.cgColor)
        for point in points { context.fillEllipse(in: CGRect(x: point.x - 2.7, y: point.y - 2.7, width: 5.4, height: 5.4)) }
        for (index, entry) in entries.enumerated() { let x = points[index].x; drawText(displayShortDate(entry.date), at: CGRect(x: x - 18, y: plot.maxY + 6, width: 36, height: 12), font: .systemFont(ofSize: 6.5), color: .darkGray, alignment: .center) }
    }

    private static func drawText(_ text: String, at rect: CGRect, font: UIFont, color: UIColor = .label, alignment: NSTextAlignment = .left) {
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = alignment
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        (text as NSString).draw(in: rect, withAttributes: attributes)
    }

    private static func compactDate(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "yyyyMMdd"; return f.string(from: date) }
    private static func displayDate(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "yyyy.MM.dd"; return f.string(from: date) }
    private static func displayShortDate(_ date: Date) -> String { let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date) }
    private static func safeName(_ name: String) -> String { name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-") }
}

