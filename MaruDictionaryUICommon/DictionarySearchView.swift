//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import MaruReaderCore
import os.log
import SwiftUI
import WebKit

public struct DictionarySearchView: View {
    @Environment(DictionarySearchViewModel.self) private var viewModel

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchView")

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Context display (if available)
            if let request = viewModel.currentRequest {
                ContextDisplayView(
                    context: request.context,
                    matchRange: viewModel.currentResponse?.primaryResultSourceRange,
                    onCharacterTap: { offset in
                        viewModel.performSearchAtOffset(offset)
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Main results area
            GeometryReader { _ in
                ZStack(alignment: .topLeading) {
                    switch viewModel.resultState {
                    case .ready:
                        WebView(viewModel.page)
                            // Popup overlay
                            .popover(
                                isPresented: Binding(get: { viewModel.showPopup }, set: { viewModel.showPopup = $0 }),
                                attachmentAnchor: .rect(.rect(viewModel.popupAnchorPosition))
                            ) {
                                WebView(viewModel.popupPage)
                                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 400, minHeight: 150, idealHeight: 200, maxHeight: 300)
                                    .presentationCompactAdaptation(.popover)
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

            // Navigation toolbar (only visible when navigation is possible)
            if viewModel.history.canGoBack || viewModel.history.canGoForward {
                HStack(spacing: 16) {
                    Button(action: { viewModel.navigateBack() }) {
                        Label("Back", systemImage: "chevron.backward")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(!viewModel.history.canGoBack)

                    Button(action: { viewModel.navigateForward() }) {
                        Label("Forward", systemImage: "chevron.forward")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(!viewModel.history.canGoForward)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    DictionarySearchView()
}
