//
//  TextClustering.swift
//  MaruReader
//
//  Created by Claude on 12/30/25.
//

import CoreGraphics
import Foundation
import os.log
import Vision

// MARK: - Text Direction

/// Inferred text direction based on spatial analysis of the observation.
/// Note: This is distinct from RecognizedTextObservation.Direction (iOS 26+)
/// which we found unreliable for Japanese text.
public enum InferredTextDirection: Sendable {
    /// Horizontal text, read left-to-right (or right-to-left for RTL languages)
    case horizontal
    /// Vertical text, read top-to-bottom, columns flow right-to-left (tategaki)
    case vertical
}

// MARK: - Observation Features

/// Extracted features from a RecognizedTextObservation used for clustering decisions.
public struct ObservationFeatures: Sendable {
    /// The original observation
    public let observation: RecognizedTextObservation

    /// Inferred text direction based on bounding box shape
    public let direction: InferredTextDirection

    /// Estimated line height (character size proxy)
    /// For horizontal text: bounding box height
    /// For vertical text: bounding box width
    public let lineHeight: CGFloat

    /// The center point of the bounding box in normalized coordinates (0-1)
    public let centroid: CGPoint

    /// Bounding box in normalized coordinates (lower-left origin)
    public let boundingBox: NormalizedRect

    /// Reading order key for sorting.
    /// For horizontal text: (y descending, x ascending) - top-to-bottom, left-to-right
    /// For vertical text: (x descending, y descending) - right-to-left columns, top-to-bottom within column
    public var readingOrderKey: (primary: CGFloat, secondary: CGFloat) {
        switch direction {
        case .horizontal:
            // Sort by Y descending (top first in normalized coords means higher Y),
            // then X ascending
            (primary: -centroid.y, secondary: centroid.x)
        case .vertical:
            // Sort by X descending (rightmost column first),
            // then Y descending (top of column first)
            (primary: -centroid.x, secondary: -centroid.y)
        }
    }

    public init(observation: RecognizedTextObservation) {
        self.observation = observation
        boundingBox = observation.boundingBox

        let box = boundingBox.cgRect
        centroid = CGPoint(x: box.midX, y: box.midY)

        // Infer direction using character-count-aware heuristic
        direction = Self.inferDirection(boundingBox: box, transcript: observation.transcript)
        lineHeight = direction == .vertical ? box.width : box.height
    }

    /// Infers text direction by comparing actual aspect ratio to expected ratios
    /// for both vertical and horizontal orientations given the character count.
    private static func inferDirection(boundingBox box: CGRect, transcript: String) -> InferredTextDirection {
        let aspectRatio = box.width / box.height

        // Strong priors for extreme aspect ratios (unambiguous cases)
        if aspectRatio < 0.25 {
            return .vertical // Definitely tall and narrow
        }
        if aspectRatio > 4.0 {
            return .horizontal // Definitely wide and short
        }

        // For ambiguous cases, use character count to determine best fit
        // Japanese characters are roughly square, so:
        // - Vertical text with N chars → expected aspect ratio ≈ 1/N
        // - Horizontal text with N chars → expected aspect ratio ≈ N
        let charCount = CGFloat(max(1, transcript.count))

        let expectedVerticalRatio = 1.0 / charCount
        let expectedHorizontalRatio = charCount

        // Compare using log scale for symmetric comparison of ratios
        // (being 2x too wide is as bad as being 2x too narrow)
        let verticalFit = abs(log(aspectRatio) - log(expectedVerticalRatio))
        let horizontalFit = abs(log(aspectRatio) - log(expectedHorizontalRatio))

        // Add a small bias toward vertical for Japanese content (manga/books)
        // This helps borderline cases where both fits are similar
        let verticalBias: CGFloat = 0.3

        return (verticalFit - verticalBias) < horizontalFit ? .vertical : .horizontal
    }
}

// MARK: - Text Cluster

/// A group of related text observations that should be treated as a unit.
public struct TextCluster: Identifiable, Sendable {
    public let id = UUID()

    /// The observations in this cluster, sorted by reading order
    public let observations: [RecognizedTextObservation]

    /// The dominant text direction of this cluster
    public let direction: InferredTextDirection

