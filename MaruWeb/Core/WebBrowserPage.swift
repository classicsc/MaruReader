// WebBrowserPage.swift
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

import CoreGraphics
import Foundation
import Observation
import UIKit
import WebKit

@MainActor
@Observable
final class WebBrowserPage {
    enum SnapshotError: Error {
        case failedToRender
        case failedToEncode
    }

    let webView: WKWebView

    var url: URL?
    var title: String?
    var isLoading = false
    var estimatedProgress = 0.0
    var canGoBack = false
    var canGoForward = false

    private var scrollOffsetChangeHandler: ((CGFloat, CGFloat) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private let delegateProxy = DelegateProxy()

    init(webView: WKWebView) {
        self.webView = webView
        webView.navigationDelegate = delegateProxy
        webView.uiDelegate = delegateProxy
        syncStateFromWebView()
        installObservers()
    }

    func setScrollOffsetChangeHandler(_ handler: ((CGFloat, CGFloat) -> Void)?) {
        scrollOffsetChangeHandler = handler
    }

    func setDictionaryLookupHandler(_ handler: (@MainActor (String) -> Void)?) {
        (webView as? DictionaryLookupWebView)?.onDictionaryLookup = handler
    }

    func setOpenRequestInNewTabHandler(_ handler: (@MainActor (URLRequest) -> Void)?) {
        delegateProxy.onOpenRequestInNewTab = handler
    }

    func setLinkContextMenuHandlers(
        openInCurrentTab: (@MainActor (URL) -> Void)?,
        openInNewTab: (@MainActor (URL) -> Void)?,
        copyLink: (@MainActor (URL) -> Void)?
    ) {
        delegateProxy.onOpenLinkInCurrentTab = openInCurrentTab
        delegateProxy.onOpenLinkInNewTab = openInNewTab
        delegateProxy.onCopyLink = copyLink
    }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func load(_ request: URLRequest) {
        webView.load(request)
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func reload() {
        webView.reload()
    }

    func stopLoading() {
        webView.stopLoading()
    }

    func callJavaScript(_ script: String) async throws -> Any? {
        try await webView.evaluateJavaScript(script)
    }

    func takeSnapshot(region: CGRect?, snapshotWidth: CGFloat?) async throws -> Data {
        let configuration = WKSnapshotConfiguration()
        if let region {
            configuration.rect = region
        }
        if let snapshotWidth {
            configuration.snapshotWidth = NSNumber(value: snapshotWidth)
        }

        let image: UIImage = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            webView.takeSnapshot(with: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image else {
                    continuation.resume(throwing: SnapshotError.failedToRender)
                    return
                }
                continuation.resume(returning: image)
            }
        }

        guard let data = image.pngData() else {
            throw SnapshotError.failedToEncode
        }
        return data
    }

    private func syncStateFromWebView() {
        url = webView.url
        title = webView.title
        isLoading = webView.isLoading
        estimatedProgress = webView.estimatedProgress
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    private func installObservers() {
        observations.append(
            webView.observe(\.url, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.url = self?.webView.url
                }
            }
        )
        observations.append(
            webView.observe(\.title, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.title = self?.webView.title
                }
            }
        )
        observations.append(
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.isLoading = self?.webView.isLoading ?? false
                }
            }
        )
        observations.append(
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.estimatedProgress = self?.webView.estimatedProgress ?? 0
                }
            }
        )
        observations.append(
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.canGoBack = self?.webView.canGoBack ?? false
                }
            }
        )
        observations.append(
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.canGoForward = self?.webView.canGoForward ?? false
                }
            }
        )
        observations.append(
            webView.scrollView.observe(\.contentOffset, options: [.old, .new]) { [weak self] _, change in
                guard let oldOffset = change.oldValue?.y,
                      let newOffset = change.newValue?.y,
                      oldOffset != newOffset
                else {
                    return
                }
                Task { @MainActor [weak self] in
                    self?.scrollOffsetChangeHandler?(oldOffset, newOffset)
                }
            }
        )
    }
}

final class DictionaryLookupWebView: WKWebView {
    var onDictionaryLookup: (@MainActor (String) -> Void)?

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        let lookupAction = UIAction(
            title: "Dictionary",
            image: UIImage(systemName: "character.book.closed.ja")
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let result = try? await self.evaluateJavaScript("window.getSelection().toString()"),
                      let selectedText = result as? String,
                      !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return }
                self.onDictionaryLookup?(selectedText)
            }
        }

        let menu = UIMenu(options: .displayInline, children: [lookupAction])
        if builder.menu(for: .lookup) != nil {
            builder.insertSibling(menu, beforeMenu: .lookup)
        } else {
            builder.insertChild(menu, atEndOfMenu: .root)
        }
    }
}

private final class DelegateProxy: NSObject, WKNavigationDelegate, WKUIDelegate {
    var onOpenRequestInNewTab: (@MainActor (URLRequest) -> Void)?
    var onOpenLinkInCurrentTab: (@MainActor (URL) -> Void)?
    var onOpenLinkInNewTab: (@MainActor (URL) -> Void)?
    var onCopyLink: (@MainActor (URL) -> Void)?

    func webView(
        _ webView: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        if let onOpenRequestInNewTab {
            Task { @MainActor in
                onOpenRequestInNewTab(navigationAction.request)
            }
        } else {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(
        _: WKWebView,
        contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
        completionHandler: @escaping @MainActor (UIContextMenuConfiguration?) -> Void
    ) {
        guard let linkURL = elementInfo.linkURL else {
            completionHandler(nil)
            return
        }

        let configuration = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let openAction = UIAction(
                title: "Open",
                image: UIImage(systemName: "arrow.right.circle")
            ) { _ in
                guard let onOpenLinkInCurrentTab = self?.onOpenLinkInCurrentTab else { return }
                Task { @MainActor in
                    onOpenLinkInCurrentTab(linkURL)
                }
            }
            let openInNewTabAction = UIAction(
                title: "Open in New Tab",
                image: UIImage(systemName: "plus.square.on.square")
            ) { _ in
                guard let onOpenLinkInNewTab = self?.onOpenLinkInNewTab else { return }
                Task { @MainActor in
                    onOpenLinkInNewTab(linkURL)
                }
            }
            let copyAction = UIAction(
                title: "Copy Link",
                image: UIImage(systemName: "doc.on.doc")
            ) { _ in
                guard let onCopyLink = self?.onCopyLink else { return }
                Task { @MainActor in
                    onCopyLink(linkURL)
                }
            }
            return UIMenu(children: [openAction, openInNewTabAction, copyAction])
        }
        completionHandler(configuration)
    }
}
