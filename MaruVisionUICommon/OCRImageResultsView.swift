//
//  OCRImageResultsView.swift
//  MaruReader
//
//  Created by Claude Code on 11/2/25.
//

import MaruDictionaryUICommon
import MaruVision
import os.log
import SwiftUI
import Vision

/// A reusable view that displays an image with OCR results as tappable bounding boxes.
/// When a text region is tapped, presents a dictionary search sheet.
public struct OCRImageResultsView: View {
    let image: UIImage
    let clusters: [TextCluster]
    let isProcessing: Bool

    /// Whether to show individual observation boxes (for debugging)
    var showObservationBoxes: Bool = false

    @State private var selectedCluster: TextCluster?
    @State private var searchSheetViewModel = DictionarySearchViewModel(resultState: .searching)

    // Pan-zoom state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "OCRImageResultsView")

    /// Initialize the OCR results view with clusters
    /// - Parameters:
    ///   - image: The image to display
    ///   - clusters: Array of text clusters detected by OCR
    ///   - isProcessing: Whether OCR is currently processing
    ///   - showObservationBoxes: Whether to show individual observation boxes (debug mode)
    public init(
        image: UIImage,
        clusters: [TextCluster],
        isProcessing: Bool = false,
        showObservationBoxes: Bool = false
    ) {
        self.image = image
        self.clusters = clusters
        self.isProcessing = isProcessing
        self.showObservationBoxes = showObservationBoxes
    }

    public var body: some View {
        GeometryReader { geometry in
            let imageRect = calculateImageRect(image: image, in: geometry.size)

            ZStack {
                // Image with bounding box overlay - transforms together
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    // Bounding box overlay
                    if !isProcessing, !clusters.isEmpty {
                        boundingBoxOverlay(imageRect: imageRect)
                    }
                }
                .scaleEffect(scale)
                .offset(offset)

                // Processing overlay (doesn't transform)
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }

                // Empty state overlay (doesn't transform)
                if !isProcessing, clusters.isEmpty {
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
        .sheet(item: $selectedCluster) { cluster in
            NavigationStack {
                DictionarySearchView()
                    .environment(searchSheetViewModel)
                    .navigationTitle("Dictionary")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                selectedCluster = nil
                            }
                        }
                    }
            }
            .onAppear {
                // Initialize the view model with the cluster's transcript
                searchSheetViewModel.performSearch(cluster.transcript)
            }
            .presentationDetents([.medium, .large])
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

    /// Calculate the actual rect for a cluster's bounding box within the image rect
    private func calculateClusterRect(cluster: TextCluster, in imageRect: CGRect) -> CGRect {
        // Convert normalized coordinates to image coordinates (with upper-left origin)
        // cluster.boundingBox is in normalized coords with lower-left origin
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

    /// Calculate the actual rect for an observation's bounding box within the image rect
    private func calculateBoxRect(observation: RecognizedTextObservation, in imageRect: CGRect) -> CGRect {
        // Convert normalized coordinates to image coordinates (with upper-left origin)
        let boxInImage = observation.boundingBox.toImageCoordinates(imageRect.size, origin: .upperLeft)

        // Offset by the image rect's position within the container
        return boxInImage.offsetBy(dx: imageRect.minX, dy: imageRect.minY)
    }

    // MARK: - Bounding Box Overlay

    /// Creates a Canvas overlay that draws all bounding boxes
    @ViewBuilder
    private func boundingBoxOverlay(imageRect: CGRect) -> some View {
        Canvas { context, _ in
            // Draw cluster boxes (primary hit targets)
            for cluster in clusters {
                let clusterRect = calculateClusterRect(cluster: cluster, in: imageRect)
                let path = Path(clusterRect)

                // Use different colors for different directions
                let color: Color = cluster.direction == .vertical ? .blue : .green
                context.stroke(path, with: .color(color), lineWidth: 2)
            }

            // Optionally draw individual observation boxes (debug mode)
            if showObservationBoxes {
                for cluster in clusters {
                    for observation in cluster.observations {
                        let boxRect = calculateBoxRect(observation: observation, in: imageRect)
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
            logger.debug("Tapped cluster with \(match.observations.count) observations: \(match.transcript.prefix(50))...")
            selectedCluster = match
        }
    }
}
