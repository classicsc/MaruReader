// OCRBoundingBoxAppearance.swift
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
import SwiftUI

public struct OCRBoundingBoxAppearance {
    public let strokeColor: Color
    public let strokeOpacity: Double
    public let fillColor: Color?
    public let strokeStyle: StrokeStyle

    public static func make(
        direction: InferredTextDirection,
        isHighlighted: Bool,
        differentiateWithoutColor: Bool,
        source: TextClusterSource = .vision
    ) -> OCRBoundingBoxAppearance {
        if isHighlighted {
            return OCRBoundingBoxAppearance(
                strokeColor: .yellow,
                strokeOpacity: 1,
                fillColor: .yellow.opacity(0.3),
                strokeStyle: StrokeStyle(lineWidth: 3)
            )
        }

        // Each source gets its own pair of direction colors, so a glance tells you
        // both which OCR produced the boxes and which way the text runs. The
        // mokuro pair is separated by roughly the same hue distance as the Vision
        // pair (red/purple 83°, blue/green 76°) to keep the two readings equally
        // easy to tell apart.
        let isVertical = direction == .vertical
        let strokeColor: Color = source == .mokuro
            ? (isVertical ? .red : .purple)
            : (isVertical ? .blue : .green)

        return OCRBoundingBoxAppearance(
            strokeColor: strokeColor,
            strokeOpacity: differentiateWithoutColor ? 1 : 0.8,
            fillColor: nil,
            strokeStyle: StrokeStyle(
                lineWidth: differentiateWithoutColor ? 3 : 2,
                dash: direction == .vertical ? [8, 4] : []
            )
        )
    }
}
