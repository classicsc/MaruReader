// MokuroDataTests.swift
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

@testable import MaruManga
import MaruVision
import Testing

struct MokuroDataTests {
    @Test func clusters_matchedPathWithNoBlocks_returnsNonNilEmptyArray() {
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]))

        let clusters = mokuroData.clusters(forPath: "page-0.jpg")

        // This is the exact contract the view model relies on to skip Vision:
        // a matched page with zero blocks must still be a match (non-nil),
        // not a signal to fall back.
        #expect(clusters != nil)
        #expect(clusters?.isEmpty == true)
    }

    @Test func clusters_unmatchedPath_returnsNil() {
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]))

        let clusters = mokuroData.clusters(forPath: "does-not-match.jpg")

        #expect(clusters == nil)
    }

    @Test func clusters_nilPath_returnsNil() {
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]))

        let clusters = mokuroData.clusters(forPath: nil)

        #expect(clusters == nil)
    }

    @Test func clusters_matchedPathWithBlocks_returnsConvertedClusters() {
        let block = MokuroBlock(
            vertical: false,
            linesCoords: [[[0, 0], [40, 0], [40, 20], [0, 20]]],
            lines: ["テスト"]
        )
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [block], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]))

        let clusters = mokuroData.clusters(forPath: "page-0.jpg")

        #expect(clusters?.map(\.transcript) == ["テスト"])
    }

    @Test func clusters_duplicatePaths_firstPageWins() {
        let volume = makeVolume(names: ["page-0.jpg", "page-0.jpg"], transcripts: ["最初", "二番目"])
        let mokuroData = MokuroData(volume: volume)

        let clusters = mokuroData.clusters(forPath: "page-0.jpg")

        #expect(clusters?.map(\.transcript) == ["最初"])
    }

    // MARK: - Helpers

    private func makeVolume(names: [String], transcripts: [String]) -> MokuroVolume {
        MokuroVolume(pages: zip(names, transcripts).map { name, transcript in
            MokuroPage(
                imgWidth: 40,
                imgHeight: 60,
                blocks: [
                    MokuroBlock(
                        vertical: false,
                        linesCoords: [[[0, 0], [40, 0], [40, 20], [0, 20]]],
                        lines: [transcript]
                    ),
                ],
                imgPath: name
            )
        })
    }

    // MARK: - Pairing is by full archive entry path

    /// An archive holding several volumes can repeat page filenames across
    /// directories. Each must pair with its own mokuro page.
    @Test func sameFilenameInDifferentDirectories_pairsEachByFullPath() {
        let volume = makeVolume(
            names: ["Vol1/page-0.jpg", "Vol2/page-0.jpg"],
            transcripts: ["一巻", "二巻"]
        )
        let mokuroData = MokuroData(volume: volume)

        #expect(mokuroData.clusters(forPath: "Vol1/page-0.jpg")?.map(\.transcript) == ["一巻"])
        #expect(mokuroData.clusters(forPath: "Vol2/page-0.jpg")?.map(\.transcript) == ["二巻"])
    }

    /// A filename alone no longer pairs with a nested `img_path`, or vice versa.
    @Test func filenameOnly_doesNotPairWithNestedPath() {
        let volume = makeVolume(names: ["contents/page-0.jpg"], transcripts: ["ゼロ"])
        let mokuroData = MokuroData(volume: volume)

        #expect(mokuroData.clusters(forPath: "page-0.jpg") == nil)
        #expect(mokuroData.matchCount(archivePaths: ["page-0.jpg"]) == 0)
    }

    /// Positional pairing was removed: mokuro orders its pages alphabetically by
    /// `img_path`, which need not be the archive's reading order, so equal page
    /// counts do not imply equal ordering. Guessing produced confident, wrong text.
    @Test func noPathMatchWithEqualPageCounts_fallsBackToVision() {
        let volume = makeVolume(
            names: ["cover.jpg", "i-001.jpg", "i-002.jpg"],
            transcripts: ["表紙", "一", "二"]
        )
        // Same page count as the archive, but nothing pairs by path.
        let mokuroData = MokuroData(volume: volume)

        #expect(mokuroData.matchCount(archivePaths: ["001.jpg", "002.jpg", "003.jpg"]) == 0)
        #expect(mokuroData.clusters(forPath: "001.jpg") == nil)
        #expect(mokuroData.clusters(forPath: "002.jpg") == nil)
        #expect(mokuroData.clusters(forPath: "003.jpg") == nil)
    }

    @Test func pathMatchPairsRegardlessOfOrdering() {
        let volume = makeVolume(
            names: ["page-0.jpg", "page-1.jpg"],
            transcripts: ["ゼロ", "イチ"]
        )
        let mokuroData = MokuroData(volume: volume)

        // Path pairing is order-independent: the archive's position is irrelevant.
        let clusters = mokuroData.clusters(forPath: "page-1.jpg")

        #expect(clusters?.map(\.transcript) == ["イチ"])
    }

    // MARK: - Match counting

    /// A page the mokuro file never saw falls back to Vision on its own, without
    /// affecting the pages that do pair.
    @Test func oneUnmatchedPath_doesNotAffectTheOthers() {
        let volume = makeVolume(
            names: ["page-0.jpg", "page-1.jpg", "page-2.jpg"],
            transcripts: ["ゼロ", "イチ", "ニ"]
        )
        // The archive's first page is a cover mokuro never saw; the rest match.
        let mokuroData = MokuroData(volume: volume)

        #expect(mokuroData.matchCount(archivePaths: ["cover.jpg", "page-1.jpg", "page-2.jpg"]) == 2)
        #expect(mokuroData.clusters(forPath: "cover.jpg") == nil)
        #expect(mokuroData.clusters(forPath: "page-1.jpg")?.map(\.transcript) == ["イチ"])
    }

    // MARK: - Malformed blocks fall through to Vision

    /// A page whose blocks all failed conversion has real text and bad geometry.
    /// Returning an empty array would tell the caller "no text here" and suppress
    /// Vision, leaving the page with nothing selectable.
    @Test func matchedPageWhoseBlocksAllFailedConversion_returnsNilSoVisionRuns() {
        let malformed = MokuroBlock(
            vertical: false,
            linesCoords: [], // no coords for one line -> block is dropped
            lines: ["テスト"]
        )
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [malformed], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]))

        let clusters = mokuroData.clusters(forPath: "page-0.jpg")

        #expect(clusters == nil, "Bad geometry must fall through to Vision, not report an empty page")
    }

    @Test func matchedPageWithGenuinelyNoBlocks_stillReturnsNonNilEmpty() {
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]))

        let clusters = mokuroData.clusters(forPath: "page-0.jpg")

        #expect(clusters != nil, "A page mokuro recorded with no blocks genuinely has no text")
        #expect(clusters?.isEmpty == true)
    }
}
