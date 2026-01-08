// SpreadLayoutTests.swift
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

import Foundation
@testable import MaruManga
import Testing

struct SpreadLayoutTests {
    // MARK: - Cover Page Tests

    @Test
    func coverPageIsAlwaysSingle_RTL() {
        let layout = SpreadLayout.compute(
            pageCount: 10,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        #expect(layout.items.first == .single(pageIndex: 0))
    }

    @Test
    func coverPageIsAlwaysSingle_LTR() {
        let layout = SpreadLayout.compute(
            pageCount: 10,
            spreadMode: true,
            readingDirection: .leftToRight
        )

        #expect(layout.items.first == .single(pageIndex: 0))
    }

    // MARK: - RTL Page Pairing Tests

    @Test
    func rtlPagesArePairedCorrectly() {
        let layout = SpreadLayout.compute(
            pageCount: 10,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        // Cover is single
        #expect(layout.items[0] == .single(pageIndex: 0))

        // Pages 1-2 form spread: page 2 on left (higher index) for RTL
        #expect(layout.items[1] == .double(leftPageIndex: 2, rightPageIndex: 1))

        // Pages 3-4 form spread
        #expect(layout.items[2] == .double(leftPageIndex: 4, rightPageIndex: 3))

        // Pages 5-6 form spread
        #expect(layout.items[3] == .double(leftPageIndex: 6, rightPageIndex: 5))

        // Pages 7-8 form spread
        #expect(layout.items[4] == .double(leftPageIndex: 8, rightPageIndex: 7))

        // Page 9 is single (last page, odd count after cover)
        #expect(layout.items[5] == .single(pageIndex: 9))
    }

    // MARK: - LTR Page Pairing Tests

    @Test
    func ltrPagesArePairedCorrectly() {
        let layout = SpreadLayout.compute(
            pageCount: 10,
            spreadMode: true,
            readingDirection: .leftToRight
        )

        // Cover is single
        #expect(layout.items[0] == .single(pageIndex: 0))

        // Pages 1-2 form spread: page 1 on left (lower index) for LTR
        #expect(layout.items[1] == .double(leftPageIndex: 1, rightPageIndex: 2))

        // Pages 3-4 form spread
        #expect(layout.items[2] == .double(leftPageIndex: 3, rightPageIndex: 4))
    }

    // MARK: - Odd Page Count Tests

    @Test
    func oddPageCountLastPageIsSingle_RTL() {
        // 5 pages: cover (0), spread (1-2), spread (3-4)
        let layout = SpreadLayout.compute(
            pageCount: 5,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        #expect(layout.items.count == 3)
        #expect(layout.items[0] == .single(pageIndex: 0))
        #expect(layout.items[1] == .double(leftPageIndex: 2, rightPageIndex: 1))
        #expect(layout.items[2] == .double(leftPageIndex: 4, rightPageIndex: 3))
    }

    @Test
    func evenPageCountNoSingleAtEnd() {
        // 6 pages: cover (0), spread (1-2), spread (3-4), single (5)
        let layout = SpreadLayout.compute(
            pageCount: 6,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        #expect(layout.items.count == 4)
        #expect(layout.items[0] == .single(pageIndex: 0))
        #expect(layout.items[1] == .double(leftPageIndex: 2, rightPageIndex: 1))
        #expect(layout.items[2] == .double(leftPageIndex: 4, rightPageIndex: 3))
        #expect(layout.items[3] == .single(pageIndex: 5))
    }

    // MARK: - Single Mode Tests

    @Test
    func singleModeReturnsAllSingles() {
        let layout = SpreadLayout.compute(
            pageCount: 5,
            spreadMode: false,
            readingDirection: .rightToLeft
        )

        #expect(layout.items.count == 5)
        for (index, item) in layout.items.enumerated() {
            #expect(item == .single(pageIndex: index))
        }
    }

    // MARK: - Vertical Mode Tests

    @Test
    func verticalModeReturnsAllSingles() {
        let layout = SpreadLayout.compute(
            pageCount: 5,
            spreadMode: true,
            readingDirection: .vertical
        )

        #expect(layout.items.count == 5)
        for (index, item) in layout.items.enumerated() {
            #expect(item == .single(pageIndex: index))
        }
    }

    // MARK: - Spread Index Lookup Tests

    @Test
    func spreadIndexFindsCorrectSpread() {
        let layout = SpreadLayout.compute(
            pageCount: 10,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        // Cover is at spread index 0
        #expect(layout.spreadIndex(forPage: 0) == 0)

        // Pages 1-2 are at spread index 1
        #expect(layout.spreadIndex(forPage: 1) == 1)
        #expect(layout.spreadIndex(forPage: 2) == 1)

        // Pages 3-4 are at spread index 2
        #expect(layout.spreadIndex(forPage: 3) == 2)
        #expect(layout.spreadIndex(forPage: 4) == 2)

        // Page 9 (last single) is at spread index 5
        #expect(layout.spreadIndex(forPage: 9) == 5)
    }

    @Test
    func spreadIndexReturnsNilForInvalidPage() {
        let layout = SpreadLayout.compute(
            pageCount: 5,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        #expect(layout.spreadIndex(forPage: -1) == nil)
        #expect(layout.spreadIndex(forPage: 100) == nil)
    }

    // MARK: - Pages At Spread Index Tests

    @Test
    func pagesAtSpreadIndexReturnsCorrectPages() {
        let layout = SpreadLayout.compute(
            pageCount: 10,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        // Cover
        #expect(layout.pages(atSpreadIndex: 0) == [0])

        // First spread (RTL: 2 on left, 1 on right)
        #expect(layout.pages(atSpreadIndex: 1) == [2, 1])

        // Second spread
        #expect(layout.pages(atSpreadIndex: 2) == [4, 3])
    }

    @Test
    func pagesAtInvalidSpreadIndexReturnsEmpty() {
        let layout = SpreadLayout.compute(
            pageCount: 5,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        #expect(layout.pages(atSpreadIndex: -1) == [])
        #expect(layout.pages(atSpreadIndex: 100) == [])
    }

    // MARK: - Empty Page Count Tests

    @Test
    func emptyPageCountReturnsEmptyLayout() {
        let layout = SpreadLayout.compute(
            pageCount: 0,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        #expect(layout.items.isEmpty)
        #expect(layout.count == 0)
    }

    // MARK: - SpreadItem Tests

    @Test
    func spreadItemPageIndices() {
        let single = SpreadLayout.SpreadItem.single(pageIndex: 5)
        #expect(single.pageIndices == [5])
        #expect(single.firstPageIndex == 5)
        #expect(single.isSingle == true)

        let double = SpreadLayout.SpreadItem.double(leftPageIndex: 4, rightPageIndex: 3)
        #expect(double.pageIndices == [4, 3])
        #expect(double.firstPageIndex == 3) // min of the two
        #expect(double.isSingle == false)
    }

    // MARK: - Single Page Manga Tests

    @Test
    func singlePageMangaHasOnlyOneSingle() {
        let layout = SpreadLayout.compute(
            pageCount: 1,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        #expect(layout.items.count == 1)
        #expect(layout.items[0] == .single(pageIndex: 0))
    }

    @Test
    func twoPageMangaHasCoverAndSingle() {
        // 2 pages: cover (0), single page 1 (no pair available)
        let layout = SpreadLayout.compute(
            pageCount: 2,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        #expect(layout.items.count == 2)
        #expect(layout.items[0] == .single(pageIndex: 0))
        #expect(layout.items[1] == .single(pageIndex: 1))
    }

    @Test
    func threePageMangaHasCoverAndSpread() {
        // 3 pages: cover (0), spread (1-2)
        let layout = SpreadLayout.compute(
            pageCount: 3,
            spreadMode: true,
            readingDirection: .rightToLeft
        )

        #expect(layout.items.count == 2)
        #expect(layout.items[0] == .single(pageIndex: 0))
        #expect(layout.items[1] == .double(leftPageIndex: 2, rightPageIndex: 1))
    }
}
