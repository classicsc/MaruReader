// SampleContentSeeder.swift
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
import MaruManga
import MaruReaderCore
import os
import ReadiumShared
import ReadiumStreamer

enum SampleContentManifestError: Error, LocalizedError {
    case unsupportedSchemaVersion(Int)
    case duplicateBookID(String)
    case duplicateMangaID(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchemaVersion(version):
            "Unsupported sample content schema version: \(version)"
        case let .duplicateBookID(id):
            "Duplicate sample book id: \(id)"
        case let .duplicateMangaID(id):
            "Duplicate sample manga id: \(id)"
        }
    }
}

struct SampleContentManifest: Decodable {
    static let supportedSchemaVersion = 1

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case books
        case manga
    }

    struct BookProgress: Decodable, Equatable {
        let href: String?
        let progression: Double?

        init(href: String? = nil, progression: Double? = nil) {
            self.href = href
            self.progression = progression
        }
    }

    struct MangaProgress: Decodable, Equatable {
        let page: Int?

        init(page: Int? = nil) {
            self.page = page
        }
    }

    struct BookItem: Decodable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case id
            case file
            case progress
        }

        let id: String
        let file: String
        let progress: BookProgress

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            file = try container.decode(String.self, forKey: .file)
            progress = try container.decodeIfPresent(BookProgress.self, forKey: .progress) ?? .init()
        }
    }

    struct MangaItem: Decodable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case id
            case file
            case progress
        }

        let id: String
        let file: String
        let progress: MangaProgress

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            file = try container.decode(String.self, forKey: .file)
            progress = try container.decodeIfPresent(MangaProgress.self, forKey: .progress) ?? .init()
        }
    }

    let schemaVersion: Int
    let books: [BookItem]
    let manga: [MangaItem]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw SampleContentManifestError.unsupportedSchemaVersion(schemaVersion)
        }

        books = try container.decodeIfPresent([BookItem].self, forKey: .books) ?? []
        manga = try container.decodeIfPresent([MangaItem].self, forKey: .manga) ?? []

        try Self.validateUniqueIDs(books.map(\.id), duplicateError: SampleContentManifestError.duplicateBookID)
        try Self.validateUniqueIDs(manga.map(\.id), duplicateError: SampleContentManifestError.duplicateMangaID)
    }

    static func load(from url: URL) throws -> SampleContentManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Self.self, from: data)
    }

    private static func validateUniqueIDs(
        _ ids: [String],
        duplicateError: (String) -> SampleContentManifestError
    ) throws {
        var seen = Set<String>()
        for id in ids {
            guard seen.insert(id).inserted else {
                throw duplicateError(id)
            }
        }
    }
}

enum SampleContentSeederError: Error, LocalizedError {
    case missingManifestFile(String)
    case sampleImportFailed(String)
    case bookProgressLocationNotFound(String)

    var errorDescription: String? {
        switch self {
        case let .missingManifestFile(path):
            "Sample content file not found: \(path)"
        case let .sampleImportFailed(message):
            message
        case let .bookProgressLocationNotFound(id):
            "Unable to resolve sample book progress for \(id)"
        }
    }
}

