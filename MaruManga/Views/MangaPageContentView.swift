// MangaPageContentView.swift
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

/// A view that renders a manga page's image and OCR bounding boxes without gestures.
/// Used by both MangaPageView (single page mode) and MangaSpreadView (spread mode).
struct MangaPageContentView: View {
    let pageIndex: Int
    @Bindable var viewModel: MangaReaderViewModel
    let containerSize: CGSize

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        let renderedPage = viewModel.renderedPageCache[pageIndex]
        let loadingState = viewModel.pageLoadingStates[pageIndex] ?? .loading

        ZStack {
            switch loadingState {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded:
                if let renderedPage {
                    let imageRect = Self.calculateImageRect(image: renderedPage.image, in: containerSize)

                    pageContent(
                        image: renderedPage.image,
                        clusters: renderedPage.textClusters,
                        imageRect: imageRect
                    )
                } else {
                    errorView(message: MangaLocalization.string("Failed to decode image"))
                }

            case let .error(message):
                errorView(message: message)
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    // MARK: - Page Content

    private func pageContent(
        image: UIImage,
        clusters: [TextCluster],
        imageRect: CGRect
    ) -> some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: containerSize.width, height: containerSize.height)

            // Bounding box overlay (always show highlighted cluster, optionally show all boxes)
            if viewModel.showBoundingBoxes || viewModel.highlightedCluster != nil, !clusters.isEmpty {
                boundingBoxOverlay(
                    clusters: clusters,
                    imageRect: imageRect,
                    highlightedClusterID: viewModel.highlightedCluster?.id,
                    showAllBoxes: viewModel.showBoundingBoxes
                )
            }
        }
    }

    // MARK: - Bounding Box Overlay

    private func boundingBoxOverlay(
        clusters: [TextCluster],
        imageRect: CGRect,
        highlightedClusterID: UUID?,
        showAllBoxes: Bool
    ) -> some View {
        Canvas { context, _ in
            for cluster in clusters {
                let isHighlighted = cluster.id == highlightedClusterID

                // Skip non-highlighted clusters if we're not showing all boxes
                if !showAllBoxes, !isHighlighted {
                    continue
                }

                let clusterRect = Self.calculateClusterRect(cluster: cluster, in: imageRect)
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

    // MARK: - Coordinate Calculations

    /// Calculate the actual rect where the image is displayed within the container
    nonisolated static func calculateImageRect(image: UIImage, in containerSize: CGSize) -> CGRect {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // Image is wider - fit to width
            let width = containerSize.width
            let height = width / imageAspect
            let yOffset = (containerSize.height - height) / 2
            return CGRect(x: 0, y: yOffset, width: width, height: height)
        } else {
            // Image is taller - fit to height
            let height = containerSize.height
            let width = height * imageAspect
            let xOffset = (containerSize.width - width) / 2
            return CGRect(x: xOffset, y: 0, width: width, height: height)
        }
    }

    /// Calculate the screen rect for a cluster's bounding box within the image rect
    nonisolated static func calculateClusterRect(cluster: TextCluster, in imageRect: CGRect) -> CGRect {
        // Convert normalized coordinates (lower-left origin) to screen coordinates (upper-left origin)
        let normalizedBox = cluster.boundingBox
        let boxInImage = CGRect(
            x: normalizedBox.minX * imageRect.width,
            y: (1 - normalizedBox.maxY) * imageRect.height, // Flip Y for upper-left origin
            width: normalizedBox.width * imageRect.width,
            height: normalizedBox.height * imageRect.height
        )

        // Offset by the image rect's position within the container
        return boxInImage.offsetBy(dx: imageRect.minX, dy: imageRect.minY)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
