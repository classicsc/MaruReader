// DictionarySeedingTests.swift
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
@testable import MaruReaderCore
import Testing

struct DictionarySeedingTests {
    @Test func seedingNeededWhenDatabaseMissing() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        #expect(DictionaryPersistenceController.isBundledDatabaseSeedingNeeded(at: baseDirectory))
    }

    @Test func seedingNotNeededWhenDatabaseExists() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        let databaseURL = baseDirectory.appendingPathComponent("MaruDictionary.sqlite")
        #expect(FileManager.default.createFile(atPath: databaseURL.path, contents: Data()))

        #expect(!DictionaryPersistenceController.isBundledDatabaseSeedingNeeded(at: baseDirectory))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        return baseDirectory
    }

    private func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
