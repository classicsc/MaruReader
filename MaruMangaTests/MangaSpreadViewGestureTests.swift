// MangaSpreadViewGestureTests.swift
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

struct MangaSpreadViewGestureTests {
    @Test func adjustedHorizontalTranslation_LeftToRight_IsUnchanged() {
        let adjusted = MangaSpreadView.adjustedHorizontalTranslation(
            42,
            readingDirection: .leftToRight
        )

        #expect(adjusted == 42)
    }

    @Test func adjustedHorizontalTranslation_RightToLeft_IsFlipped() {
        let adjusted = MangaSpreadView.adjustedHorizontalTranslation(
            -18,
            readingDirection: .rightToLeft
        )

        #expect(adjusted == 18)
    }

    @Test func adjustedOffsetForHitTesting_LeftToRight_IsUnchanged() {
        let offset = CGSize(width: 12, height: -4)

        let adjusted = MangaSpreadView.adjustedOffsetForHitTesting(
            offset,
            readingDirection: .leftToRight
        )

        #expect(adjusted == offset)
    }

    @Test func adjustedOffsetForHitTesting_RightToLeft_FlipsHorizontal() {
        let offset = CGSize(width: -30, height: 8)

        let adjusted = MangaSpreadView.adjustedOffsetForHitTesting(
            offset,
            readingDirection: .rightToLeft
        )

        #expect(adjusted == CGSize(width: 30, height: 8))
    }

    @Test func adjustedPointForZoom_LeftToRight_IsUnchanged() {
        let point = CGPoint(x: 40, y: 12)

        let adjusted = MangaSpreadView.adjustedPointForZoom(
            point,
            containerSize: CGSize(width: 200, height: 100),
            readingDirection: .leftToRight
        )

        #expect(adjusted == point)
    }

    @Test func adjustedPointForZoom_Vertical_IsUnchanged() {
        let point = CGPoint(x: 40, y: 12)

        let adjusted = MangaSpreadView.adjustedPointForZoom(
            point,
            containerSize: CGSize(width: 200, height: 100),
            readingDirection: .vertical
        )

        #expect(adjusted == point)
    }

    @Test func adjustedPointForZoom_RightToLeft_FlipsHorizontal() {
        let adjusted = MangaSpreadView.adjustedPointForZoom(
            CGPoint(x: 40, y: 12),
            containerSize: CGSize(width: 200, height: 100),
            readingDirection: .rightToLeft
        )

        #expect(adjusted == CGPoint(x: 160, y: 12))
    }
}
