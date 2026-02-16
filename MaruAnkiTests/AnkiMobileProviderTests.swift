// AnkiMobileProviderTests.swift
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
@testable import MaruAnki
import Testing

struct AnkiMobileProviderTests {
    actor TestURLOpener: AnkiMobileURLOpening {
        private(set) var lastURL: URL?
        private let result: Bool

        init(result: Bool = true) {
            self.result = result
        }

        func open(_ url: URL) async -> Bool {
            lastURL = url
            return result
        }
    }

    @Test func addNote_encodesQueryValues() async throws {
        let opener = TestURLOpener()
        let provider = AnkiMobileProvider(urlOpener: opener)

        let japaneseText = "\u{65E5}\u{672C}\u{8A9E}"
        let fields: [String: [TemplateResolvedValue]] = [
            "Front Field": [.text("Line 1<br>line 2 & more +")],
            "Back": [.text(japaneseText)],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .none,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        _ = try await provider.addNote(
            fields: fields,
            profileName: "User 1",
            deckName: "Default Deck",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let url = try #require(await opener.lastURL)
        let urlString = url.absoluteString

        #expect(urlString.contains("profile=User%201"))
        #expect(urlString.contains("deck=Default%20Deck"))
        #expect(urlString.contains("type=Basic"))
        #expect(urlString.contains("fldFront%20Field=Line%201%3Cbr%3Eline%202%20%26%20more%20%2B"))
        #expect(urlString.contains("fldBack=%E6%97%A5%E6%9C%AC%E8%AA%9E"))
        #expect(urlString.contains("dupes=1"))
    }

    @Test func addNote_omitsEmptyProfile() async throws {
        let opener = TestURLOpener()
        let provider = AnkiMobileProvider(urlOpener: opener)

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [.text("Test")],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        _ = try await provider.addNote(
            fields: fields,
            profileName: "",
            deckName: "Default",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let url = try #require(await opener.lastURL)
        let urlString = url.absoluteString

        #expect(!urlString.contains("profile="))
    }

    @Test func addNote_includesReturnURL() async throws {
        let opener = TestURLOpener()
        let returnURL = try #require(URL(string: "marureader://anki/x-success"))
        let provider = AnkiMobileProvider(urlOpener: opener, returnURL: returnURL)

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [.text("Test")],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        _ = try await provider.addNote(
            fields: fields,
            profileName: "",
            deckName: "Default",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let url = try #require(await opener.lastURL)
        let urlString = url.absoluteString

        #expect(urlString.contains("x-success=marureader%3A%2F%2Fanki%2Fx-success"))
    }

    @Test func addNote_includesRemoteMediaURLs() async throws {
        let opener = TestURLOpener()
        let provider = AnkiMobileProvider(urlOpener: opener)

        let remoteURL = try #require(URL(string: "https://example.com/image.jpg"))
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent("audio.mp3")
        let audioData = Data([0x01, 0x02, 0x03])
        try audioData.write(to: localURL)
        defer { try? FileManager.default.removeItem(at: localURL) }

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [
                TemplateResolvedValue(text: "Text", mediaFiles: ["img": remoteURL]),
                TemplateResolvedValue(mediaFiles: ["audio": localURL]),
            ],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        _ = try await provider.addNote(
            fields: fields,
            profileName: "User",
            deckName: "Default",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let url = try #require(await opener.lastURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        let frontValue = items.first { $0.name == "fldFront" }?.value

        let expectedDataURL = "data:audio/mpeg;base64,\(audioData.base64EncodedString())"
        #expect(frontValue == "Text<br>https://example.com/image.jpg<br>\(expectedDataURL)")
        #expect(!(frontValue?.contains("file://") ?? false))
    }

    @Test func addNote_convertsMarureaderAudioSchemeToDataURL() async throws {
        let opener = TestURLOpener()
        let provider = AnkiMobileProvider(urlOpener: opener)

        // Create a test audio file in the app group AudioMedia directory
        let sourceUUID = UUID()
        guard let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.net.undefinedstar.MaruReader"
        ) else {
            Issue.record("App group directory not available")
            return
        }

        let audioDir = appGroupDir
            .appendingPathComponent("AudioMedia", isDirectory: true)
            .appendingPathComponent(sourceUUID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let audioFile = audioDir.appendingPathComponent("test.mp3")
        let audioData = Data([0x01, 0x02, 0x03])
        try audioData.write(to: audioFile)
        defer {
            try? FileManager.default.removeItem(at: audioDir)
        }

        // Create a marureader-audio:// URL
        let customURL = try #require(URL(string: "marureader-audio://\(sourceUUID.uuidString)/test.mp3"))

        let fields: [String: [TemplateResolvedValue]] = [
            "Audio": [
                TemplateResolvedValue(mediaFiles: ["audio": customURL]),
            ],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        _ = try await provider.addNote(
            fields: fields,
            profileName: "User",
            deckName: "Default",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let url = try #require(await opener.lastURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        let audioValue = items.first { $0.name == "fldAudio" }?.value

        let expectedDataURL = "data:audio/mpeg;base64,\(audioData.base64EncodedString())"
        #expect(audioValue == expectedDataURL)
        #expect(!(audioValue?.contains("marureader-audio://") ?? false))
    }

    @Test func addNote_inlinesLocalMediaInHTML() async throws {
        let opener = TestURLOpener()
        let provider = AnkiMobileProvider(urlOpener: opener)

        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent("glossary.png")
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        try imageData.write(to: localURL)
        defer { try? FileManager.default.removeItem(at: localURL) }

        let html = "<div><img src=\"glossary.png\"></div>"
        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [
                TemplateResolvedValue(text: html, mediaFiles: ["glossary.png": localURL]),
            ],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        _ = try await provider.addNote(
            fields: fields,
            profileName: "User",
            deckName: "Default",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let url = try #require(await opener.lastURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        let frontValue = items.first { $0.name == "fldFront" }?.value

        let expectedDataURL = "data:image/png;base64,\(imageData.base64EncodedString())"
        #expect(frontValue == "<div><img src=\"\(expectedDataURL)\"></div>")
    }

    @Test func addNote_includesLocalImageDataURL() async throws {
        let opener = TestURLOpener()
        let provider = AnkiMobileProvider(urlOpener: opener)

        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent("image.png")
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        try imageData.write(to: localURL)
        defer { try? FileManager.default.removeItem(at: localURL) }

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [
                TemplateResolvedValue(mediaFiles: ["image": localURL]),
            ],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        _ = try await provider.addNote(
            fields: fields,
            profileName: "User",
            deckName: "Default",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        let url = try #require(await opener.lastURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = components.queryItems ?? []
        let frontValue = items.first { $0.name == "fldFront" }?.value

        let expectedDataURL = "data:image/png;base64,\(imageData.base64EncodedString())"
        #expect(frontValue == expectedDataURL)
    }

    @Test func addNote_withoutOpener_marksPending() async throws {
        let provider = AnkiMobileProvider(urlOpener: nil)

        let fields: [String: [TemplateResolvedValue]] = [
            "Front": [.text("Test")],
        ]

        let duplicateOptions = DuplicateDetectionOptions(
            scope: .deck,
            deckName: nil,
            includeChildDecks: false,
            checkAllModels: false
        )

        let result = try await provider.addNote(
            fields: fields,
            profileName: "",
            deckName: "Default",
            modelName: "Basic",
            duplicateOptions: duplicateOptions
        )

        #expect(result.pendingSync == true)
    }
}
