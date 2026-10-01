// TextClustering.swift
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

import CoreGraphics
import Foundation
import os
import Vision

// MARK: - Debug Formatting Helpers

private extension CGFloat {
    /// Format with 2 decimal places (e.g., ratios)
    func f2() -> String {
        formatted(FloatingPointFormatStyle<Double>().precision(.fractionLength(2)))
    }

    /// Format with 3 decimal places (e.g., coordinates)
    func f3() -> String {
        formatted(FloatingPointFormatStyle<Double>().precision(.fractionLength(3)))
    }

    /// Format with 4 decimal places (e.g., line heights, gaps)
    func f4() -> String {
        formatted(FloatingPointFormatStyle<Double>().precision(.fractionLength(4)))
    }
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

    /// The same observation read in `direction` instead of its inferred one.
    init(_ other: ObservationFeatures, as direction: InferredTextDirection) {
        observation = other.observation
        boundingBox = other.boundingBox
        centroid = other.centroid
        aspectRatio = other.aspectRatio
        self.direction = direction
        lineHeight = direction == .vertical ? boundingBox.cgRect.width : boundingBox.cgRect.height
    }

    /// Number of characters Vision read.
    var characterCount: Int {
        observation.transcript.count
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

    /// The text of each observation, in order. Differs from the observations'
    /// own transcripts when lines were re-read from their crops.
    public let transcripts: [String]

    /// The concatenated transcript of all observations
    public var transcript: String {
        // For vertical text, observations are in column order (right-to-left),
        // and each observation is a vertical line. No separator needed.
        // For horizontal text, observations are lines. Join with newlines for
        // paragraph structure, though the dictionary search will handle segmentation.
        transcripts.joined(separator: direction == .vertical ? "" : "\n")
    }

    public init(observations: [RecognizedTextObservation], direction: InferredTextDirection, transcripts: [String]? = nil) {
        self.observations = observations
        self.direction = direction
        self.transcripts = transcripts ?? observations.map(\.transcript)

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

    /// Joins fragments of one line: observations that overlap by at least half
    /// across the text axis and are closer along it than this many line
    /// heights. Fragments of one column never overlap vertically, so without
    /// this they only join through a neighbouring column that spans both.
    /// 0 disables.
    public var maxFragmentGapMultiplier: CGFloat

    /// Also compare line heights as length per character. Ruby beside a column
    /// widens its box, so two columns of one balloon can fail the width check
    /// while their characters are the same size.
    public var compareCharacterSize: Bool

    /// Lets an observation of one or two characters join text of the other
    /// direction when it passes that direction's merge checks. Vision reads the
    /// tops of two neighbouring columns as one short horizontal line, and a
    /// square box of two characters has no clear direction.
    public var joinShortAcrossDirections: Bool

    /// After clustering, folds a horizontal cluster into a vertical cluster
    /// with more text that it touches (see `absorbHorizontal`).
    public var absorbHorizontal: Bool

    /// Default configuration tuned for Japanese book/manga content
    public static let `default` = ClusteringConfiguration(
        lineHeightTolerance: 0.6,
        maxGapMultiplier: 2.0,
        minAlignmentOverlap: 0.3,
        verboseLogging: false,
        maxFragmentGapMultiplier: 0.5,
        compareCharacterSize: true,
        joinShortAcrossDirections: true,
        absorbHorizontal: true
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
        verboseLogging: true,
        maxFragmentGapMultiplier: 0.5,
        compareCharacterSize: true,
        joinShortAcrossDirections: true,
        absorbHorizontal: true
    )

    public init(
        lineHeightTolerance: CGFloat,
        maxGapMultiplier: CGFloat,
        minAlignmentOverlap: CGFloat,
        verboseLogging: Bool = false,
        maxFragmentGapMultiplier: CGFloat = 0,
        compareCharacterSize: Bool = false,
        joinShortAcrossDirections: Bool = false,
        absorbHorizontal: Bool = false
    ) {
        self.lineHeightTolerance = lineHeightTolerance
        self.maxGapMultiplier = maxGapMultiplier
        self.minAlignmentOverlap = minAlignmentOverlap
        self.verboseLogging = verboseLogging
        self.maxFragmentGapMultiplier = maxFragmentGapMultiplier
        self.compareCharacterSize = compareCharacterSize
        self.joinShortAcrossDirections = joinShortAcrossDirections
        self.absorbHorizontal = absorbHorizontal
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
        var features = observations.map { ObservationFeatures(observation: $0) }

        // A short observation has no clear direction of its own. It takes the
        // direction of longer text it can join, vertical first. Deciding this
        // up front keeps one character from bridging vertical and horizontal
        // text into one cluster.
        if configuration.joinShortAcrossDirections {
            let long = features.filter { $0.characterCount > 2 }
            for i in features.indices where features[i].characterCount <= 2 {
                for direction in [InferredTextDirection.vertical, .horizontal] {
                    let turned = ObservationFeatures(features[i], as: direction)
                    if long.contains(where: { $0.direction == direction && shouldMergePair(turned, $0).shouldMerge }) {
                        features[i] = turned
                        break
                    }
                }
            }
        }

        if configuration.verboseLogging {
            logger.debug("=== CLUSTERING \(observations.count) OBSERVATIONS ===")
            logger.debug("Config: heightTol=\(configuration.lineHeightTolerance) gapMult=\(configuration.maxGapMultiplier) minOverlap=\(configuration.minAlignmentOverlap)")
            logger.debug("--- ALL OBSERVATIONS ---")
            for (idx, feature) in features.enumerated() {
                logger.debug("  #\(idx): \(feature.debugDescription)")
            }
        }

        // Build graph using union-find. Pairs of different direction are
        // rejected by shouldMergePair unless one is short and
        // joinShortAcrossDirections is on.
        var uf = UnionFind(count: features.count)
        for i in 0 ..< features.count {
            for j in (i + 1) ..< features.count {
                let result = shouldMergePair(features[i], features[j])
                if result.shouldMerge {
                    uf.union(i, j)
                    if configuration.verboseLogging {
                        logger.debug("EDGE: \(features[i].debugID) <-> \(features[j].debugID)")
                    }
                } else if configuration.verboseLogging {
                    // Only log rejections between spatially close observations to reduce noise
                    if areSpatiallyClose(features[i], features[j]) {
                        logger.debug("NO EDGE: \(features[i].debugID) <-> \(features[j].debugID): \(result.reason?.description ?? "unknown")")
                        logDetailedComparison(last: features[i], candidate: features[j])
                    }
                }
            }
        }

        // Extract connected components
        let groups = uf.groups()

        if configuration.verboseLogging {
            logger.debug("Found \(groups.count) connected components")
        }

        var clusters: [TextCluster] = []
        for group in groups {
            // The direction with more characters is the group's; sort by its reading order.
            let groupFeatures = group.map { features[$0] }
            let verticalChars = groupFeatures.filter { $0.direction == .vertical }.map(\.characterCount).reduce(0, +)
            let horizontalChars = groupFeatures.filter { $0.direction == .horizontal }.map(\.characterCount).reduce(0, +)
            let direction: InferredTextDirection = verticalChars >= horizontalChars ? .vertical : .horizontal
            let sorted = groupFeatures.sorted { a, b in
                let ka = ObservationFeatures(a, as: direction).readingOrderKey
                let kb = ObservationFeatures(b, as: direction).readingOrderKey
                return ka.primary != kb.primary ? ka.primary < kb.primary : ka.secondary < kb.secondary
            }

            clusters.append(TextCluster(
                observations: sorted.map(\.observation),
                direction: direction
            ))
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

        // Check line height similarity (font size proxy). Ruby widens a column
        // by up to about half, so the character size only counts within that.
        let heightRatio = min(a.lineHeight, b.lineHeight) / max(a.lineHeight, b.lineHeight)
        guard heightRatio >= configuration.lineHeightTolerance
            || (configuration.compareCharacterSize && heightRatio >= 0.4
                && characterSizeRatio(a, b) >= configuration.lineHeightTolerance)
        else {
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

    /// Ratio of the observations' box lengths per character (smaller over larger).
    private func characterSizeRatio(_ a: ObservationFeatures, _ b: ObservationFeatures) -> CGFloat {
        func size(_ f: ObservationFeatures) -> CGFloat {
            let box = f.boundingBox.cgRect
            return (f.direction == .vertical ? box.height : box.width) / CGFloat(max(1, f.observation.transcript.count))
        }
        return min(size(a), size(b)) / max(size(a), size(b))
    }

    /// True when a and b look like fragments of one line: they share at least
    /// half of the narrower box across the text axis and the gap along it is
    /// within `maxFragmentGapMultiplier` line heights.
    private func areFragments(_ a: ObservationFeatures, _ b: ObservationFeatures) -> Bool {
        configuration.maxFragmentGapMultiplier > 0
            && fragments(a.boundingBox.cgRect, b.boundingBox.cgRect, vertical: a.direction == .vertical,
                         gapMultiplier: configuration.maxFragmentGapMultiplier)
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
            return areFragments(a, b) ? (true, nil) : (false, .noOverlap)
        }

        let minWidth = min(aBox.width, bBox.width)
        let overlapRatio = overlapWidth / minWidth

        if overlapRatio < configuration.minAlignmentOverlap {
            return areFragments(a, b) ? (true, nil) : (false, .insufficientOverlap(ratio: overlapRatio, threshold: configuration.minAlignmentOverlap))
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
            return areFragments(a, b) ? (true, nil) : (false, .noOverlap)
        }

        let minHeight = min(aBox.height, bBox.height)
        let overlapRatio = overlapHeight / minHeight

        if overlapRatio < configuration.minAlignmentOverlap {
            return areFragments(a, b) ? (true, nil) : (false, .insufficientOverlap(ratio: overlapRatio, threshold: configuration.minAlignmentOverlap))
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

// MARK: - Reading Order

/// Groups `indices` by gaps in their boxes' projection on one axis, in
/// ascending order of that axis. Each range is trimmed by 15% at both ends so
/// boxes that touch or overlap slightly still separate.
private func split(_ indices: [Int], _ range: (Int) -> (CGFloat, CGFloat)) -> [[Int]] {
    func trimmed(_ i: Int) -> (CGFloat, CGFloat) {
        let (lo, hi) = range(i)
        return (lo + (hi - lo) * 0.15, hi - (hi - lo) * 0.15)
    }
    var groups: [[Int]] = []
    var end = -CGFloat.infinity
    for i in indices.sorted(by: { trimmed($0).0 < trimmed($1).0 }) {
        let (lo, hi) = trimmed(i)
        if lo >= end || groups.isEmpty {
            groups.append([i])
        } else {
            groups[groups.count - 1].append(i)
        }
        end = max(end, hi)
    }
    return groups
}

/// Recursive XY-cut: the indices of `boxes` in reading order. Vertical text:
/// stacked groups top to bottom, then columns right to left, then fragments of
/// one column top to bottom. Horizontal text: side-by-side groups left to
/// right, then lines top down. Boxes are normalized with a lower-left origin.
/// Sorting by centroid alone puts fragments of one column bottom first.
func xyOrder(_ boxes: [CGRect], vertical: Bool) -> [Int] {
    func order(_ indices: [Int]) -> [Int] {
        guard indices.count > 1 else { return indices }
        let byY = split(indices) { (boxes[$0].minY, boxes[$0].maxY) }.reversed() as [[Int]] // top first
        let byX = split(indices) { (boxes[$0].minX, boxes[$0].maxX) }
        for groups in vertical ? [byY, byX.reversed()] : [byX, byY] where groups.count > 1 {
            return groups.flatMap(order)
        }
        // No gap on either axis: fall back to centroid order.
        return indices.sorted { i, j in
            let a = boxes[i], b = boxes[j]
            return vertical ? (a.midX, a.midY) > (b.midX, b.midY) : (-a.midY, a.midX) < (-b.midY, b.midX)
        }
    }
    return order(Array(boxes.indices))
}

/// True when the boxes look like fragments of one line: similar thickness,
/// sharing at least half of the thinner box across the text axis, and along
/// it a gap of at most `gapMultiplier` line heights, or an overlap of at most
/// one (a character read into both). The thinner box gives the line height: a
/// wide box is inflated by ruby or by a read across two columns' tops.
func fragments(_ a: CGRect, _ b: CGRect, vertical: Bool, gapMultiplier: CGFloat) -> Bool {
    let (ta, tb) = vertical ? (a.width, b.width) : (a.height, b.height)
    let thin = min(ta, tb)
    let across = vertical ? (min(a.maxX, b.maxX) - max(a.minX, b.minX)) / thin
        : (min(a.maxY, b.maxY) - max(a.minY, b.minY)) / thin
    let along = vertical ? max(a.minY, b.minY) - min(a.maxY, b.maxY) : max(a.minX, b.minX) - min(a.maxX, b.maxX)
    return thin >= 0.5 * max(ta, tb) && across >= 0.5 && along >= -thin && along <= thin * gapMultiplier
}

/// Groups the indices of `boxes` into lines, joining fragments (see
/// `fragments`) transitively. Each group is in order along the text axis.
/// Ordering the lines instead of the fragments keeps XY-cut from cutting a
/// fragment that sticks out below its neighbours into a row of its own.
func lineGroups(_ boxes: [CGRect], vertical: Bool, gapMultiplier: CGFloat) -> [[Int]] {
    var uf = UnionFind(count: boxes.count)
    for i in boxes.indices {
        for j in (i + 1) ..< boxes.count where fragments(boxes[i], boxes[j], vertical: vertical, gapMultiplier: gapMultiplier) {
            uf.union(i, j)
        }
    }
    return uf.groups().map { $0.sorted { vertical ? boxes[$0].midY > boxes[$1].midY : boxes[$0].midX < boxes[$1].midX } }
}

/// Merges each cluster whose box lies mostly inside a larger same-direction
/// cluster's box into that cluster. Returns groups of cluster indices, host
/// first. Catches a ruby-carrying column that the clusterer left out while
/// joining its neighbours around it.
func mergeContained(_ clusters: [(box: CGRect, vertical: Bool)]) -> [[Int]] {
    let byArea = clusters.indices.sorted { clusters[$0].box.width * clusters[$0].box.height > clusters[$1].box.width * clusters[$1].box.height }
    var groups = byArea.map { [$0] }
    var boxes = byArea.map { clusters[$0].box }
    var i = 1
    while i < groups.count {
        let inner = boxes[i]
        let host = (0 ..< i).first { h in
            let overlap = boxes[h].intersection(inner)
            return clusters[groups[h][0]].vertical == clusters[groups[i][0]].vertical && !overlap.isNull
                && overlap.width * overlap.height >= 0.5 * inner.width * inner.height
        }
        if let host {
            groups[host] += groups.remove(at: i)
            boxes[host] = boxes[host].union(boxes.remove(at: i))
        } else {
            i += 1
        }
    }
    return groups
}

/// Folds each horizontal group into the first vertical group with more text
/// that spans at least half of its width and lies within its own line height
/// above or below it, or overlaps it. Returns groups of indices, host first.
/// Vision reads the tops of neighbouring columns as one horizontal line, which
/// the clusterer cannot join to the columns, and horizontal text that close to
/// a vertical balloon is rare in manga.
func absorbHorizontal(_ groups: [(box: CGRect, vertical: Bool, characters: Int)]) -> [[Int]] {
    var result = groups.indices.map { [$0] }
    var boxes = groups.map(\.box)
    var i = 0
    while i < result.count {
        let s = groups[result[i][0]]
        let host = s.vertical ? nil : result.indices.first { h in
            let c = groups[result[h][0]]
            let box = boxes[h]
            let acrossX = min(box.maxX, s.box.maxX) - max(box.minX, s.box.minX)
            let gapY = max(box.minY, s.box.minY) - min(box.maxY, s.box.maxY)
            return h != i && c.vertical && c.characters > s.characters
                && acrossX >= 0.5 * s.box.width && gapY <= s.box.height * 0.5
        }
        if let host {
            let removed = result.remove(at: i), box = boxes.remove(at: i)
            let h = host > i ? host - 1 : host
            result[h] += removed
            boxes[h] = boxes[h].union(box)
        } else {
            i += 1
        }
    }
    return result
}

// MARK: - Convenience Extensions

public extension [RecognizedTextObservation] {
    /// Clusters these observations using the default configuration.
    func clustered(using configuration: ClusteringConfiguration = .default) -> [TextCluster] {
        TextClusterer(configuration: configuration).cluster(self)
    }
}