actor SampleContentSeeder {
    private let manifestURL: URL?
    private let bookContainer: NSPersistentContainer
    private let mangaContainer: NSPersistentContainer
    private let bookImportManager: BookImportManager
    private let mangaImportManager: MangaImportManager
    private let logger = Logger.maru(category: "SampleContentSeeder")

    init(
        manifestURL: URL? = SampleContentSeeder.bundledManifestURL(),
        bookContainer: NSPersistentContainer = BookDataPersistenceController.shared.container,
        mangaContainer: NSPersistentContainer = MangaDataPersistenceController.shared.container,
        bookImportManager: BookImportManager = .shared,
        mangaImportManager: MangaImportManager = .shared
    ) {
        self.manifestURL = manifestURL
        self.bookContainer = bookContainer
        self.mangaContainer = mangaContainer
        self.bookImportManager = bookImportManager
        self.mangaImportManager = mangaImportManager
    }

    nonisolated static func bundledManifestURL(in bundle: Bundle = .main) -> URL? {
        #if DEBUG
            bundle.url(forResource: "manifest", withExtension: "json", subdirectory: "SampleContent")
        #else
            nil
        #endif
    }

    nonisolated static func hasBundledSampleContent(in bundle: Bundle = .main) -> Bool {
        bundledManifestURL(in: bundle) != nil
    }

    func hasSampleContent() -> Bool {
        manifestURL != nil
    }

    func seedIfAvailable() async throws {
        guard let manifestURL else {
            logger.debug("No bundled sample content manifest found")
            return
        }

        let manifest = try SampleContentManifest.load(from: manifestURL)
        let sampleRootURL = manifestURL.deletingLastPathComponent()

        for book in manifest.books {
            try await seedBook(book, relativeTo: sampleRootURL)
        }

        for manga in manifest.manga {
            try await seedManga(manga, relativeTo: sampleRootURL)
        }
    }

    private func seedBook(_ item: SampleContentManifest.BookItem, relativeTo rootURL: URL) async throws {
        let sourceURL = rootURL.appendingPathComponent(item.file)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw SampleContentSeederError.missingManifestFile(item.file)
        }

        if let existingBookID = try await reusableBookID(for: item.id) {
            try await applyBookProgress(item.progress, to: existingBookID)
            return
        }

        let jobID = try await bookImportManager.enqueueImport(from: sourceURL)
        await bookImportManager.waitForCompletion(jobID: jobID)

        let importedBookID = try await finalizeBookImport(jobID: jobID, sampleContentID: item.id)
        try await applyBookProgress(item.progress, to: importedBookID)
    }

    private func seedManga(_ item: SampleContentManifest.MangaItem, relativeTo rootURL: URL) async throws {
        let sourceURL = rootURL.appendingPathComponent(item.file)
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw SampleContentSeederError.missingManifestFile(item.file)
        }

        if let existingMangaID = try await reusableMangaID(for: item.id) {
            await applyMangaProgress(item.progress, to: existingMangaID)
            return
        }

        let jobID = try await mangaImportManager.enqueueImport(from: sourceURL)
        await mangaImportManager.waitForCompletion(jobID: jobID)

        let importedMangaID = try await finalizeMangaImport(jobID: jobID, sampleContentID: item.id)
        await applyMangaProgress(item.progress, to: importedMangaID)
    }

    private func reusableBookID(for sampleContentID: String) async throws -> NSManagedObjectID? {
        let context = bookContainer.newBackgroundContext()
        Self.configureUniquenessWriteContext(context)
        return try await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "sampleContentID == %@", sampleContentID)
            request.fetchLimit = 1

            guard let book = try context.fetch(request).first else {
                return nil
            }

            guard
                book.pendingDeletion == false,
                book.isComplete == true,
                book.errorMessage?.isEmpty != false,
                let fileName = book.fileName,
                Self.bookFileURL(fileName: fileName) != nil,
                FileManager.default.fileExists(atPath: Self.bookFileURL(fileName: fileName)!.path)
            else {
                let cleanupInfo = (book.id, book.fileName, book.coverFileName)
                context.delete(book)
                try context.save()
                BookImportManager.cleanupBookFilesByUUID(
                    bookUUID: cleanupInfo.0 ?? UUID(),
                    fileName: cleanupInfo.1,
                    coverFileName: cleanupInfo.2
                )
                return nil
            }

            return book.objectID
        }
    }

    private func reusableMangaID(for sampleContentID: String) async throws -> NSManagedObjectID? {
        let context = mangaContainer.newBackgroundContext()
        Self.configureUniquenessWriteContext(context)
        return try await context.perform {
            let request: NSFetchRequest<MangaArchive> = MangaArchive.fetchRequest()
            request.predicate = NSPredicate(format: "sampleContentID == %@", sampleContentID)
            request.fetchLimit = 1

            guard let manga = try context.fetch(request).first else {
                return nil
            }

            guard
                manga.pendingDeletion == false,
                manga.importComplete == true,
                manga.importErrorMessage?.isEmpty != false,
                let localFileName = manga.localFileName,
                let localPath = Self.mangaFileURL(fileName: localFileName),
                FileManager.default.fileExists(atPath: localPath.path)
            else {
                let cleanupInfo = (
                    manga.localFileName.flatMap(Self.mangaFileURL(fileName:)),
                    manga.coverFileName.flatMap(Self.mangaCoverURL(fileName:))
                )
                context.delete(manga)
                try context.save()
                Self.cleanupMangaFiles(localPath: cleanupInfo.0, coverImage: cleanupInfo.1)
                return nil
            }

            return manga.objectID
        }
    }

    private func finalizeBookImport(jobID: NSManagedObjectID, sampleContentID: String) async throws -> NSManagedObjectID {
        let context = bookContainer.newBackgroundContext()
        Self.configureUniquenessWriteContext(context)
        return try await context.perform {
            guard let book = try context.existingObject(with: jobID) as? Book else {
                throw SampleContentSeederError.sampleImportFailed("Book import record was not found")
            }

            guard book.isComplete else {
                throw SampleContentSeederError.sampleImportFailed(book.errorMessage ?? "Book sample import failed")
            }

            book.sampleContentID = sampleContentID
            try context.save()
            return book.objectID
        }
    }

    private func finalizeMangaImport(jobID: NSManagedObjectID, sampleContentID: String) async throws -> NSManagedObjectID {
        let context = mangaContainer.newBackgroundContext()
        Self.configureUniquenessWriteContext(context)
        return try await context.perform {
            guard let manga = try context.existingObject(with: jobID) as? MangaArchive else {
                throw SampleContentSeederError.sampleImportFailed("Manga import record was not found")
            }

            guard manga.importComplete else {
                throw SampleContentSeederError.sampleImportFailed(manga.importErrorMessage ?? "Manga sample import failed")
            }

            manga.sampleContentID = sampleContentID
            try context.save()
            return manga.objectID
        }
    }

    private func applyBookProgress(_ progress: SampleContentManifest.BookProgress, to bookID: NSManagedObjectID) async throws {
        let readContext = bookContainer.newBackgroundContext()
        let fileName = try await readContext.perform {
            guard let book = try readContext.existingObject(with: bookID) as? Book else {
                throw SampleContentSeederError.sampleImportFailed("Imported sample book record could not be read")
            }
            guard let fileName = book.fileName else {
                throw SampleContentSeederError.sampleImportFailed("Imported sample book file name is missing")
            }
            return fileName
        }

        guard let fileURL = Self.bookFileURL(fileName: fileName) else {
            throw SampleContentSeederError.sampleImportFailed("Imported sample book file path is invalid")
        }

        let locator = try await resolveBookLocator(for: progress, bookURL: fileURL)
        let context = bookContainer.newBackgroundContext()
        try await context.perform {
            guard let book = try context.existingObject(with: bookID) as? Book else {
                throw SampleContentSeederError.sampleImportFailed("Imported sample book record could not be updated")
            }

            book.lastOpenedPage = locator.jsonString
            if let totalProgression = locator.locations.totalProgression {
                book.progressPercent = Self.formatProgress(totalProgression)
            } else {
                book.progressPercent = nil
            }
            try context.save()
        }
    }

    private func applyMangaProgress(_ progress: SampleContentManifest.MangaProgress, to mangaID: NSManagedObjectID) async {
        let context = mangaContainer.newBackgroundContext()
        await context.perform {
            guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                return
            }

            let maxPage = max(1, Int(manga.totalPages))
            let clampedPage = min(max(progress.page ?? 1, 1), maxPage)
            manga.lastReadPage = Int64(clampedPage - 1)
            manga.lastReadDate = Date()
            try? context.save()
        }
    }

    private func resolveBookLocator(for progress: SampleContentManifest.BookProgress, bookURL: URL) async throws -> Locator {
        guard let readiumFileURL = FileURL(url: bookURL) else {
            throw SampleContentSeederError.sampleImportFailed("Sample book file URL is invalid")
        }

        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)
        let parser = DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: assetRetriever,
            pdfFactory: DefaultPDFDocumentFactory()
        )
        let opener = PublicationOpener(parser: parser)

        let asset: Asset
        switch await assetRetriever.retrieve(url: readiumFileURL) {
        case let .success(retrievedAsset):
            asset = retrievedAsset
        case let .failure(error):
            throw SampleContentSeederError.sampleImportFailed("Failed to retrieve sample book asset: \(error.localizedDescription)")
        }

        let publication: Publication
        switch await opener.open(asset: asset, allowUserInteraction: false) {
        case let .success(openedPublication):
            publication = openedPublication
        case let .failure(error):
            throw SampleContentSeederError.sampleImportFailed("Failed to open sample book: \(error.localizedDescription)")
        }

        defer {
            publication.close()
        }

        guard let locator = await Self.locator(for: progress, in: publication) else {
            throw SampleContentSeederError.bookProgressLocationNotFound(progress.href ?? "start")
        }

        return locator
    }

    private nonisolated static func locator(
        for progress: SampleContentManifest.BookProgress,
        in publication: Publication
    ) async -> Locator? {
        let requestedProgression = min(max(progress.progression ?? 0.0, 0.0), 1.0)
        let positions = await publication.positionsByReadingOrder().getOrNil() ?? []
        let seedLocator: Locator?
        let requestedFragment: String?

        if let requestedHref = progress.href, !requestedHref.isEmpty {
            let requestedURL = Link(href: requestedHref).url()
            let requestedHREF = requestedURL.removingFragment().string
            requestedFragment = requestedURL.fragment

            let matchingPositions = positions
                .flatMap(\.self)
                .filter { $0.href.string == requestedHREF }

            let interpolated = interpolatedLocator(
                requestedProgression: requestedProgression,
                positions: matchingPositions
            )
            seedLocator = if let interpolated {
                interpolated
            } else {
                await publication.locate(Link(href: requestedHref))
            }
        } else {
            requestedFragment = nil

            let firstReadingOrderPositions = positions.first ?? []
            let interpolated = interpolatedLocator(
                requestedProgression: requestedProgression,
                positions: firstReadingOrderPositions
            )
            seedLocator = if let interpolated {
                interpolated
            } else if let firstReadingOrderLink = publication.readingOrder.first {
                await publication.locate(firstReadingOrderLink)
            } else {
                nil
            }
        }

        guard let seedLocator else {
            return nil
        }

        return seedLocator.copy(
            locations: { locations in
                locations.fragments = requestedFragment.map { [$0] } ?? []
                locations.progression = requestedProgression
            }
        )
    }

    private nonisolated static func interpolatedLocator(
        requestedProgression: Double,
        positions: [Locator]
    ) -> Locator? {
        guard !positions.isEmpty else { return nil }

        let sorted = positions.sorted { lhs, rhs in
            let lhsProgression = lhs.locations.progression ?? 0.0
            let rhsProgression = rhs.locations.progression ?? 0.0
            if lhsProgression == rhsProgression {
                return (lhs.locations.position ?? 0) < (rhs.locations.position ?? 0)
            }
            return lhsProgression < rhsProgression
        }

        guard let first = sorted.first, let last = sorted.last else {
            return nil
        }

        if requestedProgression <= (first.locations.progression ?? 0.0) {
            return first.copy(locations: { $0.progression = requestedProgression })
        }

        if requestedProgression >= (last.locations.progression ?? 1.0) {
            return last.copy(locations: { $0.progression = requestedProgression })
        }

        for index in 0 ..< max(0, sorted.count - 1) {
            let lower = sorted[index]
            let upper = sorted[index + 1]
            let lowerProgression = lower.locations.progression ?? 0.0
            let upperProgression = upper.locations.progression ?? lowerProgression

            guard requestedProgression >= lowerProgression, requestedProgression <= upperProgression else {
                continue
            }

            let totalProgression: Double?
            if
                upperProgression > lowerProgression,
                let lowerTotal = lower.locations.totalProgression,
                let upperTotal = upper.locations.totalProgression
            {
                let resourceDelta = requestedProgression - lowerProgression
                let progressRange = upperProgression - lowerProgression
                totalProgression = lowerTotal + ((resourceDelta / progressRange) * (upperTotal - lowerTotal))
            } else {
                totalProgression = lower.locations.totalProgression
            }

            return lower.copy(locations: { locations in
                locations.progression = requestedProgression
                if let totalProgression {
                    locations.totalProgression = totalProgression
                }
            })
        }

        return last.copy(locations: { $0.progression = requestedProgression })
    }

    private nonisolated static func bookFileURL(fileName: String) -> URL? {
        guard let appSupportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return nil
        }

        return appSupportDir
            .appendingPathComponent("Books")
            .appendingPathComponent(fileName)
    }

    private nonisolated static func mangaFileURL(fileName: String) -> URL? {
        guard let documentsDir = try? FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return documentsDir
            .appendingPathComponent("Manga")
            .appendingPathComponent(fileName)
    }

    private nonisolated static func mangaCoverURL(fileName: String) -> URL? {
        guard let appSupportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else {
            return nil
        }

        return appSupportDir
            .appendingPathComponent("Covers")
            .appendingPathComponent(fileName)
    }

    private nonisolated static func cleanupMangaFiles(localPath: URL?, coverImage: URL?) {
        let fileManager = FileManager.default

        if let localPath, fileManager.fileExists(atPath: localPath.path) {
            try? fileManager.removeItem(at: localPath)
        }

        if let coverImage, fileManager.fileExists(atPath: coverImage.path) {
            try? fileManager.removeItem(at: coverImage)
        }
    }

    private nonisolated static func formatProgress(_ value: Double) -> String {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue.formatted(.percent.precision(.fractionLength(0)))
    }

    static func configureUniquenessWriteContext(_ context: NSManagedObjectContext) {
        context.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }
}
