// WebViewerContentView.swift
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

import SwiftUI

struct WebViewerContentView: View {
    let viewModel: WebViewerViewModel
    let page: WebBrowserPage
    @Binding var isEditingAddress: Bool
    let addressSnapshot: String
    @Binding var selectedLookup: WebLookupSelection?
    let suggestionViewModel: WebSearchSuggestionViewModel
    let onNavigateFromNewTabPage: (URL) -> Void
    let onNavigateFromAddressEditing: (URL) -> Void
    let onSelectSuggestion: (String) -> Void
    @State private var transcriptPresented = false
    @State private var transcriptSheetPresented = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 1)

            ZStack {
                let model = viewModel
                HStack(spacing: 0) {
                    WebBrowserView(page: page) { [weak model] oldOffset, newOffset in
                        model?.handleScrollOffsetChange(from: oldOffset, to: newOffset)
                    }
                    .id(page.webView)
                    if transcriptPresented, horizontalSizeClass == .regular,
                       let videoID = YouTubeVideo.id(from: page.url)
                    {
                        YouTubeTranscriptView(page: page, videoID: videoID, onDismiss: closeTranscript)
                            .id(videoID)
                            .frame(width: 360)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if !transcriptPresented, !isEditingAddress,
                       YouTubeVideo.id(from: page.url) != nil
                    {
                        Button("Transcript", systemImage: "text.bubble", action: openTranscript)
                            .padding(10)
                            .glassEffect()
                            .padding()
                            .accessibilityIdentifier("web.openTranscript")
                    }
                }
                .sheet(isPresented: $transcriptSheetPresented, onDismiss: closeTranscript) {
                    if horizontalSizeClass != .regular,
                       let videoID = YouTubeVideo.id(from: page.url)
                    {
                        YouTubeTranscriptView(page: page, videoID: videoID, onDismiss: closeTranscript)
                            .id(videoID)
                            .presentationDetents([.medium, .large])
                            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    }
                }

                if viewModel.isShowingNewTabPage, !isEditingAddress {
                    NewTabPageView(
                        bookmarks: viewModel.bookmarks,
                        onNavigate: onNavigateFromNewTabPage
                    )
                    .transition(.opacity)
                }

                if isEditingAddress {
                    Group {
                        if viewModel.addressBarText != addressSnapshot {
                            WebSearchSuggestionsView(
                                suggestions: suggestionViewModel.suggestions,
                                isLoading: suggestionViewModel.isLoading,
                                onSelect: onSelectSuggestion
                            )
                        } else {
                            NewTabPageView(
                                bookmarks: viewModel.bookmarks,
                                onNavigate: onNavigateFromAddressEditing
                            )
                        }
                    }
                    .transition(.opacity)
                }

                if viewModel.readingModeEnabled {
                    GeometryReader { geometry in
                        WebReadingModeOverlay(
                            clusters: viewModel.ocrViewModel.clusters,
                            showBoundingBoxes: viewModel.showBoundingBoxes,
                            highlightedCluster: viewModel.highlightedCluster,
                            isProcessing: viewModel.ocrViewModel.isProcessing,
                            onTap: handleReadingModeTap
                        )
                        .task {
                            await viewModel.captureAndRunOCR(viewSize: geometry.size)
                        }
                    }
                }
            }

            Color.clear
                .frame(height: 1)
        }
        .onChange(of: page.webView) { closeTranscript() }
        .onChange(of: page.url) { oldURL, newURL in
            if YouTubeVideo.id(from: oldURL) != YouTubeVideo.id(from: newURL) {
                closeTranscript()
            }
        }
        .onChange(of: horizontalSizeClass) { closeTranscript() }
    }

    private func openTranscript() {
        transcriptPresented = true
        transcriptSheetPresented = horizontalSizeClass != .regular
    }

    private func closeTranscript() {
        transcriptPresented = false
        transcriptSheetPresented = false
    }

    private func handleReadingModeTap(_ location: CGPoint, _ size: CGSize) {
        Task {
            if let selection = await viewModel.lookupCluster(at: location, in: size) {
                viewModel.highlightedCluster = selection.cluster
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.exitReadingModeAfterLookupSelection()
                }
                selectedLookup = selection
                viewModel.highlightedCluster = nil
            }
        }
    }
}
