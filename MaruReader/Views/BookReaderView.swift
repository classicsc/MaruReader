// BookReaderView.swift
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
import Foundation
import MaruDictionaryUICommon
import MaruReaderCore
import ReadiumNavigator
import SwiftUI
import WebKit

// MARK: - BookReaderView

struct BookReaderView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 44
    @ScaledMetric(relativeTo: .largeTitle) private var errorIconSize: CGFloat = 48

    @State private var viewModel: BookReaderViewModel
    @State private var progressDisplayMode: ProgressDisplayMode = .book
    @State private var tourManager = TourManager()
    // This is treated as the current system scheme for Follow System mode.
    // Avoid using `.preferredColorScheme` in descendant overlays, which can contaminate this value.
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    init(book: Book) {
        _viewModel = State(wrappedValue: BookReaderViewModel(book: book))
    }

    private var showingTableOfContents: Binding<Bool> {
        Binding(
            get: { viewModel.overlayState == .showingTableOfContents },
            set: { newValue in
                viewModel.overlayState = viewModel.overlayState.settingPresentation(
                    newValue,
                    for: .showingTableOfContents
                )
            }
        )
    }

    private var showingAppearancePopover: Binding<Bool> {
        Binding(
            get: { viewModel.overlayState == .showingQuickSettings },
            set: { newValue in
                viewModel.overlayState = viewModel.overlayState.settingPresentation(
                    newValue,
                    for: .showingQuickSettings
                )
            }
        )
    }

    private var showingBookmarksPopover: Binding<Bool> {
        Binding(
            get: { viewModel.overlayState == .showingBookmarks },
            set: { newValue in
                viewModel.overlayState = viewModel.overlayState.settingPresentation(
                    newValue,
                    for: .showingBookmarks
                )
            }
        )
    }

    var body: some View {
        switch viewModel.readerState {
        case .loading:
            ProgressView("Loading book...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .error(error):
            errorView(error: error)
        case .reading:
            readerView
                .onChange(of: availableProgressDisplayModes) {
                    syncProgressDisplayMode(with: availableProgressDisplayModes)
                }
                .sheet(item: $viewModel.dictionarySheetPresentation, onDismiss: {
                    viewModel.dismissDictionarySheet()
                }) { presentation in
                    NavigationStack {
                        DictionarySearchView()
                            .environment(presentation.viewModel)
                            .environment(\.dictionaryPresentationTheme, readerDictionaryPresentationTheme)
                            .navigationTitle("Dictionary")
                            .navigationBarTitleDisplayMode(.inline)
                            .navigationBarBackButtonHidden(true)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Done") {
                                        viewModel.dismissDictionarySheet()
                                    }
                                    .foregroundStyle(readerDictionaryPresentationTheme.foregroundColor)
                                }
                            }
                    }
                    .background(dictionarySheetBackgroundColor)
                    .applyLocalColorScheme(readerOverlayForcedColorScheme)
                    .tint(readerDictionaryPresentationTheme.foregroundColor)
                    .toolbarBackground(dictionarySheetBackgroundColor, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(
                        readerDictionaryPresentationTheme.preferredColorScheme ?? colorScheme,
                        for: .navigationBar
                    )
                    .accessibilityIdentifier("bookReader.dictionarySheet")
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: showingTableOfContents) {
                    if let publication = viewModel.publication {
                        let tableOfContentsTheme = readerTableOfContentsTheme
                        TableOfContentsView(
                            publication: publication,
                            bookTitle: viewModel.book.title,
                            bookAuthor: viewModel.book.author,
                            coverImage: viewModel.coverImage,
                            currentLocator: viewModel.currentLocator,
                            bookmarks: viewModel.bookmarks,
                            chapterTitleByHref: viewModel.cachedChapterTitleByHref,
                            onNavigate: { link in
                                viewModel.navigateToLink(link)
                            },
                            onNavigateToPosition: { position in
                                viewModel.navigateToPosition(position)
                            },
                            onNavigateToBookmark: { bookmark in
                                viewModel.navigateToBookmark(bookmark)
                            },
                            onDeleteBookmark: { bookmark in
                                viewModel.deleteBookmark(bookmark)
                            },
                            onUpdateBookmarkTitle: { bookmark, title in
                                viewModel.updateBookmarkTitle(bookmark, title: title)
                            },
                            theme: tableOfContentsTheme,
                            onDismiss: {
                                viewModel.overlayState = .showingToolbars
                            }
                        )
                        .background(tableOfContentsTheme.backgroundColor)
                        .tint(tableOfContentsTheme.foregroundColor)
                        .presentationBackground(tableOfContentsTheme.backgroundColor)
                        .toolbarBackground(tableOfContentsTheme.backgroundColor, for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbarColorScheme(
                            tableOfContentsTheme.preferredColorScheme ?? colorScheme,
                            for: .navigationBar
                        )
                        .presentationDetents([.medium, .large])
                    }
                }
                .onChange(of: colorScheme) {
                    viewModel.readerPreferences.systemColorScheme = colorScheme
                    viewModel.readerPreferences.submitToNavigator()
                    applyReaderDictionaryTheme()
                }
                .onChange(of: viewModel.readerPreferences.selectedAppearanceMode) {
                    applyReaderDictionaryTheme()
                }
                .tourOverlay(manager: tourManager)
                .onAppear {
                    viewModel.readerPreferences.systemColorScheme = colorScheme
                    applyReaderDictionaryTheme()
                    if MaruReaderApp.isScreenshotMode {
                        viewModel.isDictionaryActive = true
                    } else if tourManager.startIfNeeded(BookReaderTour.self) {
                        viewModel.overlayState = .showingToolbars
                    }
                }
                .task {
                    guard MaruReaderApp.isScreenshotMode else { return }
                    try? await Task.sleep(for: .seconds(3))
                    viewModel.triggerScreenshotTextLookup()
                }
        }
    }

    private var readerView: some View {
        let overlayTheme = readerDictionaryPresentationTheme

        return ZStack(alignment: .topLeading) {
            readerBackgroundColor
            EPUBNavigatorWrapper(
                viewModel: viewModel,
                colorScheme: colorScheme
            )
            .padding(.horizontal, viewModel.readerPreferences.horizontalMargin)
            .overlay {
                BookReaderNavigatorOverlaySurface(
                    isDictionaryActive: viewModel.isDictionaryActive,
                    marginWidth: viewModel.readerPreferences.horizontalMargin,
                    showingPopup: $viewModel.showPopup,
                    popupAnchorPosition: viewModel.popupAnchorPosition,
                    popupPage: viewModel.popupPage,
                    popupBackgroundColor: dictionarySheetBackgroundColor,
                    onTap: { globalPoint in
                        viewModel.triggerTextScan(atGlobalPoint: globalPoint)
                    },
                    onSwipeLeft: {
                        Task { await viewModel.navigator?.goRight(options: .init()) }
                    },
                    onSwipeRight: {
                        Task { await viewModel.navigator?.goLeft(options: .init()) }
                    }
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            BookReaderBottomInset(
                showsToolbars: viewModel.overlayState.shouldShowToolbars,
                isDictionaryActive: viewModel.isDictionaryActive,
                isCurrentLocationBookmarked: viewModel.currentLocationBookmark != nil,
                currentBookmarkID: viewModel.currentLocationBookmark?.objectID,
                canReturnToPreviousLocation: viewModel.previousLocation != nil,
                bookmarks: viewModel.bookmarks,
                showingAppearancePopover: showingAppearancePopover,
                showingBookmarksPopover: showingBookmarksPopover,
                progressDisplayText: progressDisplayText,
                toolbarForegroundColor: toolbarForegroundColor(isPrimary: true),
                toolbarSecondaryColor: toolbarSecondaryColor,
                theme: overlayTheme,
                onShowTableOfContents: {
                    viewModel.overlayState = .showingTableOfContents
                },
                onToggleDictionaryMode: {
                    viewModel.isDictionaryActive.toggle()
                },
                onToggleAppearancePopover: toggleAppearancePopover,
                onSelectAppearanceMode: { mode in
                    viewModel.readerPreferences.setAppearanceMode(mode)
                    applyReaderDictionaryTheme()
                },
                onDismissAppearancePopover: {
                    viewModel.overlayState = viewModel.overlayState.settingPresentation(
                        false,
                        for: .showingQuickSettings
                    )
                },
                onToggleBookmarksPopover: toggleBookmarksPopover,
                onAddBookmark: {
                    viewModel.bookmarkCurrentLocation()
                    viewModel.overlayState = viewModel.overlayState.settingPresentation(
                        false,
                        for: .showingBookmarks
                    )
                },
                onRemoveBookmark: {
                    viewModel.removeBookmarkAtCurrentLocation()
                    viewModel.overlayState = viewModel.overlayState.settingPresentation(
                        false,
                        for: .showingBookmarks
                    )
                },
                onNavigateToBookmark: { bookmark in
                    viewModel.navigateToBookmark(bookmark)
                },
                onReturnToPreviousLocation: {
                    viewModel.returnToPreviousLocation()
                },
                onDismissBookmarksPopover: {
                    viewModel.overlayState = viewModel.overlayState.settingPresentation(
                        false,
                        for: .showingBookmarks
                    )
                },
                onCycleProgressDisplayMode: {
                    cycleProgressDisplayMode(availableModes: availableProgressDisplayModes)
                },
                readerPreferences: viewModel.readerPreferences
            )
            .applyLocalColorScheme(readerOverlayForcedColorScheme)
        }
        .safeAreaInset(edge: .top) {
            BookReaderTopInset(
                showsToolbars: viewModel.overlayState.shouldShowToolbars,
                title: viewModel.book.title ?? "Book Reader",
                floatingButtonIconSize: floatingButtonIconSize,
                floatingButtonFrameSize: floatingButtonFrameSize,
                primaryForegroundColor: toolbarForegroundColor(isPrimary: viewModel.overlayState.shouldShowToolbars),
                secondaryForegroundColor: toolbarSecondaryColor,
                onDismiss: { dismiss() },
                onToggleOverlay: { viewModel.toggleOverlay() }
            )
        }
        .background(readerBackgroundColor.ignoresSafeArea())
    }

    private func errorView(error: Error) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: errorIconSize))
                    .foregroundStyle(.red)
                Text("Failed to load book")
                    .font(.headline)
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            BookReaderFloatingBackButton(
                iconSize: floatingButtonIconSize,
                frameSize: floatingButtonFrameSize,
                action: { dismiss() }
            )
            .padding()
        }
    }

    // MARK: - Theme Color Helpers

    private var readerBackgroundColor: SwiftUI.Color {
        viewModel.readerPreferences.currentPageBackgroundColor
    }

    private var dictionarySheetBackgroundColor: SwiftUI.Color {
        readerDictionaryPresentationTheme.backgroundColor
    }

    private var readerTableOfContentsTheme: TableOfContentsTheme {
        let theme = readerDictionaryPresentationTheme
        return TableOfContentsTheme(
            preferredColorScheme: readerOverlayForcedColorScheme,
            backgroundColor: theme.backgroundColor,
            foregroundColor: theme.foregroundColor,
            secondaryForegroundColor: theme.secondaryForegroundColor,
            separatorColor: theme.separatorColor
        )
    }

    private var readerOverlayForcedColorScheme: ColorScheme? {
        switch viewModel.readerPreferences.selectedAppearanceMode {
        case .dark:
            .dark
        case .light, .sepia:
            .light
        case .followSystem:
            nil
        }
    }

    private var readerDictionaryPresentationTheme: DictionaryPresentationTheme {
        let interfaceBackground = viewModel.readerPreferences.currentInterfaceBackgroundColor ?? viewModel.readerPreferences.currentPageBackgroundColor
        let interfaceForeground = viewModel.readerPreferences.currentInterfaceForegroundColor ?? .primary
        let secondary = viewModel.readerPreferences.currentInterfaceSecondaryColor ?? interfaceForeground.opacity(0.6)
        let separator = secondary.opacity(0.35)

        let preferredColorScheme: ColorScheme? = switch viewModel.readerPreferences.selectedAppearanceMode {
        case .dark:
            .dark
        case .light, .sepia:
            .light
        case .followSystem:
            colorScheme
        }

        return DictionaryPresentationTheme(
            preferredColorScheme: preferredColorScheme,
            backgroundColor: interfaceBackground,
            foregroundColor: interfaceForeground,
            secondaryForegroundColor: secondary,
            separatorColor: separator,
            dictionaryWebTheme: makeDictionaryWebTheme(
                preferredColorScheme: preferredColorScheme,
                interfaceBackgroundColor: interfaceBackground,
                foregroundColor: interfaceForeground
            )
        )
    }

    private func applyReaderDictionaryTheme() {
        let webTheme = readerDictionaryPresentationTheme.dictionaryWebTheme
        viewModel.setDictionaryWebTheme(webTheme)
    }

    private func makeDictionaryWebTheme(
        preferredColorScheme: ColorScheme?,
        interfaceBackgroundColor: SwiftUI.Color,
        foregroundColor: SwiftUI.Color
    ) -> DictionaryWebTheme? {
        let interfaceBackgroundHex = cssHex(for: interfaceBackgroundColor)
        let pageBackgroundHex = cssHex(for: viewModel.readerPreferences.currentPageBackgroundColor)
        let foregroundHex = cssHex(for: foregroundColor)
        let accentHex = cssHex(for: .accentColor)

        guard pageBackgroundHex != nil || interfaceBackgroundHex != nil || foregroundHex != nil || accentHex != nil else {
            return nil
        }

        let colorSchemeString: String? = switch preferredColorScheme {
        case .light:
            "light"
        case .dark:
            "dark"
        case nil:
            nil
        @unknown default:
            nil
        }

        return DictionaryWebTheme(
            colorScheme: colorSchemeString,
            textColor: foregroundHex,
            backgroundColor: pageBackgroundHex,
            interfaceBackgroundColor: interfaceBackgroundHex,
            accentColor: accentHex,
            linkColor: accentHex,
            glossImageBackgroundColor: pageBackgroundHex
        )
    }

    private func cssHex(for color: SwiftUI.Color) -> String? {
        ReadiumNavigator.Color(swiftUIColor: color)?.cssHex
    }

    private func toolbarForegroundColor(isPrimary: Bool) -> SwiftUI.Color {
        if let color = viewModel.readerPreferences.currentInterfaceForegroundColor {
            return isPrimary ? color : color.opacity(0.6)
        }
        return isPrimary ? .primary : .secondary
    }

    private var toolbarSecondaryColor: SwiftUI.Color {
        viewModel.readerPreferences.currentInterfaceSecondaryColor ?? .secondary
    }

    private enum ProgressDisplayMode: CaseIterable {
        case book
        case chapter
        case position
    }

    private var availableProgressDisplayModes: [ProgressDisplayMode] {
        guard let locator = viewModel.currentLocator else { return [] }
        var modes: [ProgressDisplayMode] = []
        if locator.locations.totalProgression != nil {
            modes.append(.book)
        }
        if locator.locations.progression != nil {
            modes.append(.chapter)
        }
        if locator.locations.position != nil {
            modes.append(.position)
        }
        return modes
    }

    private var progressDisplayText: String? {
        guard let locator = viewModel.currentLocator else { return nil }
        guard let displayMode = resolvedProgressDisplayMode(from: availableProgressDisplayModes) else { return nil }
        switch displayMode {
        case .book:
            guard let totalProgression = locator.locations.totalProgression else { return nil }
            return String(localized: "Book \(formatProgress(totalProgression))")
        case .chapter:
            guard let progression = locator.locations.progression else { return nil }
            return String(localized: "Chapter \(formatProgress(progression))")
        case .position:
            guard let position = locator.locations.position else { return nil }
            return String(localized: "Position \(position)")
        }
    }

    private func resolvedProgressDisplayMode(from availableModes: [ProgressDisplayMode]) -> ProgressDisplayMode? {
        guard let first = availableModes.first else { return nil }
        return availableModes.contains(progressDisplayMode) ? progressDisplayMode : first
    }

    private func formatProgress(_ value: Double) -> String {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue.formatted(.percent.precision(.fractionLength(0)))
    }

    private func cycleProgressDisplayMode(availableModes: [ProgressDisplayMode]) {
        guard !availableModes.isEmpty else { return }
        guard let currentIndex = availableModes.firstIndex(of: progressDisplayMode) else {
            progressDisplayMode = availableModes[0]
            return
        }
        let nextIndex = (currentIndex + 1) % availableModes.count
        progressDisplayMode = availableModes[nextIndex]
    }

    private func syncProgressDisplayMode(with availableModes: [ProgressDisplayMode]) {
        guard let first = availableModes.first else { return }
        if !availableModes.contains(progressDisplayMode) {
            progressDisplayMode = first
        }
    }

    private func toggleAppearancePopover() {
        viewModel.overlayState = viewModel.overlayState.settingPresentation(
            viewModel.overlayState != .showingQuickSettings,
            for: .showingQuickSettings
        )
    }

    private func toggleBookmarksPopover() {
        viewModel.overlayState = viewModel.overlayState.settingPresentation(
            viewModel.overlayState != .showingBookmarks,
            for: .showingBookmarks
        )
    }
}

