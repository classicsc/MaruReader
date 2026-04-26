// GrammarDictionaryURLSchemeHandlerTests.swift
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
@testable import MaruReaderCore
import Testing
import WebKit

struct GrammarDictionaryURLSchemeHandlerTests {
    @Test @MainActor func entryEndpointRendersInstalledMarkdownByID() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let baseDirectory = tempDir.appendingPathComponent("app-group", isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dictionaryID = UUID()
        let persistenceController = makeDictionaryPersistenceController(baseDirectory: baseDirectory)
        try createStoredGrammarEntry(
            dictionaryID: dictionaryID,
            entryID: "passive",
            path: "entries/passive.md",
            in: persistenceController
        )
        try createInstalledFile(
            dictionaryID: dictionaryID,
            relativePath: "entries/passive.md",
            contents: "# Passive {#passive}\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n![logo](media/logo.png)\n",
            baseDirectory: baseDirectory
        )

        let handler = GrammarDictionaryURLSchemeHandler(persistenceController: persistenceController)
        await handler.setDisplayStyles(DisplayStyles(
            fontFamily: "Lookup Font, sans-serif",
            contentFontSize: 1.35,
            popupFontSize: 1.0,
            pitchDownstepNotationInHeaderEnabled: true,
            pitchResultsAreaCollapsedDisplay: false,
            pitchResultsAreaDownstepNotationEnabled: false,
            pitchResultsAreaDownstepPositionEnabled: true,
            pitchResultsAreaEnabled: false
        ))
        await handler.setWebTheme(DictionaryWebTheme(textColor: "#222222"))

        let requestURL = try #require(URL(string: "marureader-grammar://entry/\(dictionaryID.uuidString)/passive"))
        let results = try await handler.handleRequest(URLRequest(url: requestURL))
        let response = extractResponse(from: results)
        let data = try #require(extractData(from: results))
        let html = try #require(String(data: data, encoding: .utf8))

        #expect(response?.statusCode == 200)
        #expect(response?.value(forHTTPHeaderField: "Content-Type") == "text/html; charset=utf-8")
        #expect(html.contains("<h1 id=\"passive\">Passive</h1>"))
        #expect(html.contains("<table>"))
        #expect(html.contains("<base href=\"marureader-grammar://media/\(dictionaryID.uuidString)/\">"))
        #expect(html.contains("script-src marureader-resource:;"))
        #expect(html.contains("<script src=\"marureader-resource://textScanning.js\"></script>"))
        #expect(html.contains("<script src=\"marureader-resource://grammarEntry.js\"></script>"))
        #expect(html.contains("--font-family: Lookup Font, sans-serif;"))
        #expect(html.contains("--content-font-size-multiplier: 1.35;"))
        #expect(html.contains("--text-color: #222222;"))
    }

    @Test @MainActor func mediaEndpointServesInstalledGrammarMedia() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let baseDirectory = tempDir.appendingPathComponent("app-group", isDirectory: true)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dictionaryID = UUID()
        let persistenceController = makeDictionaryPersistenceController(baseDirectory: baseDirectory)
        try createInstalledData(
            dictionaryID: dictionaryID,
            relativePath: "media/logo.png",
            data: Data([0x89, 0x50, 0x4E, 0x47]),
            baseDirectory: baseDirectory
        )

        let handler = GrammarDictionaryURLSchemeHandler(persistenceController: persistenceController)
        let requestURL = try #require(URL(string: "marureader-grammar://media/\(dictionaryID.uuidString)/media/logo.png"))
        let results = try await handler.handleRequest(URLRequest(url: requestURL))

        #expect(extractResponse(from: results)?.statusCode == 200)
        #expect(extractResponse(from: results)?.value(forHTTPHeaderField: "Content-Type") == "image/png")
        #expect(extractData(from: results) == Data([0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func entryEndpointMissingIdentifiersReturnsBadRequest() async throws {
        let handler = GrammarDictionaryURLSchemeHandler(persistenceController: makeDictionaryPersistenceController(baseDirectory: nil))
        let requestURL = try #require(URL(string: "marureader-grammar://entry"))
        let results = try await handler.handleRequest(URLRequest(url: requestURL))

        #expect(extractResponse(from: results)?.statusCode == 400)
    }

    private func createStoredGrammarEntry(
        dictionaryID: UUID,
        entryID: String,
        path: String,
        in persistenceController: DictionaryPersistenceController
    ) throws {
        let context = persistenceController.container.viewContext
        let dictionary = GrammarDictionary(context: context)
        dictionary.id = dictionaryID
        dictionary.title = "Grammar"
        dictionary.format = 1
        dictionary.entryCount = 1
        dictionary.formTagCount = 1
        dictionary.isComplete = true
        dictionary.pendingDeletion = false

        let entry = GrammarDictionaryEntry(context: context)
        entry.id = UUID()
        entry.dictionaryID = dictionaryID
        entry.entryID = entryID
        entry.title = "Passive"
        entry.path = path
        entry.formTags = "passive"

        try context.save()
    }

    private func createInstalledFile(
        dictionaryID: UUID,
        relativePath: String,
        contents: String,
        baseDirectory: URL
    ) throws {
        try createInstalledData(
            dictionaryID: dictionaryID,
            relativePath: relativePath,
            data: Data(contents.utf8),
            baseDirectory: baseDirectory
        )
    }

    private func createInstalledData(
        dictionaryID: UUID,
        relativePath: String,
        data: Data,
        baseDirectory: URL
    ) throws {
        let installDirectory = try #require(GrammarDictionaryStorage.installedDirectoryURL(
            grammarDictionaryID: dictionaryID,
            in: baseDirectory
        ))
        let fileURL = relativePath.split(separator: "/").reduce(installDirectory) {
            $0.appendingPathComponent(String($1), isDirectory: false)
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL)
    }

    private func extractResponse(from results: [URLSchemeTaskResult]) -> HTTPURLResponse? {
        for result in results {
            if case let .response(response) = result {
                return response as? HTTPURLResponse
            }
        }
        return nil
    }

    private func extractData(from results: [URLSchemeTaskResult]) -> Data? {
        for result in results {
            if case let .data(data) = result {
                return data
            }
        }
        return nil
    }
}
