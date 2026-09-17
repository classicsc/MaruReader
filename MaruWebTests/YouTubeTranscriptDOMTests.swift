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
    @Test func transcriptTapsUseCharacterBounds() async throws {
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 220, height: 600))
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        let text = "猫犬鳥魚日本語の文字を折り返して最後まで"
        try await fixture.load(view, html: YouTubeTranscriptTextView.html(cues: [
            YouTubeTranscriptCue(id: 0, start: 0, text: text),
        ]))
        let offsets = try await view.callAsyncJavaScript("""
        const messages = [];
        window.webkit = {messageHandlers: {transcript: {postMessage: body => messages.push(body)}}};
        const span = document.querySelector('span[data-cue]');
        const node = span.firstChild;
        for (let offset = 0; offset < node.length; offset++) {
            const range = document.createRange();
            range.setStart(node, offset);
            range.setEnd(node, offset + 1);
            const rect = Array.from(range.getClientRects()).find(rect => rect.width > 0 && rect.height > 0);
            for (const fraction of [0.25, 0.75]) {
                span.dispatchEvent(new MouseEvent('click', {
                    bubbles: true, detail: 1,
                    clientX: rect.left + rect.width * fraction,
                    clientY: rect.top + rect.height / 2
                }));
            }
        }
        return messages.map(message => message.offset);
        """, arguments: [:], in: nil, contentWorld: .page) as? [Int]
        #expect(offsets == (0 ..< text.utf16.count).flatMap { [$0, $0] })
    }

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
        let anchor = CGRect(x: 30, y: 80, width: 20, height: 30)
        model.select(cueID: 0, offset: 2, anchor: anchor)
        await model.prepareLookup()
        let request = try #require(model.lookupRequest)
        #expect(request.context == "🐈猫がいます。")
        #expect(request.offset == 1)
        #expect(request.contextValues?.sourceType == .web)
        #expect(request.contextValues?.contextInfo?.contains("日本語の動画") == true)
        #expect(request.contextValues?.contextInfo?.contains("watch?v=fixture&t=42s") == true)
        #expect(request.contextValues?.screenshotURL == nil)
        #expect(model.followPlayback == false)
        #expect(model.popupAnchorPosition == anchor)
        #expect(!model.dictionaryPresented)
        #expect(model.dictionaryViewModel == nil)

        model.refresh()
        #expect(model.lookupRequest == nil)
        #expect(model.pendingLookup == nil)
        #expect(!model.showPopup)
    }

    @Test func closesYouTubePanelAfterExtractionAndAllowsReopening() async throws {
        let view = WKWebView(frame: .zero)
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        try await fixture.load(view, html: """
        <ytd-engagement-panel-section-list-renderer visibility="ENGAGEMENT_PANEL_VISIBILITY_EXPANDED">
          <ytd-engagement-panel-title-header-renderer><div id="visibility-button">
            <button onclick="this.closest('ytd-engagement-panel-section-list-renderer').setAttribute('visibility', 'ENGAGEMENT_PANEL_VISIBILITY_HIDDEN')">閉じる</button>
          </div></ytd-engagement-panel-title-header-renderer>
          <ytd-transcript-segment-renderer>
            <div class="segment-timestamp">0:01</div><span class="segment-text">こんにちは。</span>
          </ytd-transcript-segment-renderer>
        </ytd-engagement-panel-section-list-renderer>
        """)
        let json = try #require(try await run(view, action: "open") as? String)
        let snapshot = try JSONDecoder().decode(YouTubeTranscriptSnapshot.self, from: Data(json.utf8))
        #expect(snapshot.cues?.map(\.text) == ["こんにちは。"])
        let visibility = "document.querySelector('ytd-engagement-panel-section-list-renderer').getAttribute('visibility')"
        #expect(try await view.evaluateJavaScript(visibility) as? String == "ENGAGEMENT_PANEL_VISIBILITY_HIDDEN")
        _ = try await view.evaluateJavaScript("document.querySelector('ytd-engagement-panel-section-list-renderer').setAttribute('visibility', 'ENGAGEMENT_PANEL_VISIBILITY_EXPANDED')")
        _ = try await run(view, action: "time")
        #expect(try await view.evaluateJavaScript(visibility) as? String == "ENGAGEMENT_PANEL_VISIBILITY_EXPANDED")
    }

    @Test func autoOpenRespectsPlaybackPreferenceAndDismissal() async throws {
        let session = WebSession.make(dataStore: .nonPersistent())
        let view = session.page.webView
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        try await fixture.load(view, html: "<div id='movie_player'><video></video></div>")
        let model = WebViewerViewModel()
        let tabID = UUID()
        model.tabs = [WebTabState(id: tabID, session: session)]
        model.selectedTabID = tabID
        #expect(YouTubeTranscriptSettings.autoOpenEnabledDefault)
        await model.autoOpenTranscriptIfPlaying(on: session.page, enabled: true) { true }
        #expect(!model.transcriptPresented)
        // Model a decoded, playing HTMLVideoElement without a network media fixture.
        _ = try await view.callAsyncJavaScript("""
        const video = document.querySelector('video');
        Object.defineProperties(video, {
            paused: { value: false }, ended: { value: false }, readyState: { value: 4 }
        });
        """, arguments: [:], in: nil, contentWorld: .defaultClient)
        await model.autoOpenTranscriptIfPlaying(on: session.page, enabled: false) { true }
        #expect(!model.transcriptPresented)
        await model.autoOpenTranscriptIfPlaying(on: session.page, enabled: true) { false }
        #expect(!model.transcriptPresented)
        _ = try await view.evaluateJavaScript("document.querySelector('#movie_player').classList.add('ad-showing')")
        await model.autoOpenTranscriptIfPlaying(on: session.page, enabled: true) { true }
        #expect(!model.transcriptPresented)
        _ = try await view.evaluateJavaScript("document.querySelector('#movie_player').classList.remove('ad-showing')")
        await model.autoOpenTranscriptIfPlaying(on: session.page, enabled: true) { true }
        #expect(model.transcriptPresented)
        model.transcriptPresented = false
        await model.autoOpenTranscriptIfPlaying(on: session.page, enabled: true) { true }
        #expect(!model.transcriptPresented)
        model.openTranscript()
        #expect(model.transcriptPresented)
        model.transcriptPresented = false
        _ = try await view.evaluateJavaScript("history.pushState({}, '', '/watch?v=next')")
        await model.autoOpenTranscriptIfPlaying(on: session.page, enabled: true) { true }
        #expect(model.transcriptPresented)
    }

    @Test func titleSupportsEscapedTextAndCharacterLookup() async throws {
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 360, height: 600))
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        let title = "🐈が猫 <script> & 日本語"
        try await fixture.load(view, html: YouTubeTranscriptTextView.html(cues: [], title: title))
        #expect(try await view.evaluateJavaScript("document.querySelector('h1').textContent") as? String == title)
        let result = try await view.callAsyncJavaScript("""
        const messages = [];
        window.webkit = {messageHandlers: {transcript: {postMessage: body => messages.push(body)}}};
        const span = document.querySelector('[data-title]');
        const range = document.createRange();
        range.setStart(span.firstChild, 4); range.setEnd(span.firstChild, 5);
        const rect = range.getBoundingClientRect();
        span.dispatchEvent(new MouseEvent('click', {bubbles: true, detail: 1,
            clientX: rect.x + rect.width / 2, clientY: rect.y + rect.height / 2}));
        return messages[0];
        """, arguments: [:], in: nil, contentWorld: .page) as? [String: Any]
        #expect(result?["target"] as? String == "title")
        #expect(result?["offset"] as? Int == 4)

        let model = YouTubeTranscriptViewModel(page: WebBrowserPage(webView: view), videoID: "fixture")
        model.title = title
        model.currentTime = 12
        model.select(target: .title, offset: 4)
        await model.prepareLookup()
        let request = try #require(model.lookupRequest)
        #expect(request.context == title)
        #expect(request.offset == 2)
        #expect(request.contextValues?.contextInfo?.contains("t=12s") == true)
        #expect(!model.followPlayback)
    }

    @Test func displaySettingsUpdateWithoutReplacingTranscript() async throws {
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 360, height: 600))
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        let cues = (0 ..< 40).map { YouTubeTranscriptCue(id: $0, start: Double($0 * 5), text: "日本語の文章を読んでいます。猫がいます。") }
        try await fixture.load(view, html: YouTubeTranscriptTextView.html(cues: cues, title: "動画"))
        let result = try await view.callAsyncJavaScript("""
        const messages = [];
        window.webkit = {messageHandlers: {transcript: {postMessage: body => messages.push(body)}}};
        const row = document.getElementById('cue-15');
        const time = row.querySelector('button');
        const hiddenInitially = time.getClientRects().length === 0;
        window.updatePlayback(15, true, 18, false, '動画');
        const anchor = document.createRange();
        const text = row.querySelector('span').firstChild;
        anchor.setStart(text, 5); anchor.setEnd(text, 6);
        window.scrollBy(0, anchor.getBoundingClientRect().top - 20);
        const before = anchor.getBoundingClientRect().top;
        window.updatePlayback(16, false, 27, true, '新しい動画');
        const displacement = Math.abs(anchor.getBoundingClientRect().top - before);
        const visible = time.getClientRects().length > 0;
        time.click();
        const beforeHiding = anchor.getBoundingClientRect().top;
        window.updatePlayback(16, false, 27, false, '新しい動画');
        const hidingDisplacement = Math.abs(anchor.getBoundingClientRect().top - beforeHiding);
        const hiddenAgain = time.getClientRects().length === 0;
        const unchanged = row === document.getElementById('cue-15');
        window.updatePlayback(25, true, 27, true, '新しい動画');
        const active = document.querySelector('.active');
        const rect = active.getBoundingClientRect();
        return {hiddenInitially, visible, displacement, hidingDisplacement, hiddenAgain, unchanged,
            seekID: messages.find(message => message.kind === 'seek').id,
            title: document.querySelector('h1').textContent,
            activeID: active.id, centered: Math.abs((rect.top + rect.bottom) / 2 - innerHeight / 2) < 2};
        """, arguments: [:], in: nil, contentWorld: .page) as? [String: Any]
        let values = try #require(result)
        #expect(values["hiddenInitially"] as? Bool == true)
        #expect(values["visible"] as? Bool == true)
        #expect(values["hiddenAgain"] as? Bool == true)
        #expect(try #require(values["hidingDisplacement"] as? Double) < 2)
        #expect(values["unchanged"] as? Bool == true)
        #expect(try #require(values["displacement"] as? Double) < 2)
        #expect(values["seekID"] as? Int == 15)
        #expect(values["title"] as? String == "新しい動画")
        #expect(values["activeID"] as? String == "cue-25")
        #expect(values["centered"] as? Bool == true)
    }

    @Test func playbackCommandsUseLiveStateAndRespectGuards() async throws {
        let view = WKWebView(frame: .zero)
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        try await fixture.load(view, html: "<div id='movie_player'><video></video></div>")
        try await mockPlayer(view)
        func snapshot(_ action: String, seconds: Double = 0) async throws -> YouTubeTranscriptSnapshot {
            let json = try #require(try await run(view, action: action, seconds: seconds) as? String)
            return try JSONDecoder().decode(YouTubeTranscriptSnapshot.self, from: Data(json.utf8))
        }
        #expect(try await snapshot("time").playerAvailable)
        #expect(try await snapshot("skip", seconds: 5).currentTime == 15)
        #expect(try await snapshot("skip", seconds: 5).currentTime == 20)
        #expect(try await snapshot("skip", seconds: 5).currentTime == 20)
        #expect(try await snapshot("skip", seconds: -30).currentTime == 0)
        #expect(try await snapshot("time").isPlaying == false)
        #expect(try await snapshot("togglePlayback").isPlaying)
        #expect(try await snapshot("skip", seconds: 5).isPlaying)
        #expect(try await snapshot("togglePlayback").isPlaying == false)
        _ = try await view.callAsyncJavaScript("document.querySelector('video').play = () => Promise.reject(new Error('Denied'))", arguments: [:], in: nil, contentWorld: .defaultClient)
        #expect(try await snapshot("togglePlayback").isPlaying == false)
        _ = try await view.evaluateJavaScript("document.querySelector('#movie_player').classList.add('ad-showing')")
        #expect(try await snapshot("skip", seconds: 5).currentTime == 5)
        #expect(try await snapshot("togglePlayback").isPlaying == false)
        #expect(try await run(view, action: "skip", videoID: "wrong", seconds: 5) is NSNull)
        _ = try await view.evaluateJavaScript("document.querySelector('video').remove()")
        #expect(try await snapshot("togglePlayback").playerAvailable == false)
        #expect(try await snapshot("skip", seconds: 5).currentTime == 0)
    }

    @Test func queuedCommandsAccumulateAndCancelOnDismissal() async throws {
        let view = WKWebView(frame: .zero)
        let fixture = TranscriptFixtureNavigation()
        view.navigationDelegate = fixture
        try await fixture.load(view, html: "<div id='movie_player'><video></video></div>")
        try await mockPlayer(view)
        let model = YouTubeTranscriptViewModel(page: WebBrowserPage(webView: view), videoID: "fixture")
        model.playerAvailable = true
        model.followPlayback = false
        model.skip(by: 5)
        model.skip(by: 5)
        await model.commandTask?.value
        #expect(model.currentTime == 20)
        #expect(!model.followPlayback)
        model.togglePlayback()
        model.togglePlayback()
        await model.commandTask?.value
        #expect(model.isPlaying)
        #expect(!model.playbackCommandPending)
        model.skip(by: -5)
        let cancelled = model.commandTask
        model.stopCommands()
        await cancelled?.value
        #expect(model.currentTime == 20)
        _ = try await view.evaluateJavaScript("history.pushState({}, '', '/watch?v=next')")
        model.skip(by: -5)
        await model.commandTask?.value
        #expect(model.currentTime == 20)
    }

    private func mockPlayer(_ view: WKWebView) async throws {
        _ = try await view.callAsyncJavaScript("""
        const video = document.querySelector('video');
        Object.defineProperties(video, {
            currentTime: {value: 10, writable: true}, duration: {value: 20},
            paused: {value: true, writable: true}, ended: {value: false}, readyState: {value: 4}
        });
        video.play = async () => { video.paused = false; };
        video.pause = () => { video.paused = true; };
        """, arguments: [:], in: nil, contentWorld: .defaultClient)
    }

    private func run(_ view: WKWebView, action: String, videoID: String = "fixture", seconds: Double = 0) async throws -> Any? {
        try await view.callAsyncJavaScript(YouTubeTranscriptScript.source,
                                           arguments: ["expectedVideoID": videoID, "action": action, "seconds": seconds],
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
