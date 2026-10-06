// OCR.swift
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

import CoreImage
import os
import SwiftUI
import Vision

public actor OCR {
    /// The Vision request.
    var request: RecognizeTextRequest

    /// Configuration for text clustering.
    public var clusteringConfiguration: ClusteringConfiguration = .default

    private let ciContext = CIContext()
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "OCR")

    public init(clusteringConfiguration: ClusteringConfiguration = .default) {
        self.clusteringConfiguration = clusteringConfiguration

        // Initialize the request with default parameters.
        request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [.init(identifier: "ja-JP")]
    }

    /// Enable or disable verbose clustering debug logs.
    /// When enabled, detailed information about merge decisions is logged.
    public func setVerboseLogging(_ enabled: Bool) {
        clusteringConfiguration.verboseLogging = enabled
    }

    public func performOCR(imageData: Data) async throws -> [TextCluster] {
        try await cluster(recognize(.data(imageData)))
    }

    public func performOCR(cgImage: CGImage) async throws -> [TextCluster] {
        try await cluster(recognize(.image(cgImage)))
    }

    /// Looks again for text that page-level detection missed. Vision scales
    /// the page down before detecting, which loses small balloons and
    /// captions; a request on a region of the page sees them at a larger
    /// scale. Runs on a half-page window around `point`, or on four
    /// overlapping quarters of the page when `point` is nil, with no minimum
    /// text height. Lines overlapping nothing in `clusters` are clustered
    /// together with the existing lines, so a found line joins its balloon.
    /// Returns the new cluster list, or nil when nothing new was found or the
    /// image's pixels do not match its boxes (rotated by EXIF orientation).
    public func secondaryDetection(in image: UIImage, around point: CGPoint?, clusters: [TextCluster]) async throws -> [TextCluster]? {
        guard image.imageOrientation == .up, let page = image.cgImage else { return nil }
        var request = request
        request.minimumTextHeightFraction = 0
        var lines = clusters.flatMap(\.lines)
        let known = lines.count
        for region in point.map({ [Self.window(around: $0)] }) ?? Self.quarters {
            try Task.checkCancellation()
            request.regionOfInterest = NormalizedRect(x: region.minX, y: region.minY, width: region.width, height: region.height)
            for r in try await request.perform(on: page) {
                let line = TextLine(boundingBox: rebase(r.boundingBox.cgRect, into: region), text: r.transcript)
                if !lines.contains(where: { overlaps($0.boundingBox, line.boundingBox) }) {
                    lines.append(line)
                }
            }
        }
        logger.debug("Secondary detection found \(lines.count - known) new lines.")
        return lines.count > known ? cluster(lines) : nil
    }

    /// A half-page window centred on `point`, kept inside the page.
    static func window(around point: CGPoint) -> CGRect {
        CGRect(x: min(max(point.x - 0.25, 0), 0.5), y: min(max(point.y - 0.25, 0), 0.5), width: 0.5, height: 0.5)
    }

    /// Four quarters of the page, overlapping by 10% so a line on a seam is whole in one of them.
    static let quarters: [CGRect] = [0, 0.45].flatMap { x in [0, 0.45].map { CGRect(x: x, y: $0, width: 0.55, height: 0.55) } }

    /// The cluster's text after re-reading each line from its own upscaled
    /// crop of `image`, the image the cluster was recognized in. Ruby beside a
    /// line stays out of its crop, which fixes many misreads, at the cost of
    /// Vision requests per line, so this runs on demand for a tapped cluster
    /// rather than for every cluster on a page. Falls back to the page-level
    /// text when the image's pixels do not match its boxes (rotated by EXIF
    /// orientation) or the re-read fails or is cancelled.
    public nonisolated func transcript(of cluster: TextCluster, in image: UIImage) -> Task<String, Never> {
        Task(priority: .userInitiated) {
            guard image.imageOrientation == .up, let cgImage = image.cgImage,
                  let refined = try? await recropLines(cluster, page: cgImage) else { return cluster.transcript }
            return refined.transcript
        }
    }

    // MARK: - Recognition

    private enum Input {
        case data(Data)
        case image(CGImage)
    }

    private func perform(_ request: RecognizeTextRequest, on input: Input) async throws -> [RecognizedTextObservation] {
        switch input {
        case let .data(data): try await request.perform(on: data)
        case let .image(image): try await request.perform(on: image)
        }
    }

    /// The default pass plus a pass with no minimum text height. The default
    /// height (1/32 of the image) drops small balloons and breaks up
    /// low-resolution columns; the second pass adds lines that overlap nothing
    /// from the first.
    private func recognize(_ input: Input) async throws -> [TextLine] {
        let first = try await perform(request, on: input).map(TextLine.init)
        var second = request
        second.minimumTextHeightFraction = 0
        let extra = try await perform(second, on: input).map(TextLine.init)
        return first + extra.filter { o in !first.contains { overlaps($0.boundingBox, o.boundingBox) } }
    }

    private func cluster(_ lines: [TextLine]) -> [TextCluster] {
        logger.debug("OCR found \(lines.count) text lines.")
        let clusters = TextClusterer(configuration: clusteringConfiguration).cluster(lines)
        var groups = mergeContained(clusters.map { ($0.boundingBox, $0.direction == .vertical) })
        if clusteringConfiguration.absorbHorizontal {
            let summary = groups.map { g in
                (box: g.dropFirst().reduce(clusters[g[0]].boundingBox) { $0.union(clusters[$1].boundingBox) },
                 vertical: clusters[g[0]].direction == .vertical,
                 characters: g.map { clusters[$0].transcript.count }.reduce(0, +))
            }
            groups = absorbHorizontal(summary).map { $0.flatMap { groups[$0] } }
        }
        let merged = groups.map { group in
            let lines = group.flatMap { clusters[$0].lines }
            let direction = clusters[group[0]].direction
            let vertical = direction == .vertical
            let boxes = lines.map(\.boundingBox)
            let order: [Int]
            if clusteringConfiguration.maxFragmentGapMultiplier > 0 {
                // Order whole lines, then fragments within each line.
                let wholeLines = lineGroups(boxes, vertical: vertical, gapMultiplier: clusteringConfiguration.maxFragmentGapMultiplier)
                let lineBoxes = wholeLines.map { $0.dropFirst().reduce(boxes[$0[0]]) { $0.union(boxes[$1]) } }
                order = xyOrder(lineBoxes, vertical: vertical).flatMap { wholeLines[$0] }
            } else {
                order = xyOrder(boxes, vertical: vertical)
            }
            return TextCluster(lines: order.map { lines[$0] }, direction: direction)
        }
        logger.debug("Clustered into \(merged.count) clusters.")
        return merged
    }

    // MARK: - Line crops

    /// Re-reads each line from its own crop and replaces its text. Keeps the
    /// page-level text when the crop reads nothing usable.
    private func recropLines(_ cluster: TextCluster, page: CGImage) async throws -> TextCluster {
        let aspect = CGFloat(page.width) / CGFloat(page.height)
        let vertical = cluster.direction == .vertical
        var lines = cluster.lines
        for (i, line) in cluster.lines.enumerated() {
            try Task.checkCancellation()
            let box = line.boundingBox
            let t = vertical ? box.width : box.height
            // Half a line of padding along the line, 15% across it.
            let (dx, dy) = vertical ? (t * 0.15, t * 0.5 * aspect) : (t * 0.5 / aspect, t * 0.15)
            let reads = try await read(box.insetBy(dx: -dx, dy: -dy), thickness: t, vertical: vertical, page: page)
            if let text = cropText(for: box, reads: reads, vertical: vertical) {
                lines[i].text = text
            }
        }
        return TextCluster(lines: lines, direction: cluster.direction)
    }

    /// Reads a page region (normalized, lower-left origin), scaled so lines
    /// `thickness` (normalized) thick come out about 64 px thick. Boxes are
    /// returned in page coordinates.
    private func read(_ region: CGRect, thickness: CGFloat, vertical: Bool, page: CGImage) async throws -> [TextLine] {
        let w = CGFloat(page.width), h = CGFloat(page.height)
        let norm = region.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        let px = CGRect(x: norm.minX * w, y: (1 - norm.maxY) * h, width: norm.width * w, height: norm.height * h)
            .integral.intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard !px.isEmpty, let crop = page.cropping(to: px) else { return [] }
        let scale = min(max(64 / (thickness * (vertical ? w : h)), 1), 8)
        var image = crop
        if scale > 1 {
            let ci = CIImage(cgImage: crop).applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: scale])
            image = ciContext.createCGImage(ci, from: ci.extent.integral) ?? crop
        }
        // Crop-normalized to page-normalized (the crop's lower-left is at the pixel rect's bottom).
        let o = CGRect(x: px.minX / w, y: 1 - px.maxY / h, width: px.width / w, height: px.height / h)
        return try await perform(request, on: .image(image)).map { r in
            TextLine(boundingBox: rebase(r.boundingBox.cgRect, into: o), text: r.transcript)
        }
    }
}

