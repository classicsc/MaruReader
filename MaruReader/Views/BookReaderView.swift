//
//  BookReaderView.swift
//  MaruReader
//
//  Ebook reading view with Readium Navigator integration.
//

import Foundation
import SwiftUI

// MARK: - BookReaderView

struct BookReaderView: View {
    @State private var viewModel: BookReaderViewModel
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
                        DictionarySearchView(initialQuery: viewModel.sheetQueryTerm)
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
                    .presentationDetents([.medium, .large])
                }
                .sheet(isPresented: Binding(
                    get: { viewModel.overlayState == .showingSettingsEditorSheet },
                    set: { if !$0 { viewModel.overlayState = .none } }
                )) {
                    ReaderSettingsEditorView(preferences: viewModel.readerPreferences)
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
                                    .foregroundStyle(.primary)

                                switch viewModel.overlayState.shouldShowToolbars {
                                case true:
                                    Image(systemName: "chevron.up")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                case false:
                                    Image(systemName: "chevron.down")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
                            viewModel.overlayState = .showingSettingsEditorSheet
                        }
                    }
                }
                .toolbarVisibility(viewModel.overlayState.shouldShowToolbars ? .visible : .hidden, for: .bottomBar)
                .navigationBarBackButtonHidden(!viewModel.overlayState.shouldShowNavigationBackButton)
                if viewModel.showPopup {
                    if let center = DictionaryPopupView.computePopupCenter(
                        screenSize: geometry.size,
                        popupSize: CGSize(width: 200, height: 200),
                        highlightBoundingRects: viewModel.highlightBoundingRects,
                        readingProgression: viewModel.readingProgression(),
                        isVerticalWriting: viewModel.isVerticalWriting()
                    ) {
                        DictionaryPopupView(page: viewModel.popupPage)
                            .frame(width: 200, height: 200)
                            .position(x: center.x, y: center.y)
                    }
                }
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
}
