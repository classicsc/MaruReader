// MokuroImport.swift
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
import Vision

// MARK: - Mokuro File Model

/// The top-level structure of a `.mokuro` file, as produced by
/// https://github.com/kha-white/mokuro. One file covers one volume.
public struct MokuroVolume: Decodable, Sendable {
    public let pages: [MokuroPage]

    public init(pages: [MokuroPage]) {
        self.pages = pages
    }
}

/// One page's OCR data within a mokuro volume.
public struct MokuroPage: Decodable, Sendable {
    public let imgWidth: Double
    public let imgHeight: Double
    public let blocks: [MokuroBlock]
    /// The original page image's filename (e.g. "001.jpg"), used to match
    /// against the manga archive's page images.
    public let imgPath: String

    private enum CodingKeys: String, CodingKey {
        case imgWidth = "img_width"
        case imgHeight = "img_height"
        case blocks
        case imgPath = "img_path"
    }

    public init(imgWidth: Double, imgHeight: Double, blocks: [MokuroBlock], imgPath: String) {
        self.imgWidth = imgWidth
        self.imgHeight = imgHeight
        self.blocks = blocks
        self.imgPath = imgPath
    }
}

/// One OCR'd text block (bubble/paragraph) within a mokuro page. This is the
/// mokuro equivalent of a `TextCluster` — already grouped, no further
/// clustering is needed.
public struct MokuroBlock: Decodable, Sendable {
    /// Whether this block reads top-to-bottom (tategaki), as determined by mokuro.
    public let vertical: Bool
    /// Pixel-space quad `[[x, y], [x, y], [x, y], [x, y]]` per line, upper-left origin.
    public let linesCoords: [[[Double]]]
    /// The transcript for each line, same order/count as `linesCoords`.
    public let lines: [String]

    private enum CodingKeys: String, CodingKey {
        case vertical
        case linesCoords = "lines_coords"
        case lines
    }

    public init(vertical: Bool, linesCoords: [[[Double]]], lines: [String]) {
        self.vertical = vertical
        self.linesCoords = linesCoords
        self.lines = lines
    }
}

// MARK: - Mokuro Cluster Conversion

/// Converts mokuro's pre-grouped page/block data into `TextCluster`s, so it
/// can be consumed identically to Vision-sourced clusters.
public enum MokuroClusterConverter {
    /// Converts all blocks on a mokuro page into `TextCluster`s.
    /// Blocks with malformed or mismatched line data are skipped rather than
    /// failing the whole page.
    public static func clusters(for page: MokuroPage) -> [TextCluster] {
        let imageSize = CGSize(width: page.imgWidth, height: page.imgHeight)
        return page.blocks.compactMap { cluster(for: $0, imageSize: imageSize) }
    }

    private static func cluster(for block: MokuroBlock, imageSize: CGSize) -> TextCluster? {
        guard !block.lines.isEmpty, block.lines.count == block.linesCoords.count else {
            return nil
        }

        let lines: [TextClusterLine] = zip(block.lines, block.linesCoords).compactMap { transcript, quad in
            guard let boundingBox = normalizedRect(forQuad: quad, imageSize: imageSize) else {
                return nil
            }
            return TextClusterLine(transcript: transcript, boundingBox: boundingBox)
        }

        guard !lines.isEmpty else { return nil }

        let direction: InferredTextDirection = block.vertical ? .vertical : .horizontal
        return TextCluster(lines: lines, direction: direction, source: .mokuro)
    }

    /// Converts a pixel-space quad (upper-left origin) into a `NormalizedRect`
    /// (Vision's lower-left-origin convention), using the tight bounding box
    /// of the quad's four points.
    ///
    /// Each edge is clamped to the page. Mokuro quads can run slightly past the
    /// image bounds, and an out-of-range box is drawn off-page and — worse —
    /// widens the tap target used for hit-testing, letting one bubble swallow
    /// taps meant for its neighbour. The edges are clamped rather than the origin
    /// and extent separately, since the latter shifts the box instead of trimming
    /// it. A box entirely off the page clamps to zero area and is dropped.
    private static func normalizedRect(forQuad quad: [[Double]], imageSize: CGSize) -> NormalizedRect? {
        let points = quad.compactMap { point -> CGPoint? in
            guard point.count >= 2 else { return nil }
            return CGPoint(x: point[0], y: point[1])
        }
        guard !points.isEmpty,
              let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max()
        else { return nil }

        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        let pixelRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        guard pixelRect.width > 0, pixelRect.height > 0 else { return nil }

        func clamped(_ value: CGFloat) -> CGFloat {
            min(max(value, 0), 1)
        }

        let left = clamped(pixelRect.minX / imageSize.width)
        let right = clamped(pixelRect.maxX / imageSize.width)
        // The box's lower edge in Vision's coordinates is the page height minus
        // its *bottom* edge in mokuro's upper-left coordinates.
        let bottom = clamped((imageSize.height - pixelRect.maxY) / imageSize.height)
        let top = clamped((imageSize.height - pixelRect.minY) / imageSize.height)

        guard right > left, top > bottom else { return nil }

        return NormalizedRect(x: left, y: bottom, width: right - left, height: top - bottom)
    }
}
