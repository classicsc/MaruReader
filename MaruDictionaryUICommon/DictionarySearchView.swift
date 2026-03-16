// DictionarySearchView.swift
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

//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//

import MaruReaderCore
import os
import SwiftUI
import WebKit

public struct DictionaryPresentationTheme: Sendable {
    public let preferredColorScheme: ColorScheme?
    public let backgroundColor: Color
    public let foregroundColor: Color
    public let secondaryForegroundColor: Color
    public let separatorColor: Color
    public let dictionaryWebTheme: DictionaryWebTheme?

    public init(
        preferredColorScheme: ColorScheme? = nil,
        backgroundColor: Color,
        foregroundColor: Color,
        secondaryForegroundColor: Color,
        separatorColor: Color,
        dictionaryWebTheme: DictionaryWebTheme? = nil
    ) {
        self.preferredColorScheme = preferredColorScheme
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.secondaryForegroundColor = secondaryForegroundColor
        self.separatorColor = separatorColor
        self.dictionaryWebTheme = dictionaryWebTheme
    }
}

private struct DictionaryPresentationThemeKey: EnvironmentKey {
    static let defaultValue: DictionaryPresentationTheme? = nil
}

public extension EnvironmentValues {
    var dictionaryPresentationTheme: DictionaryPresentationTheme? {
        get { self[DictionaryPresentationThemeKey.self] }
        set { self[DictionaryPresentationThemeKey.self] = newValue }
    }
}

public struct DictionarySearchView: View {
    @Environment(DictionarySearchViewModel.self) private var viewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.dictionaryPresentationTheme) private var presentationTheme

    private let logger = Logger.maru(category: "DictionarySearchView")

    public init() {}

    /// Whether to show the bottom toolbar (when context exists or navigation is possible)
    private var showToolbar: Bool {
        viewModel.currentRequest != nil || viewModel.history.canGoBack || viewModel.history.canGoForward
    }

    private var themedBackgroundColor: Color {
        presentationTheme?.backgroundColor ?? Color(.systemBackground)
    }

    private var themedForegroundColor: Color {
        presentationTheme?.foregroundColor ?? .primary
    }

    private var themedSeparatorColor: Color {
        presentationTheme?.separatorColor ?? Color(.separator)
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
            ZStack(alignment: .topLeading) {
                switch viewModel.resultState {
                case .ready:
                    WebView(viewModel.page)
                        // Popup overlay for text scanning
                        .popover(
                            isPresented: $viewModel.showPopup,
                            attachmentAnchor: .rect(.rect(viewModel.popupAnchorPosition))
                        ) {
                            WebView(viewModel.popupPage)
                                .background(themedBackgroundColor)
                                .applyLocalColorScheme(presentationTheme?.preferredColorScheme)
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
                            .environment(\.dictionaryPresentationTheme, presentationTheme)
                            .applyLocalColorScheme(presentationTheme?.preferredColorScheme)
                            .presentationCompactAdaptation(.popover)
                        }
                        // Tooltip popover for title attributes
                        .popover(
                            isPresented: $viewModel.showTooltip,
                            attachmentAnchor: .rect(.rect(viewModel.tooltipAnchorRect))
                        ) {
                            ScrollView {
                                Text(viewModel.tooltipText)
                                    .font(.callout)
                                    .foregroundStyle(themedForegroundColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            }
                            .background(themedBackgroundColor)
                            .applyLocalColorScheme(presentationTheme?.preferredColorScheme)
                            .frame(minWidth: 200, maxWidth: 320, maxHeight: 240)
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
                        .background(themedBackgroundColor)
                }
            }

            // Bottom toolbar (visible when context exists or navigation is possible)
            if showToolbar {
                bottomToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .foregroundStyle(themedForegroundColor)
        .background(themedBackgroundColor)
        .applyLocalColorScheme(presentationTheme?.preferredColorScheme)
        .onAppear {
            viewModel.loadContextDisplaySettings()
            viewModel.setDictionaryWebTheme(presentationTheme?.dictionaryWebTheme)
        }
        .onChange(of: presentationTheme?.dictionaryWebTheme) {
            viewModel.setDictionaryWebTheme(presentationTheme?.dictionaryWebTheme)
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 8) {
            // Navigation buttons
            Button(action: { viewModel.navigateBack() }) {
                Label("Back", systemImage: "chevron.backward")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .disabled(!viewModel.history.canGoBack)

            Button(action: { viewModel.navigateForward() }) {
                Label("Forward", systemImage: "chevron.forward")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }
            .disabled(!viewModel.history.canGoForward)

            // Link activation toggle
            Button(action: { viewModel.toggleLinksActive() }) {
                Label("Links", systemImage: viewModel.linksActiveEnabled ? "pointer.arrow" : "pointer.arrow.slash")
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
            }

            Spacer()

            // Context action buttons (only when context exists)
            if viewModel.currentRequest != nil {
                // Furigana toggle
                Button(action: { viewModel.toggleFurigana() }) {
                    Label("Furigana", systemImage: viewModel.furiganaEnabled ? "textformat.characters.dottedunderline.ja" : "textformat.characters.ja")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }

                // Edit/Done button
                if viewModel.isEditingContext {
                    Button(action: { viewModel.commitContextEdit() }) {
                        Label("Done", systemImage: "checkmark")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }

                    Button(action: { viewModel.cancelContextEdit() }) {
                        Label("Cancel", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                } else {
                    Button(action: { viewModel.startEditingContext() }) {
                        Label("Edit", systemImage: "pencil")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                }

                // Copy button
                Button(action: { viewModel.copyContextToClipboard() }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(themedBackgroundColor)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(themedSeparatorColor)
                .frame(height: 0.5)
        }
        .foregroundStyle(themedForegroundColor)
    }
}

/// Popover content for external link confirmation
private struct ExternalLinkConfirmationView: View {
    let url: URL?
    let onOpen: () -> Void
    @Environment(\.dictionaryPresentationTheme) private var presentationTheme

    private var themedBackgroundColor: Color {
        presentationTheme?.backgroundColor ?? Color(.systemBackground)
    }

    private var themedForegroundColor: Color {
        presentationTheme?.foregroundColor ?? .primary
    }

    private var themedSecondaryColor: Color {
        presentationTheme?.secondaryForegroundColor ?? .secondary
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Open \(url?.host ?? url?.absoluteString ?? "link") in browser?")
                .font(.subheadline)
                .foregroundStyle(themedSecondaryColor)

            Button("Open", action: onOpen)
        }
        .padding()
        .foregroundStyle(themedForegroundColor)
        .background(themedBackgroundColor)
    }
}

#Preview {
    DictionarySearchView()
}

private extension View {
    @ViewBuilder
    func applyLocalColorScheme(_ colorScheme: ColorScheme?) -> some View {
        if let colorScheme {
            environment(\.colorScheme, colorScheme)
        } else {
            self
        }
    }
}
