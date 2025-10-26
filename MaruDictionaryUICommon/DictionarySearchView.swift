//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import os.log
import SwiftUI
import WebKit

public struct DictionarySearchView: View {
    @Environment(DictionarySearchViewModel.self) private var viewModel

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchView")

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    switch viewModel.resultState {
                    case .ready:
                        WebView(viewModel.page)
                        // Popup overlay
                        if viewModel.showPopup {
                            if let center = DictionaryPopupView.computePopupCenter(
                                screenSize: geometry.size,
                                popupSize: CGSize(width: 200, height: 200),
                                highlightBoundingRects: viewModel.highlightBoundingRects,
                                readingProgression: .ltr,
                                isVerticalWriting: false
                            ) {
                                DictionaryPopupView(page: viewModel.popupPage)
                                    .frame(width: 200, height: 200)
                                    .position(x: center.x, y: center.y)
                            }
                        }
                    case let .noResults(query):
                        ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("No results found for \"\(query)\""))
                    case .startPage:
                        ContentUnavailableView("Start a Search", systemImage: "book", description: Text("Enter text to search the dictionary."))
                    case let .error(error):
                        ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription))
                    case .searching:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                    }
                }
            }
        }
    }
}

#Preview {
    DictionarySearchView()
}
