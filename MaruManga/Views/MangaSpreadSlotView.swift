// MangaSpreadSlotView.swift
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

struct MangaSpreadSlotView: View {
    let pageIndex: Int
    @Bindable var viewModel: MangaReaderViewModel
    let containerSize: CGSize
    let horizontalPlacement: MangaPageHorizontalPlacement

    var body: some View {
        MangaPageContentView(
            pageIndex: pageIndex,
            viewModel: viewModel,
            containerSize: containerSize,
            horizontalPlacement: horizontalPlacement
        )
        .frame(width: containerSize.width, height: containerSize.height)
    }
}