private struct BookReaderNavigatorOverlaySurface: View {
    let isDictionaryActive: Bool
    let marginWidth: Double
    @Binding var showingPopup: Bool
    let popupAnchorPosition: CGRect
    let popupPage: WebPage
    let popupBackgroundColor: SwiftUI.Color
    let onTap: (CGPoint) -> Void
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    var body: some View {
        Group {
            if isDictionaryActive {
                DictionaryGestureOverlay(
                    marginWidth: marginWidth,
                    onTap: onTap,
                    onSwipeLeft: onSwipeLeft,
                    onSwipeRight: onSwipeRight
                )
            } else {
                MarginSwipeOverlay(
                    marginWidth: marginWidth,
                    onSwipeLeft: onSwipeLeft,
                    onSwipeRight: onSwipeRight
                )
            }
        }
        .popover(
            isPresented: $showingPopup,
            attachmentAnchor: .rect(.rect(popupAnchorPosition))
        ) {
            WebView(popupPage)
                .background(popupBackgroundColor)
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 400, minHeight: 150, idealHeight: 200, maxHeight: 300)
                .presentationCompactAdaptation(.popover)
                .accessibilityIdentifier("bookReader.dictionaryPopover")
        }
    }
}

private struct BookReaderTopInset: View {
    let showsToolbars: Bool
    let title: String
    let floatingButtonIconSize: CGFloat
    let floatingButtonFrameSize: CGFloat
    let primaryForegroundColor: SwiftUI.Color
    let secondaryForegroundColor: SwiftUI.Color
    let onDismiss: () -> Void
    let onToggleOverlay: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                Color.clear
                    .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
                Spacer()
                Text(title)
                    .font(.headline)
                    .hidden()
                Spacer()
                Color.clear
                    .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
            }
            .padding(.horizontal)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .hidden()

            HStack {
                if showsToolbars {
                    BookReaderFloatingBackButton(
                        iconSize: floatingButtonIconSize,
                        frameSize: floatingButtonFrameSize,
                        action: onDismiss
                    )
                    .tourAnchor(BookReaderTourAnchor.backButton)
                } else {
                    BookReaderFloatingBackButton(
                        iconSize: floatingButtonIconSize,
                        frameSize: floatingButtonFrameSize,
                        action: onDismiss
                    )
                    .hidden()
                }
                Spacer()
                Button(action: onToggleOverlay) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(primaryForegroundColor)
                            .lineLimit(1)
                        Image(systemName: showsToolbars ? "chevron.up" : "chevron.down")
                            .font(.headline)
                            .foregroundStyle(showsToolbars ? secondaryForegroundColor : secondaryForegroundColor.opacity(0.6))
                    }
                }
                .tourAnchor(BookReaderTourAnchor.titleToggle)
                Spacer()
                Spacer().frame(width: floatingButtonFrameSize)
            }
            .padding(.horizontal)
        }
    }
}

