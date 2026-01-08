//
//  MangaPageView.swift
//  MaruManga
//

import MaruVision
import SwiftUI

/// A view that displays a single manga page with zoom/pan and OCR bounding boxes.
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
            let pageData = viewModel.pageDataCache[pageIndex]
            let loadingState = viewModel.pageLoadingStates[pageIndex] ?? .loading

            ZStack {
                switch loadingState {
                case .loading:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .loaded:
                    if let pageData, let uiImage = UIImage(data: pageData.imageData) {
                        let imageRect = calculateImageRect(image: uiImage, in: geometry.size)

                        pageContent(
                            image: uiImage,
                            clusters: pageData.textClusters,
                            imageRect: imageRect,
                            containerSize: geometry.size
                        )
                    } else {
                        errorView(message: "Failed to decode image")
                    }

                case let .error(message):
                    errorView(message: message)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await viewModel.loadPage(at: pageIndex)
        }
    }

    // MARK: - Page Content

    @ViewBuilder
    private func pageContent(
        image: UIImage,
        clusters: [TextCluster],
        imageRect: CGRect,
        containerSize: CGSize
    ) -> some View {
        ZStack(alignment: .topLeading) {
            // Image with bounding box overlay - transforms together
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
            .scaleEffect(viewModel.scale)
            .offset(viewModel.offset)
        }
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
                clusters: clusters,
                containerSize: containerSize,
                imageRect: imageRect
            )
        }
    }

    // MARK: - Bounding Box Overlay

    @ViewBuilder
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

                let clusterRect = calculateClusterRect(cluster: cluster, in: imageRect)
                let path = Path(clusterRect)

                // Color based on text direction and highlight state
                let strokeColor: Color
                let fillColor: Color?

                if isHighlighted {
                    strokeColor = .yellow
                    fillColor = .yellow.opacity(0.3)
                } else {
                    strokeColor = cluster.direction == .vertical ? .blue : .green
                    fillColor = nil
                }

                // Fill if highlighted
                if let fillColor {
                    context.fill(path, with: .color(fillColor))
                }

                // Stroke
                context.stroke(
                    path,
                    with: .color(strokeColor.opacity(0.8)),
                    lineWidth: isHighlighted ? 3 : 2
                )
            }
        }
        .allowsHitTesting(false)
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

    /// Calculate the actual rect where the image is displayed within the container
    private func calculateImageRect(image: UIImage, in containerSize: CGSize) -> CGRect {
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
    private func calculateClusterRect(cluster: TextCluster, in imageRect: CGRect) -> CGRect {
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
        clusters: [TextCluster],
        containerSize: CGSize,
        imageRect: CGRect
    ) {
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
            viewModel.handleClusterTap(match)
        } else {
            // Tap outside clusters toggles toolbar
            viewModel.toggleToolbars()
        }
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
