// ContextImageConfigurationTests.swift
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
@testable import MaruReaderCore
import Testing

struct ContextImageConfigurationTests {
    // MARK: - Default Configuration Tests

    @Test func defaultConfiguration_bookPrefersCover() {
        let config = ContextImageConfiguration.default

        #expect(config.bookPreference == .cover)
    }

    @Test func defaultConfiguration_mangaPrefersScreenshot() {
        let config = ContextImageConfiguration.default

        #expect(config.mangaPreference == .screenshot)
    }

    // MARK: - Preferred Image Tests

    @Test func preferredImage_bookSource_returnsBookPreference() {
        var config = ContextImageConfiguration.default
        config.bookPreference = .screenshot

        #expect(config.preferredImage(for: .book) == .screenshot)
    }

    @Test func preferredImage_mangaSource_returnsMangaPreference() {
        var config = ContextImageConfiguration.default
        config.mangaPreference = .cover

        #expect(config.preferredImage(for: .manga) == .cover)
    }

    @Test func preferredImage_webSource_alwaysReturnsScreenshot() {
        let config = ContextImageConfiguration.default

        #expect(config.preferredImage(for: .web) == .screenshot)
    }

    @Test func preferredImage_dictionarySource_returnsNil() {
        let config = ContextImageConfiguration.default

        #expect(config.preferredImage(for: .dictionary) == .screenshot)
    }

    // MARK: - Encoding/Decoding Tests

    @Test func configuration_encodesAndDecodesCorrectly() throws {
        var config = ContextImageConfiguration.default
        config.bookPreference = .screenshot
        config.mangaPreference = .cover

        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ContextImageConfiguration.self, from: encoded)

        #expect(decoded.bookPreference == .screenshot)
        #expect(decoded.mangaPreference == .cover)
    }

    @Test func configuration_encodesToExpectedJSON() throws {
        let config = ContextImageConfiguration(
            bookPreference: .screenshot,
            mangaPreference: .cover
        )

        let data = try JSONEncoder().encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: String]

        #expect(json?["bookPreference"] == "screenshot")
        #expect(json?["mangaPreference"] == "cover")
    }

    @Test func configuration_decodesFromJSON() throws {
        let json = """
        {
            "bookPreference": "cover",
            "mangaPreference": "screenshot"
        }
        """
        let data = try #require(json.data(using: .utf8))

        let config = try JSONDecoder().decode(ContextImageConfiguration.self, from: data)

        #expect(config.bookPreference == .cover)
        #expect(config.mangaPreference == .screenshot)
    }

    // MARK: - Equatable Tests

    @Test func configuration_equatable_sameValuesAreEqual() {
        let config1 = ContextImageConfiguration(bookPreference: .cover, mangaPreference: .screenshot)
        let config2 = ContextImageConfiguration(bookPreference: .cover, mangaPreference: .screenshot)

        #expect(config1 == config2)
    }

    @Test func configuration_equatable_differentValuesAreNotEqual() {
        let config1 = ContextImageConfiguration(bookPreference: .cover, mangaPreference: .screenshot)
        let config2 = ContextImageConfiguration(bookPreference: .screenshot, mangaPreference: .screenshot)

        #expect(config1 != config2)
    }
}
