// WebBrowserPage.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

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

private final class DelegateProxy: NSObject, WKNavigationDelegate, WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith _: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures _: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        webView.load(navigationAction.request)
        return nil
    }
}
