// MokuroData.swift
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

import Foundation
import MaruReaderCore
import MaruVision
import os

/// Holds a parsed mokuro volume's pages so `MangaReaderViewModel` can look up
/// pre-computed OCR clusters per page without re-parsing the mokuro file.
///
/// Pages are paired with archive pages **by full archive entry path**, matching
/// `img_path` exactly. This is the same rule `MangaImportManager` validates with
/// before attaching a file, so a file that gets attached always pairs. Matching on
/// the whole path, not the filename, keeps archives holding several volumes apart
/// when their page filenames repeat (`Vol1/001.jpg`, `Vol2/001.jpg`).
///
/// Pairing by position was tried and removed: mokuro orders its `pages` array
/// alphabetically by `img_path`, which is not necessarily the archive's reading
/// order, so equal page counts do not imply equal ordering. A real 166-page volume
/// paired that way was misaligned by one — a blank page sorted last in mokuro but
/// sat second in the archive — which renders confident, wrong Japanese text with
/// nothing to signal it. There is no way to recover the true ordering from the
/// `.mokuro` file alone, so an unmatched page falls back to Vision OCR instead of
/// guessing.
///
/// The reliable workflow is to generate the `.mokuro` from the archive itself, so
/// its `img_path` values are the archive's own entry paths.
struct MokuroData: Sendable {
    private let pagesByPath: [String: MokuroPage]
    private let logger = Logger.maru(category: "MokuroData")

    init(volume: MokuroVolume) {
        var mapping: [String: MokuroPage] = [:]
        for page in volume.pages where mapping[page.imgPath] == nil {
            // Keep the first page for a given path if duplicates exist.
            mapping[page.imgPath] = page
        }
        pagesByPath = mapping
    }

    /// How many of the given archive page entry paths this volume has a page for.
    func matchCount(archivePaths: [String]) -> Int {
        archivePaths.count { pagesByPath[$0] != nil }
    }

    /// Returns mokuro-derived clusters for the archive page at the given entry
    /// path, or `nil` if this volume has nothing usable for it (the caller falls
    /// back to Vision OCR).
    ///
    /// A non-nil empty array means "this page paired and legitimately has no text"
    /// and must NOT be treated as a miss.
    func clusters(forPath path: String?) -> [TextCluster]? {
        guard let path, let page = pagesByPath[path] else { return nil }
        return usableClusters(for: page)
    }

    /// Converts a paired page, distinguishing a page that legitimately has no text
    /// from one whose blocks all failed conversion.
    ///
    /// An empty return means "no text here" and stops Vision from running. That is
    /// right for a page mokuro recorded with no blocks, but wrong for a page whose
    /// blocks were all dropped as malformed — that page has real text and bad
    /// geometry, so it should fall through to Vision rather than show nothing.
    private func usableClusters(for page: MokuroPage) -> [TextCluster]? {
        let clusters = MokuroClusterConverter.clusters(for: page)
        guard clusters.isEmpty, !page.blocks.isEmpty else { return clusters }

        logger.warning(
            """
            Mokuro page \(page.imgPath, privacy: .public) has \
            \(page.blocks.count, privacy: .public) block(s) but none could be converted; \
            falling back to Vision OCR for this page.
            """
        )
        return nil
    }
}
