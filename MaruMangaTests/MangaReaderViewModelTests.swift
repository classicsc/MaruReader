// MangaReaderViewModelTests.swift
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
import Testing

struct MangaReaderViewModelTests {
    @Test func screenshotLookupClusterIndex_PrefersProfessorExperimentPrefix() {
        let transcripts = [
            "ドドドドド",
            "教授の実験を\n見ていたんだ",
            "別の吹き出し",
        ]

        let selectedIndex = MangaReaderViewModel.screenshotLookupClusterIndex(in: transcripts)

        #expect(selectedIndex == 1)
    }

    @Test func screenshotLookupClusterIndex_FallsBackToFirstCluster() {
        let transcripts = [
            "ドドドドド",
            "別の吹き出し",
        ]

        let selectedIndex = MangaReaderViewModel.screenshotLookupClusterIndex(in: transcripts)

        #expect(selectedIndex == 0)
    }
}
