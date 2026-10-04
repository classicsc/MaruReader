// YouTubeTranscriptScript.swift
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

enum YouTubeTranscriptScript {
    @MainActor
    static var inlinePlaybackScript: WKUserScript {
        WKUserScript(source: """
        (() => {
            if (!['www.youtube.com', 'youtube.com', 'm.youtube.com'].includes(location.hostname)) return;
            const enableInline = node => {
                if (node.nodeType !== Node.ELEMENT_NODE) return;
                if (node.matches('video')) node.setAttribute('playsinline', '');
                node.querySelectorAll('video').forEach(video => video.setAttribute('playsinline', ''));
            };
            new MutationObserver(records => {
                for (const record of records) record.addedNodes.forEach(enableInline);
            }).observe(document, {childList: true, subtree: true});
            if (document.documentElement) enableInline(document.documentElement);
        })();
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: .defaultClient)
    }

    static let source: String = {
        guard let url = Bundle(for: WebBrowserPage.self).url(forResource: "youtube-transcript", withExtension: "js"),
              let source = try? String(contentsOf: url, encoding: .utf8) else { return "return null;" }
        return source
    }()

    @MainActor
    static func call(on page: WebBrowserPage, videoID: String, action: String, seconds: Double = 0) async throws -> Any? {
        try await page.webView.callAsyncJavaScript(
            source,
            arguments: ["expectedVideoID": videoID, "action": action, "seconds": seconds],
            in: nil,
            contentWorld: .defaultClient
        )
    }
}
