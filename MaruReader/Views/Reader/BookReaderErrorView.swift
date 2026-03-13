// BookReaderErrorView.swift
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

struct BookReaderErrorView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var errorIconSize: CGFloat = 48

    let error: Error
    let floatingButtonIconSize: CGFloat
    let floatingButtonFrameSize: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: errorIconSize))
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
            BookReaderFloatingBackButton(
                iconSize: floatingButtonIconSize,
                frameSize: floatingButtonFrameSize,
                action: onDismiss
            )
            .padding()
        }
    }
}
