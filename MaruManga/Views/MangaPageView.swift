// MangaPageView.swift
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

/// A view that displays a single manga page with zoom/pan and OCR bounding boxes.
/// Used in single-page mode. For spread mode, see MangaSpreadView.
struct MangaPageView: View {
    let pageIndex: Int
    @Bindable var viewModel: MangaReaderViewModel
    @Environment(\.layoutDirection) private var layoutDirection

    // MARK: - Configuration

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let swipeThreshold: CGFloat = 50.0

    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let imageRect = currentImageRect(containerSize: containerSize)

            MangaPageContentView(
                pageIndex: pageIndex,
                viewModel: viewModel,
                containerSize: containerSize
            )
            .scaleEffect(viewModel.scale)
            .offset(viewModel.offset)
            .contentShape(Rectangle())
            .gesture(
                combinedGesture(containerSize: containerSize, imageRect: imageRect)
            )
            .onTapGesture(count: 2) {
                viewModel.resetZoom()
            }
            .onTapGesture { location in
                handleTap(
                    at: location,
                    containerSize: containerSize,
                    imageRect: imageRect
                )
            }
        }
        .ignoresSafeArea()
        .task {
            await viewModel.loadPage(at: pageIndex)
        }
    }

    // MARK: - Image Rect Calculation

    /// Gets the current image rect based on loaded page data.
    private func currentImageRect(containerSize: CGSize) -> CGRect {
        guard let pageData = viewModel.pageDataCache[pageIndex],
              let uiImage = UIImage(data: pageData.imageData)
        else {
            return .zero
        }
        return MangaPageContentView.calculateImageRect(image: uiImage, in: containerSize)
    }

    // MARK: - Gesture Handling

    private func combinedGesture(containerSize: CGSize, imageRect: CGRect) -> some Gesture {
        let magnificationGesture = MagnificationGesture()
            .onChanged { value in
                let newScale = viewModel.lastScale * value
                viewModel.scale = min(max(newScale, minScale), maxScale)
                // Re-clamp offset when scale changes
                viewModel.offset = clampOffset(
                    viewModel.offset,
                    scale: viewModel.scale,
                    containerSize: containerSize,
                    imageRect: imageRect
                )
            }
            .onEnded { _ in
                viewModel.lastScale = viewModel.scale
                viewModel.lastOffset = viewModel.offset
            }

        let dragGesture = DragGesture()
            .onChanged { value in
                if viewModel.isAtBaseZoom {
                    // At base zoom, drag is tracked for potential swipe
                    // Don't update offset - we'll handle swipe on end
                } else {
                    // When zoomed, drag pans the image
                    let horizontalTranslation = Self.adjustedHorizontalTranslation(
                        value.translation.width,
                        layoutDirection: layoutDirection
                    )
                    let newOffset = CGSize(
                        width: viewModel.lastOffset.width + horizontalTranslation,
                        height: viewModel.lastOffset.height + value.translation.height
                    )
                    viewModel.offset = clampOffset(
                        newOffset,
                        scale: viewModel.scale,
                        containerSize: containerSize,
                        imageRect: imageRect
                    )
                }
            }
            .onEnded { value in
                if viewModel.isAtBaseZoom {
                    // At base zoom, check for page swipe
                    let horizontalDistance = value.translation.width
                    let verticalDistance = abs(value.translation.height)

                    // Handle swipe based on reading direction
                    switch viewModel.readingDirection {
                    case .rightToLeft, .leftToRight:
                        // Horizontal modes - only respond to horizontal swipes
                        if abs(horizontalDistance) > verticalDistance, abs(horizontalDistance) > swipeThreshold {
                            if horizontalDistance < 0 {
                                // Swipe left - next page in LTR, previous in RTL
                                if viewModel.readingDirection == .leftToRight {
                                    viewModel.goToNextPage()
                                } else {
                                    viewModel.goToPreviousPage()
                                }
                            } else {
                                // Swipe right - previous page in LTR, next in RTL
                                if viewModel.readingDirection == .leftToRight {
                                    viewModel.goToPreviousPage()
                                } else {
                                    viewModel.goToNextPage()
                                }
                            }
                        }
                    case .vertical:
                        // Vertical mode - respond to vertical swipes
                        let verticalDist = value.translation.height
                        if abs(verticalDist) > abs(horizontalDistance), abs(verticalDist) > swipeThreshold {
                            if verticalDist < 0 {
                                // Swipe up - next page
                                viewModel.goToNextPage()
                            } else {
                                // Swipe down - previous page
                                viewModel.goToPreviousPage()
                            }
                        }
                    }
                } else {
                    // When zoomed, just record the final offset
                    viewModel.lastOffset = viewModel.offset
                }
            }

        return SimultaneousGesture(magnificationGesture, dragGesture)
    }

    // MARK: - Coordinate Calculations

    nonisolated static func adjustedHorizontalTranslation(
        _ translation: CGFloat,
        layoutDirection: LayoutDirection
    ) -> CGFloat {
        layoutDirection == .rightToLeft ? -translation : translation
    }

    nonisolated static func adjustedOffsetForHitTesting(
        _ offset: CGSize,
        layoutDirection: LayoutDirection
    ) -> CGSize {
        layoutDirection == .rightToLeft
            ? CGSize(width: -offset.width, height: offset.height)
            : offset
    }

    /// Clamps the offset to keep the image within visible bounds
    private func clampOffset(
        _ proposedOffset: CGSize,
        scale: CGFloat,
        containerSize: CGSize,
        imageRect _: CGRect
    ) -> CGSize {
        // Calculate how much the scaled image extends beyond the container
        let scaledWidth = containerSize.width * scale
        let scaledHeight = containerSize.height * scale

        // Calculate maximum allowed offset in each direction
        let maxOffsetX = max(0, (scaledWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - containerSize.height) / 2)

        return CGSize(
            width: min(max(proposedOffset.width, -maxOffsetX), maxOffsetX),
            height: min(max(proposedOffset.height, -maxOffsetY), maxOffsetY)
        )
    }

    // MARK: - Hit Testing

    /// Handles tap by performing hit-testing against cluster bounding boxes
    private func handleTap(
        at tapPoint: CGPoint,
        containerSize: CGSize,
        imageRect: CGRect
    ) {
        // Get clusters from page data
        let clusters = viewModel.pageDataCache[pageIndex]?.textClusters ?? []

        let hitTestOffset = Self.adjustedOffsetForHitTesting(
            viewModel.offset,
            layoutDirection: layoutDirection
        )
        // Apply inverse transform to get the untransformed tap point
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let untransformed = CGPoint(
            x: (tapPoint.x - center.x - hitTestOffset.width) / viewModel.scale + center.x,
            y: (tapPoint.y - center.y - hitTestOffset.height) / viewModel.scale + center.y
        )

        // Check if tap is within the image rect
        guard imageRect.contains(untransformed) else {
            viewModel.toggleToolbars()
            return
        }

        // Convert to normalized image coordinates (0-1 range, lower-left origin)
        let normalizedX = (untransformed.x - imageRect.minX) / imageRect.width
        let normalizedY = 1.0 - (untransformed.y - imageRect.minY) / imageRect.height

        // Find the cluster whose bounding box contains this point
        // If multiple match, prefer the smallest (most specific)
        var bestMatch: TextCluster?
        var bestArea: CGFloat = .infinity

        for cluster in clusters {
            let bbox = cluster.boundingBox
            if normalizedX >= bbox.minX, normalizedX <= bbox.maxX,
               normalizedY >= bbox.minY, normalizedY <= bbox.maxY
            {
                let area = bbox.width * bbox.height
                if area < bestArea {
                    bestArea = area
                    bestMatch = cluster
                }
            }
        }

        if let match = bestMatch {
            viewModel.handleClusterTap(match, pageIndex: pageIndex)
        } else {
            // Tap outside clusters toggles toolbar
            viewModel.toggleToolbars()
        }
    }
}
