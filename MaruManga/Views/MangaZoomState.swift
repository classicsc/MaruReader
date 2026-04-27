// MangaZoomState.swift
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
import Foundation

struct MangaZoomState: Equatable {
    static let baseScale: CGFloat = 1.0
    static let doubleTapScale: CGFloat = 2.5
    static let baseZoomTolerance: CGFloat = 0.01

    /// Vertical drag distance, in points, that doubles (or halves) the zoom scale
    /// during the double-tap-and-hold-drag gesture. Larger = less sensitive.
    static let dragZoomDistanceForDoubling: CGFloat = 150

    var scale: CGFloat
    var offset: CGSize

    var isAtBaseZoom: Bool {
        scale <= Self.baseScale + Self.baseZoomTolerance
    }

    static var base: MangaZoomState {
        MangaZoomState(scale: baseScale, offset: .zero)
    }

    func scaled(
        by magnification: CGFloat,
        around focalPoint: CGPoint,
        containerSize: CGSize,
        minScale: CGFloat,
        maxScale: CGFloat
    ) -> MangaZoomState {
        let newScale = Self.clamp(scale * magnification, minScale, maxScale)
        return settingScale(
            newScale,
            around: focalPoint,
            containerSize: containerSize
        )
    }

    func settingScale(
        _ newScale: CGFloat,
        around focalPoint: CGPoint,
        containerSize: CGSize
    ) -> MangaZoomState {
        guard scale > 0 else {
            return MangaZoomState(
                scale: newScale,
                offset: Self.clampedOffset(.zero, scale: newScale, containerSize: containerSize)
            )
        }

        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let scaleRatio = newScale / scale
        let proposedOffset = CGSize(
            width: offset.width * scaleRatio + (focalPoint.x - center.x) * (1 - scaleRatio),
            height: offset.height * scaleRatio + (focalPoint.y - center.y) * (1 - scaleRatio)
        )

        return MangaZoomState(
            scale: newScale,
            offset: Self.clampedOffset(proposedOffset, scale: newScale, containerSize: containerSize)
        )
    }

    func doubleTapped(
        around focalPoint: CGPoint,
        containerSize: CGSize
    ) -> MangaZoomState {
        guard isAtBaseZoom else {
            return .base
        }

        return settingScale(
            Self.doubleTapScale,
            around: focalPoint,
            containerSize: containerSize
        )
    }

    /// Computes a new zoom state for a continuous double-tap-and-hold-drag gesture.
    ///
    /// - Parameters:
    ///   - verticalTranslation: The vertical drag distance from the gesture's start, in points.
    ///     Negative (drag up) zooms in, positive (drag down) zooms out, matching iOS Photos.
    ///   - focalPoint: The point in container coordinates that should remain stationary as
    ///     the scale changes (typically the location of the second tap that began the press).
    ///   - baseline: The zoom state captured when the gesture began. Subsequent updates are
    ///     computed from this baseline rather than the previous frame so the mapping is stable.
    ///   - containerSize: Size of the container view used for offset clamping.
    ///   - minScale: Minimum permitted scale.
    ///   - maxScale: Maximum permitted scale.
    static func dragZoomed(
        verticalTranslation: CGFloat,
        around focalPoint: CGPoint,
        fromBaseline baseline: MangaZoomState,
        containerSize: CGSize,
        minScale: CGFloat,
        maxScale: CGFloat
    ) -> MangaZoomState {
        let factor = CGFloat(pow(2.0, -Double(verticalTranslation) / Double(Self.dragZoomDistanceForDoubling)))
        let target = clamp(baseline.scale * factor, minScale, maxScale)
        return baseline.settingScale(
            target,
            around: focalPoint,
            containerSize: containerSize
        )
    }

    func panned(
        by translation: CGSize,
        containerSize: CGSize
    ) -> MangaZoomState {
        let proposedOffset = CGSize(
            width: offset.width + translation.width,
            height: offset.height + translation.height
        )
        return MangaZoomState(
            scale: scale,
            offset: Self.clampedOffset(proposedOffset, scale: scale, containerSize: containerSize)
        )
    }

    func untransformedPoint(
        from transformedPoint: CGPoint,
        containerSize: CGSize
    ) -> CGPoint {
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        return CGPoint(
            x: (transformedPoint.x - center.x - offset.width) / scale + center.x,
            y: (transformedPoint.y - center.y - offset.height) / scale + center.y
        )
    }

    static func clampedOffset(
        _ proposedOffset: CGSize,
        scale: CGFloat,
        containerSize: CGSize
    ) -> CGSize {
        let scaledWidth = containerSize.width * scale
        let scaledHeight = containerSize.height * scale

        let maxOffsetX = max(0, (scaledWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - containerSize.height) / 2)

        return CGSize(
            width: clamp(proposedOffset.width, -maxOffsetX, maxOffsetX),
            height: clamp(proposedOffset.height, -maxOffsetY, maxOffsetY)
        )
    }

    private static func clamp(_ value: CGFloat, _ lowerBound: CGFloat, _ upperBound: CGFloat) -> CGFloat {
        min(max(value, lowerBound), upperBound)
    }
}
