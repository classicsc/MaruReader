// AudioURLSchemeHandler.swift
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
import os
import UniformTypeIdentifiers
import WebKit

public struct AudioURLSchemeHandler: URLSchemeHandler, Sendable {
    private let lookupServiceHolder: LookupServiceHolder

    private actor LookupServiceHolder {
        private enum Storage {
            case factory(@Sendable () -> AudioLookupService)
            case service(AudioLookupService)
        }

        private var storage: Storage

        init(factory: @escaping @Sendable () -> AudioLookupService) {
            storage = .factory(factory)
        }

        init(service: AudioLookupService) {
            storage = .service(service)
        }

        func service() -> AudioLookupService {
            switch storage {
            case let .service(service):
                return service
            case let .factory(factory):
                let service = factory()
                storage = .service(service)
                return service
            }
        }
    }

    public init() {
        lookupServiceHolder = LookupServiceHolder {
            AudioLookupService(persistenceController: .shared)
        }
    }

    init(lookupService: AudioLookupService) {
        lookupServiceHolder = LookupServiceHolder(service: lookupService)
    }

    init(lookupServiceFactory: @escaping @Sendable () -> AudioLookupService) {
        lookupServiceHolder = LookupServiceHolder(factory: lookupServiceFactory)
    }

    private static let logger = Logger.maru(category: "AudioURLSchemeHandler")

    public nonisolated func reply(for request: URLRequest) -> some AsyncSequence<URLSchemeTaskResult, any Error> {
        AsyncThrowingStream<URLSchemeTaskResult, Error> { continuation in
            let task = Task { @Sendable in
                do {
                    let results = try await handleRequest(request)
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

    func handleRequest(_ request: URLRequest) async throws -> [URLSchemeTaskResult] {
        guard let url = request.url else {
            Self.logger.error("Invalid URL in request")
            return Self.createNotFoundResponse()
        }

        Self.logger.debug("Handling request for URL: \(url.absoluteString)")

        guard url.scheme == "marureader-audio" else {
            Self.logger.error("Invalid marureader-audio URL format: \(url.absoluteString)")
            return Self.createNotFoundResponse()
        }

        if url.host() == "lookup" {
            return try await handleLookupRequest(url)
        }

        // Parse the URL: marureader-audio://sourceUUID/filepath
        guard let host = url.host(),
              let sourceUUID = UUID(uuidString: host)
        else {
            Self.logger.error("Invalid marureader-audio URL format: \(url.absoluteString)")
            return Self.createNotFoundResponse()
        }

        let requestedPath = String(url.path.dropFirst())
        let fileURL = try Self.audioFileURL(sourceUUID: sourceUUID, filePath: requestedPath)

        // Check if file exists
        guard (try? fileURL.checkResourceIsReachable()) == true else {
            let dir = fileURL.deletingLastPathComponent()
            if let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                Self.logger.debug("Contents of \(dir.path): \(contents.map(\.lastPathComponent))")
            }
            Self.logger.warning("Audio file not found: \(fileURL.path)")
            return Self.createNotFoundResponse()
        }

        // Read file data
        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            Self.logger.error("Failed to read audio file: \(error.localizedDescription)")
            return Self.createServerErrorResponse()
        }

        // Determine MIME type
        let mimeType = Self.getMimeType(for: fileURL)

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

        Self.logger.debug("Serving audio file: \(fileURL.path()) (\(fileData.count) bytes, \(mimeType))")

        return [
            .response(response),
            .data(fileData),
        ]
    }

    private func handleLookupRequest(_ url: URL) async throws -> [URLSchemeTaskResult] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return Self.createBadRequestResponse(message: "Invalid lookup URL")
        }

        let queryItems = components.queryItems ?? []
        let term = queryItems.first(where: { $0.name == "term" })?.value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let term, !term.isEmpty else {
            return Self.createBadRequestResponse(message: "Missing term")
        }

        let readingValue = queryItems.first(where: { $0.name == "reading" })?.value
        let reading = readingValue?.isEmpty == true ? nil : readingValue
        let languageValue = queryItems.first(where: { $0.name == "language" })?.value
        let language = languageValue?.isEmpty == false ? languageValue! : "ja"
        let lookupService = await lookupServiceHolder.service()

        try await lookupService.ensureLoaded()

        let request = AudioLookupRequest(
            term: term,
            reading: reading,
            downstepPosition: nil,
            language: language
        )

        let result = await lookupService.lookupAudio(for: request)
        let sources = result.sources.map { source in
            AudioLookupSource(
                url: source.url.absoluteString,
                providerName: source.providerName,
                itemName: source.sourceName == source.providerName ? nil : source.sourceName,
                pitch: source.pitchNumber
            )
        }

        let responseBody = AudioLookupResponse(sources: sources)
        let data = try JSONEncoder().encode(responseBody)

        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "application/json",
                "Content-Length": "\(data.count)",
                "Cache-Control": "no-store",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "Content-Type",
            ]
        )!

        return [
            .response(response),
            .data(data),
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

    private static func createBadRequestResponse(message: String) -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-audio://error")!,
            statusCode: 400,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": "text/plain",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "Content-Type",
            ]
        )!

        let data = message.data(using: .utf8) ?? Data()

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
            headerFields: [
                "Content-Type": "text/plain",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET",
                "Access-Control-Allow-Headers": "Content-Type",
            ]
        )!

        let data = "Internal server error".data(using: .utf8)!

        return [
            .response(response),
            .data(data),
        ]
    }
}

private struct AudioLookupResponse: Encodable {
    let sources: [AudioLookupSource]
}

private struct AudioLookupSource: Encodable {
    let url: String
    let providerName: String
    let itemName: String?
    let pitch: String?
}

enum AudioURLError: Error {
    case audioDirectoryNotFound
}
