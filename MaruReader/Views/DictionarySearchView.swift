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
