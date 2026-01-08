//
//  MangaPageViewGestureTests.swift
//  MaruMangaTests
//

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
