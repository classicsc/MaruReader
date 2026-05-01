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

    @State private var dragZoomBaseline: MangaZoomState?
    @State private var dragZoomTapSuppression = MangaDragZoomTapSuppression()

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
            .gesture(dragZoomGesture(containerSize: containerSize))
            .gesture(
                combinedGesture(containerSize: containerSize)
            )
            .simultaneousGesture(tapGesture(containerSize: containerSize, imageRect: imageRect))
            .accessibilityLabel(MangaLocalization.string("Manga page"))
            .accessibilityHint(MangaLocalization.string("Double-tap to zoom in or reset zoom. Double-tap and hold, then drag up or down to adjust zoom smoothly."))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                viewModel.toggleToolbars()
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
        guard let renderedPage = viewModel.renderedPageCache[pageIndex]
        else {
            return .zero
        }
        return MangaPageContentView.calculateImageRect(image: renderedPage.image, in: containerSize)
    }

    // MARK: - Gesture Handling

    private func combinedGesture(containerSize: CGSize) -> some Gesture {
        let magnificationGesture = MagnifyGesture()
            .onChanged { value in
                let zoom = MangaZoomState(
                    scale: viewModel.lastScale,
                    offset: viewModel.lastOffset
                ).scaled(
                    by: value.magnification,
                    around: Self.adjustedPointForZoom(
                        value.startLocation,
                        containerSize: containerSize,
                        layoutDirection: layoutDirection
                    ),
                    containerSize: containerSize,
                    minScale: minScale,
                    maxScale: maxScale
                )
                applyZoomState(zoom, updateLastState: false)
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
                    let zoom = MangaZoomState(
                        scale: viewModel.scale,
                        offset: viewModel.lastOffset
                    ).panned(
                        by: CGSize(width: horizontalTranslation, height: value.translation.height),
                        containerSize: containerSize
                    )
                    applyZoomState(zoom, updateLastState: false)
                }
            }
            .onEnded { value in
                // If a drag-zoom gesture was active during this drag, the SwiftUI drag
                // also received the same touch sequence; suppress its swipe/pan handling.
                if dragZoomBaseline != nil {
                    return
                }
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

    private func dragZoomGesture(containerSize: CGSize) -> MangaDoubleTapDragZoomGesture {
        MangaDoubleTapDragZoomGesture(
            onChanged: { startLocation, translation in
                let baseline = dragZoomBaseline ?? MangaZoomState(
                    scale: viewModel.scale,
                    offset: viewModel.offset
                )
                if dragZoomBaseline == nil {
                    dragZoomBaseline = baseline
                    dragZoomTapSuppression.activate()
                }
                let zoom = MangaZoomState.dragZoomed(
                    verticalTranslation: translation.height,
                    around: Self.adjustedPointForZoom(
                        startLocation,
                        containerSize: containerSize,
                        layoutDirection: layoutDirection
                    ),
                    fromBaseline: baseline,
                    containerSize: containerSize,
                    minScale: minScale,
                    maxScale: maxScale
                )
                applyZoomState(zoom, updateLastState: false)
            },
            onEnded: { _, _ in
                viewModel.lastScale = viewModel.scale
                viewModel.lastOffset = viewModel.offset
                dragZoomBaseline = nil
            },
            onCancelled: {
                dragZoomBaseline = nil
            }
        )
    }

    private func tapGesture(containerSize: CGSize, imageRect: CGRect) -> some Gesture {
        SpatialTapGesture(count: 2)
            .exclusively(before: SpatialTapGesture(count: 1))
            .onEnded { value in
                if dragZoomTapSuppression.consumeIfNeeded() {
                    return
                }
                switch value {
                case let .first(tap):
                    handleDoubleTap(at: tap.location, containerSize: containerSize)
                case let .second(tap):
                    handleTap(
                        at: tap.location,
                        containerSize: containerSize,
                        imageRect: imageRect
                    )
                }
            }
    }

    private func handleDoubleTap(at tapPoint: CGPoint, containerSize: CGSize) {
        withAnimation(.easeOut(duration: 0.25)) {
            let zoom = MangaZoomState(
                scale: viewModel.scale,
                offset: viewModel.offset
            ).doubleTapped(
                around: Self.adjustedPointForZoom(
                    tapPoint,
                    containerSize: containerSize,
                    layoutDirection: layoutDirection
                ),
                containerSize: containerSize
            )
            applyZoomState(zoom, updateLastState: true)
        }
    }

    private func applyZoomState(_ zoom: MangaZoomState, updateLastState: Bool) {
        viewModel.scale = zoom.scale
        viewModel.offset = zoom.offset

        if updateLastState {
            viewModel.lastScale = zoom.scale
            viewModel.lastOffset = zoom.offset
        }
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

    nonisolated static func adjustedPointForZoom(
        _ point: CGPoint,
        containerSize: CGSize,
        layoutDirection: LayoutDirection
    ) -> CGPoint {
        layoutDirection == .rightToLeft
            ? CGPoint(x: containerSize.width - point.x, y: point.y)
            : point
    }

    // MARK: - Hit Testing

    /// Handles tap by performing hit-testing against cluster bounding boxes
    private func handleTap(
        at tapPoint: CGPoint,
        containerSize: CGSize,
        imageRect: CGRect
    ) {
        // Get clusters from page data
        let clusters = viewModel.renderedPageCache[pageIndex]?.textClusters ?? []

        let hitTestOffset = Self.adjustedOffsetForHitTesting(
            viewModel.offset,
            layoutDirection: layoutDirection
        )
        let untransformed = MangaZoomState(
            scale: viewModel.scale,
            offset: hitTestOffset
        ).untransformedPoint(
            from: tapPoint,
            containerSize: containerSize
        )

        // Check if tap is within the image rect
        guard imageRect.contains(untransformed) else {
            performTapMissAction(tapX: tapPoint.x, containerWidth: containerSize.width)
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
            // Tap inside the image but outside any cluster.
            performTapMissAction(tapX: tapPoint.x, containerWidth: containerSize.width)
        }
    }

    /// Dispatches a single-tap miss to either page navigation or toolbar toggling
    /// based on which third of the container was tapped.
    private func performTapMissAction(tapX: CGFloat, containerWidth: CGFloat) {
        let zone = MangaTapZoneResolver.resolve(
            tapX: tapX,
            containerWidth: containerWidth,
            isAtBaseZoom: viewModel.isAtBaseZoom,
            tapToTurnEnabled: MangaTapNavigationSettings.tapToTurnEnabled,
            readingDirection: viewModel.readingDirection
        )
        switch zone {
        case .previousPage:
            viewModel.goToPreviousPage()
        case .nextPage:
            viewModel.goToNextPage()
        case .toggleToolbars:
            viewModel.toggleToolbars()
        }
    }
}
