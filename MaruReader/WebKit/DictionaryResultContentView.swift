//
//  DictionaryResultContentView.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

import os.log
import SwiftUI
import WebKit

struct DictionaryResultContentView: UIViewRepresentable {
    let lookupResponse: TextLookupResponse
    let searchService: DictionarySearchService
    let onPopupRequest: (TextLookupResponse, CGRect) -> Void
    let onTermSelected: (String) -> Void

    @Binding var webViewRef: WKWebView?

    func makeCoordinator() -> DictionaryResultCoordinator {
        DictionaryResultCoordinator(
            parent: self,
            searchService: searchService,
            onPopupRequest: onPopupRequest,
            onTermSelected: onTermSelected
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "textSelection")
        contentController.add(context.coordinator, name: "dictionaryTermSelected")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isInspectable = true

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
        tapGesture.delegate = context.coordinator
        webView.addGestureRecognizer(tapGesture)

        DispatchQueue.main.async {
            self.webViewRef = webView
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context _: Context) {
        webView.loadHTMLString(lookupResponse.toResultsHTML(), baseURL: nil)
    }
}

class DictionaryResultCoordinator: NSObject, WKScriptMessageHandler, UIGestureRecognizerDelegate {
    var parent: DictionaryResultContentView
    let searchService: DictionarySearchService
    let onPopupRequest: (TextLookupResponse, CGRect) -> Void
    let onTermSelected: (String) -> Void

    private let lookupContextLevel = 0
    private let maxLookupContext = 250

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryResultCoordinator")

    init(parent: DictionaryResultContentView, searchService: DictionarySearchService, onPopupRequest: @escaping (TextLookupResponse, CGRect) -> Void, onTermSelected: @escaping (String) -> Void) {
        self.parent = parent
        self.searchService = searchService
        self.onPopupRequest = onPopupRequest
        self.onTermSelected = onTermSelected
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "dictionaryTermSelected", let term = message.body as? String {
            onTermSelected(term)
        }
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let webView = gesture.view as? WKWebView else { return }

        let point = gesture.location(in: webView)
        let script = "window.MaruReader.textScanning.extractTextAtPoint(\(point.x), \(point.y), \(lookupContextLevel), \(maxLookupContext));"

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.logger.error("JavaScript error: \(error.localizedDescription)")
            } else if let result {
                if let resultObject = result as? [String: Any],
                   let offset = resultObject["offset"] as? Int,
                   let context = resultObject["context"] as? String,
                   let cssSelector = resultObject["cssSelector"] as? String
                {
                    self.logger.info("Extracted text at offset \(offset) with context length \(context.count) and CSS selector \(cssSelector)")
                    self.logger.info("Character at offset: \(context[context.index(context.startIndex, offsetBy: offset)])")

                    // Perform dictionary lookup
                    Task {
                        let lookupRequest = TextLookupRequest(
                            id: UUID(),
                            offset: offset,
                            context: context,
                            rubyContext: nil,
                            cssSelector: cssSelector
                        )

                        do {
                            if let lookupResponse = try await self.searchService.performTextLookup(query: lookupRequest) {
                                // Calculate popup frame
                                let popupFrame = CGRect(x: point.x, y: point.y, width: 300, height: 400)

                                await MainActor.run {
                                    self.onPopupRequest(lookupResponse, popupFrame)
                                }
                            }
                        } catch {
                            self.logger.error("Lookup error: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                self.logger.info("Text extraction result: \(String(describing: result))")
            }
        }
    }

    // Allow simultaneous gesture recognition with WKWebView's internal gestures
    func gestureRecognizer(_: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }
}
