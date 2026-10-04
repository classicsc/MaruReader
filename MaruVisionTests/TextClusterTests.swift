// TextClusterTests.swift
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

@testable import MaruVision
import Testing
import Vision

struct TextClusterTests {
    @Test func transcript_horizontalDirection_joinsLinesWithNewline() {
        let lines = [
            TextClusterLine(transcript: "line one", boundingBox: NormalizedRect(x: 0.1, y: 0.6, width: 0.3, height: 0.2)),
            TextClusterLine(transcript: "line two", boundingBox: NormalizedRect(x: 0.1, y: 0.3, width: 0.3, height: 0.2)),
        ]
        let cluster = TextCluster(lines: lines, direction: .horizontal)

        #expect(cluster.transcript == "line one\nline two")
        #expect(cluster.lines.count == 2)
    }

    @Test func transcript_verticalDirection_joinsLinesWithoutSeparator() {
        let lines = [
            TextClusterLine(transcript: "しか", boundingBox: NormalizedRect(x: 0.7, y: 0.6, width: 0.1, height: 0.2)),
            TextClusterLine(transcript: "し、", boundingBox: NormalizedRect(x: 0.7, y: 0.4, width: 0.1, height: 0.2)),
        ]
        let cluster = TextCluster(lines: lines, direction: .vertical)

        #expect(cluster.transcript == "しかし、")
    }

    @Test func boundingBox_isUnionOfAllLines() {
        let lines = [
            TextClusterLine(transcript: "a", boundingBox: NormalizedRect(x: 0.1, y: 0.6, width: 0.2, height: 0.2)),
            TextClusterLine(transcript: "b", boundingBox: NormalizedRect(x: 0.5, y: 0.1, width: 0.3, height: 0.3)),
        ]
        let cluster = TextCluster(lines: lines, direction: .horizontal)

        let box = cluster.boundingBox
        #expect(abs(box.minX - 0.1) < 0.0001)
        #expect(abs(box.minY - 0.1) < 0.0001)
        #expect(abs(box.maxX - 0.8) < 0.0001)
        #expect(abs(box.maxY - 0.8) < 0.0001)
    }

    @Test func emptyLines_producesZeroBoundingBox() {
        let cluster = TextCluster(lines: [], direction: .horizontal)

        #expect(cluster.boundingBox == .zero)
        #expect(cluster.transcript == "")
    }
}
