// YouTubeTranscriptView.swift
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

import MaruDictionaryUICommon
import MaruReaderCore
import SwiftUI
import WebKit

struct YouTubeTranscriptView: View {
    @State private var model: YouTubeTranscriptViewModel
    @Environment(\.dictionaryFeatureAvailability) private var availability
    let onDismiss: () -> Void

    init(page: WebBrowserPage, videoID: String, onDismiss: @escaping () -> Void) {
        _model = State(initialValue: YouTubeTranscriptViewModel(page: page, videoID: videoID))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !model.title.isEmpty {
                    Text(model.title)
                        .font(.headline)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                if model.isLoading {
                    ProgressView("Loading transcript…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.cues.isEmpty {
                    ContentUnavailableView {
                        Label("Transcript Unavailable", systemImage: "text.bubble")
                    } description: {
                        Text("YouTube has not provided a transcript. Check the video’s transcript panel, then try again.")
                    } actions: {
                        Button("Try Again", action: model.refresh)
                    }
                } else {
                    YouTubeTranscriptTextView(model: model, activeCueID: model.activeCueID, followPlayback: model.followPlayback)
                        .popover(isPresented: $model.showPopup, attachmentAnchor: .rect(.rect(model.popupAnchorPosition))) {
                            WebView(model.popupPage)
                                .frame(width: 300, height: 200)
                                .presentationCompactAdaptation(.popover)
                                .accessibilityIdentifier("web.transcriptDictionaryPopover")
                        }
                    Toggle("Follow Playback", isOn: $model.followPlayback)
                        .padding()
                }
            }
            .background(.background)
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $model.dictionaryPresented) {
                if let dictionaryViewModel = model.dictionaryViewModel {
                    DictionarySearchView()
                        .environment(dictionaryViewModel)
                        .accessibilityIdentifier("web.transcriptDictionary")
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh Transcript", systemImage: "arrow.clockwise", action: model.refresh)
                }
            }
        }
        .task(id: model.reloadID) { await model.observePlayback() }
        .task(id: model.lookupID) { await model.prepareLookup() }
        .task(id: availability == .ready ? model.lookupRequest?.id : nil) {
            if case .ready = availability {
                await model.preparePopup()
            }
        }
        .accessibilityIdentifier("web.youtubeTranscript")
    }
}