    /// Combined bounding box encompassing all observations (normalized coordinates)
    public let boundingBox: CGRect

    /// The concatenated transcript of all observations
    public var transcript: String {
        // For vertical text, observations are in column order (right-to-left),
        // and each observation is a vertical line. No separator needed.
        // For horizontal text, observations are lines. Join with newlines for
        // paragraph structure, though the dictionary search will handle segmentation.
        observations.map(\.transcript).joined(separator: direction == .vertical ? "" : "\n")
    }

    public init(observations: [RecognizedTextObservation], direction: InferredTextDirection) {
        self.observations = observations
        self.direction = direction

        // Calculate union of all bounding boxes
        if let first = observations.first {
            var union = first.boundingBox.cgRect
            for obs in observations.dropFirst() {
                union = union.union(obs.boundingBox.cgRect)
            }
            boundingBox = union
        } else {
            boundingBox = .zero
        }
    }
}

// MARK: - Clustering Configuration

/// Configuration parameters for the clustering algorithm.
/// Adjust these to tune clustering behavior for different content types.
public struct ClusteringConfiguration: Sendable {
    /// Maximum ratio difference in line heights to consider observations related.
    /// 0.7 means lines must be within 70% of each other's height.
    public var lineHeightTolerance: CGFloat

    /// Maximum gap between observations as a multiple of line height.
    /// For horizontal text: vertical gap between lines
    /// For vertical text: horizontal gap between columns
    public var maxGapMultiplier: CGFloat

    /// Minimum overlap ratio for observations to be considered aligned.
    /// For horizontal text: horizontal overlap
    /// For vertical text: vertical overlap
    public var minAlignmentOverlap: CGFloat

    /// Default configuration tuned for Japanese book/manga content
    public static let `default` = ClusteringConfiguration(
        lineHeightTolerance: 0.6,
        maxGapMultiplier: 2.0,
        minAlignmentOverlap: 0.3
    )

    /// Configuration for dense text (books, articles)
    public static let denseText = ClusteringConfiguration(
        lineHeightTolerance: 0.7,
        maxGapMultiplier: 1.5,
        minAlignmentOverlap: 0.4
    )

    /// Configuration for sparse/varied layouts (signs, mixed content)
    public static let sparse = ClusteringConfiguration(
        lineHeightTolerance: 0.5,
        maxGapMultiplier: 1.0,
        minAlignmentOverlap: 0.5
    )

    public init(lineHeightTolerance: CGFloat, maxGapMultiplier: CGFloat, minAlignmentOverlap: CGFloat) {
        self.lineHeightTolerance = lineHeightTolerance
        self.maxGapMultiplier = maxGapMultiplier
        self.minAlignmentOverlap = minAlignmentOverlap
    }
}

// MARK: - Text Clusterer

