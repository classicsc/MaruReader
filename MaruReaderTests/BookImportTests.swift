// BookImportTests.swift
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
import UIKit
import Zip

struct BookImportTests {
    /// Custom errors for diagnostics
    enum MockEPUBError: Error {
        case invalidXML(String)
        case fileWriteFailed(URL)
        case fileNotFound(URL)
        case missingFile(String)
    }

    // MARK: - Helper Methods

    /// Creates a minimal valid EPUB file with metadata
    private func createValidEPUB(title: String = "Test Book", author: String = "Test Author") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create mimetype file (must be first and uncompressed)
        let mimetypeURL = tempDir.appendingPathComponent("mimetype")
        let mimetypeContent = "application/epub+zip"
        try mimetypeContent.write(to: mimetypeURL, atomically: true, encoding: .utf8)

        // Create META-INF directory
        let metaInfDir = tempDir.appendingPathComponent("META-INF")
        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)

        // Create container.xml
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
        let containerURL = metaInfDir.appendingPathComponent("container.xml")
        try containerXML.write(to: containerURL, atomically: true, encoding: .utf8)

        // Create content.opf with metadata
        let contentOPF = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="book-id">urn:uuid:\(UUID().uuidString)</dc:identifier>
                <dc:title>\(title)</dc:title>
                <dc:creator>\(author)</dc:creator>
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
        """
        let contentURL = tempDir.appendingPathComponent("content.opf")
        try contentOPF.write(to: contentURL, atomically: true, encoding: .utf8)

        // Create nav.xhtml
        let navXHTML = """
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
        """
        let navURL = tempDir.appendingPathComponent("nav.xhtml")
        try navXHTML.write(to: navURL, atomically: true, encoding: .utf8)

        // Create chapter1.xhtml
        let chapterXHTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Chapter 1</title></head>
        <body>
            <h1>Chapter 1</h1>
            <p>This is a test chapter.</p>
        </body>
        </html>
        """
        let chapterURL = tempDir.appendingPathComponent("chapter1.xhtml")
        try chapterXHTML.write(to: chapterURL, atomically: true, encoding: .utf8)

        // Create EPUB ZIP file
        let epubURL = tempDir.appendingPathComponent("test.epub")
        let filesToZip = [
            mimetypeURL,
            metaInfDir,
            contentURL,
            navURL,
            chapterURL,
        ]

        try Zip.zipFiles(paths: filesToZip, zipFilePath: epubURL, password: nil, progress: nil)

        guard FileManager.default.fileExists(atPath: epubURL.path) else {
            throw MockEPUBError.fileNotFound(epubURL)
        }

        return epubURL
    }

    /// Creates an EPUB with a cover image for testing cover extraction
    private func createEPUBWithCover(title: String = "Test Book with Cover", author: String = "Test Author") throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create mimetype file
        let mimetypeURL = tempDir.appendingPathComponent("mimetype")
        let mimetypeContent = "application/epub+zip"
        try mimetypeContent.write(to: mimetypeURL, atomically: true, encoding: .utf8)

        // Create META-INF directory
        let metaInfDir = tempDir.appendingPathComponent("META-INF")
        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)

        // Create container.xml
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>
            </rootfiles>
        </container>
        """
        let containerURL = metaInfDir.appendingPathComponent("container.xml")
        try containerXML.write(to: containerURL, atomically: true, encoding: .utf8)

        // Create a valid PNG cover image using UIKit
        let coverURL = tempDir.appendingPathComponent("cover.png")
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let coverImage = renderer.image { context in
            // Draw a simple red square as the cover
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }
        guard let pngData = coverImage.pngData() else {
            throw MockEPUBError.invalidXML("Failed to generate PNG data")
        }
        try pngData.write(to: coverURL)

        // Create content.opf with metadata and cover reference
        let contentOPF = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:identifier id="book-id">urn:uuid:\(UUID().uuidString)</dc:identifier>
                <dc:title>\(title)</dc:title>
                <dc:creator>\(author)</dc:creator>
                <dc:language>en</dc:language>
                <meta property="dcterms:modified">2025-01-01T00:00:00Z</meta>
                <meta name="cover" content="cover-image"/>
            </metadata>
            <manifest>
                <item id="cover-image" href="cover.png" media-type="image/png" properties="cover-image"/>
                <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
                <item id="chapter1" href="chapter1.xhtml" media-type="application/xhtml+xml"/>
            </manifest>
            <spine>
                <itemref idref="chapter1"/>
            </spine>
        </package>
        """
        let contentURL = tempDir.appendingPathComponent("content.opf")
        try contentOPF.write(to: contentURL, atomically: true, encoding: .utf8)

        // Create nav.xhtml
        let navXHTML = """
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
        """
        let navURL = tempDir.appendingPathComponent("nav.xhtml")
        try navXHTML.write(to: navURL, atomically: true, encoding: .utf8)

        // Create chapter1.xhtml
        let chapterXHTML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml">
        <head><title>Chapter 1</title></head>
        <body>
            <h1>Chapter 1</h1>
            <p>This is a test chapter.</p>
        </body>
        </html>
        """
        let chapterURL = tempDir.appendingPathComponent("chapter1.xhtml")
        try chapterXHTML.write(to: chapterURL, atomically: true, encoding: .utf8)

        // Create EPUB ZIP file
        let epubURL = tempDir.appendingPathComponent("test-with-cover.epub")
        let filesToZip = [
            mimetypeURL,
            metaInfDir,
            coverURL,
            contentURL,
            navURL,
            chapterURL,
        ]

        try Zip.zipFiles(paths: filesToZip, zipFilePath: epubURL, password: nil, progress: nil)

        guard FileManager.default.fileExists(atPath: epubURL.path) else {
            throw MockEPUBError.fileNotFound(epubURL)
        }

        return epubURL
    }

    /// Creates an invalid (corrupted) EPUB file for testing error handling
    private func createInvalidEPUB() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let epubURL = tempDir.appendingPathComponent("invalid.epub")
        // Create a file with EPUB-like header but corrupted content
        let corruptedData = Data([0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFF])
        try corruptedData.write(to: epubURL)

        return epubURL
    }

    /// Creates a non-EPUB file for testing file type validation
    private func createNonEPUBFile() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let textURL = tempDir.appendingPathComponent("test.txt")
        try "This is not an EPUB file".write(to: textURL, atomically: true, encoding: .utf8)

        return textURL
    }

    // MARK: - DTO Helper Methods

    private func getBookDTO(from context: NSManagedObjectContext, bookID: NSManagedObjectID) async -> BookDTO? {
        await context.perform {
            guard let book = try? context.existingObject(with: bookID) as? Book else {
                return nil
            }
            return BookDTO(from: book)
        }
    }

    private func getBookDTO(from context: NSManagedObjectContext, bookUUID: UUID) async -> BookDTO? {
        await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", bookUUID as CVarArg)
            request.fetchLimit = 1
            guard let book = try? context.fetch(request).first else {
                return nil
            }
            return BookDTO(from: book)
        }
    }

    private func fetchAllBooks(from context: NSManagedObjectContext) async -> [BookDTO] {
        await context.perform {
            let request: NSFetchRequest<Book> = Book.fetchRequest()
            let results = (try? context.fetch(request)) ?? []
            return results.map { BookDTO(from: $0) }
        }
    }

    // MARK: - Validation Helper Methods

    private func verifyImportCompleted(_ bookDTO: BookDTO?) {
        #expect(bookDTO != nil)
        #expect(bookDTO?.isComplete == true)
        #expect(bookDTO?.isCancelled == false)
        #expect(bookDTO?.metadataSaved == true)
        #expect(bookDTO?.fileCopied == true)
        #expect(bookDTO?.coverExtracted == true)
        #expect(bookDTO?.timeCompleted != nil)
        #expect(bookDTO?.displayProgressMessage == "Import complete.")
    }

    private func verifyImportCancelled(_ bookDTO: BookDTO?) {
        #expect(bookDTO != nil)
        #expect(bookDTO?.isCancelled == true)
        #expect(bookDTO?.isComplete == false)
        #expect(bookDTO?.timeCancelled != nil)
    }

    private func verifyImportFailed(_ bookDTO: BookDTO?) {
        #expect(bookDTO != nil)
        #expect(bookDTO?.isCancelled == false)
        #expect(bookDTO?.isComplete == false)
        #expect(bookDTO?.errorMessage?.isEmpty == false)
    }

    private func verifyBookPersisted(_ bookDTO: BookDTO?, expectedTitle: String, expectedAuthor: String) {
        #expect(bookDTO != nil)
        #expect(bookDTO?.title == expectedTitle)
        #expect(bookDTO?.author == expectedAuthor)
        #expect(bookDTO?.id != nil)
        #expect(bookDTO?.isComplete == true)
        #expect(bookDTO?.fileName != nil)
        #expect(bookDTO?.originalFileName != nil)
        #expect(bookDTO?.added != nil)
    }

    private func verifyFilesCopied(bookDTO: BookDTO?) throws {
        guard let bookDTO, let fileName = bookDTO.fileName else {
            Issue.record("Book or fileName is nil")
            return
        }

        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        // Verify EPUB file was copied
        let booksDir = appSupportDir.appendingPathComponent("Books")
        let bookFile = booksDir.appendingPathComponent(fileName)
        #expect(fileManager.fileExists(atPath: bookFile.path), "EPUB file should be copied to Books directory")

        // Verify file is not empty
        let fileSize = try? fileManager.attributesOfItem(atPath: bookFile.path)[.size] as? Int
        #expect((fileSize ?? 0) > 0, "Copied EPUB file should not be empty")
    }

    private func verifyCoverExtracted(bookDTO: BookDTO?) throws {
        guard let bookDTO, let coverFileName = bookDTO.coverFileName else {
            // No cover is also valid (some EPUBs don't have covers)
            return
        }

        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        // Verify cover file was extracted
        let coversDir = appSupportDir.appendingPathComponent("Covers")
        let coverFile = coversDir.appendingPathComponent(coverFileName)
        #expect(fileManager.fileExists(atPath: coverFile.path), "Cover file should be extracted to Covers directory")

        // Verify file is not empty
        let fileSize = try? fileManager.attributesOfItem(atPath: coverFile.path)[.size] as? Int
        #expect((fileSize ?? 0) > 0, "Extracted cover file should not be empty")
    }

    private func verifyFilesCleanedUp(bookDTO: BookDTO?) throws {
        guard let bookDTO, let bookID = bookDTO.id else { return }

        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        let booksDir = appSupportDir.appendingPathComponent("Books")
        let coversDir = appSupportDir.appendingPathComponent("Covers")

        if let originalFileName = bookDTO.originalFileName {
            let fileExtension = (originalFileName as NSString).pathExtension
            let bookFileName = fileExtension.isEmpty
                ? bookID.uuidString
                : "\(bookID.uuidString).\(fileExtension)"
            let bookFile = booksDir.appendingPathComponent(bookFileName)
            #expect(!fileManager.fileExists(atPath: bookFile.path), "EPUB file should be deleted after cancellation/failure")
        }

        let coverFile = coversDir.appendingPathComponent("\(bookID.uuidString).png")
        #expect(!fileManager.fileExists(atPath: coverFile.path), "Cover file should be deleted after cancellation/failure")
    }

    // MARK: - Test Cases

    @Test func importBook_ValidEPUB_ImportsSuccessfully() async throws {
        // Setup: Create a valid EPUB file
        let epubURL = try createValidEPUB(title: "Alice in Wonderland", author: "Lewis Carroll")
        defer { try? FileManager.default.removeItem(at: epubURL.deletingLastPathComponent()) }

        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let bookID = try await importManager.enqueueImport(from: epubURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: bookID)

        // Assert: Job completed successfully
        let context = persistenceController.container.viewContext
        let bookDTO = await getBookDTO(from: context, bookID: bookID)
        verifyImportCompleted(bookDTO)

        // Assert: Book entity created with correct metadata
        verifyBookPersisted(bookDTO, expectedTitle: "Alice in Wonderland", expectedAuthor: "Lewis Carroll")

        // Assert: EPUB file was copied
        try verifyFilesCopied(bookDTO: bookDTO)

        // Note: Cover extraction may fail for this minimal EPUB, which is expected
    }

    @Test func importBook_ValidEPUBWithCover_ExtractsCover() async throws {
        // Setup: Create a valid EPUB file with cover image
        let epubURL = try createEPUBWithCover(title: "Book with Cover", author: "Test Author")
        defer { try? FileManager.default.removeItem(at: epubURL.deletingLastPathComponent()) }

        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let bookID = try await importManager.enqueueImport(from: epubURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: bookID)

        // Assert: Job completed successfully
        let context = persistenceController.container.viewContext
        let bookDTO = await getBookDTO(from: context, bookID: bookID)
        verifyImportCompleted(bookDTO)

        // Assert: Book entity created with correct metadata
        verifyBookPersisted(bookDTO, expectedTitle: "Book with Cover", expectedAuthor: "Test Author")

        // Assert: EPUB file was copied
        try verifyFilesCopied(bookDTO: bookDTO)

        // Assert: Cover was extracted
        try verifyCoverExtracted(bookDTO: bookDTO)
    }

    @Test func importBook_InvalidEPUB_FailsAndCleansUp() async throws {
        // Setup: Create an invalid (corrupted) EPUB file
        let invalidURL = try createInvalidEPUB()
        defer { try? FileManager.default.removeItem(at: invalidURL.deletingLastPathComponent()) }

        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let bookID = try await importManager.enqueueImport(from: invalidURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: bookID)

        // Assert: Import marked as failed
        let context = persistenceController.container.viewContext
        let bookDTO = await getBookDTO(from: context, bookID: bookID)
        verifyImportFailed(bookDTO)

        // Assert: Book entity persisted for failed import
        let books = await fetchAllBooks(from: context)
        #expect(books.count == 1, "Failed imports should remain in the library for removal")

        // Assert: Files cleaned up
        try verifyFilesCleanedUp(bookDTO: bookDTO)
    }

    @Test func importBook_NonEPUBFile_FailsAndCleansUp() async throws {
        // Setup: Create a non-EPUB file
        let textURL = try createNonEPUBFile()
        defer { try? FileManager.default.removeItem(at: textURL.deletingLastPathComponent()) }

        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let bookID = try await importManager.enqueueImport(from: textURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: bookID)

        // Assert: Import marked as failed
        let context = persistenceController.container.viewContext
        let bookDTO = await getBookDTO(from: context, bookID: bookID)
        verifyImportFailed(bookDTO)

        // Assert: Book entity persisted for failed import
        let books = await fetchAllBooks(from: context)
        #expect(books.count == 1, "Failed imports should remain in the library for removal")
    }

    @Test func importBook_CancelDuringMetadataProcessing_CleansUpProperly() async throws {
        // Setup: Create a valid EPUB file
        let epubURL = try createValidEPUB(title: "Cancelled Book", author: "Test Author")
        defer { try? FileManager.default.removeItem(at: epubURL.deletingLastPathComponent()) }

        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        // Set up cancellation hook to trigger during metadata processing
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 1 { // First cancellation check
                throw CancellationError()
            }
        }

        // Action: Enqueue import
        let bookID = try await importManager.enqueueImport(from: epubURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: bookID)

        // Assert: Import marked as cancelled
        let context = persistenceController.container.viewContext
        let bookDTO = await getBookDTO(from: context, bookID: bookID)
        verifyImportCancelled(bookDTO)

        // Assert: Cancelled book remains in the library
        let books = await fetchAllBooks(from: context)
        #expect(books.count == 1, "Cancelled imports should remain in the library for removal")

        // Assert: Files cleaned up
        try verifyFilesCleanedUp(bookDTO: bookDTO)
    }

    @Test func importBook_CancelAfterFileCopy_CleansUpProperly() async throws {
        // Setup: Create a valid EPUB file
        let epubURL = try createValidEPUB(title: "Cancelled Book", author: "Test Author")
        defer { try? FileManager.default.removeItem(at: epubURL.deletingLastPathComponent()) }

        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        // Set up cancellation hook to trigger after file copy
        var cancellationCount = 0
        await importManager.setTestCancellationHook {
            cancellationCount += 1
            if cancellationCount == 2 { // Second cancellation check (after file copy)
                throw CancellationError()
            }
        }

        // Action: Enqueue import
        let bookID = try await importManager.enqueueImport(from: epubURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: bookID)

        // Assert: Import marked as cancelled
        let context = persistenceController.container.viewContext
        let bookDTO = await getBookDTO(from: context, bookID: bookID)
        verifyImportCancelled(bookDTO)

        // Assert: Cancelled book remains in the library
        let books = await fetchAllBooks(from: context)
        #expect(books.count == 1, "Cancelled imports should remain in the library for removal")

        // Assert: Files cleaned up (even though they were copied)
        try verifyFilesCleanedUp(bookDTO: bookDTO)
    }

    @Test func importBook_CancelQueuedJob_CleansUpProperly() async throws {
        // Setup: Create a valid EPUB file
        let epubURL = try createValidEPUB(title: "Queued Book", author: "Test Author")
        defer { try? FileManager.default.removeItem(at: epubURL.deletingLastPathComponent()) }

        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let bookID = try await importManager.enqueueImport(from: epubURL)

        // Cancel immediately (while still queued)
        await importManager.cancelImport(jobID: bookID)

        // Wait a bit for cancellation to be processed
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Assert: Job marked as cancelled
        let context = persistenceController.container.viewContext
        let bookDTO = await getBookDTO(from: context, bookID: bookID)
        verifyImportCancelled(bookDTO)

        // Assert: Cancelled book remains in the library
        let books = await fetchAllBooks(from: context)
        #expect(books.count == 1, "Cancelled queued imports should remain in the library for removal")
    }

    @Test func importBook_MissingFile_FailsAndCleansUp() async throws {
        // Setup: Create a file URL that doesn't exist
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing.epub")

        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        // Action: Enqueue import
        let bookID = try await importManager.enqueueImport(from: missingURL)

        // Wait for completion
        await importManager.waitForCompletion(jobID: bookID)

        // Assert: Import marked as failed
        let context = persistenceController.container.viewContext
        let bookDTO = await getBookDTO(from: context, bookID: bookID)
        verifyImportFailed(bookDTO)

        // Assert: Book entity persisted for failed import
        let books = await fetchAllBooks(from: context)
        #expect(books.count == 1, "Failed imports should remain in the library for removal")
    }

    @Test func cleanupInterruptedBookImports_MarksFailedAndCleansFiles() async throws {
        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let booksDir = appSupportDir.appendingPathComponent("Books")
        let coversDir = appSupportDir.appendingPathComponent("Covers")
        try fileManager.createDirectory(at: booksDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)

        let fileName = "interrupted-\(UUID().uuidString).epub"
        let coverFileName = "interrupted-\(UUID().uuidString).png"
        let bookFile = booksDir.appendingPathComponent(fileName)
        let coverFile = coversDir.appendingPathComponent(coverFileName)
        try Data("book".utf8).write(to: bookFile)
        try Data("cover".utf8).write(to: coverFile)

        let importURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".epub")
        try "source".write(to: importURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: importURL) }

        let context = persistenceController.container.newBackgroundContext()
        let bookID = try await context.perform {
            let book = Book(context: context)
            book.id = UUID()
            book.importFile = importURL
            book.originalFileName = importURL.lastPathComponent
            book.fileName = fileName
            book.coverFileName = coverFileName
            book.fileCopied = true
            book.coverExtracted = true
            book.isStarted = true
            book.isComplete = false
            book.isCancelled = false
            book.displayProgressMessage = "Importing..."
            book.timeQueued = Date()
            try context.save()
            return book.objectID
        }

        await importManager.cleanupInterruptedImports()

        let viewContext = persistenceController.container.viewContext
        let bookDTO = await getBookDTO(from: viewContext, bookID: bookID)
        verifyImportFailed(bookDTO)
        #expect(bookDTO?.fileCopied == false)
        #expect(bookDTO?.coverExtracted == false)
        #expect(bookDTO?.fileName == nil)
        #expect(bookDTO?.coverFileName == nil)
        #expect(!fileManager.fileExists(atPath: bookFile.path), "Book file should be deleted")
        #expect(!fileManager.fileExists(atPath: coverFile.path), "Cover file should be deleted")
    }

    @Test func cleanupPendingBookDeletions_RemovesBookAndFiles() async throws {
        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        let fileManager = FileManager.default
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let booksDir = appSupportDir.appendingPathComponent("Books")
        let coversDir = appSupportDir.appendingPathComponent("Covers")
        try fileManager.createDirectory(at: booksDir, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: coversDir, withIntermediateDirectories: true)

        let fileName = "pending-\(UUID().uuidString).epub"
        let coverFileName = "pending-\(UUID().uuidString).png"
        let bookFile = booksDir.appendingPathComponent(fileName)
        let coverFile = coversDir.appendingPathComponent(coverFileName)
        try Data("book".utf8).write(to: bookFile)
        try Data("cover".utf8).write(to: coverFile)

        let bookUUID = UUID()
        let context = persistenceController.container.newBackgroundContext()
        try await context.perform {
            let book = Book(context: context)
            book.id = bookUUID
            book.fileName = fileName
            book.coverFileName = coverFileName
            book.pendingDeletion = true
            book.isComplete = true
            try context.save()
        }

        await importManager.cleanupPendingDeletions()

        let verificationContext = persistenceController.container.newBackgroundContext()
        let bookDTO = await getBookDTO(from: verificationContext, bookUUID: bookUUID)
        #expect(bookDTO == nil, "Pending deletion book should be removed")
        #expect(!fileManager.fileExists(atPath: bookFile.path), "Book file should be deleted")
        #expect(!fileManager.fileExists(atPath: coverFile.path), "Cover file should be deleted")
    }

    @Test func deleteBook_RemovesBookAndFiles() async throws {
        // Setup: Import a valid EPUB first
        let epubURL = try createValidEPUB(title: "Book to Delete", author: "Test Author")
        defer { try? FileManager.default.removeItem(at: epubURL.deletingLastPathComponent()) }

        let persistenceController = BookDataPersistenceController(inMemory: true)
        let importManager = BookImportManager(container: persistenceController.container)

        let bookID = try await importManager.enqueueImport(from: epubURL)
        await importManager.waitForCompletion(jobID: bookID)

        let context = persistenceController.container.viewContext

        // Verify book was imported
        let bookDTO = await getBookDTO(from: context, bookID: bookID)
        #expect(bookDTO != nil)
        try verifyFilesCopied(bookDTO: bookDTO)

        // Save file names for later verification
        let fileName = bookDTO?.fileName
        let coverFileName = bookDTO?.coverFileName

        // Action: Delete the book
        await importManager.deleteBook(bookID: bookID)

        // Allow deletion to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Assert: Book entity deleted
        let books = await fetchAllBooks(from: context)
        #expect(books.isEmpty, "No books should remain after deletion")

        // Assert: Files cleaned up
        if let fileName {
            let fileManager = FileManager.default
            let appSupportDir = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let bookFile = appSupportDir.appendingPathComponent("Books").appendingPathComponent(fileName)
            #expect(!fileManager.fileExists(atPath: bookFile.path), "Book file should be deleted")
        }

        if let coverFileName {
            let fileManager = FileManager.default
            let appSupportDir = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            let coverFile = appSupportDir.appendingPathComponent("Covers").appendingPathComponent(coverFileName)
            #expect(!fileManager.fileExists(atPath: coverFile.path), "Cover file should be deleted")
        }
    }
}

// MARK: - DTOs for Thread-Safe Data Transfer

struct BookDTO {
    let id: UUID?
    let title: String?
    let author: String?
    let fileName: String?
    let coverFileName: String?
    let originalFileName: String?
    let mediaType: String?
    let added: Date?
    let isComplete: Bool
    let isStarted: Bool
    let isCancelled: Bool
    let metadataSaved: Bool
    let fileCopied: Bool
    let coverExtracted: Bool
    let displayProgressMessage: String?
    let timeQueued: Date?
    let timeStarted: Date?
    let timeCompleted: Date?
    let timeCancelled: Date?
    let errorMessage: String?

    init(from book: Book) {
        id = book.id
        title = book.title
        author = book.author
        fileName = book.fileName
        coverFileName = book.coverFileName
        originalFileName = book.originalFileName
        mediaType = book.mediaType
        added = book.added
        isComplete = book.isComplete
        isStarted = book.isStarted
        isCancelled = book.isCancelled
        metadataSaved = book.metadataSaved
        fileCopied = book.fileCopied
        coverExtracted = book.coverExtracted
        displayProgressMessage = book.displayProgressMessage
        timeQueued = book.timeQueued
        timeStarted = book.timeStarted
        timeCompleted = book.timeCompleted
        timeCancelled = book.timeCancelled
        errorMessage = book.errorMessage
    }
}
