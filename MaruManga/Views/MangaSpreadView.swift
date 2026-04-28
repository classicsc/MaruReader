// MangaSpreadView.swift
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

/// A view that displays one or two manga pages as a spread, with unified zoom/pan.
/// Used in landscape mode when spread mode is active.
struct MangaSpreadView: View {
    let spreadItem: SpreadLayout.SpreadItem
    @Bindable var viewModel: MangaReaderViewModel

    // MARK: - Configuration

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    private let swipeThreshold: CGFloat = 50.0

    // MARK: - Spread Zoom/Pan State

    @State private var spreadScale: CGFloat = 1.0
    @State private var spreadLastScale: CGFloat = 1.0
    @State private var spreadOffset: CGSize = .zero
    @State private var spreadLastOffset: CGSize = .zero
    @State private var dragZoomBaseline: MangaZoomState?

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
                .gesture(dragZoomGesture(containerSize: containerSize))
                .gesture(combinedGesture(containerSize: containerSize))
                .simultaneousGesture(tapGesture(containerSize: containerSize))
                .accessibilityLabel(MangaLocalization.string("Manga spread"))
                .accessibilityHint(MangaLocalization.string("Double-tap to zoom in or reset zoom. Double-tap and hold, then drag up or down to adjust zoom smoothly."))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    viewModel.toggleToolbars()
                }
        }
        .ignoresSafeArea()
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
            let pageContainerSize = CGSize(
                width: containerSize.width / 2,
                height: containerSize.height
            )

            HStack(spacing: 0) {
                MangaSpreadSlotView(
                    pageIndex: leftPageIndex,
                    viewModel: viewModel,
                    containerSize: pageContainerSize,
                    horizontalPlacement: .trailing
                )

                MangaSpreadSlotView(
                    pageIndex: rightPageIndex,
                    viewModel: viewModel,
                    containerSize: pageContainerSize,
                    horizontalPlacement: .leading
                )
            }
            .environment(\.layoutDirection, .leftToRight)
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

    private func dragZoomGesture(containerSize: CGSize) -> MangaDoubleTapDragZoomGesture {
        MangaDoubleTapDragZoomGesture(
            onChanged: { startLocation, translation in
                let baseline = dragZoomBaseline ?? MangaZoomState(
                    scale: spreadScale,
                    offset: spreadOffset
                )
                if dragZoomBaseline == nil {
                    dragZoomBaseline = baseline
                }
                let zoom = MangaZoomState.dragZoomed(
                    verticalTranslation: translation.height,
                    around: Self.adjustedPointForZoom(
                        startLocation,
                        containerSize: containerSize,
                        readingDirection: viewModel.readingDirection
                    ),
                    fromBaseline: baseline,
                    containerSize: containerSize,
                    minScale: minScale,
                    maxScale: maxScale
                )
                applySpreadZoomState(zoom, updateLastState: false)
            },
            onEnded: { _, _ in
                spreadLastScale = spreadScale
                spreadLastOffset = spreadOffset
                dragZoomBaseline = nil
            },
            onCancelled: {
                dragZoomBaseline = nil
            }
        )
    }

    private func combinedGesture(containerSize: CGSize) -> some Gesture {
        let magnificationGesture = MagnifyGesture()
            .onChanged { value in
                let zoom = MangaZoomState(
                    scale: spreadLastScale,
                    offset: spreadLastOffset
                ).scaled(
                    by: value.magnification,
                    around: Self.adjustedPointForZoom(
                        value.startLocation,
                        containerSize: containerSize,
                        readingDirection: viewModel.readingDirection
                    ),
                    containerSize: containerSize,
                    minScale: minScale,
                    maxScale: maxScale
                )
                applySpreadZoomState(zoom, updateLastState: false)
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
                    let horizontalTranslation = Self.adjustedHorizontalTranslation(
                        value.translation.width,
                        readingDirection: viewModel.readingDirection
                    )
                    let zoom = MangaZoomState(
                        scale: spreadScale,
                        offset: spreadLastOffset
                    ).panned(
                        by: CGSize(width: horizontalTranslation, height: value.translation.height),
                        containerSize: containerSize
                    )
                    applySpreadZoomState(zoom, updateLastState: false)
                }
            }
            .onEnded { value in
                if dragZoomBaseline != nil {
                    return
                }
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

    private func tapGesture(containerSize: CGSize) -> some Gesture {
        SpatialTapGesture(count: 2)
            .exclusively(before: SpatialTapGesture(count: 1))
            .onEnded { value in
                switch value {
                case let .first(tap):
                    handleSpreadDoubleTap(at: tap.location, containerSize: containerSize)
                case let .second(tap):
                    handleSpreadTap(at: tap.location, containerSize: containerSize)
                }
            }
    }

    private func handleSpreadDoubleTap(at tapPoint: CGPoint, containerSize: CGSize) {
        withAnimation(.easeOut(duration: 0.25)) {
            let zoom = MangaZoomState(
                scale: spreadScale,
                offset: spreadOffset
            ).doubleTapped(
                around: Self.adjustedPointForZoom(
                    tapPoint,
                    containerSize: containerSize,
                    readingDirection: viewModel.readingDirection
                ),
                containerSize: containerSize
            )
            applySpreadZoomState(zoom, updateLastState: true)
        }
    }

    private func applySpreadZoomState(_ zoom: MangaZoomState, updateLastState: Bool) {
        spreadScale = zoom.scale
        spreadOffset = zoom.offset

        if updateLastState {
            spreadLastScale = zoom.scale
            spreadLastOffset = zoom.offset
        }
    }

    nonisolated static func adjustedHorizontalTranslation(
        _ translation: CGFloat,
        readingDirection: MangaReadingDirection
    ) -> CGFloat {
        readingDirection == .rightToLeft ? -translation : translation
    }

    nonisolated static func adjustedOffsetForHitTesting(
        _ offset: CGSize,
        readingDirection: MangaReadingDirection
    ) -> CGSize {
        readingDirection == .rightToLeft
            ? CGSize(width: -offset.width, height: offset.height)
            : offset
    }

    nonisolated static func adjustedPointForZoom(
        _ point: CGPoint,
        containerSize: CGSize,
        readingDirection: MangaReadingDirection
    ) -> CGPoint {
        readingDirection == .rightToLeft
            ? CGPoint(x: containerSize.width - point.x, y: point.y)
            : point
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
        let hitTestOffset = Self.adjustedOffsetForHitTesting(
            spreadOffset,
            readingDirection: viewModel.readingDirection
        )

        let untransformed = MangaZoomState(
            scale: spreadScale,
            offset: hitTestOffset
        ).untransformedPoint(
            from: tapPoint,
            containerSize: containerSize
        )

        // Determine which page was tapped and get its local coordinates
        let resolvedTap = MangaSpreadPageResolver.resolvePageTap(
            spreadItem: spreadItem,
            untransformedPoint: untransformed,
            containerSize: containerSize
        )

        guard let pageIndex = resolvedTap.pageIndex else {
            performSpreadTapMissAction(tapX: tapPoint.x, containerWidth: containerSize.width)
            return
        }

        // Get page data and calculate image rect
        guard let renderedPage = viewModel.renderedPageCache[pageIndex]
        else {
            performSpreadTapMissAction(tapX: tapPoint.x, containerWidth: containerSize.width)
            return
        }

        let imageRect = MangaPageContentView.calculateImageRect(
            image: renderedPage.image,
            in: resolvedTap.pageContainerSize,
            horizontalPlacement: resolvedTap.pagePlacement
        )

        // Check if tap is within the image rect
        guard imageRect.contains(resolvedTap.pageLocalPoint) else {
            performSpreadTapMissAction(tapX: tapPoint.x, containerWidth: containerSize.width)
            return
        }

        // Convert to normalized image coordinates
        let normalizedX = (resolvedTap.pageLocalPoint.x - imageRect.minX) / imageRect.width
        let normalizedY = 1.0 - (resolvedTap.pageLocalPoint.y - imageRect.minY) / imageRect.height

        // Find matching cluster
        var bestMatch: TextCluster?
        var bestArea: CGFloat = .infinity

        for cluster in renderedPage.textClusters {
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
            performSpreadTapMissAction(tapX: tapPoint.x, containerWidth: containerSize.width)
        }
    }

    /// Dispatches a single-tap miss across the entire spread container to either
    /// spread navigation or toolbar toggling, based on which third was tapped.
    private func performSpreadTapMissAction(tapX: CGFloat, containerWidth: CGFloat) {
        let zone = MangaTapZoneResolver.resolve(
            tapX: tapX,
            containerWidth: containerWidth,
            isAtBaseZoom: isAtBaseZoom,
            tapToTurnEnabled: MangaTapNavigationSettings.tapToTurnEnabled,
            readingDirection: viewModel.readingDirection
        )
        switch zone {
        case .previousPage:
            goToPreviousSpread()
        case .nextPage:
            goToNextSpread()
        case .toggleToolbars:
            viewModel.toggleToolbars()
        }
    }
}
