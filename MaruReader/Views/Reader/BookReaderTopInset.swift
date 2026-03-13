// BookReaderTopInset.swift
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

struct BookReaderTopInset: View {
    let showsToolbars: Bool
    let title: String
    let floatingButtonIconSize: CGFloat
    let floatingButtonFrameSize: CGFloat
    let primaryForegroundColor: SwiftUI.Color
    let secondaryForegroundColor: SwiftUI.Color
    let onDismiss: () -> Void
    let onToggleOverlay: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                Color.clear
                    .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
                Spacer()
                Text(title)
                    .font(.headline)
                    .hidden()
                Spacer()
                Color.clear
                    .frame(width: floatingButtonFrameSize, height: floatingButtonFrameSize)
            }
            .padding(.horizontal)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .hidden()

            HStack {
                if showsToolbars {
                    BookReaderFloatingBackButton(
                        iconSize: floatingButtonIconSize,
                        frameSize: floatingButtonFrameSize,
                        action: onDismiss
                    )
                    .tourAnchor(BookReaderTourAnchor.backButton)
                } else {
                    BookReaderFloatingBackButton(
                        iconSize: floatingButtonIconSize,
                        frameSize: floatingButtonFrameSize,
                        action: onDismiss
                    )
                    .hidden()
                }
                Spacer()
                Button(action: onToggleOverlay) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(primaryForegroundColor)
                            .lineLimit(1)
                        Image(systemName: showsToolbars ? "chevron.up" : "chevron.down")
                            .font(.headline)
                            .foregroundStyle(showsToolbars ? secondaryForegroundColor : secondaryForegroundColor.opacity(0.6))
                    }
                }
                .tourAnchor(BookReaderTourAnchor.titleToggle)
                Spacer()
                Spacer().frame(width: floatingButtonFrameSize)
            }
            .padding(.horizontal)
        }
    }
}
