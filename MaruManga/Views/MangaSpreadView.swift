// MangaSpreadView.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import MaruVision
import SwiftUI

/// A view that displays one or two manga pages as a spread, with unified zoom/pan.
/// Used in landscape mode when spread mode is active.
struct MangaSpreadView: View {
    let spreadItem: SpreadLayout.SpreadItem
    @Bindable var viewModel: MangaReaderViewModel
    @Environment(\.layoutDirection) private var layoutDirection

    // MARK: - Configuration

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let swipeThreshold: CGFloat = 50.0

    // MARK: - Spread Zoom/Pan State

    @State private var spreadScale: CGFloat = 1.0
    @State private var spreadLastScale: CGFloat = 1.0
    @State private var spreadOffset: CGSize = .zero
    @State private var spreadLastOffset: CGSize = .zero

    private var isAtBaseZoom: Bool {
        spreadScale <= 1.01
    }

    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size

            spreadContent(containerSize: containerSize)
                .scaleEffect(spreadScale)
                .offset(spreadOffset)
                .contentShape(Rectangle())
                .gesture(combinedGesture(containerSize: containerSize))
                .onTapGesture(count: 2) {
                    resetSpreadZoom()
                }
                .onTapGesture { location in
                    handleSpreadTap(at: location, containerSize: containerSize)
                }
        }
        .task {
            // Load all pages in this spread
            for pageIndex in spreadItem.pageIndices {
                await viewModel.loadPage(at: pageIndex)
            }
        }
        .onChange(of: viewModel.currentSpreadIndex) { _, _ in
            // Reset zoom when spread changes
            resetSpreadZoom()
        }
    }

    // MARK: - Spread Content

    @ViewBuilder
    private func spreadContent(containerSize: CGSize) -> some View {
        switch spreadItem {
        case let .single(pageIndex):
            // Single page uses full width
            MangaPageContentView(
                pageIndex: pageIndex,
                viewModel: viewModel,
                containerSize: containerSize
            )

        case let .double(leftPageIndex, rightPageIndex):
            // Two pages split the width
            HStack(spacing: 0) {
                MangaPageContentView(
                    pageIndex: leftPageIndex,
                    viewModel: viewModel,
                    containerSize: CGSize(
                        width: containerSize.width / 2,
                        height: containerSize.height
                    )
                )
                .frame(width: containerSize.width / 2)

                MangaPageContentView(
                    pageIndex: rightPageIndex,
                    viewModel: viewModel,
                    containerSize: CGSize(
                        width: containerSize.width / 2,
                        height: containerSize.height
                    )
                )
                .frame(width: containerSize.width / 2)
            }
        }
    }

    // MARK: - Zoom/Pan

    private func resetSpreadZoom() {
        withAnimation(.easeOut(duration: 0.25)) {
            spreadScale = 1.0
            spreadLastScale = 1.0
            spreadOffset = .zero
            spreadLastOffset = .zero
        }
    }

    // MARK: - Gesture Handling

    private func combinedGesture(containerSize: CGSize) -> some Gesture {
        let magnificationGesture = MagnificationGesture()
            .onChanged { value in
                let newScale = spreadLastScale * value
                spreadScale = min(max(newScale, minScale), maxScale)
                spreadOffset = clampOffset(
                    spreadOffset,
                    scale: spreadScale,
                    containerSize: containerSize
                )
            }
            .onEnded { _ in
                spreadLastScale = spreadScale
                spreadLastOffset = spreadOffset
            }

        let dragGesture = DragGesture()
            .onChanged { value in
                if isAtBaseZoom {
                    // At base zoom, drag is tracked for potential swipe
                } else {
                    // When zoomed, drag pans the spread
                    let horizontalTranslation = adjustedHorizontalTranslation(value.translation.width)
                    let newOffset = CGSize(
                        width: spreadLastOffset.width + horizontalTranslation,
                        height: spreadLastOffset.height + value.translation.height
                    )
                    spreadOffset = clampOffset(
                        newOffset,
                        scale: spreadScale,
                        containerSize: containerSize
                    )
                }
            }
            .onEnded { value in
                if isAtBaseZoom {
                    // At base zoom, check for page swipe (horizontal only for spreads)
                    let horizontalDistance = value.translation.width
                    let verticalDistance = abs(value.translation.height)

                    if abs(horizontalDistance) > verticalDistance, abs(horizontalDistance) > swipeThreshold {
                        if horizontalDistance < 0 {
                            // Swipe left
                            if viewModel.readingDirection == .leftToRight {
                                goToNextSpread()
                            } else {
                                goToPreviousSpread()
                            }
                        } else {
                            // Swipe right
                            if viewModel.readingDirection == .leftToRight {
                                goToPreviousSpread()
                            } else {
                                goToNextSpread()
                            }
                        }
                    }
                } else {
                    spreadLastOffset = spreadOffset
                }
            }

        return SimultaneousGesture(magnificationGesture, dragGesture)
    }

    private func adjustedHorizontalTranslation(_ translation: CGFloat) -> CGFloat {
        layoutDirection == .rightToLeft ? -translation : translation
    }

    private func adjustedOffsetForHitTesting(_ offset: CGSize) -> CGSize {
        layoutDirection == .rightToLeft
            ? CGSize(width: -offset.width, height: offset.height)
            : offset
    }

    private func clampOffset(
        _ proposedOffset: CGSize,
        scale: CGFloat,
        containerSize: CGSize
    ) -> CGSize {
        let scaledWidth = containerSize.width * scale
        let scaledHeight = containerSize.height * scale

        let maxOffsetX = max(0, (scaledWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - containerSize.height) / 2)

        return CGSize(
            width: min(max(proposedOffset.width, -maxOffsetX), maxOffsetX),
            height: min(max(proposedOffset.height, -maxOffsetY), maxOffsetY)
        )
    }

    // MARK: - Navigation

    private func goToNextSpread() {
        let nextIndex = viewModel.currentSpreadIndex + 1
        if nextIndex < viewModel.spreadLayout.count {
            viewModel.currentSpreadIndex = nextIndex
        }
    }

    private func goToPreviousSpread() {
        let prevIndex = viewModel.currentSpreadIndex - 1
        if prevIndex >= 0 {
            viewModel.currentSpreadIndex = prevIndex
        }
    }

    // MARK: - Hit Testing

    private func handleSpreadTap(at tapPoint: CGPoint, containerSize: CGSize) {
        let hitTestOffset = adjustedOffsetForHitTesting(spreadOffset)

        // Apply inverse transform to get the untransformed tap point
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let untransformed = CGPoint(
            x: (tapPoint.x - center.x - hitTestOffset.width) / spreadScale + center.x,
            y: (tapPoint.y - center.y - hitTestOffset.height) / spreadScale + center.y
        )

        // Determine which page was tapped and get its local coordinates
        let (targetPageIndex, pageContainerSize, pageLocalPoint) = resolvePageTap(
            untransformedPoint: untransformed,
            containerSize: containerSize
        )

        guard let pageIndex = targetPageIndex else {
            viewModel.toggleToolbars()
            return
        }

        // Get page data and calculate image rect
        guard let pageData = viewModel.pageDataCache[pageIndex],
              let uiImage = UIImage(data: pageData.imageData)
        else {
            viewModel.toggleToolbars()
            return
        }

        let imageRect = MangaPageContentView.calculateImageRect(image: uiImage, in: pageContainerSize)

        // Check if tap is within the image rect
        guard imageRect.contains(pageLocalPoint) else {
            viewModel.toggleToolbars()
            return
        }

        // Convert to normalized image coordinates
        let normalizedX = (pageLocalPoint.x - imageRect.minX) / imageRect.width
        let normalizedY = 1.0 - (pageLocalPoint.y - imageRect.minY) / imageRect.height

        // Find matching cluster
        var bestMatch: TextCluster?
        var bestArea: CGFloat = .infinity

        for cluster in pageData.textClusters {
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
            viewModel.handleClusterTap(match)
        } else {
            viewModel.toggleToolbars()
        }
    }

    /// Resolves which page was tapped and returns the page index, container size, and local point.
    private func resolvePageTap(
        untransformedPoint: CGPoint,
        containerSize: CGSize
    ) -> (pageIndex: Int?, pageContainerSize: CGSize, pageLocalPoint: CGPoint) {
        switch spreadItem {
        case let .single(pageIndex):
            return (pageIndex, containerSize, untransformedPoint)

        case let .double(leftPageIndex, rightPageIndex):
            let halfWidth = containerSize.width / 2
            let pageContainerSize = CGSize(width: halfWidth, height: containerSize.height)

            // In RTL layout, the HStack flips the visual order:
            // - leftPageIndex appears on the VISUAL RIGHT
            // - rightPageIndex appears on the VISUAL LEFT
            let isRTL = layoutDirection == .rightToLeft

            let tappedVisualLeftSide = untransformedPoint.x < halfWidth

            if tappedVisualLeftSide {
                // Tapped visual left side
                let pageIndex = isRTL ? rightPageIndex : leftPageIndex
                return (pageIndex, pageContainerSize, untransformedPoint)
            } else {
                // Tapped visual right side - adjust X to be relative to that page
                let adjustedPoint = CGPoint(
                    x: untransformedPoint.x - halfWidth,
                    y: untransformedPoint.y
                )
                let pageIndex = isRTL ? leftPageIndex : rightPageIndex
                return (pageIndex, pageContainerSize, adjustedPoint)
            }
        }
    }
}
