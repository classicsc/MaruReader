// DictionarySearchToolbarView.swift
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

struct DictionarySearchToolbarView: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let linksActiveEnabled: Bool
    let showsContextActions: Bool
    let furiganaEnabled: Bool
    let isEditingContext: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onToggleLinks: () -> Void
    let onToggleFurigana: () -> Void
    let onStartEditing: () -> Void
    let onCommitEdit: () -> Void
    let onCancelEdit: () -> Void
    let onCopyContext: () -> Void
    let presentationTheme: DictionaryPresentationTheme?

    var body: some View {
        HStack(spacing: 8) {
            Button("Back", systemImage: "chevron.backward", action: onBack)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .disabled(!canGoBack)

            Button("Forward", systemImage: "chevron.forward", action: onForward)
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)
                .disabled(!canGoForward)

            Button(
                "Links",
                systemImage: linksActiveEnabled ? "pointer.arrow" : "pointer.arrow.slash",
                action: onToggleLinks
            )
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)

            Spacer()

            if showsContextActions {
                Button(
                    "Furigana",
                    systemImage: furiganaEnabled ? "textformat.characters.dottedunderline.ja" : "textformat.characters.ja",
                    action: onToggleFurigana
                )
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.rect)

                if isEditingContext {
                    Button("Done", systemImage: "checkmark", action: onCommitEdit)
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)

                    Button("Cancel", systemImage: "xmark", action: onCancelEdit)
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                } else {
                    Button("Edit", systemImage: "pencil", action: onStartEditing)
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }

                Button("Copy", systemImage: "doc.on.doc", action: onCopyContext)
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
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

    private var themedBackgroundColor: Color {
        presentationTheme?.backgroundColor ?? Color(.systemBackground)
    }

    private var themedForegroundColor: Color {
        presentationTheme?.foregroundColor ?? .primary
    }

    private var themedSeparatorColor: Color {
        presentationTheme?.separatorColor ?? Color(.separator)
    }
}
