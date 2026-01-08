// AudioURLSchemeHandler.swift
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
import os.log
import UniformTypeIdentifiers
import WebKit

public struct AudioURLSchemeHandler: URLSchemeHandler {
    public init() {}

    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "AudioURLSchemeHandler")

    public nonisolated func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream<URLSchemeTaskResult, Error> { continuation in
            let task = Task { @Sendable in
                do {
                    let results = try await Self.handleRequest(request)
                    for result in results {
                        continuation.yield(result)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private static func handleRequest(_ request: URLRequest) async throws -> [URLSchemeTaskResult] {
        guard let url = request.url else {
            logger.error("Invalid URL in request")
            return createNotFoundResponse()
        }

        logger.debug("Handling request for URL: \(url.absoluteString)")

        // Parse the URL: marureader-audio://sourceUUID/filepath
        guard url.scheme == "marureader-audio",
              let host = url.host(),
              let sourceUUID = UUID(uuidString: host)
        else {
            logger.error("Invalid marureader-audio URL format: \(url.absoluteString)")
            return createNotFoundResponse()
        }

        let requestedPath = String(url.path.dropFirst())
        let fileURL = try audioFileURL(sourceUUID: sourceUUID, filePath: requestedPath)

        // Check if file exists
        guard (try? fileURL.checkResourceIsReachable()) == true else {
            let dir = fileURL.deletingLastPathComponent()
            if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                logger.debug("Contents of \(dir.path): \(contents.map(\.lastPathComponent))")
            }
            logger.warning("Audio file not found: \(fileURL.path)")
            return createNotFoundResponse()
        }

        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            logger.error("Failed to read audio file: \(error.localizedDescription)")
            return createServerErrorResponse()
        }

        // Determine MIME type
        let mimeType = getMimeType(for: fileURL)

        // Create HTTP response
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": mimeType,
                "Content-Length": "\(fileData.count)",
                "Cache-Control": "max-age=31536000", // Cache for 1 year since audio files are immutable
            ]
        )!

        logger.debug("Serving audio file: \(fileURL.path()) (\(fileData.count) bytes, \(mimeType))")

        return [
            .response(response),
            .data(fileData),
        ]
    }

    private static func audioFileURL(sourceUUID: UUID, filePath: String) throws -> URL {
        guard let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            throw AudioURLError.audioDirectoryNotFound
        }
        let base = appGroupDir
            .appendingPathComponent("AudioMedia", isDirectory: true)
            .appendingPathComponent(sourceUUID.uuidString, isDirectory: true)

        return filePath.split(separator: "/").reduce(base) {
            $0.appendingPathComponent(String($1), isDirectory: false)
        }
    }

    private static func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()

        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }

        // Fallback for common audio types
        switch pathExtension {
        case "mp3":
            return "audio/mpeg"
        case "ogg", "oga":
            return "audio/ogg"
        case "wav":
            return "audio/wav"
        case "m4a", "aac":
            return "audio/mp4"
        case "flac":
            return "audio/flac"
        case "opus":
            return "audio/opus"
        default:
            return "application/octet-stream"
        }
    }

    private static func createNotFoundResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-audio://error")!,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        let data = "Audio file not found".data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }

    private static func createServerErrorResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-audio://error")!,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        let data = "Internal server error".data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }
}

enum AudioURLError: Error {
    case audioDirectoryNotFound
}
