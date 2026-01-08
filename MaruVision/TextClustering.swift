// TextClustering.swift
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

import CoreGraphics
import Foundation
import os.log
import Vision

// MARK: - Debug Formatting Helpers

private extension CGFloat {
    /// Format with 2 decimal places (e.g., ratios)
    func f2() -> String { formatted(FloatingPointFormatStyle<Double>().precision(.fractionLength(2))) }
    /// Format with 3 decimal places (e.g., coordinates)
    func f3() -> String { formatted(FloatingPointFormatStyle<Double>().precision(.fractionLength(3))) }
    /// Format with 4 decimal places (e.g., line heights, gaps)
    func f4() -> String { formatted(FloatingPointFormatStyle<Double>().precision(.fractionLength(4))) }
}

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
        ar=\(aspectRatio.f2()) \
        lh=\(lineHeight.f4()) \
        box=(x:\(box.minX.f3())-\(box.maxX.f3()), \
        y:\(box.minY.f3())-\(box.maxY.f3())) \
        center=(\(centroid.x.f3()),\(centroid.y.f3()))
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
            "lineHeight ratio \(ratio.f2()) < threshold \(threshold.f2())"
        case let .gapTooLarge(gap, maxGap):
            "gap \(gap.f4()) > maxGap \(maxGap.f4())"
        case let .gapTooNegative(gap, minGap):
            "gap \(gap.f4()) < minGap \(minGap.f4())"
        case .noOverlap:
            "no overlap"
        case let .insufficientOverlap(ratio, threshold):
            "overlap ratio \(ratio.f2()) < threshold \(threshold.f2())"
        }
    }
}

// MARK: - Union-Find for Graph-Based Clustering

/// A simple union-find (disjoint set) data structure for clustering.
private struct UnionFind {
    private var parent: [Int]
    private var rank: [Int]

    init(count: Int) {
        parent = Array(0 ..< count)
        rank = Array(repeating: 0, count: count)
    }

    mutating func find(_ x: Int) -> Int {
        if parent[x] != x {
            parent[x] = find(parent[x]) // Path compression
        }
        return parent[x]
    }

    mutating func union(_ x: Int, _ y: Int) {
        let rootX = find(x)
        let rootY = find(y)

        if rootX != rootY {
            // Union by rank
            if rank[rootX] < rank[rootY] {
                parent[rootX] = rootY
            } else if rank[rootX] > rank[rootY] {
                parent[rootY] = rootX
            } else {
                parent[rootY] = rootX
                rank[rootX] += 1
            }
        }
    }