/// Clusters related text observations based on spatial relationships and visual features.
public struct TextClusterer: Sendable {
    public let configuration: ClusteringConfiguration
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "TextClusterer")

    public init(configuration: ClusteringConfiguration = .default) {
        self.configuration = configuration
    }

    /// Clusters the given observations into related groups.
    /// - Parameter observations: Array of recognized text observations
    /// - Returns: Array of text clusters, each containing related observations
    public func cluster(_ observations: [RecognizedTextObservation]) -> [TextCluster] {
        guard !observations.isEmpty else { return [] }

        // Extract features for all observations
        let features = observations.map { ObservationFeatures(observation: $0) }

        // Group by direction first
        let byDirection = Dictionary(grouping: features) { $0.direction }

        var clusters: [TextCluster] = []

        for (direction, directionFeatures) in byDirection {
            // Sort by reading order
            let sorted = directionFeatures.sorted { a, b in
                if a.readingOrderKey.primary != b.readingOrderKey.primary {
                    return a.readingOrderKey.primary < b.readingOrderKey.primary
                }
                return a.readingOrderKey.secondary < b.readingOrderKey.secondary
            }

            // Build clusters by merging adjacent compatible observations
            var currentCluster: [ObservationFeatures] = []

            for feature in sorted {
                if currentCluster.isEmpty {
                    currentCluster = [feature]
                } else if shouldMerge(currentCluster: currentCluster, candidate: feature) {
                    currentCluster.append(feature)
                } else {
                    // Finalize current cluster and start new one
                    clusters.append(TextCluster(
                        observations: currentCluster.map(\.observation),
                        direction: direction
                    ))
                    currentCluster = [feature]
                }
            }

            // Don't forget the last cluster
            if !currentCluster.isEmpty {
                clusters.append(TextCluster(
                    observations: currentCluster.map(\.observation),
                    direction: direction
                ))
            }
        }

        logger.debug("Clustered \(observations.count) observations into \(clusters.count) clusters")
        return clusters
    }

    /// Determines whether a candidate observation should be merged into the current cluster.
    private func shouldMerge(currentCluster: [ObservationFeatures], candidate: ObservationFeatures) -> Bool {
        // Compare with the last observation in the cluster (most recent in reading order)
        guard let last = currentCluster.last else { return true }

        // Must have same direction (already guaranteed by grouping, but defensive)
        guard last.direction == candidate.direction else { return false }

        // Check line height similarity (font size proxy)
        let heightRatio = min(last.lineHeight, candidate.lineHeight) / max(last.lineHeight, candidate.lineHeight)
        guard heightRatio >= configuration.lineHeightTolerance else { return false }

        // Check spatial proximity and alignment based on direction
        switch last.direction {
        case .horizontal:
            return checkHorizontalMerge(last: last, candidate: candidate)
        case .vertical:
            return checkVerticalMerge(last: last, candidate: candidate)
        }
    }

    /// Check merge criteria for horizontal text (lines stacked vertically)
    private func checkHorizontalMerge(last: ObservationFeatures, candidate: ObservationFeatures) -> Bool {
        let lastBox = last.boundingBox.cgRect
        let candidateBox = candidate.boundingBox.cgRect

        // Calculate vertical gap (candidate should be below last in reading order)
        // In normalized coords (lower-left origin), "below" means smaller Y
        let verticalGap = lastBox.minY - candidateBox.maxY

        // Gap should be positive (candidate below) and within threshold
        let maxGap = max(last.lineHeight, candidate.lineHeight) * configuration.maxGapMultiplier
        guard verticalGap >= -last.lineHeight * 0.3, // Allow slight overlap
              verticalGap <= maxGap
        else { return false }

        // Check horizontal alignment (significant overlap in X axis)
        let overlapStart = max(lastBox.minX, candidateBox.minX)
        let overlapEnd = min(lastBox.maxX, candidateBox.maxX)
        let overlapWidth = overlapEnd - overlapStart

        guard overlapWidth > 0 else { return false }

        let minWidth = min(lastBox.width, candidateBox.width)
        let overlapRatio = overlapWidth / minWidth

        return overlapRatio >= configuration.minAlignmentOverlap
    }

    /// Check merge criteria for vertical text (columns arranged horizontally, right-to-left)
    private func checkVerticalMerge(last: ObservationFeatures, candidate: ObservationFeatures) -> Bool {
        let lastBox = last.boundingBox.cgRect
        let candidateBox = candidate.boundingBox.cgRect

        // For vertical text, columns flow right-to-left
        // "Next" column is to the left (smaller X)
        let horizontalGap = lastBox.minX - candidateBox.maxX

        // Gap should be positive (candidate to the left) and within threshold
        let maxGap = max(last.lineHeight, candidate.lineHeight) * configuration.maxGapMultiplier
        guard horizontalGap >= -last.lineHeight * 0.3, // Allow slight overlap
              horizontalGap <= maxGap
        else { return false }

        // Check vertical alignment (significant overlap in Y axis)
        let overlapStart = max(lastBox.minY, candidateBox.minY)
        let overlapEnd = min(lastBox.maxY, candidateBox.maxY)
        let overlapHeight = overlapEnd - overlapStart

        guard overlapHeight > 0 else { return false }

        let minHeight = min(lastBox.height, candidateBox.height)
        let overlapRatio = overlapHeight / minHeight

        return overlapRatio >= configuration.minAlignmentOverlap
    }
}

// MARK: - Convenience Extensions

public extension [RecognizedTextObservation] {
    /// Clusters these observations using the default configuration.
    func clustered(using configuration: ClusteringConfiguration = .default) -> [TextCluster] {
        TextClusterer(configuration: configuration).cluster(self)
    }
}
