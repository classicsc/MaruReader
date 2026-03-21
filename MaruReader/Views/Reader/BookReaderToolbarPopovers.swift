// BookReaderToolbarPopovers.swift
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

import CoreData
import MaruDictionaryUICommon
import SwiftUI

struct BookReaderAppearancePopover: View {
    let readerPreferences: ReaderPreferences
    let theme: DictionaryPresentationTheme
    let onSelectAppearanceMode: (ReaderAppearanceMode) -> Void
    let onDismiss: () -> Void

    private var canDecreaseFontSize: Bool {
        readerPreferences.effectiveFontSize > 50.0
    }

    private var canIncreaseFontSize: Bool {
        readerPreferences.effectiveFontSize < 200.0
    }

    var body: some View {
        BookReaderToolbarPopoverContainer(
            title: "Appearance",
            theme: theme,
            idealWidth: 320,
            maxHeight: 420,
            onDismiss: onDismiss
        ) {
            VStack(alignment: .leading, spacing: 12) {
                BookReaderToolbarPopoverSectionTitle(
                    title: String(localized: "Text"),
                    theme: theme
                )

                BookReaderToolbarFontSizeCard(
                    valueText: AppLocalization.fontScale(Int(readerPreferences.effectiveFontSize)),
                    theme: theme,
                    canDecrease: canDecreaseFontSize,
                    canIncrease: canIncreaseFontSize,
                    onDecrease: {
                        readerPreferences.decreaseFontSize()
                    },
                    onIncrease: {
                        readerPreferences.increaseFontSize()
                    }
                )

                BookReaderToolbarPopoverSectionTitle(
                    title: String(localized: "Font"),
                    theme: theme
                )

                ForEach(ReaderFontFamilyOption.allCases, id: \.self) { option in
                    BookReaderToolbarPopoverSelectionButton(
                        title: option.displayName,
                        systemImage: option == .mincho ? "text.book.closed" : "textformat",
                        isSelected: readerPreferences.selectedFontFamilyOption == option,
                        theme: theme
                    ) {
                        readerPreferences.setFontFamilyOption(option)
                    }
                }

                BookReaderToolbarPopoverSectionTitle(
                    title: String(localized: "Colors"),
                    theme: theme
                )

                ForEach(ReaderAppearanceMode.allCases, id: \.self) { mode in
                    BookReaderToolbarPopoverSelectionButton(
                        title: mode.displayName,
                        systemImage: appearanceIcon(for: mode),
                        isSelected: readerPreferences.selectedAppearanceMode == mode,
                        theme: theme
                    ) {
                        onSelectAppearanceMode(mode)
                    }
                }
            }
        }
    }

    private func appearanceIcon(for mode: ReaderAppearanceMode) -> String {
        switch mode {
        case .followSystem:
            "circle.lefthalf.filled"
        case .light:
            "sun.max"
        case .dark:
            "moon"
        case .sepia:
            "book.pages"
        }
    }
}

struct BookReaderBookmarksPopover: View {
    let rows: [BookReaderBookmarkRowData]
    let currentBookmarkID: NSManagedObjectID?
    let isCurrentLocationBookmarked: Bool
    let canReturnToPreviousLocation: Bool
    let theme: DictionaryPresentationTheme
    let onAddBookmark: () -> Void
    let onRemoveBookmark: () -> Void
    let onNavigateToBookmark: (BookReaderBookmarkSnapshot) -> Void
    let onReturnToPreviousLocation: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        BookReaderToolbarPopoverContainer(
            title: "Bookmarks",
            theme: theme,
            idealWidth: 340,
            maxHeight: 440,
            onDismiss: onDismiss
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if isCurrentLocationBookmarked {
                    BookReaderToolbarPopoverActionButton(
                        title: String(localized: "Remove Bookmark"),
                        systemImage: "bookmark.slash",
                        role: .destructive,
                        theme: theme,
                        action: onRemoveBookmark
                    )
                } else {
                    BookReaderToolbarPopoverActionButton(
                        title: String(localized: "Add Bookmark"),
                        systemImage: "bookmark.fill",
                        theme: theme,
                        action: onAddBookmark
                    )
                }

                if canReturnToPreviousLocation {
                    BookReaderToolbarPopoverActionButton(
                        title: String(localized: "Return to Previous Location"),
                        systemImage: "arrow.uturn.backward",
                        theme: theme,
                        action: onReturnToPreviousLocation
                    )
                }

                BookReaderToolbarPopoverSectionTitle(
                    title: String(localized: "Bookmarks"),
                    theme: theme
                )

                if rows.isEmpty {
                    BookReaderToolbarPopoverEmptyState(
                        title: String(localized: "No Bookmarks"),
                        description: String(localized: "Tap the bookmark button to save your place"),
                        systemImage: "bookmark",
                        theme: theme
                    )
                } else {
                    ForEach(rows) { row in
                        BookReaderToolbarBookmarkButton(
                            row: row,
                            isCurrentLocation: row.id == currentBookmarkID,
                            theme: theme
                        ) {
                            onNavigateToBookmark(row.snapshot)
                        }
                    }
                }
            }
        }
    }
}

