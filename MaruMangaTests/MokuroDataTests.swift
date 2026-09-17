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
    @Test func clusters_matchedFilenameWithNoBlocks_returnsNonNilEmptyArray() async {
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]), archiveFileNames: ["page-0.jpg"])

        let clusters = await mokuroData.clusters(forFileName: "page-0.jpg")

        // This is the exact contract the view model relies on to skip Vision:
        // a matched page with zero blocks must still be a match (non-nil),
        // not a signal to fall back.
        #expect(clusters != nil)
        #expect(clusters?.isEmpty == true)
    }

    @Test func clusters_unmatchedFilename_returnsNil() async {
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]), archiveFileNames: ["page-0.jpg"])

        let clusters = await mokuroData.clusters(forFileName: "does-not-match.jpg")

        #expect(clusters == nil)
    }

    @Test func clusters_nilFilename_returnsNil() async {
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]), archiveFileNames: ["page-0.jpg"])

        let clusters = await mokuroData.clusters(forFileName: nil)

        #expect(clusters == nil)
    }

    @Test func clusters_matchedFilenameWithBlocks_returnsConvertedClusters() async {
        let block = MokuroBlock(
            vertical: false,
            linesCoords: [[[0, 0], [40, 0], [40, 20], [0, 20]]],
            lines: ["テスト"]
        )
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [block], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [page]), archiveFileNames: ["page-0.jpg"])

        let clusters = await mokuroData.clusters(forFileName: "page-0.jpg")

        #expect(clusters?.map(\.transcript) == ["テスト"])
    }

    @Test func clusters_duplicateFileNameBasenames_firstPageWins() async {
        let firstBlock = MokuroBlock(
            vertical: false,
            linesCoords: [[[0, 0], [40, 0], [40, 20], [0, 20]]],
            lines: ["最初"]
        )
        let secondBlock = MokuroBlock(
            vertical: false,
            linesCoords: [[[0, 0], [40, 0], [40, 20], [0, 20]]],
            lines: ["二番目"]
        )
        let firstPage = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [firstBlock], imgPath: "dir1/page-0.jpg")
        let secondPage = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [secondBlock], imgPath: "dir2/page-0.jpg")
        let mokuroData = MokuroData(volume: MokuroVolume(pages: [firstPage, secondPage]), archiveFileNames: ["page-0.jpg"])

        let clusters = await mokuroData.clusters(forFileName: "page-0.jpg")

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

    // MARK: - Pairing is by filename only

    /// Positional pairing was removed: mokuro orders its pages alphabetically by
    /// `img_path`, which need not be the archive's reading order, so equal page
    /// counts do not imply equal ordering. Guessing produced confident, wrong text.
    @Test func noFilenameMatchWithEqualPageCounts_fallsBackToVision() async {
        let volume = makeVolume(
            names: ["cover.jpg", "i-001.jpg", "i-002.jpg"],
            transcripts: ["表紙", "一", "二"]
        )
        // Same page count as the archive, but nothing pairs by name.
        let mokuroData = MokuroData(volume: volume, archiveFileNames: ["001.jpg", "002.jpg", "003.jpg"])

        #expect(await mokuroData.clusters(forFileName: "001.jpg") == nil)
        #expect(await mokuroData.clusters(forFileName: "002.jpg") == nil)
        #expect(await mokuroData.clusters(forFileName: "003.jpg") == nil)
    }

    @Test func filenameMatchPairsRegardlessOfOrdering() async {
        let volume = makeVolume(
            names: ["page-0.jpg", "page-1.jpg"],
            transcripts: ["ゼロ", "イチ"]
        )
        let mokuroData = MokuroData(volume: volume, archiveFileNames: ["page-0.jpg", "page-1.jpg"])

        // Filename pairing is order-independent: the archive's position is irrelevant.
        let clusters = await mokuroData.clusters(forFileName: "page-1.jpg")

        #expect(clusters?.map(\.transcript) == ["イチ"])
    }

    // MARK: - Mode is decided from the whole archive, not one sample

    /// A page the mokuro file never saw falls back to Vision on its own, without
    /// affecting the pages that do pair.
    @Test func oneUnmatchedFilename_doesNotAffectTheOthers() async {
        let volume = makeVolume(
            names: ["page-0.jpg", "page-1.jpg", "page-2.jpg"],
            transcripts: ["ゼロ", "イチ", "ニ"]
        )
        // The archive's first page is a cover mokuro never saw; the rest match.
        let mokuroData = MokuroData(
            volume: volume,
            archiveFileNames: ["cover.jpg", "page-1.jpg", "page-2.jpg"]
        )

        #expect(await mokuroData.clusters(forFileName: "cover.jpg") == nil)

        let matched = await mokuroData.clusters(forFileName: "page-1.jpg")
        #expect(matched?.map(\.transcript) == ["イチ"])
    }

    @Test func resultsAreIndependentOfLookupOrder() async {
        let volume = makeVolume(names: ["page-0.jpg", "page-1.jpg"], transcripts: ["ゼロ", "イチ"])
        let archive = ["page-0.jpg", "page-1.jpg"]

        let forward = MokuroData(volume: volume, archiveFileNames: archive)
        let forwardFirst = await forward.clusters(forFileName: "page-0.jpg")

        let reverse = MokuroData(volume: volume, archiveFileNames: archive)
        _ = await reverse.clusters(forFileName: "page-1.jpg")
        let reverseFirst = await reverse.clusters(forFileName: "page-0.jpg")

        #expect(forwardFirst?.map(\.transcript) == reverseFirst?.map(\.transcript))
    }

    // MARK: - Malformed blocks fall through to Vision

    /// A page whose blocks all failed conversion has real text and bad geometry.
    /// Returning an empty array would tell the caller "no text here" and suppress
    /// Vision, leaving the page with nothing selectable.
    @Test func matchedPageWhoseBlocksAllFailedConversion_returnsNilSoVisionRuns() async {
        let malformed = MokuroBlock(
            vertical: false,
            linesCoords: [], // no coords for one line -> block is dropped
            lines: ["テスト"]
        )
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [malformed], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(
            volume: MokuroVolume(pages: [page]),
            archiveFileNames: ["page-0.jpg"]
        )

        let clusters = await mokuroData.clusters(forFileName: "page-0.jpg")

        #expect(clusters == nil, "Bad geometry must fall through to Vision, not report an empty page")
    }

    @Test func matchedPageWithGenuinelyNoBlocks_stillReturnsNonNilEmpty() async {
        let page = MokuroPage(imgWidth: 40, imgHeight: 60, blocks: [], imgPath: "page-0.jpg")
        let mokuroData = MokuroData(
            volume: MokuroVolume(pages: [page]),
            archiveFileNames: ["page-0.jpg"]
        )

        let clusters = await mokuroData.clusters(forFileName: "page-0.jpg")

        #expect(clusters != nil, "A page mokuro recorded with no blocks genuinely has no text")
        #expect(clusters?.isEmpty == true)
    }
}
