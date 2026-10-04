// MaruVisionTests.swift
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
@testable import MaruVision
import Testing

/// A vertical column at `x`, spanning `y0` to `y1` (normalized, lower-left origin).
private func column(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> CGRect {
    CGRect(x: x, y: y0, width: 0.05, height: y1 - y0)
}

struct ReadingOrderTests {
    @Test func verticalColumnsRightToLeftThenFragmentsTopDown() {
        let boxes = [column(0.5, 0.1, 0.4), column(0.6, 0.1, 0.9), column(0.5, 0.5, 0.9)]
        #expect(xyOrder(boxes, vertical: true) == [1, 2, 0])
    }

    @Test func verticalStackedGroupsTopFirst() {
        let boxes = [column(0.8, 0.1, 0.4), column(0.7, 0.1, 0.4), column(0.3, 0.6, 0.9), column(0.2, 0.6, 0.9)]
        #expect(xyOrder(boxes, vertical: true) == [2, 3, 0, 1])
    }

    @Test func horizontalLinesTopDown() {
        let row = { (y: CGFloat) in CGRect(x: 0.1, y: y, width: 0.5, height: 0.05) }
        #expect(xyOrder([row(0.1), row(0.5), row(0.3)], vertical: false) == [1, 2, 0])
    }

    @Test func noGapFallsBackToCentroidOrder() {
        let boxes = [column(0.5, 0.1, 0.5), column(0.52, 0.3, 0.7)]
        #expect(xyOrder(boxes, vertical: true) == [1, 0])
    }
}

struct MergeContainedTests {
    let host = CGRect(x: 0.1, y: 0.1, width: 0.4, height: 0.5)
    let inner = CGRect(x: 0.2, y: 0.2, width: 0.05, height: 0.3)

    @Test func containedClusterJoinsLargerHost() {
        let far = CGRect(x: 0.7, y: 0.1, width: 0.1, height: 0.1)
        #expect(mergeContained([(inner, true), (host, true), (far, true)]) == [[1, 0], [2]])
    }

    @Test func differentDirectionStaysSeparate() {
        #expect(mergeContained([(host, true), (inner, false)]) == [[0], [1]])
    }
}

struct CropTextTests {
    let line = CGRect(x: 0.5, y: 0.2, width: 0.05, height: 0.4)

    @Test func joinsFragmentsTopDown() {
        let reads = [
            CropRead(box: CGRect(x: 0.5, y: 0.2, width: 0.05, height: 0.15), text: "下"),
            CropRead(box: CGRect(x: 0.5, y: 0.4, width: 0.05, height: 0.2), text: "上"),
        ]
        #expect(cropText(for: line, reads: reads, vertical: true) == "上下")
    }

    @Test func dropsNeighbourOutsideLineAndRuby() {
        let reads = [
            CropRead(box: line, text: "本文"),
            CropRead(box: CGRect(x: 0.56, y: 0.2, width: 0.02, height: 0.4), text: "隣"),
            CropRead(box: CGRect(x: 0.53, y: 0.25, width: 0.02, height: 0.3), text: "ふり"),
        ]
        #expect(cropText(for: line, reads: reads, vertical: true) == "本文")
    }

    @Test func keepsPageTextWhenNothingOrStackedReads() {
        #expect(cropText(for: line, reads: [], vertical: true) == nil)
        let stacked = [
            CropRead(box: CGRect(x: 0.5, y: 0.2, width: 0.025, height: 0.4), text: "a"),
            CropRead(box: CGRect(x: 0.525, y: 0.2, width: 0.025, height: 0.4), text: "b"),
        ]
        #expect(cropText(for: line, reads: stacked, vertical: true) == nil)
    }
}

struct SecondPassTests {
    @Test func overlapNeedsThirtyPercentOfSmallerBox() {
        let a = CGRect(x: 0, y: 0, width: 1, height: 1)
        #expect(overlaps(a, CGRect(x: 0.5, y: 0, width: 1, height: 1)))
        #expect(!overlaps(a, CGRect(x: 0.8, y: 0, width: 1, height: 1)))
        #expect(!overlaps(a, CGRect(x: 2, y: 0, width: 1, height: 1)))
    }
}

struct FragmentTests {
    @Test func pieceOfOneColumnWithinGap() {
        #expect(fragments(column(0.5, 0.1, 0.4), column(0.5, 0.42, 0.9), vertical: true, gapMultiplier: 0.5))
        #expect(!fragments(column(0.5, 0.1, 0.4), column(0.5, 0.5, 0.9), vertical: true, gapMultiplier: 0.5))
    }

    @Test func sideBySideColumnsAreNotFragments() {
        #expect(!fragments(column(0.5, 0.1, 0.5), column(0.56, 0.1, 0.5), vertical: true, gapMultiplier: 0.5))
        // Overlap along the text axis by more than one line height.
        #expect(!fragments(column(0.5, 0.1, 0.5), column(0.52, 0.3, 0.7), vertical: true, gapMultiplier: 0.5))
    }

    @Test func wideBoxIsNotFragmentOfThinOne() {
        let wide = CGRect(x: 0.48, y: 0.42, width: 0.12, height: 0.1)
        #expect(!fragments(column(0.5, 0.1, 0.4), wide, vertical: true, gapMultiplier: 0.5))
    }

    @Test func lineGroupsJoinFragmentsTopFirst() {
        let boxes = [column(0.5, 0.1, 0.4), column(0.6, 0.1, 0.9), column(0.5, 0.42, 0.9)]
        let groups = lineGroups(boxes, vertical: true, gapMultiplier: 0.5)
        #expect(Set(groups) == [[2, 0], [1]])
    }
}

struct AbsorbHorizontalTests {
    let host = CGRect(x: 0.4, y: 0.2, width: 0.2, height: 0.5)

    @Test func shortReadAboveColumnsJoinsThem() {
        let tops = CGRect(x: 0.42, y: 0.71, width: 0.15, height: 0.04)
        #expect(absorbHorizontal([(host, true, 10), (tops, false, 2)]) == [[0, 1]])
    }

    @Test func distantOrLongerHorizontalStaysSeparate() {
        let far = CGRect(x: 0.42, y: 0.8, width: 0.15, height: 0.04)
        let long = CGRect(x: 0.42, y: 0.71, width: 0.15, height: 0.04)
        #expect(absorbHorizontal([(host, true, 10), (far, false, 2)]) == [[0], [1]])
        #expect(absorbHorizontal([(host, true, 10), (long, false, 12)]) == [[0], [1]])
    }
}
