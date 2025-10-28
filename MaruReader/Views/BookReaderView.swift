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
    @State private var searchSheetViewModel = DictionarySearchViewModel(resultState: .searching)
    @Environment(\.colorScheme) var colorScheme

    init(book: Book) {
        _viewModel = State(wrappedValue: BookReaderViewModel(book: book))
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
                        DictionarySearchView()
                            .environment(searchSheetViewModel)
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
                    .onAppear {
                        searchSheetViewModel.performSearch(viewModel.sheetQueryTerm)
                    }
                    .presentationDetents([.medium, .large])
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
                .ignoresSafeArea()
                .popover(
                    isPresented: $viewModel.showPopup,
                    attachmentAnchor: .point(.zero)
                ) {
                    WebView(viewModel.popupPage)
                        .frame(width: 200, height: 200)
                        .presentationCompactAdaptation(.popover)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .tabBar)
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

                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            viewModel.overlayState = .showingTableOfContents
                        } label: {
                            Image(systemName: "list.bullet")
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
                }
                .toolbarVisibility(viewModel.overlayState.shouldShowToolbars ? .visible : .hidden, for: .bottomBar)
                .navigationBarBackButtonHidden(!viewModel.overlayState.shouldShowNavigationBackButton)
                .applyThemeColors(preferences: viewModel.readerPreferences)
            }
        }
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
            .toolbarBackground(preferences.currentInterfaceBackgroundColor ?? Color(uiColor: .systemBackground), for: .bottomBar)
            .tint(preferences.currentInterfaceForegroundColor ?? .primary)
    }
}
