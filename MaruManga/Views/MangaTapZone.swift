// MangaTapZone.swift
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

/// The action a single tap on the manga page should trigger when the tap
/// misses every OCR cluster.
enum MangaTapZone: Equatable {
    case previousPage
    case nextPage
    case toggleToolbars
}

enum MangaTapZoneResolver {
    /// Resolves a single-tap miss into a `MangaTapZone`.
    ///
    /// Tap x is expected to be in absolute (left-origin) container coordinates,
    /// which is what `SpatialTapGesture.location` always reports — regardless
    /// of the surrounding `LayoutDirection` environment. The reading direction
    /// determines which visual side counts as "next".
    ///
    /// - Parameters:
    ///   - tapX: The tap's x coordinate within the container, left-origin.
    ///   - containerWidth: The width of the tap container.
    ///   - isAtBaseZoom: Whether the page/spread is at base (un-zoomed) scale.
    ///     When zoomed in, panning takes precedence and we always toggle toolbars.
    ///   - tapToTurnEnabled: User preference. When disabled, always toggles toolbars.
    ///   - readingDirection: The manga's reading direction, used to map left/right
    ///     thirds onto previous/next.
    static func resolve(
        tapX: CGFloat,
        containerWidth: CGFloat,
        isAtBaseZoom: Bool,
        tapToTurnEnabled: Bool,
        readingDirection: MangaReadingDirection
    ) -> MangaTapZone {
        guard tapToTurnEnabled, isAtBaseZoom, containerWidth > 0 else {
            return .toggleToolbars
        }
        let third = containerWidth / 3
        let inLeftThird = tapX < third
        let inRightThird = tapX > containerWidth - third

        if !inLeftThird, !inRightThird {
            return .toggleToolbars
        }

        switch readingDirection {
        case .rightToLeft:
            return inLeftThird ? .nextPage : .previousPage
        case .leftToRight, .vertical:
            return inLeftThird ? .previousPage : .nextPage
        }
    }
}
