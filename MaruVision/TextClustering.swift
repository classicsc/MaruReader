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
public enum InferredTextDirection: Sendable, CustomStringConvertible {
    /// Horizontal text, read left-to-right (or right-to-left for RTL languages)
    case horizontal
    /// Vertical text, read top-to-bottom, columns flow right-to-left (tategaki)
    case vertical

    public var description: String {
        switch self {
        case .horizontal: "H"
        case .vertical: "V"
        }
    }
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

    /// Aspect ratio of the bounding box (width / height)
    public let aspectRatio: CGFloat

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

    /// Short identifier for logging
    public var debugID: String {
        let preview = observation.transcript.prefix(8)
        return "[\(direction)|\(preview)]"
    }

    /// Detailed debug description
    public var debugDescription: String {
        let box = boundingBox.cgRect
        return """
        \(debugID) chars=\(observation.transcript.count) \
        ar=\(String(format: "%.2f", aspectRatio)) \
        lh=\(String(format: "%.4f", lineHeight)) \
        box=(x:\(String(format: "%.3f", box.minX))-\(String(format: "%.3f", box.maxX)), \
        y:\(String(format: "%.3f", box.minY))-\(String(format: "%.3f", box.maxY))) \
        center=(\(String(format: "%.3f", centroid.x)),\(String(format: "%.3f", centroid.y)))
        """
    }

    public init(observation: RecognizedTextObservation) {
        self.observation = observation
        boundingBox = observation.boundingBox

        let box = boundingBox.cgRect
        centroid = CGPoint(x: box.midX, y: box.midY)
        aspectRatio = box.width / box.height

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

    /// Enable verbose debug logging
    public var verboseLogging: Bool

    /// Default configuration tuned for Japanese book/manga content
    public static let `default` = ClusteringConfiguration(
        lineHeightTolerance: 0.6,
        maxGapMultiplier: 2.0,
        minAlignmentOverlap: 0.3,
        verboseLogging: false
    )

    /// Configuration for dense text (books, articles)
    public static let denseText = ClusteringConfiguration(
        lineHeightTolerance: 0.7,
        maxGapMultiplier: 1.5,
        minAlignmentOverlap: 0.4,
        verboseLogging: false
    )

    /// Configuration for sparse/varied layouts (signs, mixed content)
    public static let sparse = ClusteringConfiguration(
        lineHeightTolerance: 0.5,
        maxGapMultiplier: 1.0,
        minAlignmentOverlap: 0.5,
        verboseLogging: false
    )

    /// Debug configuration with verbose logging enabled
    public static let debug = ClusteringConfiguration(
        lineHeightTolerance: 0.6,
        maxGapMultiplier: 2.0,
        minAlignmentOverlap: 0.3,
        verboseLogging: true
    )

    public init(
        lineHeightTolerance: CGFloat,
        maxGapMultiplier: CGFloat,
        minAlignmentOverlap: CGFloat,
        verboseLogging: Bool = false
    ) {
        self.lineHeightTolerance = lineHeightTolerance
        self.maxGapMultiplier = maxGapMultiplier
        self.minAlignmentOverlap = minAlignmentOverlap
        self.verboseLogging = verboseLogging
    }
}

// MARK: - Merge Rejection Reason

/// Describes why two observations were not merged.
enum MergeRejectionReason: CustomStringConvertible {
    case directionMismatch
    case lineHeightMismatch(ratio: CGFloat, threshold: CGFloat)
    case gapTooLarge(gap: CGFloat, maxGap: CGFloat)
    case gapTooNegative(gap: CGFloat, minGap: CGFloat)
    case noOverlap
    case insufficientOverlap(ratio: CGFloat, threshold: CGFloat)

