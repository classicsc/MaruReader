// OCRImageResultsView.swift
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

import MaruDictionaryUICommon
import MaruReaderCore
import MaruVision
import os
import SwiftUI

/// A reusable view that displays an image with OCR results as tappable bounding boxes.
/// When a text region is tapped, presents a dictionary search sheet.
public struct OCRImageResultsView: View {
    let image: UIImage
    let clusters: [TextCluster]
    let isProcessing: Bool
    /// Re-reads a tapped cluster's lines from their crops before lookup, when set.
    let ocr: OCR?

    /// Whether to show individual observation boxes (for debugging)
    var showObservationBoxes: Bool = false

    @State private var showBoundingBoxes: Bool = false
    @State private var highlightedCluster: TextCluster?
    @State private var selectedCluster: TextCluster?
    @State private var selectedText: Task<String, Never>?
    /// Clusters after a secondary detection added to the ones passed in.
    @State private var detectedClusters: [TextCluster]?
    @State private var secondaryTask: Task<Void, Never>?
    private var allClusters: [TextCluster] {
        detectedClusters ?? clusters
    }

    // Pan-zoom state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    private let logger = Logger.maru(category: "OCRImageResultsView")

    /// Initialize the OCR results view with clusters
    /// - Parameters:
    ///   - image: The image to display
    ///   - clusters: Array of text clusters detected by OCR
    ///   - isProcessing: Whether OCR is currently processing
    ///   - ocr: The recognizer that produced the clusters, used to refine a tapped cluster's text
    ///   - showObservationBoxes: Whether to show individual observation boxes (debug mode)
    public init(
        image: UIImage,
        clusters: [TextCluster],
        isProcessing: Bool = false,
        ocr: OCR? = nil,
        showObservationBoxes: Bool = false
    ) {
        self.image = image
        self.clusters = clusters
        self.isProcessing = isProcessing
        self.ocr = ocr
        self.showObservationBoxes = showObservationBoxes
    }

