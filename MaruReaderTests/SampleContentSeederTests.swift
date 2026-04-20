// SampleContentSeederTests.swift
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
import MaruDictionaryUICommon
@testable import MaruManga
@testable import MaruReader
import ReadiumShared
import Testing
import UIKit
import Zip

struct SampleContentSeederTests {
    enum FixtureError: Error {
        case invalidImage
    }

    @Test func manifest_ValidJSON_Decodes() throws {
        let manifestURL = try writeManifest(
            json: """
            {
              "schemaVersion": 1,
              "books": [
                {
                  "id": "botchan",
                  "file": "Books/Botchan.epub",
                  "progress": {
                    "href": "chapter1.xhtml",
                    "progression": 0.42
                  }
                }
              ],
              "manga": [
                {
                  "id": "yotsuba-01",
                  "file": "Manga/Yotsuba-01.cbz",
                  "progress": {
                    "page": 12
                  }
                }
              ]
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: manifestURL.deletingLastPathComponent()) }

        let manifest = try SampleContentManifest.load(from: manifestURL)
        #expect(manifest.schemaVersion == 1)
        #expect(manifest.books.count == 1)
        #expect(manifest.manga.count == 1)
        #expect(manifest.books[0].progress.progression == 0.42)
        #expect(manifest.manga[0].progress.page == 12)
    }

    @Test func manifest_DuplicateBookIDs_Throws() throws {
        let manifestURL = try writeManifest(
            json: """
            {
              "schemaVersion": 1,
              "books": [
                {
                  "id": "duplicate",
                  "file": "Books/One.epub",
                  "progress": {
                    "href": "chapter1.xhtml"
                  }
                },
                {
                  "id": "duplicate",
                  "file": "Books/Two.epub",
                  "progress": {
                    "href": "chapter2.xhtml"
                  }
                }
              ],
              "manga": []
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: manifestURL.deletingLastPathComponent()) }

        #expect(throws: SampleContentManifestError.self) {
            try SampleContentManifest.load(from: manifestURL)
        }
    }

    @Test func manifest_UnsupportedSchemaVersion_Throws() throws {
        let manifestURL = try writeManifest(
            json: """
            {
              "schemaVersion": 99,
              "books": [],
              "manga": []
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: manifestURL.deletingLastPathComponent()) }

        #expect(throws: SampleContentManifestError.self) {
            try SampleContentManifest.load(from: manifestURL)
        }
    }

    @Test func manifest_EmptyProgress_DefaultsToStart() throws {
        let manifestURL = try writeManifest(
            json: """
            {
              "schemaVersion": 1,
              "books": [
                {
                  "id": "botchan",
                  "file": "Books/Botchan.epub",
                  "progress": {}
                }
              ],
              "manga": []
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: manifestURL.deletingLastPathComponent()) }

        let manifest = try SampleContentManifest.load(from: manifestURL)
        #expect(manifest.books[0].progress.href == nil)
        #expect(manifest.books[0].progress.progression == nil)
    }

    @Test func manifest_MissingRequiredFields_Throws() throws {
        let manifestURL = try writeManifest(
            json: """
            {
              "schemaVersion": 1,
              "books": [
                {
                  "id": "botchan",
                  "progress": {}
                }
              ],
              "manga": []
            }
            """
        )
        defer { try? FileManager.default.removeItem(at: manifestURL.deletingLastPathComponent()) }

        #expect(throws: Error.self) {
            try SampleContentManifest.load(from: manifestURL)
        }
    }

    @Test func seedIfAvailable_ImportsAndReappliesProgressWithoutDuplicates() async throws {
        let fixture = try makeSampleContentFixture(mangaPage: 99)
        defer {
            cleanupImportedItems(bookContainer: fixture.bookContainer, mangaContainer: fixture.mangaContainer)
            try? FileManager.default.removeItem(at: fixture.sampleRootURL)
        }

        let seeder = SampleContentSeeder(
            manifestURL: fixture.manifestURL,
            bookContainer: fixture.bookContainer,
            mangaContainer: fixture.mangaContainer,
            bookImportManager: fixture.bookImportManager,
            mangaImportManager: fixture.mangaImportManager
        )

        try await seeder.seedIfAvailable()
        let firstBooks = await fetchBooks(from: fixture.bookContainer.viewContext)
        let firstManga = await fetchManga(from: fixture.mangaContainer.viewContext)
        try await seeder.seedIfAvailable()

        let books = await fetchBooks(from: fixture.bookContainer.viewContext)
        let manga = await fetchManga(from: fixture.mangaContainer.viewContext)

        #expect(firstBooks.count == 1)
        #expect(firstManga.count == 1)
        #expect(books.count == 1)
        #expect(manga.count == 1)
        #expect(books[0].objectID == firstBooks[0].objectID)
        #expect(manga[0].objectID == firstManga[0].objectID)
        #expect(books[0].sampleContentID == "sample-book")
        #expect(manga[0].sampleContentID == "sample-manga")
        #expect(books[0].progressPercent?.isEmpty == false)
        #expect(manga[0].lastReadPage == 4)
        #expect(manga[0].lastReadDate != nil)

        guard let locatorJSON = books[0].lastOpenedPage else {
            Issue.record("Expected seeded book locator JSON")
            return
        }
        let locator = try #require(try Locator(jsonString: locatorJSON))
        #expect(locator.href.string == "chapter1.xhtml")
        #expect(locator.locations.progression == 0.42)
    }

    @Test func seedIfAvailable_ReimportsMissingSampleItem() async throws {
        let fixture = try makeSampleContentFixture(mangaPage: 3)
        defer {
            cleanupImportedItems(bookContainer: fixture.bookContainer, mangaContainer: fixture.mangaContainer)
            try? FileManager.default.removeItem(at: fixture.sampleRootURL)
        }

        let seeder = SampleContentSeeder(
            manifestURL: fixture.manifestURL,
            bookContainer: fixture.bookContainer,
            mangaContainer: fixture.mangaContainer,
            bookImportManager: fixture.bookImportManager,
            mangaImportManager: fixture.mangaImportManager
        )

        try await seeder.seedIfAvailable()

        let existingBook = try #require(await fetchBooks(from: fixture.bookContainer.viewContext).first)
        await deleteBook(existingBook, from: fixture.bookContainer.viewContext)

        try await seeder.seedIfAvailable()

        let books = await fetchBooks(from: fixture.bookContainer.viewContext)
        #expect(books.count == 1)
        #expect(books[0].sampleContentID == "sample-book")
        #expect(books[0].progressPercent?.isEmpty == false)
    }

    @Test func seedIfAvailable_EmptyProgressStartsAtBeginning() async throws {
        let fixture = try makeSampleContentFixture(bookProgressJSON: "{}", mangaProgressJSON: "{}")
        defer {
            cleanupImportedItems(bookContainer: fixture.bookContainer, mangaContainer: fixture.mangaContainer)
            try? FileManager.default.removeItem(at: fixture.sampleRootURL)
        }

        let seeder = SampleContentSeeder(
            manifestURL: fixture.manifestURL,
            bookContainer: fixture.bookContainer,
            mangaContainer: fixture.mangaContainer,
            bookImportManager: fixture.bookImportManager,
            mangaImportManager: fixture.mangaImportManager
        )

        try await seeder.seedIfAvailable()

        let books = await fetchBooks(from: fixture.bookContainer.viewContext)
        let manga = await fetchManga(from: fixture.mangaContainer.viewContext)

        #expect(books.count == 1)
        #expect(manga.count == 1)
        #expect(manga[0].lastReadPage == 0)
        #expect(manga[0].lastReadDate != nil)

        guard let locatorJSON = books[0].lastOpenedPage else {
            Issue.record("Expected seeded book locator JSON")
            return
        }

        let locator = try #require(try Locator(jsonString: locatorJSON))
        #expect(locator.href.string == "chapter1.xhtml")
        #expect(locator.locations.progression == 0.0)
    }

    @Test func startupPreparationCoordinator_CleansUpBeforeSampleImport() async {
        let recorder = EventRecorder()
        let coordinator = await MainActor.run {
            StartupPreparationCoordinator(
                needsDictionarySeeding: false,
                sampleContentAvailable: true,
                operations: .init(
                    seedDictionaryIfNeeded: {},
                    setAnkiPreferencesUpdater: {
                        await recorder.record("anki")
                    },
                    cleanupInterruptedImportsAndPendingDeletions: {
                        await recorder.record("cleanup")
                    },
                    importSampleContentIfAvailable: {
                        await recorder.record("sample")
                    },
                    resumePendingDictionaryUpdates: {
                        await recorder.record("updates")
                    },
                    configureScreenshotStateIfNeeded: {
                        await recorder.record("screenshot")
                    }
                )
            )
        }

        await coordinator.waitUntilComplete()
        let events = await recorder.snapshot()
        #expect(events == ["anki", "cleanup", "sample", "updates", "screenshot"])
    }

    @Test func requiresWelcomeScreen_OnlyDictionarySeeding_ReturnsFalse() async {
        let coordinator = await MainActor.run {
            StartupPreparationCoordinator(
                needsDictionarySeeding: true,
                sampleContentAvailable: false,
                operations: .init(
                    seedDictionaryIfNeeded: {},
                    setAnkiPreferencesUpdater: {},
                    cleanupInterruptedImportsAndPendingDeletions: {},
                    importSampleContentIfAvailable: {},
                    resumePendingDictionaryUpdates: {},
                    configureScreenshotStateIfNeeded: {}
                ),
                autoStart: false
            )
        }
        let requires = await coordinator.requiresWelcomeScreen
        #expect(requires == false)
    }

    @Test func requiresWelcomeScreen_SampleContentAvailable_ReturnsTrue() async {
        let coordinator = await MainActor.run {
            StartupPreparationCoordinator(
                needsDictionarySeeding: false,
                sampleContentAvailable: true,
                operations: .init(
                    seedDictionaryIfNeeded: {},
                    setAnkiPreferencesUpdater: {},
                    cleanupInterruptedImportsAndPendingDeletions: {},
                    importSampleContentIfAvailable: {},
                    resumePendingDictionaryUpdates: {},
                    configureScreenshotStateIfNeeded: {}
                ),
                autoStart: false
            )
        }
        let requires = await coordinator.requiresWelcomeScreen
        #expect(requires == true)
    }

    @Test func dictionaryFeatureAvailability_DuringSeeding_IsPreparing() async {
        let coordinator = await MainActor.run {
            StartupPreparationCoordinator(
                needsDictionarySeeding: true,
                sampleContentAvailable: false,
                operations: .init(
                    seedDictionaryIfNeeded: {},
                    setAnkiPreferencesUpdater: {},
                    cleanupInterruptedImportsAndPendingDeletions: {},
                    importSampleContentIfAvailable: {},
                    resumePendingDictionaryUpdates: {},
                    configureScreenshotStateIfNeeded: {}
                ),
                autoStart: false
            )
        }
        let availability = await coordinator.dictionaryFeatureAvailability
        #expect(availability == .preparing(description: "Preparing dictionary..."))
    }

    @Test func dictionaryFeatureAvailability_NoSeedingNeeded_IsReady() async {
        let coordinator = await MainActor.run {
            StartupPreparationCoordinator(
                needsDictionarySeeding: false,
                sampleContentAvailable: false,
                operations: .init(
                    seedDictionaryIfNeeded: {},
                    setAnkiPreferencesUpdater: {},
                    cleanupInterruptedImportsAndPendingDeletions: {},
                    importSampleContentIfAvailable: {},
                    resumePendingDictionaryUpdates: {},
                    configureScreenshotStateIfNeeded: {}
                ),
                autoStart: false
            )
        }
        let availability = await coordinator.dictionaryFeatureAvailability
        #expect(availability == .ready)
    }

    @Test func dictionaryFeatureAvailability_AfterSeedingCompletes_IsReady() async {
        let coordinator = await MainActor.run {
            StartupPreparationCoordinator(
                needsDictionarySeeding: true,
                sampleContentAvailable: false,
                operations: .init(
                    seedDictionaryIfNeeded: {},
                    setAnkiPreferencesUpdater: {},
                    cleanupInterruptedImportsAndPendingDeletions: {},
                    importSampleContentIfAvailable: {},
                    resumePendingDictionaryUpdates: {},
                    configureScreenshotStateIfNeeded: {}
                )
            )
        }
        await coordinator.waitUntilComplete()
        let availability = await coordinator.dictionaryFeatureAvailability
        #expect(availability == .ready)
    }

    private func makeSampleContentFixture(
        mangaPage: Int = 99,
        bookProgressJSON: String = """
        {
          "href": "chapter1.xhtml",
          "progression": 0.42
        }
        """,
        mangaProgressJSON: String? = nil
    ) throws -> (
        sampleRootURL: URL,
        manifestURL: URL,
        bookContainer: NSPersistentContainer,
        mangaContainer: NSPersistentContainer,
        bookImportManager: BookImportManager,
        mangaImportManager: MangaImportManager
    ) {
        let sampleRootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let booksURL = sampleRootURL.appendingPathComponent("Books", isDirectory: true)
        let mangaURL = sampleRootURL.appendingPathComponent("Manga", isDirectory: true)

        try FileManager.default.createDirectory(at: booksURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mangaURL, withIntermediateDirectories: true)

        let epubURL = try createValidEPUB(at: booksURL.appendingPathComponent("Sample.epub"))
        let archiveURL = try createValidMangaArchive(
            at: mangaURL.appendingPathComponent("Sample.cbz"),
            imageCount: 5
        )

        #expect(FileManager.default.fileExists(atPath: epubURL.path))
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))

        let manifestURL = sampleRootURL.appendingPathComponent("manifest.json")
        let resolvedMangaProgressJSON = mangaProgressJSON ?? """
        {
          "page": \(mangaPage)
        }
        """

        let manifest = """
        {
          "schemaVersion": 1,
          "books": [
            {
              "id": "sample-book",
              "file": "Books/Sample.epub",
              "progress": \(bookProgressJSON)
            }
          ],
          "manga": [
            {
              "id": "sample-manga",
              "file": "Manga/Sample.cbz",
              "progress": \(resolvedMangaProgressJSON)
            }
          ]
        }
        """
        try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)

        let bookPersistenceController = makeBookPersistenceController()
        let mangaPersistenceController = makeMangaPersistenceController()

        return (
            sampleRootURL,
            manifestURL,
            bookPersistenceController.container,
            mangaPersistenceController.container,
            BookImportManager(container: bookPersistenceController.container),
            MangaImportManager(container: mangaPersistenceController.container)
        )
    }

    private func writeManifest(json: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let manifestURL = directoryURL.appendingPathComponent("manifest.json")
        try json.write(to: manifestURL, atomically: true, encoding: .utf8)
        return manifestURL
    }

    private func createValidEPUB(at outputURL: URL) throws -> URL {
        let workingDirectory = outputURL.deletingLastPathComponent().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workingDirectory) }

        let mimetypeURL = workingDirectory.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypeURL, atomically: true, encoding: .utf8)

        let metaInfURL = workingDirectory.appendingPathComponent("META-INF", isDirectory: true)
        try FileManager.default.createDirectory(at: metaInfURL, withIntermediateDirectories: true)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """.write(to: metaInfURL.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        let chapterText = String(repeating: "<p>This is a long test chapter for locator interpolation.</p>", count: 200)
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="book-id">urn:uuid:\(UUID().uuidString)</dc:identifier>
                <dc:title>Sample Book</dc:title>
                <dc:creator>Sample Author</dc:creator>
                <dc:language>en</dc:language>
                <meta property="dcterms:modified">2025-01-01T00:00:00Z</meta>
            </metadata>
            <manifest>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
            </manifest>
            <spine>
                <itemref idref="chapter1"/>
            </spine>
        </package>
        """.write(to: workingDirectory.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head><title>Navigation</title></head>
        <body>
            <nav epub:type="toc">
                <ol>
                    <li><a href="chapter1.xhtml">Chapter 1</a></li>
                </ol>
            </nav>
        </body>
        </html>
        """.write(to: workingDirectory.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)

        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Chapter 1</title></head>
        <body>
            <h1>Chapter 1</h1>
            \(chapterText)
        </body>
        </html>
        """.write(to: workingDirectory.appendingPathComponent("chapter1.xhtml"), atomically: true, encoding: .utf8)

        try Zip.zipFiles(
            paths: [
                mimetypeURL,
                metaInfURL,
                workingDirectory.appendingPathComponent("content.opf"),
                workingDirectory.appendingPathComponent("nav.xhtml"),
                workingDirectory.appendingPathComponent("chapter1.xhtml"),
            ],
            zipFilePath: outputURL,
            password: nil,
            progress: nil
        )

        return outputURL
    }

    private func createValidMangaArchive(at outputURL: URL, imageCount: Int) throws -> URL {
        let workingDirectory = outputURL.deletingLastPathComponent().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workingDirectory) }

        var imageURLs: [URL] = []
        for index in 1 ... imageCount {
            let imageURL = workingDirectory.appendingPathComponent("page_\(String(index).padding(toLength: 3, withPad: "0", startingAt: 0)).jpg")
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
            let image = renderer.image { context in
                UIColor(
                    hue: CGFloat(index) / CGFloat(imageCount),
                    saturation: 1.0,
                    brightness: 1.0,
                    alpha: 1.0
                ).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
            }
            guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
                throw FixtureError.invalidImage
            }
            try jpegData.write(to: imageURL)
            imageURLs.append(imageURL)
        }

        try Zip.zipFiles(paths: imageURLs, zipFilePath: outputURL, password: nil, progress: nil)
        return outputURL
    }

    private func fetchBooks(from context: NSManagedObjectContext) async -> [BookSnapshot] {
        await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            let books = (try? context.fetch(request)) ?? []
            return books.map(BookSnapshot.init)
        }
    }

    private func fetchManga(from context: NSManagedObjectContext) async -> [MangaSnapshot] {
        await context.perform {
            let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
            let manga = (try? context.fetch(request)) ?? []
            return manga.map(MangaSnapshot.init)
        }
    }

    private func deleteBook(_ snapshot: BookSnapshot, from context: NSManagedObjectContext) async {
        await context.perform {
            guard
                let book = try? context.existingObject(with: snapshot.objectID) as? Book
            else {
                return
            }

            let cleanupInfo = (book.id, book.fileName, book.coverFileName)
            context.delete(book)
            try? context.save()
            BookImportManager.cleanupBookFilesByUUID(
                bookUUID: cleanupInfo.0 ?? UUID(),
                fileName: cleanupInfo.1,
                coverFileName: cleanupInfo.2
            )
        }
    }

    private func cleanupImportedItems(bookContainer: NSPersistentContainer, mangaContainer: NSPersistentContainer) {
        let bookContext = bookContainer.viewContext
        let mangaContext = mangaContainer.viewContext

        bookContext.performAndWait {
            var books: [BookSnapshot] = []
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            let results = (try? bookContext.fetch(request)) ?? []
            books = results.map(BookSnapshot.init)
            for book in books {
                BookImportManager.cleanupBookFilesByUUID(
                    bookUUID: book.id ?? UUID(),
                    fileName: book.fileName,
                    coverFileName: book.coverFileName
                )
            }
        }

        mangaContext.performAndWait {
            var mangaItems: [MangaSnapshot] = []
            let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
            let results = (try? mangaContext.fetch(request)) ?? []
            mangaItems = results.map(MangaSnapshot.init)
            for manga in mangaItems {
                MangaImportManager.cleanupMangaFiles(localPath: manga.localPath, coverImage: manga.coverImage)
            }
        }
    }
}

private struct BookSnapshot {
    let objectID: NSManagedObjectID
    let id: UUID?
    let fileName: String?
    let coverFileName: String?
    let sampleContentID: String?
    let lastOpenedPage: String?
    let progressPercent: String?

    init(_ book: Book) {
        objectID = book.objectID
        id = book.id
        fileName = book.fileName
        coverFileName = book.coverFileName
        sampleContentID = book.sampleContentID
        lastOpenedPage = book.lastOpenedPage
        progressPercent = book.progressPercent
    }
}

private struct MangaSnapshot {
    let objectID: NSManagedObjectID
    let sampleContentID: String?
    let localPath: URL?
    let coverImage: URL?
    let lastReadPage: Int64
    let lastReadDate: Date?

    init(_ manga: MangaArchive) {
        objectID = manga.objectID
        sampleContentID = manga.sampleContentID
        localPath = manga.localPath
        coverImage = manga.coverImage
        lastReadPage = manga.lastReadPage
        lastReadDate = manga.lastReadDate
    }
}

private actor EventRecorder {
    private var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }

    func snapshot() -> [String] {
        events
    }
}
