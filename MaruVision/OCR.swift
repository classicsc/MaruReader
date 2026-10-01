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
import ImageIO
import os
import SwiftUI
import Vision

public actor OCR {
    /// The Vision request.
    var request: RecognizeTextRequest

    /// Configuration for text clustering.
    public var clusteringConfiguration: ClusteringConfiguration = .default

    /// Re-read each line from its own upscaled crop after the page pass. Ruby
    /// beside a line stays out of the crop, which fixes many misreads, at the
    /// cost of one Vision request per line.
    public var cropLines = true

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
        // Vision reads the encoded data slightly differently from a decoded
        // CGImage, so the page passes use the data; crops need the CGImage.
        let clusters = try await cluster(recognize(.data(imageData)))
        guard cropLines, let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return clusters }
        return try await recropLines(clusters, page: image)
    }

    public func performOCR(cgImage: CGImage) async throws -> [TextCluster] {
        let clusters = try await cluster(recognize(.image(cgImage)))
        return cropLines ? try await recropLines(clusters, page: cgImage) : clusters
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
    private func recognize(_ input: Input) async throws -> [RecognizedTextObservation] {
        let first = try await perform(request, on: input)
        var second = request
        second.minimumTextHeightFraction = 0
        let extra = try await perform(second, on: input)
        return first + extra.filter { o in !first.contains { overlaps($0.boundingBox.cgRect, o.boundingBox.cgRect) } }
    }

    private func cluster(_ observations: [RecognizedTextObservation]) -> [TextCluster] {
        logger.debug("OCR found \(observations.count) text observations.")
        let clusters = TextClusterer(configuration: clusteringConfiguration).cluster(observations)
        let merged = mergeContained(clusters.map { ($0.boundingBox, $0.direction == .vertical) }).map { group in
            let observations = group.flatMap { clusters[$0].observations }
            let direction = clusters[group[0]].direction
            let order = xyOrder(observations.map(\.boundingBox.cgRect), vertical: direction == .vertical)
            return TextCluster(observations: order.map { observations[$0] }, direction: direction)
        }
        logger.debug("Clustered into \(merged.count) clusters.")
        return merged
    }

    // MARK: - Line crops

    /// Re-reads each line from its own crop and replaces its text. Keeps the
    /// page-level text when the crop reads nothing usable.
    private func recropLines(_ clusters: [TextCluster], page: CGImage) async throws -> [TextCluster] {
        let aspect = CGFloat(page.width) / CGFloat(page.height)
        var result: [TextCluster] = []
        for cluster in clusters {
            let vertical = cluster.direction == .vertical
            var texts = cluster.transcripts
            for (i, observation) in cluster.observations.enumerated() {
                try Task.checkCancellation()
                let box = observation.boundingBox.cgRect
                let t = vertical ? box.width : box.height
                // Half a line of padding along the line, 15% across it.
                let (dx, dy) = vertical ? (t * 0.15, t * 0.5 * aspect) : (t * 0.5 / aspect, t * 0.15)
                let reads = try await read(box.insetBy(dx: -dx, dy: -dy), thickness: t, vertical: vertical, page: page)
                if let text = cropText(for: box, reads: reads, vertical: vertical) {
                    texts[i] = text
                }
            }
            result.append(TextCluster(observations: cluster.observations, direction: cluster.direction, transcripts: texts))
        }
        return result
    }

    /// Reads a page region (normalized, lower-left origin), scaled so lines
    /// `thickness` (normalized) thick come out about 64 px thick. Boxes are
    /// returned in page coordinates.
    private func read(_ region: CGRect, thickness: CGFloat, vertical: Bool, page: CGImage) async throws -> [CropRead] {
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
        return try await recognize(.image(image)).map { r in
            let b = r.boundingBox.cgRect
            let box = CGRect(x: o.minX + b.minX * o.width, y: o.minY + b.minY * o.height,
                             width: b.width * o.width, height: b.height * o.height)
            return CropRead(box: box, text: r.transcript)
        }
    }
}

/// One line read from a crop, in page coordinates.
struct CropRead {
    var box: CGRect
    var text: String
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
func cropText(for line: CGRect, reads: [CropRead], vertical: Bool) -> String? {
    let inside = reads.filter { r in
        let i = r.box.intersection(line)
        return !i.isNull && i.width * i.height >= 0.5 * r.box.width * r.box.height
    }
    let thickness = { (r: CropRead) in vertical ? r.box.width : r.box.height }
    let thickest = inside.map(thickness).max() ?? 0
    let kept = inside.filter { thickness($0) >= thickest * 0.6 }
    let along = { (r: CropRead) in vertical ? (r.box.minY, r.box.maxY) : (r.box.minX, r.box.maxX) }
    let stacked = kept.indices.contains { i in kept.indices.contains { j in
        let (a0, a1) = along(kept[i]), (b0, b1) = along(kept[j])
        return i < j && min(a1, b1) - max(a0, b0) > 0.5 * min(a1 - a0, b1 - b0)
    } }
    guard !kept.isEmpty, !stacked else { return nil }
    return kept.sorted { vertical ? $0.box.midY > $1.box.midY : $0.box.midX < $1.box.midX }.map(\.text).joined()
}
