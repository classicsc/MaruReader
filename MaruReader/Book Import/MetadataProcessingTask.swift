//
//  MetadataProcessingTask.swift
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

actor MetadataProcessingTask {
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

            let fileURL = try await context.perform {
                guard let job = try context.existingObject(with: jobID) as? BookEPUBImport else {
                    throw BookImportError.importNotFound
                }
                guard let fileURL = job.file else {
                    throw BookImportError.missingFile
                }

                // Update progress message
                job.displayProgressMessage = "Reading book metadata..."
                try context.save()
                return fileURL
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

            // Create Book entity in Core Data
            try await context.perform {
                guard let job = try context.existingObject(with: jobID) as? BookEPUBImport else {
                    throw BookImportError.importNotFound
                }

                // Create Book entity
                let book = Book(context: context)
                book.id = UUID()
                book.title = title
                book.author = author
                book.mediaType = mediaType
                book.added = Date()
                book.language = language
                book.originalFileName = fileURL.lastPathComponent

                context.insert(book)

                // Link job to book
                job.book = book
                job.metadataSaved = true
                job.displayProgressMessage = "Metadata extracted."

                try context.save()
            }
        }
    }
}