    var description: String {
        switch self {
        case .directionMismatch:
            "direction mismatch"
        case let .lineHeightMismatch(ratio, threshold):
            "lineHeight ratio \(String(format: "%.2f", ratio)) < threshold \(String(format: "%.2f", threshold))"
        case let .gapTooLarge(gap, maxGap):
            "gap \(String(format: "%.4f", gap)) > maxGap \(String(format: "%.4f", maxGap))"
        case let .gapTooNegative(gap, minGap):
            "gap \(String(format: "%.4f", gap)) < minGap \(String(format: "%.4f", minGap))"
        case .noOverlap:
            "no overlap"
        case let .insufficientOverlap(ratio, threshold):
            "overlap ratio \(String(format: "%.2f", ratio)) < threshold \(String(format: "%.2f", threshold))"
        }
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

        if configuration.verboseLogging {
            logger.debug("=== CLUSTERING \(observations.count) OBSERVATIONS ===")
            logger.debug("Config: heightTol=\(configuration.lineHeightTolerance) gapMult=\(configuration.maxGapMultiplier) minOverlap=\(configuration.minAlignmentOverlap)")
            logger.debug("--- ALL OBSERVATIONS ---")
            for (idx, feature) in features.enumerated() {
                logger.debug("  #\(idx): \(feature.debugDescription)")
            }
        }

        // Group by direction first
        let byDirection = Dictionary(grouping: features) { $0.direction }

        if configuration.verboseLogging {
            let verticalCount = byDirection[.vertical]?.count ?? 0
            let horizontalCount = byDirection[.horizontal]?.count ?? 0
            logger.debug("Direction groups: V=\(verticalCount) H=\(horizontalCount)")
        }

        var clusters: [TextCluster] = []

        for (direction, directionFeatures) in byDirection {
            if configuration.verboseLogging {
                logger.debug("--- PROCESSING \(direction) GROUP (\(directionFeatures.count) obs) ---")
            }

            // Sort by reading order
            let sorted = directionFeatures.sorted { a, b in
                if a.readingOrderKey.primary != b.readingOrderKey.primary {
                    return a.readingOrderKey.primary < b.readingOrderKey.primary
                }
                return a.readingOrderKey.secondary < b.readingOrderKey.secondary
            }

            if configuration.verboseLogging {
                logger.debug("Reading order:")
                for (idx, feature) in sorted.enumerated() {
                    logger.debug("  \(idx): \(feature.debugID) key=(\(String(format: "%.3f", feature.readingOrderKey.primary)), \(String(format: "%.3f", feature.readingOrderKey.secondary)))")
                }
            }

            // Build clusters by merging adjacent compatible observations
            var currentCluster: [ObservationFeatures] = []
            var clusterIndex = 0

            for (idx, feature) in sorted.enumerated() {
                if currentCluster.isEmpty {
                    currentCluster = [feature]
                    if configuration.verboseLogging {
                        logger.debug("Cluster \(clusterIndex): Starting with \(feature.debugID)")
                    }
                } else {
                    let mergeResult = shouldMergeWithReason(currentCluster: currentCluster, candidate: feature)
                    if mergeResult.shouldMerge {
                        currentCluster.append(feature)
                        if configuration.verboseLogging {
                            logger.debug("Cluster \(clusterIndex): + \(feature.debugID) (merged)")
                        }
                    } else {
                        if configuration.verboseLogging {
                            let last = currentCluster.last!
                            logger.debug("Cluster \(clusterIndex): ✗ \(feature.debugID) REJECTED: \(mergeResult.reason?.description ?? "unknown")")
                            logger.debug("  Comparing: \(last.debugID) → \(feature.debugID)")
                            logDetailedComparison(last: last, candidate: feature)
                        }
                        // Finalize current cluster and start new one
                        clusters.append(TextCluster(
                            observations: currentCluster.map(\.observation),
                            direction: direction
                        ))
                        clusterIndex += 1
                        currentCluster = [feature]
                        if configuration.verboseLogging {
                            logger.debug("Cluster \(clusterIndex): Starting with \(feature.debugID)")
                        }
                    }
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

        if configuration.verboseLogging {
            logger.debug("=== RESULT: \(clusters.count) CLUSTERS ===")
            for (idx, cluster) in clusters.enumerated() {
                let transcriptPreview = cluster.transcript.prefix(30).replacingOccurrences(of: "\n", with: "↵")
                logger.debug("  Cluster \(idx) [\(cluster.direction)]: \(cluster.observations.count) obs, \"\(transcriptPreview)...\"")
            }
        } else {
            logger.debug("Clustered \(observations.count) observations into \(clusters.count) clusters")
        }

        return clusters
    }

    /// Logs detailed comparison data for debugging merge failures
    private func logDetailedComparison(last: ObservationFeatures, candidate: ObservationFeatures) {
        let lastBox = last.boundingBox.cgRect
        let candidateBox = candidate.boundingBox.cgRect

        let heightRatio = min(last.lineHeight, candidate.lineHeight) / max(last.lineHeight, candidate.lineHeight)
        logger.debug("  LineHeight: last=\(String(format: "%.4f", last.lineHeight)) cand=\(String(format: "%.4f", candidate.lineHeight)) ratio=\(String(format: "%.2f", heightRatio)) (need ≥\(String(format: "%.2f", configuration.lineHeightTolerance)))")

        switch last.direction {
        case .vertical:
            let horizontalGap = lastBox.minX - candidateBox.maxX
            let maxGap = max(last.lineHeight, candidate.lineHeight) * configuration.maxGapMultiplier
            let minGap = -last.lineHeight * 0.3
            logger.debug("  HorizGap: \(String(format: "%.4f", horizontalGap)) (need \(String(format: "%.4f", minGap)) to \(String(format: "%.4f", maxGap)))")

            let overlapStart = max(lastBox.minY, candidateBox.minY)
            let overlapEnd = min(lastBox.maxY, candidateBox.maxY)
            let overlapHeight = overlapEnd - overlapStart
            let minHeight = min(lastBox.height, candidateBox.height)
            let overlapRatio = overlapHeight > 0 ? overlapHeight / minHeight : 0
            logger.debug("  VertOverlap: \(String(format: "%.4f", overlapHeight)) ratio=\(String(format: "%.2f", overlapRatio)) (need ≥\(String(format: "%.2f", configuration.minAlignmentOverlap)))")
            logger.debug("  Y ranges: last=[\(String(format: "%.3f", lastBox.minY))-\(String(format: "%.3f", lastBox.maxY))] cand=[\(String(format: "%.3f", candidateBox.minY))-\(String(format: "%.3f", candidateBox.maxY))]")

        case .horizontal:
            let verticalGap = lastBox.minY - candidateBox.maxY
            let maxGap = max(last.lineHeight, candidate.lineHeight) * configuration.maxGapMultiplier
            let minGap = -last.lineHeight * 0.3
            logger.debug("  VertGap: \(String(format: "%.4f", verticalGap)) (need \(String(format: "%.4f", minGap)) to \(String(format: "%.4f", maxGap)))")

            let overlapStart = max(lastBox.minX, candidateBox.minX)
            let overlapEnd = min(lastBox.maxX, candidateBox.maxX)
            let overlapWidth = overlapEnd - overlapStart
            let minWidth = min(lastBox.width, candidateBox.width)
            let overlapRatio = overlapWidth > 0 ? overlapWidth / minWidth : 0
            logger.debug("  HorizOverlap: \(String(format: "%.4f", overlapWidth)) ratio=\(String(format: "%.2f", overlapRatio)) (need ≥\(String(format: "%.2f", configuration.minAlignmentOverlap)))")
            logger.debug("  X ranges: last=[\(String(format: "%.3f", lastBox.minX))-\(String(format: "%.3f", lastBox.maxX))] cand=[\(String(format: "%.3f", candidateBox.minX))-\(String(format: "%.3f", candidateBox.maxX))]")
        }
    }

    /// Determines whether a candidate observation should be merged into the current cluster.
    /// Returns the result along with the rejection reason if not merging.
    private func shouldMergeWithReason(
        currentCluster: [ObservationFeatures],
        candidate: ObservationFeatures
    ) -> (shouldMerge: Bool, reason: MergeRejectionReason?) {
        // Compare with the last observation in the cluster (most recent in reading order)
        guard let last = currentCluster.last else { return (true, nil) }

        // Must have same direction (already guaranteed by grouping, but defensive)
        guard last.direction == candidate.direction else {
            return (false, .directionMismatch)
        }

        // Check line height similarity (font size proxy)
        let heightRatio = min(last.lineHeight, candidate.lineHeight) / max(last.lineHeight, candidate.lineHeight)
        guard heightRatio >= configuration.lineHeightTolerance else {
            return (false, .lineHeightMismatch(ratio: heightRatio, threshold: configuration.lineHeightTolerance))
        }

        // Check spatial proximity and alignment based on direction
        switch last.direction {
        case .horizontal:
            return checkHorizontalMergeWithReason(last: last, candidate: candidate)
        case .vertical:
            return checkVerticalMergeWithReason(last: last, candidate: candidate)
        }
    }

    /// Legacy method for backward compatibility
    private func shouldMerge(currentCluster: [ObservationFeatures], candidate: ObservationFeatures) -> Bool {
        shouldMergeWithReason(currentCluster: currentCluster, candidate: candidate).shouldMerge
    }

    /// Check merge criteria for horizontal text (lines stacked vertically)
    private func checkHorizontalMergeWithReason(
        last: ObservationFeatures,
        candidate: ObservationFeatures
    ) -> (shouldMerge: Bool, reason: MergeRejectionReason?) {
        let lastBox = last.boundingBox.cgRect
        let candidateBox = candidate.boundingBox.cgRect

        // Calculate vertical gap (candidate should be below last in reading order)
        // In normalized coords (lower-left origin), "below" means smaller Y
        let verticalGap = lastBox.minY - candidateBox.maxY

        // Gap should be positive (candidate below) and within threshold
        let maxGap = max(last.lineHeight, candidate.lineHeight) * configuration.maxGapMultiplier
        let minGap = -last.lineHeight * 0.3

        if verticalGap < minGap {
            return (false, .gapTooNegative(gap: verticalGap, minGap: minGap))
        }
        if verticalGap > maxGap {
            return (false, .gapTooLarge(gap: verticalGap, maxGap: maxGap))
        }

        // Check horizontal alignment (significant overlap in X axis)
        let overlapStart = max(lastBox.minX, candidateBox.minX)
        let overlapEnd = min(lastBox.maxX, candidateBox.maxX)
        let overlapWidth = overlapEnd - overlapStart

        if overlapWidth <= 0 {
            return (false, .noOverlap)
        }

        let minWidth = min(lastBox.width, candidateBox.width)
        let overlapRatio = overlapWidth / minWidth

        if overlapRatio < configuration.minAlignmentOverlap {
            return (false, .insufficientOverlap(ratio: overlapRatio, threshold: configuration.minAlignmentOverlap))
        }

        return (true, nil)
    }

    /// Check merge criteria for vertical text (columns arranged horizontally, right-to-left)
    private func checkVerticalMergeWithReason(
        last: ObservationFeatures,
        candidate: ObservationFeatures
    ) -> (shouldMerge: Bool, reason: MergeRejectionReason?) {
        let lastBox = last.boundingBox.cgRect
        let candidateBox = candidate.boundingBox.cgRect

        // For vertical text, columns flow right-to-left
        // "Next" column is to the left (smaller X)
        let horizontalGap = lastBox.minX - candidateBox.maxX

        // Gap should be positive (candidate to the left) and within threshold
        let maxGap = max(last.lineHeight, candidate.lineHeight) * configuration.maxGapMultiplier
        let minGap = -last.lineHeight * 0.3

        if horizontalGap < minGap {
            return (false, .gapTooNegative(gap: horizontalGap, minGap: minGap))
        }
        if horizontalGap > maxGap {
            return (false, .gapTooLarge(gap: horizontalGap, maxGap: maxGap))
        }

        // Check vertical alignment (significant overlap in Y axis)
        let overlapStart = max(lastBox.minY, candidateBox.minY)
        let overlapEnd = min(lastBox.maxY, candidateBox.maxY)
        let overlapHeight = overlapEnd - overlapStart

        if overlapHeight <= 0 {
            return (false, .noOverlap)
        }

        let minHeight = min(lastBox.height, candidateBox.height)
        let overlapRatio = overlapHeight / minHeight

        if overlapRatio < configuration.minAlignmentOverlap {
            return (false, .insufficientOverlap(ratio: overlapRatio, threshold: configuration.minAlignmentOverlap))
        }

        return (true, nil)
    }
}

// MARK: - Convenience Extensions

public extension [RecognizedTextObservation] {
    /// Clusters these observations using the default configuration.
    func clustered(using configuration: ClusteringConfiguration = .default) -> [TextCluster] {
        TextClusterer(configuration: configuration).cluster(self)
    }
}
