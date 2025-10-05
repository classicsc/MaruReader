//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import os.log
import SwiftUI
import WebKit

struct DictionarySearchView: View {
    @StateObject private var viewModel = DictionarySearchViewModel()
    @FocusState private var isTextFieldFocused: Bool
    @State private var query: String = ""

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchView")

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search dictionary", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top)
                    .focused($isTextFieldFocused)
                    .onChange(of: query) { _, newValue in
                        viewModel.performSearch(newValue)
                    }
                    .onChange(of: isTextFieldFocused) { _, isFocused in
                        if isFocused {
                            viewModel.textFieldFocused()
                        } else {
                            viewModel.textFieldUnfocused()
                        }
                    }
                    .onSubmit {
                        viewModel.performSearch(query)
                    }

                ZStack(alignment: .topLeading) {
                    switch viewModel.resultState {
                    case .ready:
                        WebView(viewModel.page)
                        // Popup overlay
                        if viewModel.showPopup {
                            DictionaryPopupView(viewModel: viewModel)
                                .frame(width: 300, height: 400)
                                .padding()
                        }
                    case .noResults:
                        ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("No results found for \"\(query)\""))
                    case .startPage:
                        ContentUnavailableView("Start a Search", systemImage: "book", description: Text("Enter a term above to search the dictionary."))
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
            .padding(.horizontal)
            .navigationTitle("Dictionary")
        }
    }
}

#Preview {
    DictionarySearchView()
}
