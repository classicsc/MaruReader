// MangaTapZoneTests.swift
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

struct MangaTapZoneTests {
    private let containerWidth: CGFloat = 300
    // Tap x values that fall solidly within each visual third of a 300-wide
    // container (left-origin, since SpatialTapGesture reports absolute coords).
    private let leftX: CGFloat = 50
    private let middleX: CGFloat = 150
    private let rightX: CGFloat = 250

    // MARK: - Disabled / zoomed always toggles

    @Test func resolve_settingDisabled_alwaysToggles() {
        for x in [leftX, middleX, rightX] {
            let zone = MangaTapZoneResolver.resolve(
                tapX: x,
                containerWidth: containerWidth,
                isAtBaseZoom: true,
                tapToTurnEnabled: false,
                readingDirection: .leftToRight
            )
            #expect(zone == .toggleToolbars)
        }
    }

    @Test func resolve_zoomedIn_alwaysToggles() {
        for x in [leftX, middleX, rightX] {
            let zone = MangaTapZoneResolver.resolve(
                tapX: x,
                containerWidth: containerWidth,
                isAtBaseZoom: false,
                tapToTurnEnabled: true,
                readingDirection: .rightToLeft
            )
            #expect(zone == .toggleToolbars)
        }
    }

    @Test func resolve_zeroContainerWidth_toggles() {
        let zone = MangaTapZoneResolver.resolve(
            tapX: 0,
            containerWidth: 0,
            isAtBaseZoom: true,
            tapToTurnEnabled: true,
            readingDirection: .leftToRight
        )
        #expect(zone == .toggleToolbars)
    }

    // MARK: - Middle third toggles

    @Test func resolve_middleThird_togglesToolbars() {
        for direction in [MangaReadingDirection.leftToRight, .rightToLeft, .vertical] {
            let zone = MangaTapZoneResolver.resolve(
                tapX: middleX,
                containerWidth: containerWidth,
                isAtBaseZoom: true,
                tapToTurnEnabled: true,
                readingDirection: direction
            )
            #expect(zone == .toggleToolbars)
        }
    }

    // MARK: - Reading-direction mapping

    @Test func resolve_leftToRight_leftIsPrevious_rightIsNext() {
        let left = MangaTapZoneResolver.resolve(
            tapX: leftX,
            containerWidth: containerWidth,
            isAtBaseZoom: true,
            tapToTurnEnabled: true,
            readingDirection: .leftToRight
        )
        let right = MangaTapZoneResolver.resolve(
            tapX: rightX,
            containerWidth: containerWidth,
            isAtBaseZoom: true,
            tapToTurnEnabled: true,
            readingDirection: .leftToRight
        )
        #expect(left == .previousPage)
        #expect(right == .nextPage)
    }

    @Test func resolve_rightToLeft_leftIsNext_rightIsPrevious() {
        let left = MangaTapZoneResolver.resolve(
            tapX: leftX,
            containerWidth: containerWidth,
            isAtBaseZoom: true,
            tapToTurnEnabled: true,
            readingDirection: .rightToLeft
        )
        let right = MangaTapZoneResolver.resolve(
            tapX: rightX,
            containerWidth: containerWidth,
            isAtBaseZoom: true,
            tapToTurnEnabled: true,
            readingDirection: .rightToLeft
        )
        #expect(left == .nextPage)
        #expect(right == .previousPage)
    }

    @Test func resolve_vertical_treatsLeftAsPrevious() {
        let left = MangaTapZoneResolver.resolve(
            tapX: leftX,
            containerWidth: containerWidth,
            isAtBaseZoom: true,
            tapToTurnEnabled: true,
            readingDirection: .vertical
        )
        let right = MangaTapZoneResolver.resolve(
            tapX: rightX,
            containerWidth: containerWidth,
            isAtBaseZoom: true,
            tapToTurnEnabled: true,
            readingDirection: .vertical
        )
        #expect(left == .previousPage)
        #expect(right == .nextPage)
    }

    // MARK: - Boundary behavior

    @Test func resolve_exactlyAtThirdBoundary_isMiddle() {
        // tapX == containerWidth / 3 is NOT < third, so falls into middle.
        let zone = MangaTapZoneResolver.resolve(
            tapX: containerWidth / 3,
            containerWidth: containerWidth,
            isAtBaseZoom: true,
            tapToTurnEnabled: true,
            readingDirection: .leftToRight
        )
        #expect(zone == .toggleToolbars)
    }
}