private struct BookReaderFloatingBackButton: View {
    let iconSize: CGFloat
    let frameSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: iconSize, weight: .semibold))
                .frame(width: frameSize, height: frameSize)
        }
        .contentShape(.circle)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Back")
        .accessibilityIdentifier("bookReader.back")
    }
}

private struct BookReaderBottomInset: View {
    let showsToolbars: Bool
    let isDictionaryActive: Bool
    let isCurrentLocationBookmarked: Bool
    let currentBookmarkID: NSManagedObjectID?
    let canReturnToPreviousLocation: Bool
    let bookmarks: [Bookmark]
    let showingAppearancePopover: Binding<Bool>
    let showingBookmarksPopover: Binding<Bool>
    let progressDisplayText: String?
    let toolbarForegroundColor: SwiftUI.Color
    let toolbarSecondaryColor: SwiftUI.Color
    let theme: DictionaryPresentationTheme
    let onShowTableOfContents: () -> Void
    let onToggleDictionaryMode: () -> Void
    let onToggleAppearancePopover: () -> Void
    let onSelectAppearanceMode: (ReaderAppearanceMode) -> Void
    let onDismissAppearancePopover: () -> Void
    let onToggleBookmarksPopover: () -> Void
    let onAddBookmark: () -> Void
    let onRemoveBookmark: () -> Void
    let onNavigateToBookmark: (Bookmark) -> Void
    let onReturnToPreviousLocation: () -> Void
    let onDismissBookmarksPopover: () -> Void
    let onCycleProgressDisplayMode: () -> Void
    let readerPreferences: ReaderPreferences

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clear
                .frame(height: 88)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .hidden()

