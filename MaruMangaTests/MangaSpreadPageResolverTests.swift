// MangaSpreadPageResolverTests.swift
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
@testable import MaruManga
import Testing

struct MangaSpreadPageResolverTests {
    @Test func resolvePageTap_UsesVisualOrderForRTLSpread() {
        let spreadItem = SpreadLayout.compute(
            pageCount: 6,
            spreadMode: true,
            readingDirection: .rightToLeft
        ).items[1]

        let leftTap = MangaSpreadPageResolver.resolvePageTap(
            spreadItem: spreadItem,
            untransformedPoint: CGPoint(x: 40, y: 60),
            containerSize: CGSize(width: 200, height: 120)
        )
        let rightTap = MangaSpreadPageResolver.resolvePageTap(
            spreadItem: spreadItem,
            untransformedPoint: CGPoint(x: 140, y: 60),
            containerSize: CGSize(width: 200, height: 120)
        )

        #expect(leftTap.pageIndex == 2)
        #expect(leftTap.pagePlacement == .trailing)
        #expect(leftTap.pageLocalPoint == CGPoint(x: 40, y: 60))

        #expect(rightTap.pageIndex == 1)
        #expect(rightTap.pagePlacement == .leading)
        #expect(rightTap.pageLocalPoint == CGPoint(x: 40, y: 60))
    }

    @Test func resolvePageTap_UsesVisualOrderForLTRSpread() {
        let spreadItem = SpreadLayout.compute(
            pageCount: 6,
            spreadMode: true,
            readingDirection: .leftToRight
        ).items[1]

        let leftTap = MangaSpreadPageResolver.resolvePageTap(
            spreadItem: spreadItem,
            untransformedPoint: CGPoint(x: 40, y: 60),
            containerSize: CGSize(width: 200, height: 120)
        )
        let rightTap = MangaSpreadPageResolver.resolvePageTap(
            spreadItem: spreadItem,
            untransformedPoint: CGPoint(x: 140, y: 60),
            containerSize: CGSize(width: 200, height: 120)
        )

        #expect(leftTap.pageIndex == 1)
        #expect(leftTap.pagePlacement == .trailing)
        #expect(rightTap.pageIndex == 2)
        #expect(rightTap.pagePlacement == .leading)
    }

    @Test func resolvePageTap_UsesFullContainerForSinglePageSpread() {
        let resolvedTap = MangaSpreadPageResolver.resolvePageTap(
            spreadItem: .single(pageIndex: 0),
            untransformedPoint: CGPoint(x: 80, y: 30),
            containerSize: CGSize(width: 200, height: 120)
        )

        #expect(resolvedTap.pageIndex == 0)
        #expect(resolvedTap.pageContainerSize == CGSize(width: 200, height: 120))
        #expect(resolvedTap.pageLocalPoint == CGPoint(x: 80, y: 30))
        #expect(resolvedTap.pagePlacement == .centered)
    }
}
