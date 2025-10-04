//
//  DictionaryPopupView.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/3/25.
//

import os.log
import SwiftUI
import WebKit

struct DictionaryPopupView: View {
    @State private var page: WebPage
    @Binding var query: String?
    @Binding var context: String?

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionaryPopupView")

    init(query: Binding<String?>, context: Binding<String?>, onNavigate: @escaping @Sendable (String) -> Void) {
        self._query = query
        self._context = context

        var config = WebPage.Configuration()
        config.urlSchemeHandlers[URLScheme("marureader-media")!] = MediaURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-resource")!] = ResourceURLSchemeHandler()
        config.urlSchemeHandlers[URLScheme("marureader-lookup")!] = DictionaryLookupURLSchemeHandler(
            onNavigate: onNavigate,
            onScan: { _, _, _ in }
        )
        self._page = State(initialValue: WebPage(configuration: config))
    }

    var body: some View {
        WebView(page)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.separator), lineWidth: 1)
            )
            .cornerRadius(12)
            .shadow(radius: 10)
            .task(id: query) {
                // Load initial page or update when query changes
                performSearch(query)
            }
    }

    private func performSearch(_ query: String?) {
        guard let query else {
            if let url = lookupURL(for: "") {
                page.load(URLRequest(url: url))
            }
            return
        }

        if let url = lookupURL(for: query) {
            page.load(URLRequest(url: url))
        } else {
            logger.error("Failed to encode query for URL: \(query)")
        }
    }

    private func lookupURL(for query: String) -> URL? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return URL(string: "marureader-lookup://lookup/popup.html")
        }

        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        return URL(string: "marureader-lookup://lookup/popup.html?query=\(encodedQuery)")
    }
}
