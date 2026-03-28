// DictionarySeedingTests.swift
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

    @Test func copyStarterDictionaryContents_copiesDatabaseAndMedia() throws {
        let starterDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(starterDirectory) }

        let destinationDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(destinationDirectory) }

        let databaseURL = starterDirectory.appendingPathComponent("MaruDictionary.sqlite")
        #expect(FileManager.default.createFile(atPath: databaseURL.path, contents: Data("db".utf8)))

        let mediaDirectory = starterDirectory.appendingPathComponent("Media")
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        let mediaFileURL = mediaDirectory.appendingPathComponent("entry.txt")
        #expect(FileManager.default.createFile(atPath: mediaFileURL.path, contents: Data("media".utf8)))

        let audioMediaDirectory = starterDirectory.appendingPathComponent("AudioMedia")
        try FileManager.default.createDirectory(at: audioMediaDirectory, withIntermediateDirectories: true)
        let audioFileURL = audioMediaDirectory.appendingPathComponent("audio.txt")
        #expect(FileManager.default.createFile(atPath: audioFileURL.path, contents: Data("audio".utf8)))

        try DictionaryPersistenceController.copyStarterDictionaryContents(from: starterDirectory, to: destinationDirectory)

        let copiedDatabaseURL = destinationDirectory.appendingPathComponent("MaruDictionary.sqlite")
        let copiedMediaURL = destinationDirectory.appendingPathComponent("Media/entry.txt")
        let copiedAudioURL = destinationDirectory.appendingPathComponent("AudioMedia/audio.txt")

        #expect(FileManager.default.fileExists(atPath: copiedDatabaseURL.path))
        #expect(FileManager.default.fileExists(atPath: copiedMediaURL.path))
        #expect(FileManager.default.fileExists(atPath: copiedAudioURL.path))
    }

    // MARK: - removeStoreFiles

    @Test func removeStoreFiles_deletesAllRelatedFiles() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        let storeURL = baseDirectory.appendingPathComponent("MaruDictionary.sqlite")
        let walURL = baseDirectory.appendingPathComponent("MaruDictionary.sqlite-wal")
        let shmURL = baseDirectory.appendingPathComponent("MaruDictionary.sqlite-shm")

        for url in [storeURL, walURL, shmURL] {
            #expect(FileManager.default.createFile(atPath: url.path, contents: Data()))
        }

        DictionaryPersistenceController.removeStoreFiles(at: storeURL)

        #expect(!FileManager.default.fileExists(atPath: storeURL.path))
        #expect(!FileManager.default.fileExists(atPath: walURL.path))
        #expect(!FileManager.default.fileExists(atPath: shmURL.path))
    }

    @Test func removeStoreFiles_safeOnDevNull() {
        DictionaryPersistenceController.removeStoreFiles(at: URL(fileURLWithPath: "/dev/null"))
    }

    @Test func removeStoreFiles_noopWhenFilesAbsent() throws {
        let baseDirectory = try makeTemporaryDirectory()
        defer { cleanupTemporaryDirectory(baseDirectory) }

        let storeURL = baseDirectory.appendingPathComponent("NonExistent.sqlite")
        DictionaryPersistenceController.removeStoreFiles(at: storeURL)
    }

    // MARK: - Helpers

    private func makeTemporaryDirectory() throws -> URL {
        let baseDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        return baseDirectory
    }

    private func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
