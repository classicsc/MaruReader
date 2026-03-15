// WebReadingModeOverlay.swift
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

struct WebReadingModeOverlay: View {
    let clusters: [TextCluster]
    let showBoundingBoxes: Bool
    let highlightedCluster: TextCluster?
    let isProcessing: Bool
    let onTap: (CGPoint, CGSize) -> Void

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(tapGesture(in: geometry.size))

                if !isProcessing, !clusters.isEmpty,
                   showBoundingBoxes || highlightedCluster != nil
                {
                    boundingBoxOverlay(in: geometry.size)
                }

                if isProcessing {
                    ProgressView("Scanning...")
                        .padding(12)
                        .background(.clear, in: Capsule())
                        .glassEffect()
                }
            }
        }
    }

    /// Canvas overlay that draws bounding boxes over the viewport.
    /// Normalized OCR coords map directly to view coords (flip Y only).
    private func boundingBoxOverlay(in viewSize: CGSize) -> some View {
        Canvas { context, _ in
            let highlightedID = highlightedCluster?.id

            for cluster in clusters {
                let isHighlighted = cluster.id == highlightedID

                if !showBoundingBoxes, !isHighlighted {
                    continue
                }

                let bbox = cluster.boundingBox
                let clusterRect = CGRect(
                    x: bbox.minX * viewSize.width,
                    y: (1 - bbox.maxY) * viewSize.height,
                    width: bbox.width * viewSize.width,
                    height: bbox.height * viewSize.height
                )
                let path = Path(clusterRect)

                let appearance = OCRBoundingBoxAppearance.make(
                    direction: cluster.direction,
                    isHighlighted: isHighlighted,
                    differentiateWithoutColor: differentiateWithoutColor
                )

                if let fillColor = appearance.fillColor {
                    context.fill(path, with: .color(fillColor))
                }

                context.stroke(
                    path,
                    with: .color(appearance.strokeColor.opacity(appearance.strokeOpacity)),
                    style: appearance.strokeStyle
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func tapGesture(in size: CGSize) -> some Gesture {
        TapGesture()
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                if case let .second(_, drag) = value, let location = drag?.location {
                    onTap(location, size)
                }
            }
    }
}
