// OCRBoundingBoxAppearanceTests.swift
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

import MaruVision
import MaruVisionUICommon
import SwiftUI
import Testing

struct OCRBoundingBoxAppearanceTests {
    @Test func verticalTextUsesDashedStroke() {
        let appearance = OCRBoundingBoxAppearance.make(
            direction: .vertical,
            isHighlighted: false,
            differentiateWithoutColor: false
        )

        #expect(appearance.strokeStyle.lineWidth == 2)
        #expect(appearance.strokeStyle.dash == [8, 4])
        #expect(appearance.strokeOpacity == 0.8)
        #expect(appearance.fillColor == nil)
    }

    @Test func differentiateWithoutColorUsesHigherContrastStroke() {
        let appearance = OCRBoundingBoxAppearance.make(
            direction: .horizontal,
            isHighlighted: false,
            differentiateWithoutColor: true
        )

        #expect(appearance.strokeStyle.lineWidth == 3)
        #expect(appearance.strokeStyle.dash.isEmpty)
        #expect(appearance.strokeOpacity == 1)
        #expect(appearance.fillColor == nil)
    }

    @Test func highlightedBoxesStaySolidAndFilled() {
        let appearance = OCRBoundingBoxAppearance.make(
            direction: .vertical,
            isHighlighted: true,
            differentiateWithoutColor: true
        )

        #expect(appearance.strokeStyle.lineWidth == 3)
        #expect(appearance.strokeStyle.dash.isEmpty)
        #expect(appearance.strokeOpacity == 1)
        #expect(appearance.fillColor != nil)
    }
}
