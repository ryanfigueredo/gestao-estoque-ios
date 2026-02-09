import SwiftUI
import WebKit

struct FiscalReceiptSheet: View {
    @Environment(\.dismiss) private var dismiss
    let htmlContent: String
    let saleId: String
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            WebView(html: htmlWithViewport(htmlContent))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .ignoresSafeArea(.container)
            .background(Color(.systemBackground))
            .navigationTitle("Cupom fiscal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Compartilhar", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [createHtmlFileURL()])
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func htmlWithViewport(_ raw: String) -> String {
        let viewport = #"<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0, user-scalable=yes">"#
        let style = #"<style>body { margin: 0; padding: 12px; max-width: 100%; box-sizing: border-box; } * { box-sizing: border-box; }</style>"#
        if raw.lowercased().contains("</head>") {
            return raw.replacingOccurrences(of: "</head>", with: viewport + style + "</head>")
        }
        if raw.lowercased().contains("<html") {
            return raw.replacingOccurrences(of: "<body", with: "<head>" + viewport + style + "</head><body", options: .caseInsensitive)
        }
        return "<!DOCTYPE html><html><head>" + viewport + style + "</head><body>" + raw + "</body></html>"
    }

    private func createHtmlFileURL() -> URL {
        let filename = "CupomFiscal-\(saleId.prefix(8)).html"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        try? htmlContent.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct WebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = false
        config.defaultWebpagePreferences = prefs
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.isOpaque = true
        webView.scrollView.bounces = true
        webView.scrollView.minimumZoomScale = 0.5
        webView.scrollView.maximumZoomScale = 3.0
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
