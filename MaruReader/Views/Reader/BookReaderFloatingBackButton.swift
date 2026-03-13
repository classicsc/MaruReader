// BookReaderFloatingBackButton.swift
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

struct BookReaderFloatingBackButton: View {
    let iconSize: CGFloat
    let frameSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Back", systemImage: "xmark")
                .font(.system(size: iconSize, weight: .semibold))
                .labelStyle(.iconOnly)
                .frame(width: frameSize, height: frameSize)
        }
        .contentShape(.circle)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityIdentifier("bookReader.back")
    }
}