    /// Returns all elements grouped by their root.
    mutating func groups() -> [[Int]] {
        var groupMap: [Int: [Int]] = [:]
        for i in 0 ..< parent.count {
            let root = find(i)
            groupMap[root, default: []].append(i)
        }
        return Array(groupMap.values)
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
    /// Uses graph-based clustering: observations that pass merge criteria are connected,
    /// and connected components form clusters.
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
        let byDirection = Dictionary(grouping: features.enumerated().map(\.self)) { $0.element.direction }

        if configuration.verboseLogging {
            let verticalCount = byDirection[.vertical]?.count ?? 0
            let horizontalCount = byDirection[.horizontal]?.count ?? 0
            logger.debug("Direction groups: V=\(verticalCount) H=\(horizontalCount)")
        }

        var clusters: [TextCluster] = []

        for (direction, indexedFeatures) in byDirection {
            if configuration.verboseLogging {
                logger.debug("--- PROCESSING \(direction) GROUP (\(indexedFeatures.count) obs) ---")
            }

            // Build graph using union-find
            var uf = UnionFind(count: indexedFeatures.count)
            let localFeatures = indexedFeatures.map(\.element)

            // Check all pairs for merge eligibility
            for i in 0 ..< localFeatures.count {
                for j in (i + 1) ..< localFeatures.count {
                    let result = shouldMergePair(localFeatures[i], localFeatures[j])
                    if result.shouldMerge {
                        uf.union(i, j)
                        if configuration.verboseLogging {
                            logger.debug("EDGE: \(localFeatures[i].debugID) <-> \(localFeatures[j].debugID)")
                        }
                    } else if configuration.verboseLogging {
                        // Only log rejections between spatially close observations to reduce noise
                        if areSpatiallyClose(localFeatures[i], localFeatures[j]) {
                            logger.debug("NO EDGE: \(localFeatures[i].debugID) <-> \(localFeatures[j].debugID): \(result.reason?.description ?? "unknown")")
                            logDetailedComparison(last: localFeatures[i], candidate: localFeatures[j])
                        }
                    }
                }
            }

            // Extract connected components
            let groups = uf.groups()

            if configuration.verboseLogging {
                logger.debug("Found \(groups.count) connected components")
            }

            for group in groups {
                // Get features for this group and sort by reading order
                let groupFeatures = group.map { localFeatures[$0] }
                let sorted = groupFeatures.sorted { a, b in
                    if a.readingOrderKey.primary != b.readingOrderKey.primary {
                        return a.readingOrderKey.primary < b.readingOrderKey.primary
                    }
                    return a.readingOrderKey.secondary < b.readingOrderKey.secondary
                }

                clusters.append(TextCluster(
                    observations: sorted.map(\.observation),
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

    /// Checks if two observations are spatially close enough to be worth logging.
    /// Used to reduce noise in debug output.
    private func areSpatiallyClose(_ a: ObservationFeatures, _ b: ObservationFeatures) -> Bool {
        let maxDistance: CGFloat = 0.15 // 15% of image dimension
        let dx = abs(a.centroid.x - b.centroid.x)
        let dy = abs(a.centroid.y - b.centroid.y)
        return dx < maxDistance && dy < maxDistance
    }

    /// Determines whether two observations should be merged (symmetric check).
    /// Unlike the sequential approach, this doesn't depend on reading order.
    private func shouldMergePair(
        _ a: ObservationFeatures,
        _ b: ObservationFeatures
    ) -> (shouldMerge: Bool, reason: MergeRejectionReason?) {
        // Must have same direction
        guard a.direction == b.direction else {
            return (false, .directionMismatch)
        }

        // Check line height similarity (font size proxy)
        let heightRatio = min(a.lineHeight, b.lineHeight) / max(a.lineHeight, b.lineHeight)
        guard heightRatio >= configuration.lineHeightTolerance else {
            return (false, .lineHeightMismatch(ratio: heightRatio, threshold: configuration.lineHeightTolerance))
        }

        // Check spatial proximity and alignment based on direction
        switch a.direction {
        case .horizontal:
            return checkHorizontalMergePair(a, b)
        case .vertical:
            return checkVerticalMergePair(a, b)
        }
    }

    /// Check merge criteria for two horizontal text observations (symmetric).
    private func checkHorizontalMergePair(
        _ a: ObservationFeatures,
        _ b: ObservationFeatures
    ) -> (shouldMerge: Bool, reason: MergeRejectionReason?) {
        let aBox = a.boundingBox.cgRect
        let bBox = b.boundingBox.cgRect

        // Calculate vertical gap (absolute distance between boxes)
        let verticalGap: CGFloat = if aBox.minY > bBox.maxY {
            aBox.minY - bBox.maxY // a is above b
        } else if bBox.minY > aBox.maxY {
            bBox.minY - aBox.maxY // b is above a
        } else {
            0 // overlapping vertically
        }

        let maxGap = max(a.lineHeight, b.lineHeight) * configuration.maxGapMultiplier

        // Check if gap is within bounds
        if verticalGap > maxGap {
            return (false, .gapTooLarge(gap: verticalGap, maxGap: maxGap))
        }

        // Check horizontal alignment (significant overlap in X axis)
        let overlapStart = max(aBox.minX, bBox.minX)
        let overlapEnd = min(aBox.maxX, bBox.maxX)
        let overlapWidth = overlapEnd - overlapStart

        if overlapWidth <= 0 {
            return (false, .noOverlap)
        }

        let minWidth = min(aBox.width, bBox.width)
        let overlapRatio = overlapWidth / minWidth

        if overlapRatio < configuration.minAlignmentOverlap {
            return (false, .insufficientOverlap(ratio: overlapRatio, threshold: configuration.minAlignmentOverlap))
        }

        return (true, nil)
    }

    /// Check merge criteria for two vertical text observations (symmetric).
    private func checkVerticalMergePair(
        _ a: ObservationFeatures,
        _ b: ObservationFeatures
    ) -> (shouldMerge: Bool, reason: MergeRejectionReason?) {
        let aBox = a.boundingBox.cgRect
        let bBox = b.boundingBox.cgRect

        // Calculate horizontal gap (absolute distance between boxes)
        let horizontalGap: CGFloat = if aBox.minX > bBox.maxX {
            aBox.minX - bBox.maxX // a is to the right of b
        } else if bBox.minX > aBox.maxX {
            bBox.minX - aBox.maxX // b is to the right of a
        } else {
            0 // overlapping horizontally
        }

        let maxGap = max(a.lineHeight, b.lineHeight) * configuration.maxGapMultiplier

        // Check if gap is within bounds
        if horizontalGap > maxGap {
            return (false, .gapTooLarge(gap: horizontalGap, maxGap: maxGap))
        }

        // Check vertical alignment (significant overlap in Y axis)
        let overlapStart = max(aBox.minY, bBox.minY)
        let overlapEnd = min(aBox.maxY, bBox.maxY)
        let overlapHeight = overlapEnd - overlapStart

        if overlapHeight <= 0 {
            return (false, .noOverlap)
        }

        let minHeight = min(aBox.height, bBox.height)
        let overlapRatio = overlapHeight / minHeight

        if overlapRatio < configuration.minAlignmentOverlap {
            return (false, .insufficientOverlap(ratio: overlapRatio, threshold: configuration.minAlignmentOverlap))
        }

        return (true, nil)
    }

    /// Logs detailed comparison data for debugging merge failures
    private func logDetailedComparison(last: ObservationFeatures, candidate: ObservationFeatures) {
        let lastBox = last.boundingBox.cgRect
        let candidateBox = candidate.boundingBox.cgRect

        let heightRatio = min(last.lineHeight, candidate.lineHeight) / max(last.lineHeight, candidate.lineHeight)
        logger.debug("  LineHeight: last=\(last.lineHeight.f4()) cand=\(candidate.lineHeight.f4()) ratio=\(heightRatio.f2()) (need ≥\(configuration.lineHeightTolerance.f2()))")

        switch last.direction {
        case .vertical:
            let horizontalGap = lastBox.minX - candidateBox.maxX
            let maxGap = max(last.lineHeight, candidate.lineHeight) * configuration.maxGapMultiplier
            let minGap = -last.lineHeight * 0.3
            logger.debug("  HorizGap: \(horizontalGap.f4()) (need \(minGap.f4()) to \(maxGap.f4()))")

            let overlapStart = max(lastBox.minY, candidateBox.minY)
            let overlapEnd = min(lastBox.maxY, candidateBox.maxY)
            let overlapHeight = overlapEnd - overlapStart
            let minHeight = min(lastBox.height, candidateBox.height)
            let overlapRatio = overlapHeight > 0 ? overlapHeight / minHeight : 0
            logger.debug("  VertOverlap: \(overlapHeight.f4()) ratio=\(overlapRatio.f2()) (need ≥\(configuration.minAlignmentOverlap.f2()))")
            logger.debug("  Y ranges: last=[\(lastBox.minY.f3())-\(lastBox.maxY.f3())] cand=[\(candidateBox.minY.f3())-\(candidateBox.maxY.f3())]")

        case .horizontal:
            let verticalGap = lastBox.minY - candidateBox.maxY
            let maxGap = max(last.lineHeight, candidate.lineHeight) * configuration.maxGapMultiplier
            let minGap = -last.lineHeight * 0.3
            logger.debug("  VertGap: \(verticalGap.f4()) (need \(minGap.f4()) to \(maxGap.f4()))")

            let overlapStart = max(lastBox.minX, candidateBox.minX)
            let overlapEnd = min(lastBox.maxX, candidateBox.maxX)
            let overlapWidth = overlapEnd - overlapStart
            let minWidth = min(lastBox.width, candidateBox.width)
            let overlapRatio = overlapWidth > 0 ? overlapWidth / minWidth : 0
            logger.debug("  HorizOverlap: \(overlapWidth.f4()) ratio=\(overlapRatio.f2()) (need ≥\(configuration.minAlignmentOverlap.f2()))")
            logger.debug("  X ranges: last=[\(lastBox.minX.f3())-\(lastBox.maxX.f3())] cand=[\(candidateBox.minX.f3())-\(candidateBox.maxX.f3())]")
        }
    }
}

// MARK: - Convenience Extensions

public extension [RecognizedTextObservation] {
    /// Clusters these observations using the default configuration.
    func clustered(using configuration: ClusteringConfiguration = .default) -> [TextCluster] {
        TextClusterer(configuration: configuration).cluster(self)
    }
}
