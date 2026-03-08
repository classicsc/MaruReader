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
    var faviconData: Data?

    private var scrollOffsetChangeHandler: ((CGFloat, CGFloat) -> Void)?
    private var observations: [NSKeyValueObservation] = []
    private let delegateProxy = DelegateProxy()
    private var faviconFetchTask: Task<Void, Never>?

    init(webView: WKWebView) {
        self.webView = webView
        webView.navigationDelegate = delegateProxy
        webView.uiDelegate = delegateProxy
        delegateProxy.onDidStartNavigation = { [weak self] in
            self?.handleNavigationDidStart()
        }
        delegateProxy.onDidFinishNavigation = { [weak self] in
            self?.handleNavigationDidFinish()
        }
        delegateProxy.onDidFailNavigation = { [weak self] in
            self?.handleNavigationDidFail()
        }
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

    private func handleNavigationDidStart() {
        syncStateFromWebView()
        faviconFetchTask?.cancel()
        faviconFetchTask = nil
        faviconData = nil
    }

    private func handleNavigationDidFinish() {
        syncStateFromWebView()
        faviconFetchTask?.cancel()
        guard let currentURL = url,
              let scheme = currentURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            faviconFetchTask = nil
            faviconData = nil
            return
        }

        faviconFetchTask = Task { [weak self] in
            guard let self else { return }
            let data = await self.resolveFaviconData(for: currentURL)
            guard !Task.isCancelled else { return }
            guard self.url == currentURL else { return }
            self.faviconData = data
        }
    }

    private func handleNavigationDidFail() {
        syncStateFromWebView()
        faviconFetchTask?.cancel()
        faviconFetchTask = nil
    }

    private func resolveFaviconData(for pageURL: URL) async -> Data? {
        let candidates = await faviconCandidates(for: pageURL)
        return await Self.fetchFirstFaviconData(from: candidates)
    }

    private func faviconCandidates(for pageURL: URL) async -> [URL] {
        let script = """
        (() => {
          const baseURI = document.baseURI || window.location.href || "";
          const links = Array.from(document.querySelectorAll('link[rel][href]')).map(link => ({
            href: link.getAttribute('href') || "",
            rel: (link.getAttribute('rel') || "").toLowerCase(),
            sizes: (link.getAttribute('sizes') || "").toLowerCase(),
            type: (link.getAttribute('type') || "").toLowerCase()
          }));
          return { baseURI, links };
        })()
        """

        let result = try? await callJavaScript(script)
        let parsed = Self.parseFaviconCandidates(result, pageURL: pageURL)
        return parsed.map(\.url)
    }

    private nonisolated static func parseFaviconCandidates(_ result: Any?, pageURL: URL) -> [FaviconCandidate] {
        let payload = result as? [String: Any]
        let baseURL: URL = if let baseURI = payload?["baseURI"] as? String,
                              let parsedBaseURL = URL(string: baseURI)
        {
            parsedBaseURL
        } else {
            pageURL
        }

        let linkEntries = payload?["links"] as? [[String: Any]] ?? []
        var candidates: [FaviconCandidate] = []
        candidates.reserveCapacity(linkEntries.count + 1)

        for entry in linkEntries {
            guard let href = entry["href"] as? String else { continue }
            let rel = (entry["rel"] as? String ?? "").lowercased()
            guard rel.contains("icon") else { continue }

            guard let resolvedURL = URL(string: href, relativeTo: baseURL)?.absoluteURL else { continue }
            guard let scheme = resolvedURL.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else {
                continue
            }

            let candidate = FaviconCandidate(
                url: resolvedURL,
                rel: rel,
                sizes: (entry["sizes"] as? String)?.lowercased(),
                type: (entry["type"] as? String)?.lowercased()
            )
            candidates.append(candidate)
        }

        if let fallbackURL = fallbackFaviconURL(for: pageURL) {
            candidates.append(
                FaviconCandidate(
                    url: fallbackURL,
                    rel: "fallback favicon",
                    sizes: nil,
                    type: nil
                )
            )
        }

        let sorted = candidates.sorted { lhs, rhs in
            if lhs.priorityScore == rhs.priorityScore {
                return lhs.url.absoluteString < rhs.url.absoluteString
            }
            return lhs.priorityScore > rhs.priorityScore
        }

        var seen = Set<URL>()
        var deduped: [FaviconCandidate] = []
        deduped.reserveCapacity(sorted.count)
        for candidate in sorted where seen.insert(candidate.url).inserted {
            deduped.append(candidate)
        }
        return deduped
    }

    private nonisolated static func fallbackFaviconURL(for pageURL: URL) -> URL? {
        guard var components = URLComponents(url: pageURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }

        components.user = nil
        components.password = nil
        components.path = "/favicon.ico"
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private nonisolated static func fetchFirstFaviconData(
        from candidateURLs: [URL],
        maxDownloadBytes: Int = 512_000,
        targetSize: CGFloat = 32
    ) async -> Data? {
        for url in candidateURLs {
            guard !Task.isCancelled else { return nil }
            guard let data = try? await fetchFaviconData(from: url, maxDownloadBytes: maxDownloadBytes) else { continue }
            guard let normalized = normalizeFavicon(data, targetSize: targetSize) else { continue }
            return normalized
        }
        return nil
    }

    private nonisolated static func fetchFaviconData(from url: URL, maxDownloadBytes: Int) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        request.setValue("image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse,
           !(200 ... 299).contains(http.statusCode)
        {
            throw URLError(.badServerResponse)
        }
        guard data.count <= maxDownloadBytes else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        return data
    }

    private nonisolated static func normalizeFavicon(_ data: Data, targetSize: CGFloat) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return image.pngData()
        }

        let target = CGSize(width: targetSize, height: targetSize)
        let drawScale = min(target.width / imageSize.width, target.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * drawScale, height: imageSize.height * drawScale)
        let origin = CGPoint(
            x: (target.width - scaledSize.width) / 2,
            y: (target.height - scaledSize.height) / 2
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.pngData { _ in
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
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

private struct FaviconCandidate {
    let url: URL
    let rel: String
    let sizes: String?
    let type: String?

    var priorityScore: Int {
        var score = 0

        if rel.contains("apple-touch-icon") {
            score += 600
        } else if rel.contains("shortcut icon") {
            score += 450
        } else if rel.contains("icon") {
            score += 400
        }

        if rel.contains("mask-icon") {
            score -= 250
        }

        if let type {
            if type.contains("png") { score += 50 }
            if type.contains("x-icon") || type.contains("vnd.microsoft.icon") { score += 20 }
            if type.contains("svg") { score -= 200 }
        }

        let ext = url.pathExtension.lowercased()
        if ext == "png" { score += 40 }
        if ext == "ico" { score += 20 }
        if ext == "svg" { score -= 200 }

        score += min(maxDeclaredSize, 256)

        if url.path.lowercased() == "/favicon.ico" {
            score += 5
        }

        return score
    }

    private var maxDeclaredSize: Int {
        guard let sizes, !sizes.isEmpty else { return 0 }
        return sizes
            .split(separator: " ")
            .compactMap { token in
                let parts = token.split(separator: "x")
                guard parts.count == 2,
                      let w = Int(parts[0]),
                      let h = Int(parts[1])
                else {
                    return nil
                }
                return max(w, h)
            }
            .max() ?? 0
    }
}

final class DictionaryLookupWebView: WKWebView {
    var onDictionaryLookup: (@MainActor (String) -> Void)?

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)

        let lookupAction = UIAction(
            title: String(localized: "Dictionary", comment: "A button in the text selection menu that opens the dictionary lookup for the selected word."),
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
    var onDidStartNavigation: (@MainActor () -> Void)?
    var onDidFinishNavigation: (@MainActor () -> Void)?
    var onDidFailNavigation: (@MainActor () -> Void)?

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

    func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        guard let onDidStartNavigation else { return }
        Task { @MainActor in
            onDidStartNavigation()
        }
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        guard let onDidFinishNavigation else { return }
        Task { @MainActor in
            onDidFinishNavigation()
        }
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError _: Error) {
        guard let onDidFailNavigation else { return }
        Task { @MainActor in
            onDidFailNavigation()
        }
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: Error) {
        guard let onDidFailNavigation else { return }
        Task { @MainActor in
            onDidFailNavigation()
        }
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
                title: String(localized: "Open", comment: "A button in the link context menu that opens the link in the current tab."),
                image: UIImage(systemName: "arrow.right.circle")
            ) { _ in
                guard let onOpenLinkInCurrentTab = self?.onOpenLinkInCurrentTab else { return }
                Task { @MainActor in
                    onOpenLinkInCurrentTab(linkURL)
                }
            }
            let openInNewTabAction = UIAction(
                title: String(localized: "Open in New Tab", comment: "A button in the link context menu that opens the link in a new tab."),
                image: UIImage(systemName: "plus.square.on.square")
            ) { _ in
                guard let onOpenLinkInNewTab = self?.onOpenLinkInNewTab else { return }
                Task { @MainActor in
                    onOpenLinkInNewTab(linkURL)
                }
            }
            let copyAction = UIAction(
                title: String(localized: "Copy Link", comment: "A button in the link context menu that copies the link URL to the clipboard."),
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
