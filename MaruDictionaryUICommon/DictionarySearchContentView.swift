// DictionarySearchContentView.swift
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

import MaruReaderCore
import SwiftUI

@MainActor
struct DictionarySearchContentView: View {
    let viewModel: DictionarySearchViewModel
    let presentationState: DictionarySearchPresentationState
    let openURL: OpenURLAction
    let presentationTheme: DictionaryPresentationTheme?

    var body: some View {
        @Bindable var presentationState = presentationState

        VStack(alignment: .leading, spacing: 0) {
            if let currentContext, viewModel.currentRequest != nil {
                ContextDisplayView(
                    context: currentContext,
                    matchRange: viewModel.currentResponse?.effectivePrimaryResultSourceRange,
                    furiganaSegments: presentationState.furiganaSegments(for: currentContext),
                    fontSize: presentationState.contextFontSize,
                    furiganaEnabled: presentationState.furiganaEnabled,
                    isEditing: presentationState.isEditingContext,
                    onCharacterTap: performSearchAtOffset,
                    onCommitEdit: commitContextEdit,
                    editText: $presentationState.editContextText
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            DictionarySearchResultsView(
                viewModel: viewModel,
                openURL: openURL,
                presentationTheme: presentationTheme
            )

            if showToolbar {
                DictionarySearchToolbarView(
                    canGoBack: viewModel.canNavigateBack,
                    canGoForward: viewModel.canNavigateForward,
                    linksActiveEnabled: viewModel.linksActiveEnabled,
                    showsContextActions: viewModel.currentRequest != nil,
                    furiganaEnabled: presentationState.furiganaEnabled,
                    isEditingContext: presentationState.isEditingContext,
                    onBack: navigateBack,
                    onForward: navigateForward,
                    onToggleLinks: toggleLinksActive,
                    onToggleFurigana: toggleFurigana,
                    onStartEditing: startEditingContext,
                    onCommitEdit: commitContextEdit,
                    onCancelEdit: cancelContextEdit,
                    onCopyContext: copyContextToClipboard,
                    presentationTheme: presentationTheme
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .foregroundStyle(themedForegroundColor)
        .background(themedBackgroundColor)
        .applyLocalColorScheme(presentationTheme?.preferredColorScheme)
    }

    private var currentContext: String? {
        guard let request = viewModel.currentRequest else { return nil }
        return viewModel.currentResponse?.effectiveContext ?? request.context
    }

    private var showToolbar: Bool {
        viewModel.currentRequest != nil || viewModel.canNavigateBack || viewModel.canNavigateForward
    }

    private var themedBackgroundColor: Color {
        presentationTheme?.backgroundColor ?? Color(.systemBackground)
    }

    private var themedForegroundColor: Color {
        presentationTheme?.foregroundColor ?? .primary
    }

    private func performSearchAtOffset(_ offset: Int) {
        viewModel.performSearchAtOffset(offset)
    }

    private func navigateBack() {
        viewModel.navigateBack()
    }

    private func navigateForward() {
        viewModel.navigateForward()
    }

    private func toggleLinksActive() {
        viewModel.toggleLinksActive()
    }

    private func toggleFurigana() {
        presentationState.toggleFurigana()
    }

    private func startEditingContext() {
        guard let currentContext else { return }
        presentationState.startEditing(context: currentContext)
    }

    private func commitContextEdit() {
        let editedText = presentationState.editContextText
        Task { @MainActor in
            await viewModel.commitContextEdit(editedText)
            presentationState.clearEditing()
        }
    }

    private func cancelContextEdit() {
        presentationState.clearEditing()
    }

    private func copyContextToClipboard() {
        viewModel.copyContextToClipboard()
    }
}
