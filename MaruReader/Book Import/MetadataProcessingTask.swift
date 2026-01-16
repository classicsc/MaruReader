// MetadataProcessingTask.swift
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

import CoreData
import Foundation
import MaruReaderCore
import os.log
import ReadiumShared
import ReadiumStreamer

struct MetadataProcessingTask {
    let bookID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookImport")

    init(bookID: NSManagedObjectID, container: NSPersistentContainer = BookDataPersistenceController.shared.container) {
        self.bookID = bookID
        self.persistentContainer = container
    }

    func start() async throws {
        let container = persistentContainer
        let bookID = self.bookID
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true

        let fileURL = try await context.perform {
            guard let book = try context.existingObject(with: bookID) as? Book else {
                throw BookImportError.importNotFound
            }
            guard let fileURL = book.importFile else {
                throw BookImportError.missingFile
            }

            // Update progress message
            book.displayProgressMessage = "Reading book metadata..."
            try context.save()
            return fileURL
        }

        try Task.checkCancellation()

        // Access security scoped resource if needed (returns false for in-sandbox files)
        let didStartAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // Check if file exists and is accessible
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw BookImportError.missingFile
        }

        // Create AssetRetriever and PublicationOpener
        let httpClient = DefaultHTTPClient()
        let assetRetriever = AssetRetriever(httpClient: httpClient)
        let parser = DefaultPublicationParser(
            httpClient: httpClient,
            assetRetriever: assetRetriever,
            pdfFactory: DefaultPDFDocumentFactory()
        )
        let opener = PublicationOpener(parser: parser)

        // Convert URL to FileURL
        guard let readiumFileURL = FileURL(url: fileURL) else {
            throw BookImportError.metadataExtractionFailed(underlyingError: NSError(domain: "BookImport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid file URL"]))
        }

        // Retrieve asset from file URL
        let asset: Asset
        switch await assetRetriever.retrieve(url: readiumFileURL) {
        case let .success(retrievedAsset):
            asset = retrievedAsset
        case let .failure(error):
            throw BookImportError.metadataExtractionFailed(underlyingError: error)
        }

        // Open publication
        let publication: Publication
        switch await opener.open(asset: asset, allowUserInteraction: false) {
        case let .success(pub):
            publication = pub
        case let .failure(error):
            throw BookImportError.metadataExtractionFailed(underlyingError: error)
        }

        try Task.checkCancellation()

        // Extract metadata
        let metadata = publication.metadata
        let title = metadata.title
        let author = metadata.authors.first?.name
        let mediaType = publication.manifest.metadata.type
        let language = metadata.language?.code.removingRegion().bcp47

        // Close the publication to release resources
        publication.close()

        try Task.checkCancellation()

        try await context.perform {
            guard let book = try context.existingObject(with: bookID) as? Book else {
                throw BookImportError.importNotFound
            }

            book.title = title
            book.author = author
            book.mediaType = mediaType
            if book.added == nil {
                book.added = Date()
            }
            book.language = language
            book.originalFileName = fileURL.lastPathComponent
            book.metadataSaved = true
            book.displayProgressMessage = "Metadata extracted."

            try context.save()
        }
    }
}