private struct BookReaderToolbarPopoverContainer<Content: View>: View {
    let title: LocalizedStringKey
    let theme: DictionaryPresentationTheme
    let idealWidth: CGFloat
    let maxHeight: CGFloat
    let onDismiss: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.foregroundColor)

                Spacer()

                Button(action: onDismiss) {
                    Label(String(localized: "Close"), systemImage: "xmark")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 44, height: 44)
                        .background(cardBackgroundColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.foregroundColor)
            }
            .padding(16)

            Divider()
                .overlay {
                    theme.separatorColor
                }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(minWidth: 280, idealWidth: idealWidth, maxWidth: 360, maxHeight: maxHeight)
        .background(theme.backgroundColor)
        .presentationBackground(theme.backgroundColor)
        .presentationCompactAdaptation(.popover)
        .applyLocalColorScheme(theme.preferredColorScheme)
        .tint(theme.foregroundColor)
    }

    private var cardBackgroundColor: Color {
        theme.secondaryForegroundColor.opacity(0.12)
    }
}

private struct BookReaderToolbarPopoverSectionTitle: View {
    let title: String
    let theme: DictionaryPresentationTheme

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.secondaryForegroundColor)
            .textCase(.uppercase)
            .padding(.horizontal, 4)
    }
}

private struct BookReaderToolbarFontSizeCard: View {
    let valueText: String
    let theme: DictionaryPresentationTheme
    let canDecrease: Bool
    let canIncrease: Bool
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(valueText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(theme.foregroundColor)

            HStack(spacing: 12) {
                fontSizeButton(
                    systemImage: "minus",
                    isEnabled: canDecrease,
                    accessibilityLabel: String(localized: "Decrease text size"),
                    action: onDecrease
                )

                fontSizeButton(
                    systemImage: "plus",
                    isEnabled: canIncrease,
                    accessibilityLabel: String(localized: "Increase text size"),
                    action: onIncrease
                )
            }
        }
        .padding(16)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Text Size"))
        .accessibilityValue(valueText)
    }

    private var cardBackgroundColor: Color {
        theme.secondaryForegroundColor.opacity(0.08)
    }

    private func fontSizeButton(
        systemImage: String,
        isEnabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(accessibilityLabel, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.backgroundColor.opacity(isEnabled ? 1.0 : 0.6))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .foregroundStyle(isEnabled ? theme.foregroundColor : theme.secondaryForegroundColor)
    }
}

private struct BookReaderToolbarPopoverSelectionButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let theme: DictionaryPresentationTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .foregroundStyle(theme.secondaryForegroundColor)

                Text(title)
                    .font(.body)
                    .foregroundStyle(theme.foregroundColor)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var cardBackgroundColor: Color {
        theme.secondaryForegroundColor.opacity(0.08)
    }
}

private struct BookReaderToolbarPopoverActionButton: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    let theme: DictionaryPresentationTheme
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 18)

                Text(title)
                    .font(.body.weight(.medium))

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : theme.foregroundColor)
    }

    private var cardBackgroundColor: Color {
        theme.secondaryForegroundColor.opacity(0.08)
    }
}

private struct BookReaderToolbarBookmarkButton: View {
    let row: BookReaderBookmarkRowData
    let isCurrentLocation: Bool
    let theme: DictionaryPresentationTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isCurrentLocation ? "bookmark.fill" : "bookmark")
                    .frame(width: 18)
                    .foregroundStyle(isCurrentLocation ? Color.accentColor : theme.secondaryForegroundColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.displayTitle)
                        .font(.body)
                        .foregroundStyle(theme.foregroundColor)
                        .lineLimit(1)

                    if isCurrentLocation {
                        Text(String(localized: "Current location"))
                            .font(.caption)
                            .foregroundStyle(theme.secondaryForegroundColor)
                    } else if let progressText = row.progressText {
                        Text(progressText)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryForegroundColor)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(cardBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var cardBackgroundColor: Color {
        theme.secondaryForegroundColor.opacity(0.08)
    }
}

private struct BookReaderToolbarPopoverEmptyState: View {
    let title: String
    let description: String
    let systemImage: String
    let theme: DictionaryPresentationTheme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(theme.secondaryForegroundColor)

            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(theme.foregroundColor)

            Text(description)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.secondaryForegroundColor)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(theme.secondaryForegroundColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
