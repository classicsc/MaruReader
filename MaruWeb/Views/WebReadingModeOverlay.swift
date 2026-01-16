// WebReadingModeOverlay.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import SwiftUI

struct WebReadingModeOverlay: View {
    let isProcessing: Bool
    let pagingAxis: ReadingPagingAxis
    let pagingBehavior: ReadingPagingBehavior
    let onTap: (CGPoint, CGSize) -> Void
    let onPageAction: (_ axis: ReadingPagingAxis, _ behavior: ReadingPagingBehavior, _ direction: Int) -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(swipeGesture)
                    .simultaneousGesture(tapGesture(in: geometry.size))

                if isProcessing {
                    ProgressView("Scanning...")
                        .padding(12)
                        .background(.clear, in: Capsule())
                        .glassEffect()
                }
            }
        }
    }

    private func tapGesture(in size: CGSize) -> some Gesture {
        TapGesture()
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                if case let .second(_, drag) = value, let location = drag?.location {
                    onTap(location, size)
                }
            }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let horizontalDistance = value.translation.width
                let verticalDistance = value.translation.height

                switch pagingAxis {
                case .vertical:
                    if abs(verticalDistance) > abs(horizontalDistance) {
                        let direction = verticalDistance < 0 ? 1 : -1
                        onPageAction(pagingAxis, pagingBehavior, direction)
                    }
                case .horizontal:
                    if abs(horizontalDistance) > abs(verticalDistance) {
                        let direction = horizontalDistance < 0 ? 1 : -1
                        onPageAction(pagingAxis, pagingBehavior, direction)
                    }
                }
            }
    }
}
