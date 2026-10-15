// MokuroFixtures.swift
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
import UIKit
import Zip

/// CBZ and `.mokuro` fixtures shared by the embedded-import and manual-attach
/// mokuro tests.
enum MokuroFixture {
    enum FixtureError: Error {
        case imageEncodingFailed
        case archiveNotWritten
    }

    /// The directory the fixture CBZ wraps its files in, mirroring a real volume
    /// archive. Page entry paths are therefore prefixed, which is what a mokuro
    /// file generated from such an archive records in `img_path`.
    static let archiveDirectory = "contents"

    static let defaultImageNames = ["001.jpg", "002.jpg", "003.jpg"]

    /// The path a fixture page image has inside the archive.
    static func archivePath(_ imageName: String) -> String {
        "\(archiveDirectory)/\(imageName)"
    }

    /// Mokuro JSON covering the given paths, exactly as mokuro records them.
    /// `imgWidth` distinguishes otherwise identical fixtures.
    static func mokuroJSON(imgPaths: [String], imgWidth: Int = 10) -> String {
        let pages = imgPaths.map { path in
            """
            {"img_width": \(imgWidth), "img_height": 10, "blocks": [], "img_path": "\(path)"}
            """
        }
        return "{\"pages\": [\(pages.joined(separator: ","))]}"
    }

    /// Mokuro JSON covering the default fixture archive, page for page.
    static func matchingMokuroJSON(imgWidth: Int = 10) -> String {
        mokuroJSON(imgPaths: defaultImageNames.map(archivePath), imgWidth: imgWidth)
    }

    static func imageData(hue: CGFloat) throws -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { context in
            UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw FixtureError.imageEncodingFailed
        }
        return data
    }

    /// Builds a CBZ containing the given page images plus whichever extra files are
    /// given as `path relative to the archive's directory` -> `contents`.
    ///
    /// The caller owns the returned URL's parent directory and should delete it.
    static func makeArchive(
        named name: String = "Fixture Manga",
        imageNames: [String] = defaultImageNames,
        extraFiles: [String: String] = [:]
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let contentsDir = tempDir.appendingPathComponent(archiveDirectory)
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        for (index, imageName) in imageNames.enumerated() {
            let data = try imageData(hue: CGFloat(index) / CGFloat(max(imageNames.count, 1)))
            try data.write(to: contentsDir.appendingPathComponent(imageName))
        }

        for (relativePath, contents) in extraFiles {
            let fileURL = contentsDir.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let archiveURL = tempDir.appendingPathComponent("\(name).cbz")
        try Zip.zipFiles(paths: [contentsDir], zipFilePath: archiveURL, password: nil, progress: nil)

        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            throw FixtureError.archiveNotWritten
        }
        return archiveURL
    }
}
