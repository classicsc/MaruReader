// AnkiFieldValueFormatter.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import Foundation
import UniformTypeIdentifiers

enum AnkiFieldValueFormatter {
    private static let fallbackMIMETypes: [String: String] = [
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "webp": "image/webp",
        "heic": "image/heic",
        "heif": "image/heif",
        "bmp": "image/bmp",
        "tif": "image/tiff",
        "tiff": "image/tiff",
        "mp3": "audio/mpeg",
        "m4a": "audio/mp4",
        "aac": "audio/aac",
        "wav": "audio/wav",
        "ogg": "audio/ogg",
        "flac": "audio/flac",
        "caf": "audio/x-caf",
    ]

    static func buildFieldValues(from fields: [String: [TemplateResolvedValue]]) -> [String: String] {
        var output: [String: String] = [:]

        for (fieldName, values) in fields {
            var pieces: [String] = []

            for value in values {
                if let text = value.text, !text.isEmpty {
                    pieces.append(text)
                }

                let mediaLinks = value.mediaFiles.values.compactMap { formatMediaLink(from: $0) }
                pieces.append(contentsOf: mediaLinks)
            }

            output[fieldName] = pieces.joined(separator: "<br>")
        }

        return output
    }

    private static func formatMediaLink(from url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased() else {
            return nil
        }

        switch scheme {
        case "http", "https":
            return url.absoluteString
        case "file":
            return dataURL(for: url)
        default:
            return nil
        }
    }

    private static func dataURL(for fileURL: URL) -> String? {
        guard let mimeType = mediaMimeType(for: fileURL) else {
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        let base64 = data.base64EncodedString()
        return "data:\(mimeType);base64,\(base64)"
    }

    private static func mediaMimeType(for fileURL: URL) -> String? {
        let ext = fileURL.pathExtension.lowercased()
        guard !ext.isEmpty
        else {
            return nil
        }

        if let type = UTType(filenameExtension: ext) {
            guard type.conforms(to: .image) || type.conforms(to: .audio) else {
                return nil
            }

            if let mimeType = type.preferredMIMEType {
                return mimeType
            }
        }

        return fallbackMIMETypes[ext]
    }
}
