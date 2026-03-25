// MangaPageContentViewTests.swift
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

@testable import MaruManga
import Testing
import UIKit

struct MangaPageContentViewTests {
    @Test func calculateImageRect_CenteredPlacementCentersTallPage() {
        let imageRect = MangaPageContentView.calculateImageRect(
            image: makeImage(size: CGSize(width: 50, height: 100)),
            in: CGSize(width: 200, height: 100),
            horizontalPlacement: .centered
        )

        #expect(imageRect == CGRect(x: 75, y: 0, width: 50, height: 100))
    }

    @Test func calculateImageRect_LeadingPlacementPinsTallPageToLeadingEdge() {
        let imageRect = MangaPageContentView.calculateImageRect(
            image: makeImage(size: CGSize(width: 50, height: 100)),
            in: CGSize(width: 200, height: 100),
            horizontalPlacement: .leading
        )

        #expect(imageRect == CGRect(x: 0, y: 0, width: 50, height: 100))
    }

    @Test func calculateImageRect_TrailingPlacementPinsTallPageToTrailingEdge() {
        let imageRect = MangaPageContentView.calculateImageRect(
            image: makeImage(size: CGSize(width: 50, height: 100)),
            in: CGSize(width: 200, height: 100),
            horizontalPlacement: .trailing
        )

        #expect(imageRect == CGRect(x: 150, y: 0, width: 50, height: 100))
    }

    @Test func calculateImageRect_SpreadPlacementsEliminateCenterGapForTallPages() {
        let slotSize = CGSize(width: 100, height: 100)
        let leftRect = MangaPageContentView.calculateImageRect(
            image: makeImage(size: CGSize(width: 50, height: 100)),
            in: slotSize,
            horizontalPlacement: .trailing
        )
        let rightRect = MangaPageContentView.calculateImageRect(
            image: makeImage(size: CGSize(width: 50, height: 100)),
            in: slotSize,
            horizontalPlacement: .leading
        ).offsetBy(dx: slotSize.width, dy: 0)

        #expect(leftRect.maxX == rightRect.minX)
    }
}

private extension MangaPageContentViewTests {
    func makeImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
