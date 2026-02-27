// CoverExtractionTask.swift
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
import MaruReaderCore
import os
import ReadiumShared
import ReadiumStreamer
import UIKit

struct CoverExtractionTask {
    let bookID: NSManagedObjectID
    let persistentContainer: NSPersistentContainer
    private let logger = Logger.maru(category: "BookImport")

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

        let (fileURL, bookUUID) = try await context.perform {
            guard let book = try context.existingObject(with: bookID) as? Book else {
                throw BookImportError.importNotFound
            }
            guard let fileURL = book.importFile else {
                throw BookImportError.missingFile
            }
            guard let bookUUID = book.id else {
                throw BookImportError.bookCreationFailed
            }

            // Update progress message
            book.displayProgressMessage = "Extracting book cover..."
            try context.save()
            return (fileURL, bookUUID)
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
            throw BookImportError.coverExtractionFailed(underlyingError: NSError(domain: "BookImport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid file URL"]))
        }

        // Retrieve asset from file URL
        let asset: Asset
        switch await assetRetriever.retrieve(url: readiumFileURL) {
        case let .success(retrievedAsset):
            asset = retrievedAsset
        case let .failure(error):
            throw BookImportError.coverExtractionFailed(underlyingError: error)
        }

        // Open publication
        let publication: Publication
        switch await opener.open(asset: asset, allowUserInteraction: false) {
        case let .success(pub):
            publication = pub
        case let .failure(error):
            throw BookImportError.coverExtractionFailed(underlyingError: error)
        }

        try Task.checkCancellation()

        // Extract cover image
        let coverImage: UIImage?
        switch await publication.cover() {
        case let .success(image):
            coverImage = image
        case let .failure(error):
            // Close the publication
            publication.close()
            throw BookImportError.coverExtractionFailed(underlyingError: error)
        }

        // Close the publication to release resources
        publication.close()

        try Task.checkCancellation()

        // If no cover image, mark as complete but without saving a cover file
        guard let coverImage else {
            try await context.perform {
                guard let book = try context.existingObject(with: bookID) as? Book else {
                    throw BookImportError.importNotFound
                }

                book.coverExtracted = true
                book.displayProgressMessage = "No cover image found."

                try context.save()
            }
            return
        }

        // Get application support directory
        let appSupportDir: URL
        do {
            appSupportDir = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        } catch {
            throw BookImportError.coverExtractionFailed(underlyingError: error)
        }

        // Create Covers directory if needed
        let coversDir = appSupportDir.appendingPathComponent("Covers")
        do {
            try FileManager.default.createDirectory(at: coversDir, withIntermediateDirectories: true)
        } catch {
            throw BookImportError.coverExtractionFailed(underlyingError: error)
        }

        // Save cover image as PNG
        let coverFileName = "\(bookUUID.uuidString).png"
        let coverURL = coversDir.appendingPathComponent(coverFileName)

        do {
            // Convert image to PNG data
            guard let pngData = coverImage.pngData() else {
                throw BookImportError.coverExtractionFailed(underlyingError: NSError(domain: "BookImport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert cover to PNG"]))
            }

            // Remove destination if it exists
            if FileManager.default.fileExists(atPath: coverURL.path) {
                try FileManager.default.removeItem(at: coverURL)
            }

            // Write image data
            try pngData.write(to: coverURL)
        } catch {
            throw BookImportError.coverExtractionFailed(underlyingError: error)
        }

        try Task.checkCancellation()

        // Update Book entity with cover file name
        try await context.perform {
            guard let book = try context.existingObject(with: bookID) as? Book else {
                throw BookImportError.importNotFound
            }

            book.coverFileName = coverFileName
            book.coverExtracted = true
            book.displayProgressMessage = "Cover extracted."

            try context.save()
        }
    }
}
