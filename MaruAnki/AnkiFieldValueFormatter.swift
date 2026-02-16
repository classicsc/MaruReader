// AnkiFieldValueFormatter.swift
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
                var usedMediaKeys: Set<String> = []

                if let text = value.text, !text.isEmpty {
                    let inlineResult = inlineMediaLinks(in: text, mediaFiles: value.mediaFiles)
                    usedMediaKeys = inlineResult.usedKeys
                    pieces.append(inlineResult.text)
                }

                let remainingMedia = value.mediaFiles.filter { !usedMediaKeys.contains($0.key) }
                let mediaLinks = remainingMedia.values.compactMap { formatMediaLink(from: $0) }
                for mediaLink in mediaLinks {
                    if !pieces.isEmpty {
                        pieces.append("<br>")
                    }
                    pieces.append(mediaLink)
                }
            }

            output[fieldName] = pieces.joined()
        }

        return output
    }

    private static func inlineMediaLinks(
        in text: String,
        mediaFiles: [String: URL]
    ) -> (text: String, usedKeys: Set<String>) {
        var updated = text
        var usedKeys: Set<String> = []

        for (key, url) in mediaFiles {
            guard let link = formatMediaLink(from: url) else {
                continue
            }

            let escapedKey = escapeHTMLAttribute(key)
            let patterns = [
                "src=\"\(escapedKey)\"",
                "src='\(escapedKey)'",
                "src=\"\(key)\"",
                "src='\(key)'",
            ]

            var replaced = false
            for pattern in patterns where updated.contains(pattern) {
                updated = updated.replacingOccurrences(of: pattern, with: "src=\"\(link)\"")
                replaced = true
            }

            if replaced {
                usedKeys.insert(key)
            }
        }

        return (updated, usedKeys)
    }

    /// Returns a URL string for use in HTML src attributes (for inlining into existing tags).
    private static func formatMediaLink(from url: URL) -> String? {
        guard let scheme = url.scheme?.lowercased() else {
            return nil
        }

        switch scheme {
        case "http", "https":
            return url.absoluteString
        case "file":
            return dataURL(for: url)
        case "marureader-audio":
            return dataURLForAudioScheme(url)
        default:
            return nil
        }
    }

    private enum MediaType {
        case audio
        case image
        case unknown
    }

    private static func mediaType(for url: URL) -> MediaType {
        let ext = url.pathExtension.lowercased()
        guard !ext.isEmpty else {
            return .unknown
        }

        if let type = UTType(filenameExtension: ext) {
            if type.conforms(to: .audio) {
                return .audio
            } else if type.conforms(to: .image) {
                return .image
            }
        }

        // Fallback for extensions not recognized by UTType
        let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "ogg", "flac", "caf"]
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tif", "tiff"]

        if audioExtensions.contains(ext) {
            return .audio
        } else if imageExtensions.contains(ext) {
            return .image
        }

        return .unknown
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

    /// Converts a marureader-audio:// URL to a data URL by resolving the file path.
    /// Format: marureader-audio://{sourceUUID}/{filepath}
    private static func dataURLForAudioScheme(_ url: URL) -> String? {
        guard url.scheme == "marureader-audio",
              let host = url.host(),
              UUID(uuidString: host) != nil
        else {
            return nil
        }

        guard let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AnkiPersistenceController.appGroupIdentifier
        ) else {
            return nil
        }

        let requestedPath = String(url.path.dropFirst())
        let fileURL = requestedPath.split(separator: "/").reduce(
            appGroupDir
                .appendingPathComponent("AudioMedia", isDirectory: true)
                .appendingPathComponent(host, isDirectory: true)
        ) {
            $0.appendingPathComponent(String($1), isDirectory: false)
        }

        return dataURL(for: fileURL)
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

    private static func escapeHTMLAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
