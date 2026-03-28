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

struct BookReaderContentView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 44

    @Bindable var session: BookReaderSessionModel
    @Bindable var chrome: BookReaderChromeModel
    @Bindable var bookmarks: BookReaderBookmarksModel
    @Bindable var lookup: BookReaderLookupModel
    @Bindable var readerPreferences: ReaderPreferences
    let onDismiss: () -> Void

    @State private var tourManager = TourManager()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dictionaryFeatureAvailability) private var dictionaryAvailability

    var body: some View {
        readerContent
            .onChange(of: availableProgressDisplayModes) {
                chrome.syncProgressDisplayMode(for: session.currentLocator)
            }
            .sheet(item: $lookup.dictionarySheetPresentation, onDismiss: {
                lookup.dismissDictionarySheet()
            }) { presentation in
                NavigationStack {
                    Group {
                        switch dictionaryAvailability {
                        case .ready:
                            DictionarySearchView()
                                .environment(presentation.viewModel)
                                .environment(\.dictionaryPresentationTheme, readerDictionaryPresentationTheme)
                        case let .preparing(description):
                            ProgressView(description)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case let .failed(message):
                            ContentUnavailableView(
                                "Dictionary Unavailable",
                                systemImage: "character.book.closed.ja",
                                description: Text(message)
                            )
                        @unknown default:
                            DictionarySearchView()
                                .environment(presentation.viewModel)
                                .environment(\.dictionaryPresentationTheme, readerDictionaryPresentationTheme)
                        }
                    }
                    .navigationTitle("Dictionary")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                lookup.dismissDictionarySheet()
                            }
                            .foregroundStyle(readerDictionaryPresentationTheme.foregroundColor)
                        }
                    }
                }
                .onChange(of: dictionaryAvailability) { _, newValue in
                    if case .ready = newValue {
                        lookup.replayPendingSheetSearch()
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
            .sheet(isPresented: $chrome.isShowingTableOfContents) {
                if let publication = session.publication {
                    let tableOfContentsTheme = readerTableOfContentsTheme
                    TableOfContentsView(
                        publication: publication,
                        bookTitle: session.bookSnapshot.title,
                        bookAuthor: session.bookSnapshot.author,
                        coverImage: session.coverImage,
                        currentLocator: session.currentLocator,
                        bookmarkRows: bookmarks.bookmarkRows,
                        onNavigate: { link in
                            session.navigateToLink(link) {
                                chrome.route = .none
                            }
                        },
                        onNavigateToPosition: { position in
                            session.navigateToPosition(position) {
                                chrome.route = .none
                            }
                        },
                        onNavigateToBookmark: { bookmark in
                            bookmarks.navigateToBookmark(bookmark) {
                                chrome.route = .none
                            }
                        },
                        onDeleteBookmark: { bookmark in
                            bookmarks.deleteBookmark(bookmark)
                        },
                        onUpdateBookmarkTitle: { bookmark, title in
                            bookmarks.updateBookmarkTitle(bookmark, title: title)
                        },
                        theme: tableOfContentsTheme,
                        onDismiss: {
                            chrome.route = .showingToolbars
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
                readerPreferences.systemColorScheme = colorScheme
                readerPreferences.submitToNavigator()
                applyReaderDictionaryTheme()
            }
            .onChange(of: readerPreferences.selectedAppearanceMode) {
                applyReaderDictionaryTheme()
            }
            .tourOverlay(manager: tourManager)
            .onAppear {
                readerPreferences.systemColorScheme = colorScheme
                applyReaderDictionaryTheme()
                lookup.isDictionaryReady = dictionaryAvailability == .ready
                if MaruReaderApp.isScreenshotMode {
                    chrome.isDictionaryActive = true
                } else if tourManager.startIfNeeded(BookReaderTour.self) {
                    chrome.route = .showingToolbars
                }
            }
            .onChange(of: dictionaryAvailability) { _, newValue in
                lookup.isDictionaryReady = newValue == .ready
            }
            .task {
                guard MaruReaderApp.isScreenshotMode else { return }

                // Wait for the navigator's first locationDidChange, which fires
                // after the spread loads and content is rendered (up to ~30s).
                for _ in 0 ..< 60 {
                    if session.hasReceivedLocationUpdate { break }
                    try? await Task.sleep(for: .milliseconds(500))
                }
                guard session.hasReceivedLocationUpdate else { return }

                // Turn the page only if the target text isn't already visible.
                // On larger screens (iPad) the text is on the initial page;
                // on smaller screens (iPhone) we need to advance one page.
                if await !lookup.isScreenshotTextVisible() {
                    // Another wait is needed on a fresh sim due to webkit
                    // startup slowness on debug
                    try? await Task.sleep(for: .seconds(5))
                    session.goLeft()
                }

                lookup.triggerScreenshotTextLookup()
            }
    }

    private var readerContent: some View {
        let overlayTheme = readerDictionaryPresentationTheme

        return ZStack(alignment: .topLeading) {
            readerBackgroundColor
            EPUBNavigatorWrapper(
                session: session,
                lookup: lookup,
                readerPreferences: readerPreferences,
                colorScheme: colorScheme
            )
            .padding(.horizontal, readerPreferences.horizontalMargin)
            .overlay {
                BookReaderNavigatorOverlaySurface(
                    isDictionaryActive: chrome.isDictionaryActive,
                    marginWidth: readerPreferences.horizontalMargin,
                    showingPopup: $lookup.showPopup,
                    popupAnchorPosition: lookup.popupAnchorPosition,
                    popupPage: lookup.popupPage,
                    popupBackgroundColor: dictionarySheetBackgroundColor,
                    onTap: { globalPoint in
                        lookup.triggerTextScan(atGlobalPoint: globalPoint)
                    },
                    onSwipeLeft: {
                        session.goRight()
                    },
                    onSwipeRight: {
                        session.goLeft()
                    }
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            BookReaderBottomInset(
                chrome: chrome,
                bookmarks: bookmarks,
                readerPreferences: readerPreferences,
                progressDisplayText: chrome.progressDisplayText(for: session.currentLocator),
                toolbarForegroundColor: toolbarForegroundColor(isPrimary: true),
                toolbarSecondaryColor: toolbarSecondaryColor,
                theme: overlayTheme,
                onSelectAppearanceMode: { mode in
                    readerPreferences.setAppearanceMode(mode)
                    applyReaderDictionaryTheme()
                },
                onCycleProgressDisplayMode: {
                    chrome.cycleProgressDisplayMode(for: session.currentLocator)
                }
            )
            .applyLocalColorScheme(readerOverlayForcedColorScheme)
        }
        .safeAreaInset(edge: .top) {
            BookReaderTopInset(
                showsToolbars: chrome.showsToolbars,
                title: session.bookSnapshot.title ?? "Book Reader",
                floatingButtonIconSize: floatingButtonIconSize,
                floatingButtonFrameSize: floatingButtonFrameSize,
                primaryForegroundColor: toolbarForegroundColor(isPrimary: chrome.showsToolbars),
                secondaryForegroundColor: toolbarSecondaryColor,
                onDismiss: onDismiss,
                onToggleOverlay: { chrome.toggleOverlay() }
            )
        }
        .background(readerBackgroundColor.ignoresSafeArea())
    }

    private var availableProgressDisplayModes: [BookReaderProgressDisplayMode] {
        chrome.availableProgressDisplayModes(for: session.currentLocator)
    }

    private var readerBackgroundColor: SwiftUI.Color {
        readerPreferences.currentPageBackgroundColor
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
        switch readerPreferences.selectedAppearanceMode {
        case .dark:
            .dark
        case .light, .sepia:
            .light
        case .followSystem:
            nil
        }
    }

    private var readerDictionaryPresentationTheme: DictionaryPresentationTheme {
        let interfaceBackground = readerPreferences.currentInterfaceBackgroundColor
        let interfaceForeground = readerPreferences.currentInterfaceForegroundColor
        let secondary = readerPreferences.currentInterfaceSecondaryColor
        let separator = secondary.opacity(0.35)

        let preferredColorScheme: ColorScheme? = switch readerPreferences.selectedAppearanceMode {
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
        lookup.setDictionaryWebTheme(webTheme)
    }

    private func makeDictionaryWebTheme(
        preferredColorScheme: ColorScheme?,
        interfaceBackgroundColor: SwiftUI.Color,
        foregroundColor: SwiftUI.Color
    ) -> DictionaryWebTheme? {
        let interfaceBackgroundHex = cssHex(for: interfaceBackgroundColor)
        let pageBackgroundHex = cssHex(for: readerPreferences.currentPageBackgroundColor)
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
        let color = readerPreferences.currentInterfaceForegroundColor
        return isPrimary ? color : color.opacity(0.6)
    }

    private var toolbarSecondaryColor: SwiftUI.Color {
        readerPreferences.currentInterfaceSecondaryColor
    }
}
