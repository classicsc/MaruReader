// MangaDragZoomTapSuppressionTests.swift
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

import Foundation
@testable import MaruManga
import Testing

struct MangaDragZoomTapSuppressionTests {
    @Test func consumeWithinDurationSuppressesTapOnce() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var suppression = MangaDragZoomTapSuppression(duration: 0.4)

        suppression.activate(now: start)

        let firstConsume = suppression.consumeIfNeeded(now: start.addingTimeInterval(0.2))
        let secondConsume = suppression.consumeIfNeeded(now: start.addingTimeInterval(0.3))

        #expect(firstConsume)
        #expect(!secondConsume)
    }

    @Test func consumeAfterDurationDoesNotSuppressTap() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var suppression = MangaDragZoomTapSuppression(duration: 0.4)

        suppression.activate(now: start)

        let consume = suppression.consumeIfNeeded(now: start.addingTimeInterval(0.5))

        #expect(!consume)
    }

    @Test func reactivationExtendsSuppressionWindow() {
        let start = Date(timeIntervalSinceReferenceDate: 100)
        var suppression = MangaDragZoomTapSuppression(duration: 0.4)

        suppression.activate(now: start)
        suppression.activate(now: start.addingTimeInterval(0.3))

        let consume = suppression.consumeIfNeeded(now: start.addingTimeInterval(0.6))

        #expect(consume)
    }
}
