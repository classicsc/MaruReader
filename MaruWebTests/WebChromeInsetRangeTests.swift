// WebChromeInsetRangeTests.swift
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

@testable import MaruWeb
import Testing
import UIKit

struct WebChromeInsetRangeTests {
    @Test func firstSampleSetsBothBounds() {
        var range = WebChromeInsetRange()
        range.record(top: 59, bottom: 150)
        #expect(range.minimum == UIEdgeInsets(top: 59, left: 0, bottom: 150, right: 0))
        #expect(range.maximum == UIEdgeInsets(top: 59, left: 0, bottom: 150, right: 0))
    }

    @Test func collapseAndExpandWidenRange() {
        var range = WebChromeInsetRange()
        range.record(top: 59, bottom: 150)
        range.record(top: 59, bottom: 80)
        range.record(top: 59, bottom: 150)
        #expect(range.minimum.bottom == 80)
        #expect(range.maximum.bottom == 150)
    }

    @Test func topChangeResetsRange() {
        var range = WebChromeInsetRange()
        range.record(top: 59, bottom: 150)
        range.record(top: 59, bottom: 80)
        range.record(top: 0, bottom: 120)
        #expect(range.minimum == UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0))
        #expect(range.maximum == UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0))
    }

    @Test func minimumNeverExceedsMaximum() {
        var range = WebChromeInsetRange()
        for bottom in [150.0, 80.0, 34.0, 200.0, 150.0] {
            range.record(top: 59, bottom: bottom)
            #expect(range.minimum.bottom <= range.maximum.bottom)
        }
    }
}
