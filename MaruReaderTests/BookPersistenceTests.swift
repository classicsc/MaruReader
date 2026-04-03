// BookPersistenceTests.swift
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
@testable import MaruReader
import Testing

struct BookPersistenceTests {
    @Test func defaultInit_UsesApplicationSupportStoreURL() throws {
        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let expectedStoreURL = appSupportDir.appendingPathComponent("MaruBookData.sqlite")
        removeStoreFiles(at: expectedStoreURL)

        let controller = BookDataPersistenceController()
        guard let actualStoreURL = controller.container.persistentStoreCoordinator.persistentStores.first?.url else {
            Issue.record("Expected MaruBook persistent store URL")
            return
        }

        #expect(actualStoreURL.standardizedFileURL == expectedStoreURL.standardizedFileURL)

        if let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.net.undefinedstar.MaruReader") {
            let appGroupStoreURL = appGroupURL.appendingPathComponent("MaruBookData.sqlite")
            #expect(actualStoreURL.standardizedFileURL != appGroupStoreURL.standardizedFileURL)
        }
    }

    private func removeStoreFiles(at storeURL: URL) {
        let fileManager = FileManager.default
        let basePath = storeURL.path
        for path in [basePath, "\(basePath)-wal", "\(basePath)-shm"] {
            if fileManager.fileExists(atPath: path) {
                try? fileManager.removeItem(atPath: path)
            }
        }
    }
}
