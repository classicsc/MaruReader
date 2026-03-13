// BookReaderView.swift
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

import SwiftUI

struct BookReaderView: View {
    @ScaledMetric(relativeTo: .body) private var floatingButtonIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var floatingButtonFrameSize: CGFloat = 44

    @State private var viewModel: BookReaderViewModel
    @Environment(\.dismiss) private var dismiss

    init(book: Book) {
        _viewModel = State(wrappedValue: BookReaderViewModel(book: book))
    }

    var body: some View {
        switch viewModel.readerState {
        case .loading:
            ProgressView("Loading book...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .error(error):
            BookReaderErrorView(
                error: error,
                floatingButtonIconSize: floatingButtonIconSize,
                floatingButtonFrameSize: floatingButtonFrameSize,
                onDismiss: { dismiss() }
            )
        case .reading:
            BookReaderContentView(viewModel: viewModel)
        }
    }
}