    public var body: some View {
        GeometryReader { geometry in
            let imageRect = calculateImageRect(image: image, in: geometry.size)

            ZStack {
                Color.black
                    .ignoresSafeArea()

                // Image with bounding box overlay - transforms together
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    // Bounding box overlay
                    if !isProcessing, !allClusters.isEmpty,
                       showBoundingBoxes || highlightedCluster != nil
                    {
                        boundingBoxOverlay(
                            imageRect: imageRect,
                            highlightedClusterID: highlightedCluster?.id,
                            showAllBoxes: showBoundingBoxes
                        )
                    }
                }
                .scaleEffect(scale)
                .offset(offset)

                // Processing overlay (doesn't transform)
                if isProcessing || secondaryTask != nil {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }

                // Empty state overlay (doesn't transform)
                if !isProcessing, allClusters.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No text detected")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
                }
            }
            .contentShape(Rectangle())
            .gesture(combinedGesture(containerSize: geometry.size, imageRect: imageRect))
            .onTapGesture { location in
                handleTap(at: location, containerSize: geometry.size, imageRect: imageRect)
            }
            .onTapGesture(count: 2) {
                // Double-tap to reset zoom/pan
                withAnimation(.easeOut(duration: 0.25)) {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
            }
        }
        .onChange(of: clusters.map(\.id)) {
            secondaryTask?.cancel()
            secondaryTask = nil
            detectedClusters = nil
        }
        .sheet(item: $selectedCluster) { cluster in
            DictionarySearchSheetView(
                searchText: selectedText ?? Task { cluster.transcript },
                contextValues: LookupContextValues(
                    contextInfo: "Scanned image",
                    sourceType: .dictionary
                ),
                accessibilityIdentifier: "ocr.dictionarySheet",
                onDismiss: {
                    selectedCluster = nil
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBoundingBoxes.toggle()
                    }
                } label: {
                    Image(systemName: showBoundingBoxes ? "text.viewfinder" : "viewfinder")
                }
                .accessibilityLabel(showBoundingBoxes ? "Hide text regions" : "Show text regions")
            }
        }
    }

    /// Calculate the actual rect where the image is displayed within the container
    private func calculateImageRect(image: UIImage, in containerSize: CGSize) -> CGRect {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        let imageRect: CGRect
        if imageAspect > containerAspect {
            // Image is wider - fit to width
            let width = containerSize.width
            let height = width / imageAspect
            let yOffset = (containerSize.height - height) / 2
            imageRect = CGRect(x: 0, y: yOffset, width: width, height: height)
        } else {
            // Image is taller - fit to height
            let height = containerSize.height
            let width = height * imageAspect
            let xOffset = (containerSize.width - width) / 2
            imageRect = CGRect(x: xOffset, y: 0, width: width, height: height)
        }

        return imageRect
    }

    /// Calculate the actual rect for a normalized box (lower-left origin) within the image rect
    private func calculateBoxRect(_ normalizedBox: CGRect, in imageRect: CGRect) -> CGRect {
        // Convert normalized coordinates to image coordinates (with upper-left origin)
        let boxInImage = CGRect(
            x: normalizedBox.minX * imageRect.width,
            y: (1 - normalizedBox.maxY) * imageRect.height, // Flip Y for upper-left origin
            width: normalizedBox.width * imageRect.width,
            height: normalizedBox.height * imageRect.height
        )

        // Offset by the image rect's position within the container
        return boxInImage.offsetBy(dx: imageRect.minX, dy: imageRect.minY)
    }

    // MARK: - Bounding Box Overlay

    /// Creates a Canvas overlay that draws bounding boxes with highlight support
    private func boundingBoxOverlay(
        imageRect: CGRect,
        highlightedClusterID: UUID?,
        showAllBoxes: Bool
    ) -> some View {
        Canvas { context, _ in
            for cluster in allClusters {
                let isHighlighted = cluster.id == highlightedClusterID

                if !showAllBoxes, !isHighlighted {
                    continue
                }

                let clusterRect = calculateBoxRect(cluster.boundingBox, in: imageRect)
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

            // Optionally draw individual observation boxes (debug mode)
            if showObservationBoxes {
                for cluster in allClusters {
                    for line in cluster.lines {
                        let boxRect = calculateBoxRect(line.boundingBox, in: imageRect)
                        let path = Path(boxRect)
                        context.stroke(path, with: .color(.orange.opacity(0.5)), lineWidth: 1)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Gesture Handling

    /// Creates the combined pan and zoom gesture
    private func combinedGesture(containerSize: CGSize, imageRect: CGRect) -> some Gesture {
        let magnificationGesture = MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), maxScale)
                // Re-clamp offset when scale changes
                offset = clampOffset(offset, scale: scale, containerSize: containerSize, imageRect: imageRect)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
            }

        let dragGesture = DragGesture()
            .onChanged { value in
                let newOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampOffset(newOffset, scale: scale, containerSize: containerSize, imageRect: imageRect)
            }
            .onEnded { _ in
                lastOffset = offset
            }

        return SimultaneousGesture(magnificationGesture, dragGesture)
    }

    /// Clamps the offset to keep the image within visible bounds
    private func clampOffset(_ proposedOffset: CGSize, scale: CGFloat, containerSize: CGSize, imageRect _: CGRect) -> CGSize {
        // Calculate how much the scaled image extends beyond the container
        let scaledWidth = containerSize.width * scale
        let scaledHeight = containerSize.height * scale

        // Calculate maximum allowed offset in each direction
        // When zoomed in, we can pan up to (scaledSize - containerSize) / 2 in each direction
        let maxOffsetX = max(0, (scaledWidth - containerSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - containerSize.height) / 2)

        return CGSize(
            width: min(max(proposedOffset.width, -maxOffsetX), maxOffsetX),
            height: min(max(proposedOffset.height, -maxOffsetY), maxOffsetY)
        )
    }

    // MARK: - Hit Testing

    /// Handles tap by performing hit-testing against cluster bounding boxes
    private func handleTap(at tapPoint: CGPoint, containerSize: CGSize, imageRect: CGRect) {
        // Apply inverse transform to get the untransformed tap point
        // Transform is: scale around center, then offset
        // Inverse: subtract offset, then unscale around center
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let untransformed = CGPoint(
            x: (tapPoint.x - center.x - offset.width) / scale + center.x,
            y: (tapPoint.y - center.y - offset.height) / scale + center.y
        )

        // Check if tap is within the image rect
        guard imageRect.contains(untransformed) else {
            return
        }

        // Convert to normalized image coordinates (0-1 range)
        // The bounding box uses lower-left origin, so we need to flip Y
        let normalizedX = (untransformed.x - imageRect.minX) / imageRect.width
        let normalizedY = 1.0 - (untransformed.y - imageRect.minY) / imageRect.height

        let point = CGPoint(x: normalizedX, y: normalizedY)
        if let match = allClusters.smallest(containing: point) {
            open(match)
        } else if let ocr, !isProcessing, secondaryTask == nil {
            // Nothing here at page level: look again around the tap at a larger scale.
            secondaryTask = Task {
                defer { secondaryTask = nil }
                guard let found = try? await ocr.secondaryDetection(in: image, around: point, clusters: allClusters),
                      !Task.isCancelled else { return }
                detectedClusters = found
                if let match = found.smallest(containing: point) {
                    open(match)
                }
            }
        }
    }

    private func open(_ match: TextCluster) {
        logger.debug("Tapped cluster with \(match.lines.count) lines: \(match.transcript.prefix(50))...")
        // Start the line re-read now so it overlaps the highlight and sheet animations.
        let text = ocr?.transcript(of: match, in: image) ?? Task { match.transcript }
        Task {
            highlightedCluster = match
            try? await Task.sleep(nanoseconds: 100_000_000)
            selectedText = text
            selectedCluster = match
            highlightedCluster = nil
        }
    }
}
