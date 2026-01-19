// DictionarySearchView.swift
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

//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//

import MaruReaderCore
import os.log
import SwiftUI
import WebKit

public struct DictionarySearchView: View {
    @Environment(DictionarySearchViewModel.self) private var viewModel
    @Environment(\.openURL) private var openURL

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchView")

    public init() {}

    /// Whether to show the bottom toolbar (when context exists or navigation is possible)
    private var showToolbar: Bool {
        viewModel.currentRequest != nil || viewModel.history.canGoBack || viewModel.history.canGoForward
    }

    public var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 0) {
            // Context display (if available)
            if let request = viewModel.currentRequest {
                ContextDisplayView(
                    context: viewModel.currentResponse?.effectiveContext ?? request.context,
                    matchRange: viewModel.currentResponse?.effectivePrimaryResultSourceRange,
                    furiganaSegments: viewModel.currentFuriganaSegments,
                    fontSize: viewModel.contextFontSize,
                    furiganaEnabled: viewModel.furiganaEnabled,
                    isEditing: viewModel.isEditingContext,
                    onCharacterTap: { offset in
                        viewModel.performSearchAtOffset(offset)
                    },
                    onCommitEdit: { viewModel.commitContextEdit() },
                    editText: $viewModel.editContextText
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Main results area
            GeometryReader { _ in
                ZStack(alignment: .topLeading) {
                    switch viewModel.resultState {
                    case .ready:
                        WebView(viewModel.page)
                            // Popup overlay for text scanning
                            .popover(
                                isPresented: Binding(get: { viewModel.showPopup }, set: { viewModel.showPopup = $0 }),
                                attachmentAnchor: .rect(.rect(viewModel.popupAnchorPosition))
                            ) {
                                WebView(viewModel.popupPage)
                                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 400, minHeight: 150, idealHeight: 200, maxHeight: 300)
                                    .presentationCompactAdaptation(.popover)
                            }
                            // External link confirmation popover
                            .popover(
                                isPresented: $viewModel.showExternalLinkConfirmation,
                                attachmentAnchor: .rect(.rect(viewModel.externalLinkAnchorRect))
                            ) {
                                ExternalLinkConfirmationView(
                                    url: viewModel.pendingExternalURL,
                                    onOpen: {
                                        if let url = viewModel.pendingExternalURL {
                                            openURL(url)
                                        }
                                        viewModel.clearPendingExternalURL()
                                        viewModel.showExternalLinkConfirmation = false
                                    }
                                )
                                .presentationCompactAdaptation(.popover)
                            }
                            // Tooltip popover for title attributes
                            .popover(
                                isPresented: $viewModel.showTooltip,
                                attachmentAnchor: .rect(.rect(viewModel.tooltipAnchorRect))
                            ) {
                                Text(viewModel.tooltipText)
                                    .font(.callout)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .presentationCompactAdaptation(.popover)
                            }
                    case let .noResults(query):
                        ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("No results found for \"\(query)\""))
                    case .startPage:
                        ContentUnavailableView("Start a Search", systemImage: "book", description: Text("Enter text to search the dictionary."))
                    case let .error(error):
                        ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
                    case .searching:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                    }
                }
            }

            // Bottom toolbar (visible when context exists or navigation is possible)
            if showToolbar {
                bottomToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            viewModel.loadContextDisplaySettings()
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 16) {
            // Navigation buttons
            Button(action: { viewModel.navigateBack() }) {
                Label("Back", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
            }
            .disabled(!viewModel.history.canGoBack)

            Button(action: { viewModel.navigateForward() }) {
                Label("Forward", systemImage: "chevron.forward")
                    .labelStyle(.iconOnly)
            }
            .disabled(!viewModel.history.canGoForward)

            // Link activation toggle
            Button(action: { viewModel.toggleLinksActive() }) {
                Label("Links", systemImage: viewModel.linksActiveEnabled ? "pointer.arrow" : "pointer.arrow.slash")
                    .labelStyle(.iconOnly)
            }

            Spacer()

            // Context action buttons (only when context exists)
            if viewModel.currentRequest != nil {
                // Furigana toggle
                Button(action: { viewModel.toggleFurigana() }) {
                    Label("Furigana", systemImage: viewModel.furiganaEnabled ? "textformat.abc.dottedunderline" : "textformat.abc")
                        .labelStyle(.iconOnly)
                }

                // Edit/Done button
                if viewModel.isEditingContext {
                    Button(action: { viewModel.commitContextEdit() }) {
                        Label("Done", systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                    }

                    Button(action: { viewModel.cancelContextEdit() }) {
                        Label("Cancel", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                    }
                } else {
                    Button(action: { viewModel.startEditingContext() }) {
                        Label("Edit", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                    }
                }

                // Copy button
                Button(action: { viewModel.copyContextToClipboard() }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

/// Popover content for external link confirmation
private struct ExternalLinkConfirmationView: View {
    let url: URL?
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Open \(url?.host ?? url?.absoluteString ?? "link") in browser?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Open", action: onOpen)
        }
        .padding()
    }
}

#Preview {
    DictionarySearchView()
}
