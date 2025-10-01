//
//  MediaRouteHandler.swift
//  MaruReader
//
//  Route handler for serving dictionary media files via HTTP.
//  Replaces MediaURLSchemeHandler.
//

import Foundation
import os.log
import ReadiumGCDWebServer
import UniformTypeIdentifiers

/// Handles HTTP requests for dictionary media files
/// Route pattern: /media/{dictionaryUUID}/{filepath}
class MediaRouteHandler {
    private static let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "MediaRouteHandler")

    /// Registers the media route handler with the server manager
    @MainActor
    static func register(with manager: WebServerManager) {
        manager.addHandler(
            matchBlock: { method, url, _, urlPath, _ in
                // Match GET requests to /media/*
                guard method == "GET",
                      urlPath.hasPrefix("/media/")
                else {
                    return nil
                }
                return ReadiumGCDWebServerRequest(method: method, url: url, headers: [:], path: urlPath, query: [:])
            },
            processBlock: { request in
                Self.handleRequest(request)
            }
        )
    }

    private static func handleRequest(_ request: ReadiumGCDWebServerRequest) -> ReadiumGCDWebServerResponse? {
        let urlPath = request.path
        logger.info("Handling media request: \(urlPath)")

        // Parse path: /media/{dictionaryUUID}/{filepath}
        let components = urlPath.split(separator: "/").map(String.init)
        guard components.count >= 3,
              components[0] == "media",
              let dictionaryUUID = UUID(uuidString: components[1])
        else {
            logger.error("Invalid media URL format: \(urlPath)")
            return createNotFoundResponse()
        }

        let filePath = components[2...].joined(separator: "/")

        do {
            let fileURL = try mediaFileURL(dictionaryUUID: dictionaryUUID, filePath: filePath)

            // Check if file exists
            guard (try? fileURL.checkResourceIsReachable()) == true else {
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

            logger.debug("Serving media file: \(fileURL.path()) (\(fileData.count) bytes, \(mimeType))")

            // Create response
            let response = ReadiumGCDWebServerDataResponse(data: fileData, contentType: mimeType)
            response.cacheControlMaxAge = 31_536_000 // Cache for 1 year
            return response

        } catch {
            logger.error("Error handling media request: \(error.localizedDescription)")
            return createServerErrorResponse()
        }
    }

    private static func mediaFileURL(dictionaryUUID: UUID, filePath: String) throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let base = appSupport
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

    private static func createNotFoundResponse() -> ReadiumGCDWebServerResponse {
        ReadiumGCDWebServerDataResponse(
            data: "File not found".data(using: .utf8)!,
            contentType: "text/plain"
        )
    }

    private static func createServerErrorResponse() -> ReadiumGCDWebServerResponse {
        let response = ReadiumGCDWebServerDataResponse(
            data: "Internal server error".data(using: .utf8)!,
            contentType: "text/plain"
        )
        response.statusCode = 500
        return response
    }
}
