// BookReaderNavigatorOverlaySurface.swift
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
import WebKit

struct BookReaderNavigatorOverlaySurface: View {
    let isDictionaryActive: Bool
    let marginWidth: Double
    @Binding var showingPopup: Bool
    let popupAnchorPosition: CGRect
    let popupPage: WebPage
    let popupBackgroundColor: SwiftUI.Color
    let onTap: (CGPoint) -> Void
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    var body: some View {
        Group {
            if isDictionaryActive {
                BookReaderDictionaryGestureOverlay(
                    marginWidth: marginWidth,
                    onTap: onTap,
                    onSwipeLeft: onSwipeLeft,
                    onSwipeRight: onSwipeRight
                )
            } else {
                BookReaderMarginSwipeOverlay(
                    marginWidth: marginWidth,
                    onSwipeLeft: onSwipeLeft,
                    onSwipeRight: onSwipeRight
                )
            }
        }
        .popover(
            isPresented: $showingPopup,
            attachmentAnchor: .rect(.rect(popupAnchorPosition))
        ) {
            WebView(popupPage)
                .background(popupBackgroundColor)
                .frame(minWidth: 250, idealWidth: 300, maxWidth: 300, minHeight: 150, idealHeight: 200, maxHeight: 200)
                .presentationCompactAdaptation(.popover)
                .accessibilityIdentifier("bookReader.dictionaryPopover")
        }
    }
}
