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

    func makeUIView(context _: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let resourceSchemeHandler = ResourceURLSchemeHandler()
        let mediaSchemeHandler = MediaURLSchemeHandler()
        let lookupSchemeHandler = DictionaryLookupURLSchemeHandler()
        configuration.setURLSchemeHandler(resourceSchemeHandler, forURLScheme: "marureader-resource")
        configuration.setURLSchemeHandler(mediaSchemeHandler, forURLScheme: "marureader-media")
        configuration.setURLSchemeHandler(lookupSchemeHandler, forURLScheme: "marureader-lookup")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isInspectable = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context _: Context) {
        webView.loadHTMLString(lookupResponse.toPopupHTML(), baseURL: nil)
    }
}
