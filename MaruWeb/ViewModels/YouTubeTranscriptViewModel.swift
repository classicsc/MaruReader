// YouTubeTranscriptViewModel.swift
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
import MaruDictionaryUICommon
import MaruReaderCore
import Observation
import os
import WebKit

@MainActor
@Observable
final class YouTubeTranscriptViewModel: NSObject, WKScriptMessageHandler {
    let page: WebBrowserPage
    let videoID: String
    var cues: [YouTubeTranscriptCue] = []
    var title = ""
    var currentTime = 0.0
    var adPlaying = false
    var isLoading = true
    var followPlayback = true
    var reloadID = UUID()
    var lookupRequest: TextLookupRequest?
    var pendingLookup: (cueID: Int, offset: Int)?
    var lookupID = UUID()
    var popupPage = WebPage()
    var popupAnchorPosition: CGRect = .zero
    var showPopup = false
    var dictionaryPresented = false
    var dictionaryViewModel: DictionarySearchViewModel?
    private var popupSession: TextLookupSession?
    private let resultsSchemeHandler = DictionaryResultsURLSchemeHandler()
    private let ankiSchemeHandler = AnkiURLSchemeHandler()
    private let logger = Logger.maru(category: "YouTubeTranscriptViewModel")

    init(page: WebBrowserPage, videoID: String) {
        self.page = page
        self.videoID = videoID
        super.init()
        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[URLScheme("marureader-resource")!] = ResourceURLSchemeHandler()
        configuration.urlSchemeHandlers[URLScheme("marureader-media")!] = MediaURLSchemeHandler()
        configuration.urlSchemeHandlers[URLScheme("marureader-audio")!] = AudioURLSchemeHandler()
        configuration.urlSchemeHandlers[URLScheme("marureader-lookup")!] = resultsSchemeHandler
        configuration.urlSchemeHandlers[URLScheme("marureader-grammar")!] = GrammarDictionaryURLSchemeHandler()
        configuration.urlSchemeHandlers[URLScheme("marureader-anki")!] = ankiSchemeHandler
        let controller = WKUserContentController()
        controller.add(self, name: "navigateToTerm")
        controller.addUserScript(makeDictionaryLocalizedStringsScript())
        configuration.userContentController = controller
        popupPage = WebPage(configuration: configuration)
    }

    var activeCueID: Int? {
        adPlaying ? nil : YouTubeTranscriptCue.activeID(in: cues, at: currentTime)
    }

    func refresh() {
        showPopup = false
        lookupRequest = nil
        pendingLookup = nil
        lookupID = UUID()
        cues = []
        isLoading = true
        reloadID = UUID()
    }

    func observePlayback() async {
        var attempts = 0
        while !Task.isCancelled, YouTubeVideo.id(from: page.url) == videoID {
            do {
                let action = attempts == 0 ? "open" : (cues.isEmpty && attempts < 20 ? "read" : "time")
                let value = try await YouTubeTranscriptScript.call(on: page, videoID: videoID, action: action)
                try Task.checkCancellation()
                guard YouTubeVideo.id(from: page.url) == videoID else { return }
                if let string = value as? String,
                   let data = string.data(using: .utf8),
                   let snapshot = try? JSONDecoder().decode(YouTubeTranscriptSnapshot.self, from: data),
                   snapshot.videoID == videoID
                {
                    title = snapshot.title
                    if !snapshot.adPlaying {
                        currentTime = snapshot.currentTime
                    }
                    adPlaying = snapshot.adPlaying
                    if let extracted = snapshot.cues, !extracted.isEmpty {
                        cues = extracted
                        isLoading = false
                    }
                }
                attempts += 1
                if attempts >= 20 {
                    isLoading = false
                }
                try await Task.sleep(for: .milliseconds(500))
            } catch is CancellationError {
                return
            } catch {
                isLoading = false
                return
            }
        }
    }

    func seek(to cueID: Int) async {
        guard let cue = cues.first(where: { $0.id == cueID }) else { return }
        _ = try? await YouTubeTranscriptScript.call(on: page, videoID: videoID, action: "seek", seconds: cue.start)
    }

    func select(cueID: Int, offset: Int, anchor: CGRect = .zero) {
        showPopup = false
        lookupRequest = nil
        popupSession = nil
        popupAnchorPosition = anchor
        followPlayback = false
        pendingLookup = (cueID, offset)
        lookupID = UUID()
    }

    func prepareLookup() async {
        guard let selection = pendingLookup,
              let cue = cues.first(where: { $0.id == selection.cueID }),
              let characterOffset = cue.characterOffset(forUTF16Offset: selection.offset) else { return }
        let capturedTitle = title
        let capturedTime = currentTime
        let frame = try? await YouTubeTranscriptScript.call(on: page, videoID: videoID, action: "frame")
        guard !Task.isCancelled, YouTubeVideo.id(from: page.url) == videoID else { return }
        let screenshotURL = Self.writeFrame(frame as? String)
        let url = "https://www.youtube.com/watch?v=\(videoID)&t=\(Int(capturedTime))s"
        lookupRequest = TextLookupRequest(
            context: cue.text,
            offset: characterOffset,
            contextValues: LookupContextValues(
                contextInfo: WebStrings.contextInfo(title: capturedTitle, urlString: url),
                screenshotURL: screenshotURL,
                sourceType: .web
            )
        )
    }

    func preparePopup() async {
        guard let request = lookupRequest else { return }
        do {
            guard let session = try await DictionarySearchService().startTextLookup(request: request),
                  try await session.prepareInitialResults() else { return }
            try Task.checkCancellation()
            await resultsSchemeHandler.setSession(session)
            try Task.checkCancellation()
            await ankiSchemeHandler.setSession(session)
            try Task.checkCancellation()
            let url = URL(string: "marureader-resource://dictionary.html?mode=popup&requestId=\(request.id.uuidString)")!
            for try await event in popupPage.load(URLRequest(url: url)) {
                try Task.checkCancellation()
                guard lookupRequest?.id == request.id else { return }
                if event == .finished {
                    popupSession = session
                    showPopup = true
                    return
                }
            }
        } catch is CancellationError {
            return
        } catch {
            logger.error("Transcript popup lookup failed: \(error.localizedDescription)")
        }
    }

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "navigateToTerm", message.body is String,
              let popupSession else { return }
        dictionaryViewModel = DictionarySearchViewModel(session: popupSession)
        showPopup = false
        dictionaryPresented = true
    }

    private static func writeFrame(_ dataURL: String?) -> URL? {
        guard let dataURL, dataURL.hasPrefix("data:image/jpeg;base64,"),
              let data = Data(base64Encoded: String(dataURL.dropFirst("data:image/jpeg;base64,".count))) else { return nil }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MaruContextMedia", isDirectory: true)
        let url = directory.appendingPathComponent("youtube_\(UUID().uuidString).jpg")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
