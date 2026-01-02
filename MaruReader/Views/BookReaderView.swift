//
//  BookReaderView.swift
//  MaruReader
//
//  Ebook reading view with Readium Navigator integration.
//

import Foundation
import MaruDictionaryUICommon
import MaruReaderCore
import SwiftUI
import WebKit

// MARK: - BookReaderView

struct BookReaderView: View {
    @State private var viewModel: BookReaderViewModel
    @State private var searchSheetViewModel: DictionarySearchViewModel?
    @Environment(\.colorScheme) var colorScheme

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
                    .onAppear {
                        // Initialize the view model with the lookup response
                        if let response = viewModel.sheetLookupResponse {
                            searchSheetViewModel = DictionarySearchViewModel(response: response)
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: showingTableOfContents) {
                    if let publication = viewModel.publication {
                        TableOfContentsView(
                            publication: publication,
                            bookTitle: viewModel.book.title,
                            coverImage: viewModel.coverImage,
                            currentLocator: viewModel.currentLocator,
                            onNavigate: { link in
                                viewModel.navigateToLink(link)
                            },
                            onDismiss: {
                                viewModel.overlayState = .showingToolbars
                            }
                        )
                        .presentationDetents([.medium, .large])
                    }
                }
                .onChange(of: colorScheme) {
                    viewModel.readerPreferences.submitToNavigator()
                }
        }
    }

    private var readerView: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                EPUBNavigatorWrapper(
                    viewModel: viewModel
                )
                .padding(viewModel.readerPreferences.horizontalMargin)
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
                        .frame(minWidth: 250, idealWidth: 300, maxWidth: 400, minHeight: 150, idealHeight: 200, maxHeight: 300)
                        .presentationCompactAdaptation(.popover)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .tabBar)
                .toolbar(.hidden, for: .bottomBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Button {
                            viewModel.toggleOverlay()
                        } label: {
                            HStack {
                                Text(viewModel.book.title ?? "")
                                    .font(.headline)
                                    .foregroundStyle(toolbarForegroundColor(isPrimary: viewModel.overlayState.shouldShowToolbars))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                switch viewModel.overlayState.shouldShowToolbars {
                                case true:
                                    Image(systemName: "chevron.up")
                                        .font(.headline)
                                        .foregroundStyle(toolbarSecondaryColor)
                                case false:
                                    Image(systemName: "chevron.down")
                                        .font(.headline)
                                        .foregroundStyle(toolbarSecondaryColor.opacity(0.6))
                                }
                            }
                            .frame(maxWidth: geometry.size.width * 0.7)
                        }
                    }
                }
                .navigationBarBackButtonHidden(!viewModel.overlayState.shouldShowNavigationBackButton)
                .applyThemeColors(preferences: viewModel.readerPreferences)

                if viewModel.overlayState.shouldShowToolbars {
                    bottomToolbarOverlay
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    private var bottomToolbarOverlay: some View {
        HStack(spacing: 32) {
            Button {
                viewModel.overlayState = .showingTableOfContents
            } label: {
                Image(systemName: "list.bullet")
            }

            Button {
                viewModel.isDictionaryActive.toggle()
            } label: {
                Image(systemName: viewModel.isDictionaryActive ? "character.book.closed.fill" : "character.book.closed")
            }

            Button {
                viewModel.bookmarkCurrentLocation()
            } label: {
                Image(systemName: "bookmark")
            }

            QuickReaderSettingsMenu(preferences: viewModel.readerPreferences) {
                viewModel.overlayState = .showingQuickSettings
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .buttonStyle(.plain)
        .background(
            Capsule()
                .fill(viewModel.readerPreferences.currentInterfaceBackgroundColor ?? Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                .glassEffect()
        )
        .tint(viewModel.readerPreferences.currentInterfaceForegroundColor ?? .primary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 20)
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
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
    }

    // MARK: - Theme Color Helpers

    private func toolbarForegroundColor(isPrimary: Bool) -> Color {
        if let color = viewModel.readerPreferences.currentInterfaceForegroundColor {
            return isPrimary ? color : color.opacity(0.6)
        }
        return isPrimary ? .primary : .secondary
    }

    private var toolbarSecondaryColor: Color {
        viewModel.readerPreferences.currentInterfaceSecondaryColor ?? .secondary
    }
}

// MARK: - Theme Color View Modifier

private extension View {
    @ViewBuilder
    func applyThemeColors(preferences: ReaderPreferences) -> some View {
        self
            .toolbarBackground(preferences.currentInterfaceBackgroundColor ?? Color(uiColor: .systemBackground), for: .navigationBar)
            .tint(preferences.currentInterfaceForegroundColor ?? .primary)
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
    }
}
