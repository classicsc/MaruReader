//
//  CoverExtractionTask.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/30/25.
//

import CoreData
import Foundation
import MaruReaderCore
import os.log
import ReadiumShared
import ReadiumStreamer
import UIKit

actor CoverExtractionTask {
    let jobID: NSManagedObjectID
    var task: Task<Void, Error>?
    let persistentContainer: NSPersistentContainer
    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookImport")

    init(jobID: NSManagedObjectID, container: NSPersistentContainer = PersistenceController.shared.container) {
        self.jobID = jobID
        self.persistentContainer = container
    }

    func start() {
        let container = persistentContainer
        let jobID = self.jobID
        task = Task {
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            context.undoManager = nil
            context.shouldDeleteInaccessibleFaults = true

            let (fileURL, bookID) = try await context.perform {
                guard let job = try context.existingObject(with: jobID) as? BookEPUBImport else {
                    throw BookImportError.importNotFound
                }
                guard let fileURL = job.file else {
                    throw BookImportError.missingFile
                }
                guard let book = job.book, let bookID = book.id else {
                    throw BookImportError.bookCreationFailed
                }

                // Update progress message
                job.displayProgressMessage = "Extracting book cover..."
                try context.save()
                return (fileURL, bookID)
            }

            try Task.checkCancellation()

            // Access security scoped resource
            guard fileURL.startAccessingSecurityScopedResource() else {
                throw BookImportError.fileAccessDenied
            }

            defer {
                fileURL.stopAccessingSecurityScopedResource()
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
                    guard let job = try context.existingObject(with: jobID) as? BookEPUBImport else {
                        throw BookImportError.importNotFound
                    }

                    job.coverExtracted = true
                    job.displayProgressMessage = "No cover image found."

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
            let coverFileName = "\(bookID.uuidString).png"
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
                guard let job = try context.existingObject(with: jobID) as? BookEPUBImport else {
                    throw BookImportError.importNotFound
                }
                guard let book = job.book else {
                    throw BookImportError.bookCreationFailed
                }

                book.coverFileName = coverFileName
                job.coverExtracted = true
                job.displayProgressMessage = "Cover extracted."

                try context.save()
            }
        }
    }
}
