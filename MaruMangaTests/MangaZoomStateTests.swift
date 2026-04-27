// MangaZoomStateTests.swift
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

struct MangaZoomStateTests {
    private let containerSize = CGSize(width: 200, height: 100)

    @Test func settingScaleAroundCenterKeepsZeroOffset() {
        let zoom = MangaZoomState.base.settingScale(
            2,
            around: CGPoint(x: 100, y: 50),
            containerSize: containerSize
        )

        #expect(zoom.scale == 2)
        #expect(zoom.offset == .zero)
    }

    @Test func settingScaleAroundCornerKeepsFocalPointUnderTouch() {
        let focalPoint = CGPoint(x: 25, y: 20)
        let zoom = MangaZoomState.base.settingScale(
            2,
            around: focalPoint,
            containerSize: containerSize
        )

        #expect(zoom.scale == 2)
        #expect(zoom.untransformedPoint(from: focalPoint, containerSize: containerSize).isApproximatelyEqual(to: focalPoint))
    }

    @Test func scaledClampsScaleAndOffset() {
        let zoom = MangaZoomState.base.scaled(
            by: 10,
            around: CGPoint(x: 0, y: 0),
            containerSize: containerSize,
            minScale: 1,
            maxScale: 5
        )

        #expect(zoom.scale == 5)
        #expect(zoom.offset == CGSize(width: 400, height: 200))
    }

    @Test func pannedClampsOffset() {
        let zoom = MangaZoomState(
            scale: 2,
            offset: .zero
        ).panned(
            by: CGSize(width: 200, height: -200),
            containerSize: containerSize
        )

        #expect(zoom.offset == CGSize(width: 100, height: -50))
    }

    @Test func baseZoomUsesTolerance() {
        #expect(MangaZoomState(scale: 1.01, offset: .zero).isAtBaseZoom)
        #expect(!MangaZoomState(scale: 1.02, offset: .zero).isAtBaseZoom)
    }

    @Test func doubleTapScalePreservesTappedLocation() {
        let tapPoint = CGPoint(x: 160, y: 70)
        let zoom = MangaZoomState.base.doubleTapped(
            around: tapPoint,
            containerSize: containerSize
        )

        #expect(zoom.scale == MangaZoomState.doubleTapScale)
        #expect(zoom.untransformedPoint(from: tapPoint, containerSize: containerSize).isApproximatelyEqual(to: tapPoint))
    }

    @Test func doubleTapWhileZoomedResetsZoom() {
        let zoom = MangaZoomState(
            scale: 2,
            offset: CGSize(width: 30, height: -20)
        ).doubleTapped(
            around: CGPoint(x: 160, y: 70),
            containerSize: containerSize
        )

        #expect(zoom == .base)
    }

    // MARK: - dragZoomed

    @Test func dragZoomedUpwardIncreasesScale() {
        let baseline = MangaZoomState.base
        let zoom = MangaZoomState.dragZoomed(
            verticalTranslation: -MangaZoomState.dragZoomDistanceForDoubling,
            around: CGPoint(x: 100, y: 50),
            fromBaseline: baseline,
            containerSize: containerSize,
            minScale: 1,
            maxScale: 5
        )

        #expect(abs(zoom.scale - 2) < 0.0001)
    }

    @Test func dragZoomedDownwardDecreasesScale() {
        let baseline = MangaZoomState(scale: 2, offset: .zero)
        let zoom = MangaZoomState.dragZoomed(
            verticalTranslation: MangaZoomState.dragZoomDistanceForDoubling,
            around: CGPoint(x: 100, y: 50),
            fromBaseline: baseline,
            containerSize: containerSize,
            minScale: 1,
            maxScale: 5
        )

        #expect(abs(zoom.scale - 1) < 0.0001)
    }

    @Test func dragZoomedClampsToMinAndMax() {
        let baseline = MangaZoomState(scale: 2, offset: .zero)

        let zoomedIn = MangaZoomState.dragZoomed(
            verticalTranslation: -10000,
            around: CGPoint(x: 100, y: 50),
            fromBaseline: baseline,
            containerSize: containerSize,
            minScale: 1,
            maxScale: 5
        )
        #expect(zoomedIn.scale == 5)

        let zoomedOut = MangaZoomState.dragZoomed(
            verticalTranslation: 10000,
            around: CGPoint(x: 100, y: 50),
            fromBaseline: baseline,
            containerSize: containerSize,
            minScale: 1,
            maxScale: 5
        )
        #expect(zoomedOut.scale == 1)
    }

    @Test func dragZoomedRoundTripReturnsBaselineScale() {
        let baseline = MangaZoomState(scale: 1.5, offset: .zero)
        let mid = MangaZoomState.dragZoomed(
            verticalTranslation: -50,
            around: CGPoint(x: 100, y: 50),
            fromBaseline: baseline,
            containerSize: containerSize,
            minScale: 1,
            maxScale: 5
        )
        let back = MangaZoomState.dragZoomed(
            verticalTranslation: 0,
            around: CGPoint(x: 100, y: 50),
            fromBaseline: baseline,
            containerSize: containerSize,
            minScale: 1,
            maxScale: 5
        )

        #expect(mid.scale > baseline.scale)
        #expect(abs(back.scale - baseline.scale) < 0.0001)
    }

    @Test func dragZoomedKeepsFocalPointStationary() {
        let baseline = MangaZoomState.base
        let focalPoint = CGPoint(x: 30, y: 20)
        let zoom = MangaZoomState.dragZoomed(
            verticalTranslation: -75,
            around: focalPoint,
            fromBaseline: baseline,
            containerSize: containerSize,
            minScale: 1,
            maxScale: 5
        )

        #expect(zoom.untransformedPoint(from: focalPoint, containerSize: containerSize).isApproximatelyEqual(to: focalPoint))
    }
}

private extension CGPoint {
    func isApproximatelyEqual(to other: CGPoint) -> Bool {
        abs(x - other.x) < 0.0001 && abs(y - other.y) < 0.0001
    }
}
