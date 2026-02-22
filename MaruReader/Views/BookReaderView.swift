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

import Foundation
import MaruDictionaryUICommon
import MaruReaderCore
import ReadiumNavigator
import SwiftUI
import WebKit

// MARK: - BookReaderView

struct BookReaderView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var errorIconSize: CGFloat = 48

    @State private var viewModel: BookReaderViewModel
    @State private var searchSheetViewModel: DictionarySearchViewModel?
    @State private var progressDisplayMode: ProgressDisplayMode = .book
    @State private var tourManager = TourManager()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    init(book: Book) {
        _viewModel = State(wrappedValue: BookReaderViewModel(book: book))
    }

    private var showingTableOfContents: Binding<Bool> {
        Binding(
            get: { viewModel.overlayState == .showingTableOfContents },
            set: { newValue in
                if newValue {
                    viewModel.overlayState = .showingTableOfContents
                } else if viewModel.overlayState == .showingTableOfContents {
                    viewModel.overlayState = .showingToolbars
                }
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
                .sheet(isPresented: $viewModel.showingDictionarySheet) {
                    NavigationStack {
                        if let sheetViewModel = searchSheetViewModel {
                            DictionarySearchView()
                                .environment(sheetViewModel)
                                .environment(\.dictionaryPresentationTheme, readerDictionaryPresentationTheme)
                                .navigationTitle("Dictionary")
                                .navigationBarTitleDisplayMode(.inline)
                                .navigationBarBackButtonHidden(true)
                                .toolbar {
                                    ToolbarItem(placement: .cancellationAction) {
                                        Button("Done") {
                                            viewModel.showingDictionarySheet = false
                                        }
                                    }
                                }
                        }
                    }
                    .background(dictionarySheetBackgroundColor)
                    .preferredColorScheme(readerDictionaryPresentationTheme.preferredColorScheme)
                    .onAppear {
                        // Initialize the view model with the lookup session
                        if let session = viewModel.sheetLookupSession {
                            searchSheetViewModel = DictionarySearchViewModel(
                                session: session,
                                dictionaryWebTheme: readerDictionaryPresentationTheme.dictionaryWebTheme
                            )
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: showingTableOfContents) {
                    if let publication = viewModel.publication {
                        TableOfContentsView(
                            publication: publication,
                            bookTitle: viewModel.book.title,
                            bookAuthor: viewModel.book.author,
                            coverImage: viewModel.coverImage,
                            currentLocator: viewModel.currentLocator,
                            bookmarks: viewModel.bookmarks,
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
                            onDismiss: {
                                viewModel.overlayState = .showingToolbars
                            }
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
                    if tourManager.startIfNeeded(BookReaderTour.self) {
                        viewModel.overlayState = .showingToolbars
                    }
                }
        }
    }

    private var readerView: some View {
        GeometryReader { _ in
            ZStack(alignment: .topLeading) {
                readerBackgroundColor
                EPUBNavigatorWrapper(
                    viewModel: viewModel,
                    colorScheme: colorScheme
                )
                .padding(.horizontal, viewModel.readerPreferences.horizontalMargin)
                .overlay {
                    if viewModel.isDictionaryActive {
                        DictionaryGestureOverlay(
                            marginWidth: viewModel.readerPreferences.horizontalMargin,
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
                    } else {
                        MarginSwipeOverlay(
                            marginWidth: viewModel.readerPreferences.horizontalMargin,
                            onSwipeLeft: {
                                Task { await viewModel.navigator?.goRight(options: .init()) }
                            },
                            onSwipeRight: {
                                Task { await viewModel.navigator?.goLeft(options: .init()) }
                            }
                        )
                    }
                }
                .popover(
                    isPresented: $viewModel.showPopup,
                    attachmentAnchor: .rect(.rect(viewModel.popupAnchorPosition))
                ) {
                    WebView(viewModel.popupPage)
                        .background(dictionarySheetBackgroundColor)
                        .preferredColorScheme(readerDictionaryPresentationTheme.preferredColorScheme)
                        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400, minHeight: 150, idealHeight: 200, maxHeight: 300)
                        .presentationCompactAdaptation(.popover)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ZStack(alignment: .bottom) {
                    // Invisible spacer to reserve consistent height
                    bottomToolbarOverlay.hidden()

                    if viewModel.overlayState.shouldShowToolbars {
                        bottomToolbarOverlay
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        progressDisplayOverlay
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .safeAreaInset(edge: .top) {
                topToolbarOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(readerBackgroundColor.ignoresSafeArea())
    }

    private var topToolbarOverlay: some View {
        HStack {
            if viewModel.overlayState.shouldShowToolbars {
                floatingBackButton
                    .tourAnchor(BookReaderTourAnchor.backButton)
            } else {
                floatingBackButton.hidden()
            }
            Spacer()
            Button { viewModel.toggleOverlay() } label: {
                HStack {
                    Text(viewModel.book.title ?? "Book Reader")
                        .font(.headline)
                        .foregroundColor(toolbarForegroundColor(isPrimary: viewModel.overlayState.shouldShowToolbars))
                        .lineLimit(1)
                    Image(systemName: viewModel.overlayState.shouldShowToolbars ? "chevron.up" : "chevron.down")
                        .font(.headline)
                        .foregroundColor(viewModel.overlayState.shouldShowToolbars ? toolbarSecondaryColor : toolbarSecondaryColor.opacity(0.6))
                }
            }
            .tourAnchor(BookReaderTourAnchor.titleToggle)
            Spacer()
            Spacer().frame(width: floatingButtonFrameSize)
        }
        .padding(.horizontal)
    }

    private var bottomToolbarOverlay: some View {
        HStack(spacing: 32) {
            Button {
                viewModel.overlayState = .showingTableOfContents
            } label: {
                Image(systemName: "list.bullet")
            }
            .accessibilityLabel("Table of contents")
            .tourAnchor(BookReaderTourAnchor.tableOfContents)

            Button {
                viewModel.isDictionaryActive.toggle()
            } label: {
                Image(systemName: viewModel.isDictionaryActive ? "character.book.closed.fill.ja" : "character.book.closed.ja")
            }
            .accessibilityLabel(viewModel.isDictionaryActive ? "Disable dictionary mode" : "Enable dictionary mode")
            .tourAnchor(BookReaderTourAnchor.dictionaryMode)

            bookmarkButton
                .tourAnchor(BookReaderTourAnchor.bookmark)

            appearanceMenuButton
                .tourAnchor(BookReaderTourAnchor.appearanceMenu)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .buttonStyle(.plain)
        .foregroundStyle(toolbarForegroundColor(isPrimary: true))
        .background(
            Capsule()
                .fill(.clear)
                .glassEffect()
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 20)
    }

    private var progressDisplayOverlay: some View {
        let availableModes = availableProgressDisplayModes
        return Group {
            if let text = progressDisplayText {
                Button {
                    cycleProgressDisplayMode(availableModes: availableModes)
                } label: {
                    Text(text)
                        .font(.caption)
                        .foregroundColor(toolbarSecondaryColor.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
                .accessibilityLabel("Reading progress")
                .accessibilityValue(text)
                .onChange(of: availableModes) {
                    syncProgressDisplayMode(with: availableModes)
                }
            }
        }
    }

    private var appearanceMenuButton: some View {
        Menu {
            Section("Text Size") {
                Button {
                    viewModel.readerPreferences.decreaseFontSize()
                } label: {
                    Label("Smaller", systemImage: "textformat.size.smaller")
                }

                Button {
                    viewModel.readerPreferences.increaseFontSize()
                } label: {
                    Label("Larger", systemImage: "textformat.size.larger")
                }
            }

            Section("Font") {
                ForEach(ReaderFontFamilyOption.allCases, id: \.self) { option in
                    appearanceMenuSelectionButton(
                        title: option.displayName,
                        isSelected: viewModel.readerPreferences.selectedFontFamilyOption == option
                    ) {
                        viewModel.readerPreferences.setFontFamilyOption(option)
                    }
                }
            }

            Section("Appearance") {
                ForEach(ReaderAppearanceMode.allCases, id: \.self) { mode in
                    appearanceMenuSelectionButton(
                        title: mode.displayName,
                        isSelected: viewModel.readerPreferences.selectedAppearanceMode == mode
                    ) {
                        viewModel.readerPreferences.setAppearanceMode(mode)
                        applyReaderDictionaryTheme()
                    }
                }
            }
        } label: {
            Image(systemName: "textformat")
                .accessibilityLabel("Appearance and text")
        }
        .accessibilityLabel("Appearance and text")
    }

    private var floatingBackButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: floatingButtonIconSize, weight: .semibold))
                .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel("Back")
    }

    @ViewBuilder
    private var bookmarkButton: some View {
        let isCurrentLocationBookmarked = viewModel.currentLocationBookmark != nil
        Menu {
            if isCurrentLocationBookmarked {
                Button(role: .destructive) {
                    viewModel.removeBookmarkAtCurrentLocation()
                } label: {
                    Label("Remove Bookmark", systemImage: "bookmark.slash")
                }
            } else {
                Button {
                    viewModel.bookmarkCurrentLocation()
                } label: {
                    Label("Add Bookmark", systemImage: "bookmark.fill")
                }
            }

            if !viewModel.bookmarks.isEmpty {
                Section("Bookmarks") {
                    ForEach(viewModel.bookmarks, id: \.id) { bookmark in
                        Button {
                            viewModel.navigateToBookmark(bookmark)
                        } label: {
                            Text(bookmark.title ?? "Bookmark")
                        }
                    }
                }
            }

            if viewModel.previousLocation != nil {
                Section {
                    Button {
                        viewModel.returnToPreviousLocation()
                    } label: {
                        Label("Return to Previous Location", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        } label: {
            Image(systemName: isCurrentLocationBookmarked ? "bookmark.fill" : "bookmark")
        }
        .accessibilityLabel("Bookmarks")
    }

    private func errorView(error: Error) -> some View {
        ZStack {
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
            floatingBackButton
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
                backgroundColor: interfaceBackground,
                foregroundColor: interfaceForeground
            )
        )
    }

    private func applyReaderDictionaryTheme() {
        let webTheme = readerDictionaryPresentationTheme.dictionaryWebTheme
        viewModel.setDictionaryWebTheme(webTheme)
        searchSheetViewModel?.setDictionaryWebTheme(webTheme)
    }

    private func makeDictionaryWebTheme(
        preferredColorScheme: ColorScheme?,
        backgroundColor: SwiftUI.Color,
        foregroundColor: SwiftUI.Color
    ) -> DictionaryWebTheme? {
        let backgroundHex = cssHex(for: backgroundColor)
        let foregroundHex = cssHex(for: foregroundColor)
        let accentHex = cssHex(for: .accentColor)

        guard backgroundHex != nil || foregroundHex != nil || accentHex != nil else {
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
            backgroundColor: backgroundHex,
            accentColor: accentHex,
            linkColor: accentHex,
            glossImageBackgroundColor: backgroundHex
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

    private func appearanceMenuSelectionButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
        }
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
            return "Book \(formatProgress(totalProgression))"
        case .chapter:
            guard let progression = locator.locations.progression else { return nil }
            return "Chapter \(formatProgress(progression))"
        case .position:
            guard let position = locator.locations.position else { return nil }
            return "Position \(position)"
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
        GeometryReader { _ in
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
        }
        .accessibilityHidden(true)
    }
}
