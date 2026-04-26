// GrammarDictionaryURLSchemeHandler.swift
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

import CoreData
import Foundation
import MaruMark
import os
import UniformTypeIdentifiers
import WebKit

public final actor GrammarDictionaryURLSchemeHandler: URLSchemeHandler {
    private struct StoredEntry {
        let title: String
        let path: String
    }

    private static let logger = Logger.maru(category: "GrammarDictionaryURLSchemeHandler")

    private let persistentContainer: NSPersistentContainer
    private let baseDirectory: URL?
    private var displayStylesOverride: DisplayStyles?
    private var webTheme: DictionaryWebTheme?

    public init(
        persistenceController: DictionaryPersistenceController = .shared,
        baseDirectory: URL? = nil
    ) {
        persistentContainer = persistenceController.container
        self.baseDirectory = baseDirectory ?? persistenceController.baseDirectory
    }

    public func setDisplayStyles(_ styles: DisplayStyles?) {
        displayStylesOverride = styles
    }

    public func setWebTheme(_ theme: DictionaryWebTheme?) {
        webTheme = theme
    }

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

        guard url.scheme == "marureader-grammar", let host = url.host(), !host.isEmpty else {
            Self.logger.error("Invalid marureader-grammar URL format: \(url.absoluteString)")
            return Self.createNotFoundResponse()
        }

        switch host {
        case "entry":
            return try await handleEntryRequest(url: url)
        case "media":
            return try handleMediaRequest(url: url)
        default:
            Self.logger.error("Unknown marureader-grammar endpoint: \(host)")
            return Self.createNotFoundResponse()
        }
    }

    private func handleEntryRequest(url: URL) async throws -> [URLSchemeTaskResult] {
        guard let identifiers = Self.entryIdentifiers(from: url) else {
            return Self.createBadRequestResponse()
        }

        guard let installDirectory = GrammarDictionaryStorage.installedDirectoryURL(
            grammarDictionaryID: identifiers.dictionaryID,
            in: baseDirectory
        ) else {
            return Self.createNotFoundResponse()
        }

        guard let entry = try await fetchEntry(
            dictionaryID: identifiers.dictionaryID,
            entryID: identifiers.entryID
        ) else {
            return Self.createNotFoundResponse()
        }

        let markdownURL = Self.resolvedFileURL(relativePath: entry.path, in: installDirectory)
        guard Self.isFile(markdownURL, containedIn: installDirectory) else {
            return Self.createNotFoundResponse()
        }

        let markdown: String
        do {
            markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        } catch {
            Self.logger.error("Failed to read grammar entry \(entry.path): \(error.localizedDescription)")
            return Self.createServerErrorResponse()
        }

        let renderer = MarkdownDocumentRenderer(
            styles: MarkdownDisplayStyles(dictionaryDisplayStyles),
            webTheme: webTheme.map(MarkdownWebTheme.init)
        )
        let baseURL = URL(string: "marureader-grammar://media/\(identifiers.dictionaryID.uuidString)/")
        let html = Self.injectGrammarEntryScripts(
            into: renderer.renderDocument(markdown: markdown, title: entry.title, baseURL: baseURL)
        )
        return Self.createDataResponse(
            data: Data(html.utf8),
            url: url,
            contentType: "text/html; charset=utf-8",
            cacheControl: "no-store"
        )
    }

    private func handleMediaRequest(url: URL) throws -> [URLSchemeTaskResult] {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let dictionaryIDString = pathComponents.first,
              let dictionaryID = UUID(uuidString: dictionaryIDString),
              pathComponents.count > 1,
              let installDirectory = GrammarDictionaryStorage.installedDirectoryURL(
                  grammarDictionaryID: dictionaryID,
                  in: baseDirectory
              )
        else {
            return Self.createNotFoundResponse()
        }

        let relativePath = pathComponents.dropFirst().joined(separator: "/")
        let mediaRoot = installDirectory.appendingPathComponent(GrammarDictionaryStorage.mediaDirectoryName, isDirectory: true)
        let fileURL = Self.resolvedFileURL(relativePath: relativePath, in: installDirectory)
        guard Self.isFile(fileURL, containedIn: mediaRoot) else {
            return Self.createNotFoundResponse()
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return Self.createDataResponse(
                data: data,
                url: url,
                contentType: Self.mimeType(for: fileURL),
                cacheControl: "max-age=31536000"
            )
        } catch {
            Self.logger.error("Failed to read grammar media file: \(error.localizedDescription)")
            return Self.createServerErrorResponse()
        }
    }

    private var dictionaryDisplayStyles: DisplayStyles {
        displayStylesOverride ?? DictionaryDisplayPreferences.displayStyles
    }

    private func fetchEntry(dictionaryID: UUID, entryID: String) async throws -> StoredEntry? {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)
        context.undoManager = nil

        return try await context.perform { () -> StoredEntry? in
            let request: NSFetchRequest<GrammarDictionaryEntry> = GrammarDictionaryEntry.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(
                format: "dictionaryID == %@ AND entryID == %@",
                dictionaryID as CVarArg,
                entryID
            )

            guard let entry = try context.fetch(request).first else {
                return nil
            }

            guard let title = entry.title, let path = entry.path else {
                return nil
            }

            return StoredEntry(title: title, path: path)
        }
    }

    private static func entryIdentifiers(from url: URL) -> (dictionaryID: UUID, entryID: String)? {
        let params = queryParameters(from: url)
        if let dictionaryIDString = params["dictionaryID"],
           let dictionaryID = UUID(uuidString: dictionaryIDString),
           let entryID = params["entryID"],
           !entryID.isEmpty
        {
            return (dictionaryID, entryID)
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2,
              let dictionaryID = UUID(uuidString: pathComponents[0])
        else {
            return nil
        }

        return (dictionaryID, pathComponents.dropFirst().joined(separator: "/"))
    }

    private static func queryParameters(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return [:]
        }

        return (components.queryItems ?? []).reduce(into: [String: String]()) { params, item in
            params[item.name] = item.value ?? ""
        }
    }

    private static func resolvedFileURL(relativePath: String, in directory: URL) -> URL {
        relativePath.split(separator: "/").reduce(directory) {
            $0.appendingPathComponent(String($1), isDirectory: false)
        }
    }

    private static func isFile(_ fileURL: URL, containedIn directory: URL) -> Bool {
        let standardizedFilePath = fileURL.standardizedFileURL.path
        let standardizedDirectoryPath = directory.standardizedFileURL.path
        let directoryPrefix = standardizedDirectoryPath.hasSuffix("/") ? standardizedDirectoryPath : standardizedDirectoryPath + "/"

        guard standardizedFilePath.hasPrefix(directoryPrefix) else {
            return false
        }

        return (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private static func mimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()

        if let utType = UTType(filenameExtension: pathExtension) {
            return utType.preferredMIMEType ?? "application/octet-stream"
        }

        switch pathExtension {
        case "css":
            return "text/css"
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
        default:
            return "application/octet-stream"
        }
    }

    private static func injectGrammarEntryScripts(into html: String) -> String {
        let scripts = """
            <script src="marureader-resource://domUtilities.js"></script>
            <script src="marureader-resource://textScanning.js"></script>
            <script src="marureader-resource://grammarEntry.js"></script>
        """
        let htmlWithScripts = html.replacingOccurrences(
            of: "</body>",
            with: "\(scripts)\n</body>"
        )
        return htmlWithScripts.replacingOccurrences(
            of: "default-src 'none'; img-src marureader-grammar: data:; style-src 'unsafe-inline';",
            with: "default-src 'none'; img-src marureader-grammar: data:; script-src marureader-resource:; style-src 'unsafe-inline';"
        )
    }

    private static func createDataResponse(
        data: Data,
        url: URL,
        contentType: String,
        cacheControl: String
    ) -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [
                "Content-Type": contentType,
                "Content-Length": "\(data.count)",
                "Cache-Control": cacheControl,
            ]
        )!

        return [
            .response(response),
            .data(data),
        ]
    }

    private static func createBadRequestResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-grammar://error")!,
            statusCode: 400,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        return [
            .response(response),
            .data(Data("Bad request".utf8)),
        ]
    }

    private static func createNotFoundResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-grammar://error")!,
            statusCode: 404,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        return [
            .response(response),
            .data(Data("Resource not found".utf8)),
        ]
    }

    private static func createServerErrorResponse() -> [URLSchemeTaskResult] {
        let response = HTTPURLResponse(
            url: URL(string: "marureader-grammar://error")!,
            statusCode: 500,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain"]
        )!

        return [
            .response(response),
            .data(Data("Internal server error".utf8)),
        ]
    }
}

private extension MarkdownDisplayStyles {
    init(_ styles: DisplayStyles) {
        self.init(
            fontFamily: styles.fontFamily,
            contentFontSize: styles.contentFontSize
        )
    }
}

private extension MarkdownWebTheme {
    init(_ theme: DictionaryWebTheme) {
        self.init(
            colorScheme: theme.colorScheme,
            textColor: theme.textColor,
            backgroundColor: theme.backgroundColor,
            interfaceBackgroundColor: theme.interfaceBackgroundColor,
            accentColor: theme.accentColor,
            linkColor: theme.linkColor,
            glossImageBackgroundColor: theme.glossImageBackgroundColor
        )
    }
}
