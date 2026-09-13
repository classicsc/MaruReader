// YouTubeTranscriptDOMTests.swift
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
import MaruReaderCore
@testable import MaruWeb
import Testing
import WebKit

@MainActor
struct YouTubeTranscriptDOMTests {
    @Test func extractsRenderedTextAndRejectsWrongVideo() async throws {
        let view = WKWebView(frame: .zero)
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        try await fixture.load(view, html: """
        <ytd-watch-flexy video-id="fixture"></ytd-watch-flexy>
        <ytd-watch-metadata><h1>日本語の動画</h1></ytd-watch-metadata>
        <transcript-segment-view-model>
          <div class="ytwTranscriptSegmentViewModelTimestamp">0:01</div>
          <span class="ytAttributedStringHost">猫 &amp; 犬 🐈</span>
        </transcript-segment-view-model>
        <ytd-transcript-segment-renderer>
          <div class="segment-timestamp">1:02:03</div><span class="segment-text">こんにちは。</span>
        </ytd-transcript-segment-renderer>
        <transcript-segment-view-model><span class="ytAttributedStringHost">missing timestamp</span></transcript-segment-view-model>
        """)
        let result = try await run(view, action: "read")
        let json = try #require(result as? String)
        let snapshot = try JSONDecoder().decode(YouTubeTranscriptSnapshot.self, from: Data(json.utf8))
        #expect(snapshot.title == "日本語の動画")
        #expect(snapshot.cues?.map(\.text) == ["猫 & 犬 🐈", "こんにちは。"])
        #expect(snapshot.cues?.map(\.start) == [1, 3723])
        #expect(try await run(view, action: "read", videoID: "other") is NSNull)
        #expect(try await run(view, action: "frame") is NSNull)
    }

    @Test func opensTranscriptThroughDOMButton() async throws {
        let view = WKWebView(frame: .zero)
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        try await fixture.load(view, html: """
        <ytd-video-description-transcript-section-renderer>
          <button onclick="document.body.dataset.opened = Number(document.body.dataset.opened || 0) + 1">文字起こしを表示</button>
        </ytd-video-description-transcript-section-renderer>
        """)
        _ = try await run(view, action: "read")
        _ = try await run(view, action: "read")
        _ = try await run(view, action: "read")
        let opened = try await view.evaluateJavaScript("document.body.dataset.opened") as? String
        #expect(opened == "1")
    }

    @Test func rejectsStaleRowsAfterSinglePageNavigation() async throws {
        let view = WKWebView(frame: .zero)
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        try await fixture.load(view, html: """
        <transcript-segment-view-model>
          <div class="ytwTranscriptSegmentViewModelTimestamp">0:01</div>
          <span class="ytAttributedStringHost">古い動画</span>
        </transcript-segment-view-model>
        """)
        _ = try await run(view, action: "read")
        _ = try await view.evaluateJavaScript("history.pushState({}, '', '/watch?v=next')")
        let staleJSON = try #require(try await run(view, action: "read", videoID: "next") as? String)
        let stale = try JSONDecoder().decode(YouTubeTranscriptSnapshot.self, from: Data(staleJSON.utf8))
        #expect(stale.cues?.isEmpty == true)
        _ = try await view.evaluateJavaScript("document.querySelector('span').textContent = '新しい動画'")
        let freshJSON = try #require(try await run(view, action: "read", videoID: "next") as? String)
        let fresh = try JSONDecoder().decode(YouTubeTranscriptSnapshot.self, from: Data(freshJSON.utf8))
        #expect(fresh.cues?.map(\.text) == ["新しい動画"])
    }

    @Test func lookupCarriesVideoTitleTimeAndSentence() async throws {
        let view = WKWebView(frame: .zero)
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        try await fixture.load(view, html: "<p>Video has no decoded frame.</p>")
        let page = WebBrowserPage(webView: view)
        let model = YouTubeTranscriptViewModel(page: page, videoID: "fixture")
        model.title = "日本語の動画"
        model.currentTime = 42.8
        model.cues = [YouTubeTranscriptCue(id: 0, start: 40, text: "🐈猫がいます。")]
        model.select(cueID: 0, offset: 2)
        await model.prepareLookup()
        let request = try #require(model.lookupRequest)
        #expect(request.context == "🐈猫がいます。")
        #expect(request.offset == 1)
        #expect(request.contextValues?.sourceType == .web)
        #expect(request.contextValues?.contextInfo?.contains("日本語の動画") == true)
        #expect(request.contextValues?.contextInfo?.contains("watch?v=fixture&t=42s") == true)
        #expect(request.contextValues?.screenshotURL == nil)
        #expect(model.followPlayback == false)
    }

    private func run(_ view: WKWebView, action: String, videoID: String = "fixture") async throws -> Any? {
        try await view.callAsyncJavaScript(YouTubeTranscriptScript.source,
                                           arguments: ["expectedVideoID": videoID, "action": action, "seconds": 0],
                                           in: nil, contentWorld: .defaultClient)
    }
}

@MainActor
private final class TranscriptFixtureNavigation: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func load(_ view: WKWebView, html: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            view.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com/watch?v=fixture"))
        }
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
