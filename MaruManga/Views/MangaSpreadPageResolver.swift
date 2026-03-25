// MangaSpreadPageResolver.swift
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

import CoreGraphics

enum MangaSpreadPageResolver {
    static func resolvePageTap(
        spreadItem: SpreadLayout.SpreadItem,
        untransformedPoint: CGPoint,
        containerSize: CGSize
    ) -> (
        pageIndex: Int?,
        pageContainerSize: CGSize,
        pageLocalPoint: CGPoint,
        pagePlacement: MangaPageHorizontalPlacement
    ) {
        switch spreadItem {
        case let .single(pageIndex):
            return (pageIndex, containerSize, untransformedPoint, .centered)

        case let .double(leftPageIndex, rightPageIndex):
            let halfWidth = containerSize.width / 2
            let pageContainerSize = CGSize(width: halfWidth, height: containerSize.height)

            if untransformedPoint.x < halfWidth {
                return (
                    leftPageIndex,
                    pageContainerSize,
                    untransformedPoint,
                    .trailing
                )
            }

            let adjustedPoint = CGPoint(
                x: untransformedPoint.x - halfWidth,
                y: untransformedPoint.y
            )
            return (
                rightPageIndex,
                pageContainerSize,
                adjustedPoint,
                .leading
            )
        }
    }
}
