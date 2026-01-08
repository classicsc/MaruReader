// AnkiMobileProviderTests.swift
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
        let localURL = URL(fileURLWithPath: "/tmp/audio.mp3")

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

        #expect(frontValue == "Text<br>https://example.com/image.jpg")
        #expect(!(frontValue?.contains("file://") ?? false))
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
