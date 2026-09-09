import Foundation
import UIKit
import WebKit
#if DEBUG
import PDFKit
#endif

@MainActor
final class ReportTemplateExporter: NSObject, WKNavigationDelegate {
    private let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 687, height: 980))
    private var navigation: CheckedContinuation<Void, Error>?
    private var loadTimeout: Task<Void, Never>?

    static func export(_ document: ReportDocument) async throws -> URL {
        let job = ReportTemplateExporter()
        return try await job.run(document)
    }

    private func run(_ document: ReportDocument) async throws -> URL {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let source = bundle.url(forResource: "ReportTemplate", withExtension: "html") else {
            throw NSError(domain: "Report", code: 1, userInfo: [NSLocalizedDescriptionKey: "보고서 템플릿이 없습니다."])
        }
        webView.navigationDelegate = self
        let html = try String(contentsOf: source, encoding: .utf8)
        try await withCheckedThrowingContinuation { continuation in
            navigation = continuation
            webView.loadHTMLString(html, baseURL: nil)
            loadTimeout = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, let self else { return }
                self.navigation?.resume(throwing: NSError(domain: "Report", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "보고서 양식 로딩 시간이 초과되었습니다."]))
                self.navigation = nil
                self.webView.stopLoading()
            }
        }
        let data = try JSONEncoder().encode(document)
        let object = try JSONSerialization.jsonObject(with: data)
        _ = try await webView.callAsyncJavaScript(
            "renderReport(doc); await document.fonts.ready; return true;",
            arguments: ["doc": object], in: nil, contentWorld: .page
        )
        let renderer = ReportPageRenderer(institution: document.draft.institution,
                                          copyright: document.draft.copyright)
        renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        guard renderer.numberOfPages > 0 else {
            throw NSError(domain: "Report", code: 3, userInfo: [NSLocalizedDescriptionKey: "인쇄할 보고서 페이지가 없습니다."])
        }
        let output = NSMutableData()
        UIGraphicsBeginPDFContextToData(output, renderer.paperRect, nil)
        for index in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: index, in: renderer.paperRect)
        }
        UIGraphicsEndPDFContext()
        // Each export has a new identity; existing shared PDFs are never silently overwritten.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ABA_Report_\(UUID().uuidString).pdf")
        try (output as Data).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadTimeout?.cancel()
        self.navigation?.resume()
        self.navigation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadTimeout?.cancel()
        self.navigation?.resume(throwing: error)
        self.navigation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        loadTimeout?.cancel()
        self.navigation?.resume(throwing: error)
        self.navigation = nil
    }
}

#if DEBUG
extension ReportTemplateExporter {
    // Only enabled by an explicit simulator environment flag. Never included in Release.
    static func runSyntheticVerification() async {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let output = root.appendingPathComponent("qa-output", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let input = try Data(contentsOf: root.appendingPathComponent("qa-input.json"))
            let documents = try JSONDecoder().decode([ReportDocument].self, from: input)
            var results: [[String: Any]] = []
            for (index, document) in documents.enumerated() {
                let generated = try await export(document)
                let destination = output.appendingPathComponent("report-\(index).pdf")
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: generated, to: destination)
                guard let pdf = PDFDocument(url: destination), let content = pdf.string,
                      content.contains(document.childName), content.contains("검증끝"), pdf.pageCount >= 16 else {
                    throw NSError(domain: "ReportQA", code: 1, userInfo: [NSLocalizedDescriptionKey: "PDF text or page verification failed"])
                }
                if index == 0 && pdf.pageCount != 16 {
                    throw NSError(domain: "ReportQA", code: 2, userInfo: [NSLocalizedDescriptionKey: "Baseline page count: \(pdf.pageCount), expected 16"])
                }
                results.append(["fixture": index, "pages": pdf.pageCount, "textVerified": true])
            }
            try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted])
                .write(to: output.appendingPathComponent("success.json"))
        } catch {
            try? error.localizedDescription.write(to: output.appendingPathComponent("failure.txt"), atomically: true, encoding: .utf8)
        }
    }
}
#endif

@MainActor
private final class ReportPageRenderer: UIPrintPageRenderer {
    private let institution: String
    private let copyright: String
    override var paperRect: CGRect { CGRect(x: 0, y: 0, width: 595, height: 842) }
    override var printableRect: CGRect { CGRect(x: 40, y: 22, width: 515, height: 804) }

    init(institution: String, copyright: String) {
        self.institution = institution
        self.copyright = copyright
        super.init()
        headerHeight = 38
        footerHeight = 25
    }

    override func drawHeaderForPage(at pageIndex: Int, in headerRect: CGRect) {
        draw(institution, in: headerRect, color: UIColor(red: 0.91, green: 0.40, blue: 0.55, alpha: 1), size: 9, alignment: .center)
    }

    override func drawFooterForPage(at pageIndex: Int, in footerRect: CGRect) {
        draw(copyright, in: CGRect(x: footerRect.minX, y: footerRect.minY, width: footerRect.width - 68, height: footerRect.height),
             color: .lightGray, size: 6.5, alignment: .center)
        draw("Page \(pageIndex + 1) / \(numberOfPages)",
             in: CGRect(x: footerRect.maxX - 65, y: footerRect.minY, width: 65, height: footerRect.height),
             color: .gray, size: 7, alignment: .right)
    }

    private func draw(_ text: String, in rect: CGRect, color: UIColor, size: CGFloat, alignment: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        (text as NSString).draw(in: rect, withAttributes: [
            .font: UIFont.systemFont(ofSize: size), .foregroundColor: color, .paragraphStyle: style
        ])
    }
}
