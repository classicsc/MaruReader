// BookReaderContentView.swift
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
import ReadiumNavigator
import SwiftUI
import WebKit

struct BookReaderContentView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 44

    @Bindable var viewModel: BookReaderViewModel
    @State private var progressDisplayMode: ProgressDisplayMode = .book
    @State private var tourManager = TourManager()
    // This is treated as the current system scheme for Follow System mode.
    // Avoid using `.preferredColorScheme` in descendant overlays, which can contaminate this value.
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        readerContent
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
            .sheet(isPresented: $viewModel.isShowingTableOfContents) {
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

    private var readerContent: some View {
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
                viewModel: viewModel,
                progressDisplayText: progressDisplayText,
                toolbarForegroundColor: toolbarForegroundColor(isPrimary: true),
                toolbarSecondaryColor: toolbarSecondaryColor,
                theme: overlayTheme,
                onSelectAppearanceMode: { mode in
                    viewModel.readerPreferences.setAppearanceMode(mode)
                    applyReaderDictionaryTheme()
                },
                onCycleProgressDisplayMode: {
                    cycleProgressDisplayMode(availableModes: availableProgressDisplayModes)
                }
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
        let interfaceBackground = viewModel.readerPreferences.currentInterfaceBackgroundColor
        let interfaceForeground = viewModel.readerPreferences.currentInterfaceForegroundColor
        let secondary = viewModel.readerPreferences.currentInterfaceSecondaryColor
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

    func toolbarForegroundColor(isPrimary: Bool) -> SwiftUI.Color {
        let color = viewModel.readerPreferences.currentInterfaceForegroundColor
        return isPrimary ? color : color.opacity(0.6)
    }

    private var toolbarSecondaryColor: SwiftUI.Color {
        viewModel.readerPreferences.currentInterfaceSecondaryColor
    }

    // MARK: - Progress Display

    enum ProgressDisplayMode: CaseIterable {
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
}
