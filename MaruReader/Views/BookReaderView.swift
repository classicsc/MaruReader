//
//  BookReaderView.swift
//  MaruReader
//
//  Ebook reading view with Readium Navigator integration.
//

import CoreData
import Foundation
import ReadiumAdapterGCDWebServer
import ReadiumNavigator
@unsafe @preconcurrency import ReadiumShared
import ReadiumStreamer
import SwiftUI
import UIKit

// MARK: - Supporting Types

struct LoadedPublication {
    let publication: Publication
    let initialLocation: Locator?
}

enum BookReaderError: LocalizedError {
    case bookFileNotFound
    case cannotAccessAppSupport
    case invalidBookPath
    case unknownError

    var errorDescription: String? {
        switch self {
        case .bookFileNotFound:
            "Book file not found"
        case .cannotAccessAppSupport:
            "Cannot access application support directory"
        case .invalidBookPath:
            "Invalid book file path"
        case .unknownError:
            "An unknown error occurred"
        }
    }
}

// MARK: - BookReaderView

struct BookReaderView: View {
    @State private var viewModel: BookReaderViewModel

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
        }
    }

    private var readerView: some View {
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

                    Button {
                        viewModel.overlayState = .showingQuickSettings
                    } label: {
                        Image(systemName: "textformat.size.ja")
                    }
                }
            }
            .toolbarVisibility(viewModel.overlayState.shouldShowToolbars ? .visible : .hidden, for: .bottomBar)
            .navigationBarBackButtonHidden(viewModel.overlayState.shouldShowNavigationBackButton)
            if viewModel.showPopup {
                DictionaryPopupView(page: viewModel.popupPage)
                    .frame(width: 300, height: 400)
                    .padding()
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
