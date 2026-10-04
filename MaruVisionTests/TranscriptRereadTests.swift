// TranscriptRereadTests.swift
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
import UIKit
import Vision

/// `OCR.transcript(of:in:)` re-reads a tapped cluster's lines with Vision. Only
/// clusters Vision produced may be re-read: mokuro text comes from a dedicated
/// manga OCR model, and replacing it with Vision's reading of the same boxes
/// would undo the reason for attaching the mokuro file.
struct TranscriptRereadTests {
    /// The rendered text and the box it was drawn in (normalized, lower-left origin).
    private static let renderedText = "日本語"
    private static let lineBox = NormalizedRect(x: 0.05, y: 0.2, width: 0.9, height: 0.6)

    private static func makeImage() -> UIImage {
        let size = CGSize(width: 400, height: 200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            (renderedText as NSString).draw(
                at: CGPoint(x: 60, y: 60),
                withAttributes: [.font: UIFont.systemFont(ofSize: 80), .foregroundColor: UIColor.black]
            )
        }
    }

    private static func cluster(source: TextClusterSource) -> TextCluster {
        TextCluster(
            lines: [TextClusterLine(transcript: "別の文字", boundingBox: lineBox)],
            direction: .horizontal,
            source: source
        )
    }

    @Test func mokuroCluster_keepsItsOwnText() async {
        let text = await OCR().transcript(of: Self.cluster(source: .mokuro), in: Self.makeImage()).value

        #expect(text == "別の文字")
    }

    /// Control for the test above: the same box is readable, so a Vision cluster
    /// does get re-read. Without this, the mokuro test would also pass if the
    /// re-read simply failed.
    @Test func visionCluster_isReread() async {
        let text = await OCR().transcript(of: Self.cluster(source: .vision), in: Self.makeImage()).value

        #expect(text == Self.renderedText)
    }
}
