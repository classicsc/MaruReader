// MokuroImportTests.swift
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
@testable import MaruVision
import Testing

struct MokuroImportTests {
    private let sampleJSON = """
    {
      "version": "0.2.2",
      "title": "Test Volume",
      "title_uuid": "uuid-1",
      "volume": "test_1",
      "volume_uuid": "uuid-2",
      "pages": [
        {
          "version": "0.2.2",
          "img_width": 100,
          "img_height": 200,
          "blocks": [
            {
              "box": [10, 20, 30, 60],
              "vertical": true,
              "font_size": 40,
              "lines_coords": [[[10, 20], [30, 20], [30, 60], [10, 60]]],
              "lines": ["しかし、"]
            },
            {
              "box": [0, 0, 60, 20],
              "vertical": false,
              "font_size": 20,
              "lines_coords": [[[0, 0], [30, 0], [30, 20], [0, 20]]],
              "lines": ["a"]
            },
            {
              "box": [0, 100, 20, 120],
              "vertical": true,
              "font_size": 20,
              "lines_coords": [[[0, 100], [20, 100], [20, 120], [0, 120]]],
              "lines": ["mismatched", "block"]
            }
          ],
          "img_path": "001.jpg"
        }
      ]
    }
    """

    @Test func decode_parsesVolumeStructure() throws {
        let data = Data(sampleJSON.utf8)
        let volume = try JSONDecoder().decode(MokuroVolume.self, from: data)

        #expect(volume.pages.count == 1)
        let page = try #require(volume.pages.first)
        #expect(page.imgWidth == 100)
        #expect(page.imgHeight == 200)
        #expect(page.imgPath == "001.jpg")
        #expect(page.blocks.count == 3)
    }

    @Test func clusters_verticalBlock_usesVerticalDirectionAndJoinsLinesWithoutSeparator() throws {
        let volume = try JSONDecoder().decode(MokuroVolume.self, from: Data(sampleJSON.utf8))
        let page = try #require(volume.pages.first)

        let clusters = MokuroClusterConverter.clusters(for: page)
        let verticalCluster = try #require(clusters.first { $0.transcript == "しかし、" })

        #expect(verticalCluster.direction == .vertical)
        #expect(verticalCluster.lines.count == 1)
    }

    @Test func clusters_horizontalBlock_usesHorizontalDirection() throws {
        let volume = try JSONDecoder().decode(MokuroVolume.self, from: Data(sampleJSON.utf8))
        let page = try #require(volume.pages.first)

        let clusters = MokuroClusterConverter.clusters(for: page)
        let horizontalCluster = try #require(clusters.first { $0.transcript == "a" })

        #expect(horizontalCluster.direction == .horizontal)
    }

    @Test func clusters_boundingBoxIsNormalizedAgainstPageImageSize() throws {
        let volume = try JSONDecoder().decode(MokuroVolume.self, from: Data(sampleJSON.utf8))
        let page = try #require(volume.pages.first)

        let clusters = MokuroClusterConverter.clusters(for: page)
        let verticalCluster = try #require(clusters.first { $0.transcript == "しかし、" })

        // Pixel rect x:10-30, y:20-60 within a 100x200 image, converted to
        // Vision's lower-left-origin normalized coordinates.
        let box = verticalCluster.boundingBox
        #expect(abs(box.minX - 0.1) < 0.001)
        #expect(abs(box.width - 0.2) < 0.001)
        #expect(abs(box.minY - 0.7) < 0.001)
        #expect(abs(box.height - 0.2) < 0.001)
    }

    @Test func clusters_mismatchedLinesAndCoordsCount_skipsBlock() throws {
        let volume = try JSONDecoder().decode(MokuroVolume.self, from: Data(sampleJSON.utf8))
        let page = try #require(volume.pages.first)

        let clusters = MokuroClusterConverter.clusters(for: page)

        #expect(clusters.count == 2)
        #expect(!clusters.contains { $0.transcript.contains("mismatched") })
    }

    // MARK: - Out-of-bounds quads

    private func page(withQuad quad: [[Double]]) -> MokuroPage {
        MokuroPage(
            imgWidth: 100,
            imgHeight: 200,
            blocks: [MokuroBlock(vertical: false, linesCoords: [quad], lines: ["テスト"])],
            imgPath: "001.jpg"
        )
    }

    /// Mokuro quads can run past the image edge. An unclamped box is drawn
    /// off-page and widens the tap target, letting one bubble steal taps from its
    /// neighbour during hit-testing.
    @Test func clusters_quadExceedingPageBounds_isClampedToThePage() throws {
        // Overhangs the left edge and the bottom edge.
        let quad: [[Double]] = [[-20, -30], [40, -30], [40, 260], [-20, 260]]

        let clusters = MokuroClusterConverter.clusters(for: page(withQuad: quad))
        let box = try #require(clusters.first?.boundingBox)

        #expect(box.minX >= 0)
        #expect(box.minY >= 0)
        #expect(box.maxX <= 1)
        #expect(box.maxY <= 1)
    }

    @Test func clusters_quadClampingPreservesTheInBoundsEdge() throws {
        // Left edge is off-page; the right edge at x=40 of 100 must stay at 0.4.
        let quad: [[Double]] = [[-20, 20], [40, 20], [40, 60], [-20, 60]]

        let clusters = MokuroClusterConverter.clusters(for: page(withQuad: quad))
        let box = try #require(clusters.first?.boundingBox)

        // Trimmed at the page edge, not shifted right by the overhang.
        #expect(abs(box.minX - 0.0) < 0.001)
        #expect(abs(box.maxX - 0.4) < 0.001)
    }

    @Test func clusters_quadEntirelyOutsideThePage_isDropped() {
        let quad: [[Double]] = [[-80, -80], [-40, -80], [-40, -20], [-80, -20]]

        #expect(MokuroClusterConverter.clusters(for: page(withQuad: quad)).isEmpty)
    }

    @Test func clusters_zeroSizedPage_isDropped() {
        let page = MokuroPage(
            imgWidth: 0,
            imgHeight: 0,
            blocks: [MokuroBlock(
                vertical: false,
                linesCoords: [[[0, 0], [10, 0], [10, 10], [0, 10]]],
                lines: ["テスト"]
            )],
            imgPath: "001.jpg"
        )

        #expect(MokuroClusterConverter.clusters(for: page).isEmpty)
    }

    @Test func clusters_emptyBlocks_returnsEmptyArray() {
        let page = MokuroPage(imgWidth: 100, imgHeight: 100, blocks: [], imgPath: "empty.jpg")

        #expect(MokuroClusterConverter.clusters(for: page).isEmpty)
    }
}