/// A box normalized to `region` (itself normalized to the page), in page coordinates.
func rebase(_ box: CGRect, into region: CGRect) -> CGRect {
    CGRect(x: region.minX + box.minX * region.width, y: region.minY + box.minY * region.height,
           width: box.width * region.width, height: box.height * region.height)
}

/// True when the boxes share more than 30% of the smaller one's area.
func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
    let i = a.intersection(b)
    return !i.isNull && i.width * i.height > 0.3 * min(a.width * a.height, b.width * b.height)
}

/// Text for a line from the reads of its padded crop, or nil to keep the
/// page-level text. Drops reads mostly outside the line (neighbours caught by
/// the padding) and reads much thinner than the thickest (ruby). Gives up when
/// reads overlap along the line: slanted text gets a wide box holding two
/// columns, and the page-level read is right then.
func cropText(for line: CGRect, reads: [TextLine], vertical: Bool) -> String? {
    let inside = reads.filter { r in
        let i = r.boundingBox.intersection(line)
        return !i.isNull && i.width * i.height >= 0.5 * r.boundingBox.width * r.boundingBox.height
    }
    let thickness = { (r: TextLine) in vertical ? r.boundingBox.width : r.boundingBox.height }
    let thickest = inside.map(thickness).max() ?? 0
    let kept = inside.filter { thickness($0) >= thickest * 0.6 }
    let along = { (r: TextLine) in vertical ? (r.boundingBox.minY, r.boundingBox.maxY) : (r.boundingBox.minX, r.boundingBox.maxX) }
    let stacked = kept.indices.contains { i in kept.indices.contains { j in
        let (a0, a1) = along(kept[i]), (b0, b1) = along(kept[j])
        return i < j && min(a1, b1) - max(a0, b0) > 0.5 * min(a1 - a0, b1 - b0)
    } }
    guard !kept.isEmpty, !stacked else { return nil }
    return kept.sorted { vertical ? $0.boundingBox.midY > $1.boundingBox.midY : $0.boundingBox.midX < $1.boundingBox.midX }.map(\.text).joined()
}
