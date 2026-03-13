// BookReaderGestureOverlays.swift
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

// MARK: - Margin Swipe Overlay

struct BookReaderMarginSwipeOverlay: View {
    let marginWidth: Double
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: marginWidth)
                .contentShape(Rectangle())
                .gesture(swipeGesture)

            Spacer()

            Color.clear
                .frame(width: marginWidth)
                .contentShape(Rectangle())
                .gesture(swipeGesture)
        }
        .allowsHitTesting(true)
        .accessibilityHidden(true)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = abs(value.translation.height)

                // Only trigger if horizontal movement is dominant
                guard abs(horizontalDistance) > verticalDistance else { return }

                if horizontalDistance < 0 {
                    onSwipeLeft()
                } else {
                    onSwipeRight()
                }
            }
    }
}

// MARK: - Dictionary Gesture Overlay

/// Overlay that captures all gestures when dictionary mode is active.
/// Taps trigger dictionary lookup, drags flip pages.
struct BookReaderDictionaryGestureOverlay: View {
    let marginWidth: Double
    let onTap: (CGPoint) -> Void
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let horizontalDistance = value.translation.width
                        let verticalDistance = abs(value.translation.height)

                        guard abs(horizontalDistance) > verticalDistance else { return }

                        if horizontalDistance < 0 {
                            onSwipeLeft()
                        } else {
                            onSwipeRight()
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture()
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                    .onEnded { value in
                        if case let .second(_, drag) = value, let location = drag?.location {
                            onTap(location)
                        }
                    }
            )
            .accessibilityHidden(true)
    }
}
