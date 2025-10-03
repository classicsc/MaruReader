//
//  DictionaryPopupContentView.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

import SwiftUI
import WebKit

struct DictionaryPopupContentView: UIViewRepresentable {
    let lookupResponse: TextLookupResponse
    let onTermSelected: (String) -> Void

    func makeCoordinator() -> DictionaryPopupCoordinator {
        DictionaryPopupCoordinator(onTermSelected: onTermSelected)
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "dictionaryTermSelected")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isInspectable = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context _: Context) {
        webView.loadHTMLString(lookupResponse.toPopupHTML(), baseURL: nil)
    }
}

class DictionaryPopupCoordinator: NSObject, WKScriptMessageHandler {
    let onTermSelected: (String) -> Void

    init(onTermSelected: @escaping (String) -> Void) {
        self.onTermSelected = onTermSelected
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "dictionaryTermSelected", let term = message.body as? String {
            onTermSelected(term)
        }
    }
}
