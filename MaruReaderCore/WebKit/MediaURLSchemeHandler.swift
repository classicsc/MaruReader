//
//  MediaURLSchemeHandler.swift
//  MaruReader
//
//  URL scheme handler for marureader-media:// scheme to serve dictionary media files.
//

import Foundation
import os.log
import UniformTypeIdentifiers
import WebKit

public class MediaURLSchemeHandler: URLSchemeHandler {
    public init() {}

    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "MediaURLSchemeHandler")

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

        // Parse the URL: marureader-media://dictionaryUUID/filepath
        guard url.scheme == "marureader-media",
              let host = url.host(),
              let dictionaryUUID = UUID(uuidString: host)
        else {
            logger.error("Invalid marureader-media URL format: \(url.absoluteString)")
            return createNotFoundResponse()
        }

        let requestedPath = String(url.path.dropFirst())
        let fileURL = try mediaFileURL(dictionaryUUID: dictionaryUUID, filePath: requestedPath)

        // Check if file exists
        guard (try? fileURL.checkResourceIsReachable()) == true else {
            let dir = fileURL.deletingLastPathComponent()
            if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                logger.debug("Contents of \(dir.path): \(contents.map(\.lastPathComponent))")
            }
            logger.warning("Media file not found: \(fileURL.path)")
            return createNotFoundResponse()
        }

        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            logger.error("Failed to read media file: \(error.localizedDescription)")
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
                "Cache-Control": "max-age=31536000", // Cache for 1 year since media files are immutable
            ]
        )!

        logger.debug("Serving media file: \(fileURL.path()) (\(fileData.count) bytes, \(mimeType))")

        return [
            .response(response),
            .data(fileData),
        ]
    }

    private static func mediaFileURL(dictionaryUUID: UUID, filePath: String) throws -> URL {
        guard let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            throw MediaURLError.mediaDirectoryNotFound
        }
        let base = appGroupDir
            .appendingPathComponent("Media", isDirectory: true)
            .appendingPathComponent(dictionaryUUID.uuidString, isDirectory: true)

        return filePath.split(separator: "/").reduce(base) {
            $0.appendingPathComponent(String($1), isDirectory: false)
        }
    }

    private static func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()

        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }

        // Fallback for common media types
        switch pathExtension {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "svg":
            return "image/svg+xml"
        case "webp":
            return "image/webp"
        case "mp3":
            return "audio/mpeg"
        case "ogg":
            return "audio/ogg"
        case "wav":
            return "audio/wav"
        case "mp4":
            return "video/mp4"
        case "webm":
            return "video/webm"
        default:
            return "application/octet-stream"
        }
    }

    private static func createNotFoundResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-media://error")!,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        let data = "File not found".data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }

    private static func createServerErrorResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-media://error")!,
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

enum MediaURLError: Error {
    case mediaDirectoryNotFound
}
