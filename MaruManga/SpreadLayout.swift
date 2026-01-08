// SpreadLayout.swift
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

/// Represents how manga pages are grouped for display (single or side-by-side spreads).
struct SpreadLayout: Equatable, Sendable {
    /// A single display unit containing one or two pages.
    enum SpreadItem: Equatable, Sendable {
        case single(pageIndex: Int)
        case double(leftPageIndex: Int, rightPageIndex: Int)

        /// All page indices contained in this spread item.
        var pageIndices: [Int] {
            switch self {
            case let .single(pageIndex):
                [pageIndex]
            case let .double(leftPageIndex, rightPageIndex):
                [leftPageIndex, rightPageIndex]
            }
        }

        /// The first (lowest) page index in this spread item.
        var firstPageIndex: Int {
            switch self {
            case let .single(pageIndex):
                pageIndex
            case let .double(leftPageIndex, rightPageIndex):
                min(leftPageIndex, rightPageIndex)
            }
        }

        /// Whether this is a single page (not a spread).
        var isSingle: Bool {
            if case .single = self { return true }
            return false
        }
    }

    /// All spread items in reading order.
    let items: [SpreadItem]

    /// Creates a spread layout for the given page count and settings.
    ///
    /// - Parameters:
    ///   - pageCount: Total number of pages in the manga.
    ///   - spreadMode: Whether spreads are enabled (false = all singles).
    ///   - readingDirection: The reading direction (affects page placement in spreads).
    /// - Returns: A computed spread layout.
    static func compute(
        pageCount: Int,
        spreadMode: Bool,
        readingDirection: MangaReadingDirection
    ) -> SpreadLayout {
        guard pageCount > 0 else {
            return SpreadLayout(items: [])
        }

        // No spreads in single mode or vertical reading
        guard spreadMode, readingDirection != .vertical else {
            return SpreadLayout(items: (0 ..< pageCount).map { .single(pageIndex: $0) })
        }

        var items: [SpreadItem] = []

        // Cover (page 0) is always single
        items.append(.single(pageIndex: 0))

        // Pair remaining pages
        var i = 1
        while i < pageCount {
            if i + 1 < pageCount {
                // Create spread with two pages
                // RTL: higher page index goes on the left (reading right-to-left)
                // LTR: lower page index goes on the left (reading left-to-right)
                if readingDirection == .rightToLeft {
                    items.append(.double(leftPageIndex: i + 1, rightPageIndex: i))
                } else {
                    items.append(.double(leftPageIndex: i, rightPageIndex: i + 1))
                }
                i += 2
            } else {
                // Odd last page - single
                items.append(.single(pageIndex: i))
                i += 1
            }
        }

        return SpreadLayout(items: items)
    }

    /// Finds the spread index containing the given page index.
    ///
    /// - Parameter pageIndex: The page index to find.
    /// - Returns: The spread index, or nil if not found.
    func spreadIndex(forPage pageIndex: Int) -> Int? {
        items.firstIndex { $0.pageIndices.contains(pageIndex) }
    }

    /// Gets the page indices for the spread at the given index.
    ///
    /// - Parameter index: The spread index.
    /// - Returns: Array of page indices (1 or 2 elements), or empty if index is invalid.
    func pages(atSpreadIndex index: Int) -> [Int] {
        guard index >= 0, index < items.count else { return [] }
        return items[index].pageIndices
    }

    /// The total number of spread items.
    var count: Int {
        items.count
    }
}
