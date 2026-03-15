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
        differentiateWithoutColor: Bool
    ) -> OCRBoundingBoxAppearance {
        if isHighlighted {
            return OCRBoundingBoxAppearance(
                strokeColor: .yellow,
                strokeOpacity: 1,
                fillColor: .yellow.opacity(0.3),
                strokeStyle: StrokeStyle(lineWidth: 3)
            )
        }

        return OCRBoundingBoxAppearance(
            strokeColor: direction == .vertical ? .blue : .green,
            strokeOpacity: differentiateWithoutColor ? 1 : 0.8,
            fillColor: nil,
            strokeStyle: StrokeStyle(
                lineWidth: differentiateWithoutColor ? 3 : 2,
                dash: direction == .vertical ? [8, 4] : []
            )
        )
    }
}