            if showsToolbars {
                HStack(spacing: 32) {
                    Button(action: onShowTableOfContents) {
                        Image(systemName: "list.bullet")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Table of contents")
                    .accessibilityIdentifier("bookReader.tableOfContents")
                    .tourAnchor(BookReaderTourAnchor.tableOfContents)

                    Button(action: onToggleDictionaryMode) {
                        Image(systemName: isDictionaryActive ? "character.book.closed.fill.ja" : "character.book.closed.ja")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel(isDictionaryActive ? "Disable dictionary mode" : "Enable dictionary mode")
                    .accessibilityIdentifier("bookReader.dictionaryMode")
                    .tourAnchor(BookReaderTourAnchor.dictionaryMode)

                    Button(action: onToggleBookmarksPopover) {
                        Image(systemName: isCurrentLocationBookmarked ? "bookmark.fill" : "bookmark")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Bookmarks")
                    .accessibilityIdentifier("bookReader.bookmarksButton")
                    .tourAnchor(BookReaderTourAnchor.bookmark)
                    .popover(
                        isPresented: showingBookmarksPopover,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .bottom
                    ) {
                        BookReaderBookmarksPopover(
                            bookmarks: bookmarks,
                            currentBookmarkID: currentBookmarkID,
                            isCurrentLocationBookmarked: isCurrentLocationBookmarked,
                            canReturnToPreviousLocation: canReturnToPreviousLocation,
                            theme: theme,
                            onAddBookmark: onAddBookmark,
                            onRemoveBookmark: onRemoveBookmark,
                            onNavigateToBookmark: onNavigateToBookmark,
                            onReturnToPreviousLocation: onReturnToPreviousLocation,
                            onDismiss: onDismissBookmarksPopover
                        )
                        .accessibilityIdentifier("bookReader.bookmarksPopover")
                    }

                    Button(action: onToggleAppearancePopover) {
                        Image(systemName: "textformat")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Appearance and text")
                    .accessibilityIdentifier("bookReader.appearanceButton")
                    .tourAnchor(BookReaderTourAnchor.appearanceMenu)
                    .popover(
                        isPresented: showingAppearancePopover,
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .bottom
                    ) {
                        BookReaderAppearancePopover(
                            readerPreferences: readerPreferences,
                            theme: theme,
                            onSelectAppearanceMode: onSelectAppearanceMode,
                            onDismiss: onDismissAppearancePopover
                        )
                        .accessibilityIdentifier("bookReader.appearancePopover")
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .buttonStyle(.plain)
                .foregroundStyle(toolbarForegroundColor)
                .background(
                    Capsule()
                        .fill(.clear)
                        .glassEffect()
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if let progressDisplayText {
                Button(action: onCycleProgressDisplayMode) {
                    Text(progressDisplayText)
                        .font(.caption)
                        .foregroundStyle(toolbarSecondaryColor.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .accessibilityLabel("Reading progress")
                .accessibilityValue(progressDisplayText)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
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

// MARK: - Margin Swipe Overlay

private struct MarginSwipeOverlay: View {
    let marginWidth: Double
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: marginWidth)
                .contentShape(Rectangle())
                .gesture(swipeGesture)

            Spacer()

            Color.clear
                .frame(width: marginWidth)
                .contentShape(Rectangle())
                .gesture(swipeGesture)
        }
        .allowsHitTesting(true)
        .accessibilityHidden(true)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)

                // Only trigger if horizontal movement is dominant
                guard abs(horizontalDistance) > verticalDistance else { return }

                if horizontalDistance < 0 {
                    onSwipeLeft()
                } else {
                    onSwipeRight()
                }
            }
    }
}

// MARK: - Dictionary Gesture Overlay

/// Overlay that captures all gestures when dictionary mode is active.
/// Taps trigger dictionary lookup, drags flip pages.
private struct DictionaryGestureOverlay: View {
    let marginWidth: Double
    let onTap: (CGPoint) -> Void
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let horizontalDistance = value.translation.width
                        let verticalDistance = abs(value.translation.height)

                        guard abs(horizontalDistance) > verticalDistance else { return }

                        if horizontalDistance < 0 {
                            onSwipeLeft()
                        } else {
                            onSwipeRight()
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                    .onEnded { value in
                        if case let .second(_, drag) = value, let location = drag?.location {
                            onTap(location)
                        }
                    }
            )
            .accessibilityHidden(true)
    }
}
