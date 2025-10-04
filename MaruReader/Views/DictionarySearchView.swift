//  DictionarySearchView.swift
//  MaruReader
//
//  Dictionary search view with integrated HTML rendering.
//
import os.log
import SwiftUI
import WebKit

struct HighlightRect: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
    let left: Int
    let top: Int
    let right: Int
    let bottom: Int
}

struct DictionarySearchView: View {
    @StateObject private var viewModel = DictionarySearchViewModel()
    @State private var highlightRects: [HighlightRect] = []
    @FocusState private var isTextFieldFocused: Bool

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "DictionarySearchView")

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search dictionary", text: $viewModel.query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top)
                    .focused($isTextFieldFocused)
                    .onChange(of: viewModel.query) { _, newValue in
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
                        viewModel.performSearch(viewModel.query)
                    }

                ZStack(alignment: .topLeading) {
                    WebView(viewModel.page)
                        .task {
                            viewModel.initializeWebPage()
                        }
                        .animation(.default, value: viewModel.query)
                        .animation(.default, value: viewModel.isUpdatingFromNavigation)

                    // Popup overlay
                    if viewModel.showPopup {
                        DictionaryPopupView(viewModel: viewModel)
                            .frame(width: 300, height: 400)
                            .padding()
                    }

                    if viewModel.page.isLoading {
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
