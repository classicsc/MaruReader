// BookmarkFaviconView.swift
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
import UIKit

struct BookmarkFaviconView: View {
    let data: Data?
    let fallbackSystemImage: String
    let size: CGFloat

    init(
        data: Data?,
        fallbackSystemImage: String = "globe",
        size: CGFloat
    ) {
        self.data = data
        self.fallbackSystemImage = fallbackSystemImage
        self.size = size
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.fill.tertiary)

            if let image = decodedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: size * 0.52, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var cornerRadius: CGFloat {
        max(4, size * 0.22)
    }

    private var decodedImage: UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
    }
}
