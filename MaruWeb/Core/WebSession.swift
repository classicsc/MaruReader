// WebSession.swift
// MaruReader
// Copyright (c) 2026  Samuel Smoker
//
// MaruReader is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// MaruReader is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with MaruReader.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
import WebKit

@MainActor
final class WebSession {
    let page: WebBrowserPage
    let dataStore: WKWebsiteDataStore

    private init(
        page: WebBrowserPage,
        dataStore: WKWebsiteDataStore
    ) {
        self.page = page
        self.dataStore = dataStore
    }

    static func make(
        dataStore: WKWebsiteDataStore = WebsiteDataStore.main,
        extensionController: WKWebExtensionController? = nil
    ) -> WebSession {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.webExtensionController = extensionController

        let webView = DictionaryLookupWebView(frame: .zero, configuration: configuration)
        webView.isInspectable = true
        webView.allowsBackForwardNavigationGestures = true
        let page = WebBrowserPage(webView: webView)
        return WebSession(page: page, dataStore: dataStore)
    }
}
