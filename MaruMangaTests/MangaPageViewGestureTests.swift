// MangaPageViewGestureTests.swift
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
import SwiftUI
import Testing

struct MangaPageViewGestureTests {
    @Test func adjustedHorizontalTranslation_LeftToRight_IsUnchanged() {
        let translation: CGFloat = 42

        let adjusted = MangaPageView.adjustedHorizontalTranslation(
            translation,
            layoutDirection: .leftToRight
        )

        #expect(adjusted == translation)
    }

    @Test func adjustedHorizontalTranslation_RightToLeft_IsFlipped() {
        let translation: CGFloat = -18

        let adjusted = MangaPageView.adjustedHorizontalTranslation(
            translation,
            layoutDirection: .rightToLeft
        )

        #expect(adjusted == 18)
    }

    @Test func adjustedOffsetForHitTesting_LeftToRight_IsUnchanged() {
        let offset = CGSize(width: 12, height: -4)

        let adjusted = MangaPageView.adjustedOffsetForHitTesting(
            offset,
            layoutDirection: .leftToRight
        )

        #expect(adjusted == offset)
    }

    @Test func adjustedOffsetForHitTesting_RightToLeft_FlipsHorizontal() {
        let offset = CGSize(width: -30, height: 8)

        let adjusted = MangaPageView.adjustedOffsetForHitTesting(
            offset,
            layoutDirection: .rightToLeft
        )

        #expect(adjusted == CGSize(width: 30, height: 8))
    }
}
