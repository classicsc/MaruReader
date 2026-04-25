// MangaArchiveReaderTests.swift
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
@testable import MaruManga
import Testing
import UIKit
import Zip

struct MangaArchiveReaderTests {
    // MARK: - Helper Methods

    /// Creates a minimal valid manga archive (CBZ) with images
    private func createMangaArchive(
        imageNames: [String],
        imageSize: CGSize = CGSize(width: 100, height: 100)
    ) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let imagesDir = tempDir.appendingPathComponent("images")
        try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        // Create image files with unique content
        for (index, name) in imageNames.enumerated() {
            let imageURL = imagesDir.appendingPathComponent(name)

            let renderer = UIGraphicsImageRenderer(size: imageSize)
            let image = renderer.image { context in
                // Different color per image for uniqueness
                UIColor(hue: CGFloat(index) / CGFloat(imageNames.count), saturation: 1.0, brightness: 1.0, alpha: 1.0).setFill()
                context.fill(CGRect(origin: .zero, size: imageSize))

                // Draw the page number for verification
                let text = "\(index + 1)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24),
                    .foregroundColor: UIColor.white,
                ]
                text.draw(at: CGPoint(x: 10, y: 10), withAttributes: attributes)
            }

            let ext = (name as NSString).pathExtension.lowercased()
            let imageData: Data? = if ext == "png" {
                image.pngData()
            } else {
                image.jpegData(compressionQuality: 0.8)
            }

            guard let data = imageData else {
                throw NSError(domain: "MangaArchiveReaderTests", code: -1)
            }
            try data.write(to: imageURL)
        }

        // Create CBZ archive
        let archiveURL = tempDir.appendingPathComponent("test.cbz")
        let imageFiles = try FileManager.default.contentsOfDirectory(at: imagesDir, includingPropertiesForKeys: nil)

        try Zip.zipFiles(paths: imageFiles, zipFilePath: archiveURL, password: nil, progress: nil)

        return archiveURL
    }

    private func createMangaArchiveWithMacOSArtifacts() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        let macOSXDir = contentsDir.appendingPathComponent("__MACOSX")
        try FileManager.default.createDirectory(at: macOSXDir, withIntermediateDirectories: true)

        try makeImageData().write(to: contentsDir.appendingPathComponent("001.jpg"))
        try Data().write(to: contentsDir.appendingPathComponent("002.jpg"))
        try makeImageData().write(to: contentsDir.appendingPathComponent("003.jpg"))
        try Data("AppleDouble metadata".utf8).write(to: macOSXDir.appendingPathComponent("._001.jpg"))
        try Data("AppleDouble metadata".utf8).write(to: macOSXDir.appendingPathComponent("._003.jpg"))

        let archiveURL = tempDir.appendingPathComponent("macos-artifacts.cbz")
        try Zip.zipFiles(paths: [contentsDir], zipFilePath: archiveURL, password: nil, progress: nil)

        return archiveURL
    }

    private func makeImageData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        return image.jpegData(compressionQuality: 0.8)!
    }

    /// Creates an archive with no images
    private func createEmptyArchive() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let contentsDir = tempDir.appendingPathComponent("contents")
        try FileManager.default.createDirectory(at: contentsDir, withIntermediateDirectories: true)

        let textURL = contentsDir.appendingPathComponent("readme.txt")
        try "No images here".write(to: textURL, atomically: true, encoding: .utf8)

        let archiveURL = tempDir.appendingPathComponent("empty.cbz")
        try Zip.zipFiles(paths: [textURL], zipFilePath: archiveURL, password: nil, progress: nil)

        return archiveURL
    }

    /// Creates an invalid archive
    private func createInvalidArchive() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let archiveURL = tempDir.appendingPathComponent("invalid.cbz")
        let corruptedData = Data([0x50, 0x4B, 0x03, 0x04, 0xFF, 0xFF])
        try corruptedData.write(to: archiveURL)

        return archiveURL
    }

    // MARK: - Initialization Tests

    @Test func init_validArchive_succeeds() async throws {
        let archiveURL = try createMangaArchive(imageNames: ["page1.jpg", "page2.jpg", "page3.jpg"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        #expect(await reader.pageCount == 3)
    }

    @Test func init_invalidArchive_throwsError() async throws {
        let archiveURL = try createInvalidArchive()
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        do {
            _ = try await MangaArchiveReader(url: archiveURL)
            Issue.record("Expected archiveNotReadable error")
        } catch let error as MangaArchiveReaderError {
            if case .archiveNotReadable = error {
                // Expected
            } else {
                Issue.record("Expected archiveNotReadable, got \(error)")
            }
        }
    }

    @Test func init_emptyArchive_throwsNoImagesError() async throws {
        let archiveURL = try createEmptyArchive()
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        do {
            _ = try await MangaArchiveReader(url: archiveURL)
            Issue.record("Expected noImagesFound error")
        } catch let error as MangaArchiveReaderError {
            if case .noImagesFound = error {
                // Expected
            } else {
                Issue.record("Expected noImagesFound, got \(error)")
            }
        }
    }

    @Test func init_archiveWithMacOSArtifacts_ignoresSidecarsAndEmptyImages() async throws {
        let archiveURL = try createMangaArchiveWithMacOSArtifacts()
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        #expect(await reader.pageCount == 2)
        let paths = await reader.sortedPagePaths
        let filenames = paths.map { ($0 as NSString).lastPathComponent }
        #expect(filenames == ["001.jpg", "003.jpg"])
    }

    @Test func init_missingFile_throwsError() async throws {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing.cbz")

        do {
            _ = try await MangaArchiveReader(url: missingURL)
            Issue.record("Expected archiveNotReadable error")
        } catch let error as MangaArchiveReaderError {
            if case .archiveNotReadable = error {
                // Expected
            } else {
                Issue.record("Expected archiveNotReadable, got \(error)")
            }
        }
    }

    // MARK: - Natural Sorting Tests

    @Test func naturalSorting_numericFilenames_sortsCorrectly() async throws {
        // Create images with names that would sort incorrectly with string sorting
        let imageNames = ["10.jpg", "2.jpg", "1.jpg", "20.jpg", "3.jpg"]
        let archiveURL = try createMangaArchive(imageNames: imageNames)
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        #expect(await reader.pageCount == 5)

        // Verify pages are in correct natural order: 1, 2, 3, 10, 20
        let paths = await reader.sortedPagePaths
        let filenames = paths.map { ($0 as NSString).lastPathComponent }
        #expect(filenames == ["1.jpg", "2.jpg", "3.jpg", "10.jpg", "20.jpg"])
    }

    @Test func naturalSorting_paddedFilenames_sortsCorrectly() async throws {
        // Create images with zero-padded names
        let imageNames = ["page_010.jpg", "page_002.jpg", "page_001.jpg", "page_100.png"]
        let archiveURL = try createMangaArchive(imageNames: imageNames)
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        #expect(await reader.pageCount == 4)

        // Verify natural sort order: 001, 002, 010, 100
        let paths = await reader.sortedPagePaths
        let filenames = paths.map { ($0 as NSString).lastPathComponent }
        #expect(filenames == ["page_001.jpg", "page_002.jpg", "page_010.jpg", "page_100.png"])
    }

    @Test func naturalSorting_mixedExtensions_includesAllImages() async throws {
        // Only use extensions that UIKit can create: jpg, jpeg, png
        let imageNames = ["page1.jpg", "page2.png", "page3.jpeg"]
        let archiveURL = try createMangaArchive(imageNames: imageNames)
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        #expect(await reader.pageCount == 3)

        // Verify all extensions are recognized and sorted
        let paths = await reader.sortedPagePaths
        let filenames = paths.map { ($0 as NSString).lastPathComponent }
        #expect(filenames == ["page1.jpg", "page2.png", "page3.jpeg"])
    }

    // MARK: - Page Access Tests

    @Test func pageData_validIndex_returnsData() async throws {
        let archiveURL = try createMangaArchive(imageNames: ["page1.jpg", "page2.jpg"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        let pageData = try await reader.pageData(at: 0)

        #expect(!pageData.imageData.isEmpty)
        // Verify it's valid image data
        #expect(UIImage(data: pageData.imageData) != nil)
    }

    @Test func pageData_allPages_returnValidImages() async throws {
        let archiveURL = try createMangaArchive(imageNames: ["a.jpg", "b.jpg", "c.jpg"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)
        let count = await reader.pageCount

        for i in 0 ..< count {
            let pageData = try await reader.pageData(at: i)
            #expect(!pageData.imageData.isEmpty, "Page \(i) should have data")
            #expect(UIImage(data: pageData.imageData) != nil, "Page \(i) should be valid image")
        }
    }

    @Test func pageData_negativeIndex_throwsOutOfBounds() async throws {
        let archiveURL = try createMangaArchive(imageNames: ["page1.jpg"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        do {
            _ = try await reader.pageData(at: -1)
            Issue.record("Expected pageIndexOutOfBounds error")
        } catch let error as MangaArchiveReaderError {
            if case let .pageIndexOutOfBounds(index, count) = error {
                #expect(index == -1)
                #expect(count == 1)
            } else {
                Issue.record("Expected pageIndexOutOfBounds, got \(error)")
            }
        }
    }

    @Test func pageData_indexBeyondCount_throwsOutOfBounds() async throws {
        let archiveURL = try createMangaArchive(imageNames: ["page1.jpg", "page2.jpg"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        do {
            _ = try await reader.pageData(at: 5)
            Issue.record("Expected pageIndexOutOfBounds error")
        } catch let error as MangaArchiveReaderError {
            if case let .pageIndexOutOfBounds(index, count) = error {
                #expect(index == 5)
                #expect(count == 2)
            } else {
                Issue.record("Expected pageIndexOutOfBounds, got \(error)")
            }
        }
    }

    // MARK: - Cache Tests

    @Test func cache_pageNotCachedInitially() async throws {
        let archiveURL = try createMangaArchive(imageNames: ["page1.jpg"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        // Before accessing, page should not be cached
        #expect(await reader.isPageCached(at: 0) == false)
        #expect(await reader.cachedPageCount == 0)
    }

    @Test func cache_pageIsCachedAfterAccess() async throws {
        let archiveURL = try createMangaArchive(imageNames: ["page1.jpg"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        // Access the page
        _ = try await reader.pageData(at: 0)

        // Now it should be cached
        #expect(await reader.isPageCached(at: 0) == true)
        #expect(await reader.cachedPageCount == 1)
    }

    @Test func cache_multiplePages_allCached() async throws {
        let archiveURL = try createMangaArchive(imageNames: ["p1.jpg", "p2.jpg", "p3.jpg"])
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        // Access all pages
        _ = try await reader.pageData(at: 0)
        _ = try await reader.pageData(at: 1)
        _ = try await reader.pageData(at: 2)

        // Wait for any prefetch to complete
        await reader.waitForPrefetch()

        // All pages should be cached
        #expect(await reader.isPageCached(at: 0) == true)
        #expect(await reader.isPageCached(at: 1) == true)
        #expect(await reader.isPageCached(at: 2) == true)
        #expect(await reader.cachedPageCount == 3)
    }

    @Test func cache_withSmallLimit_evictsOldPages() async throws {
        // Create images to test cache eviction
        // 100x100 JPEGs are roughly 2-5KB each
        let archiveURL = try createMangaArchive(
            imageNames: ["p1.jpg", "p2.jpg", "p3.jpg", "p4.jpg", "p5.jpg"],
            imageSize: CGSize(width: 100, height: 100)
        )
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        // Use a cache limit that can hold ~2-3 images but not all 5
        // Each 100x100 JPEG is roughly 2-5KB, so 10KB should force eviction
        let reader = try await MangaArchiveReader(url: archiveURL, cacheSizeLimit: 10000)

        // Access all pages sequentially (this won't trigger prefetch cascade now)
        for i in 0 ..< 5 {
            _ = try await reader.pageData(at: i)
        }

        // Wait for any prefetch to complete
        await reader.waitForPrefetch()

        // With a 10KB limit and ~2-5KB images, not all 5 can fit
        // The cache should have evicted some pages
        let cachedCount = await reader.cachedPageCount
        #expect(cachedCount < 5, "Cache should have evicted some pages, but has \(cachedCount)")
        #expect(cachedCount >= 1, "Cache should have at least 1 page")
    }

    // MARK: - Prefetch Tests

    @Test func prefetch_accessingPageZero_prefetchesPagesAhead() async throws {
        let archiveURL = try createMangaArchive(
            imageNames: ["p1.jpg", "p2.jpg", "p3.jpg", "p4.jpg", "p5.jpg"]
        )
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        // Initially nothing is cached
        #expect(await reader.cachedPageCount == 0)

        // Access page 0 - this should trigger prefetch of pages 1, 2, 3 (ahead) and none behind
        _ = try await reader.pageData(at: 0)

        // Wait for prefetch to complete
        await reader.waitForPrefetch()

        // Page 0 should be cached (we accessed it)
        #expect(await reader.isPageCached(at: 0) == true)

        // Pages 1, 2, 3 should be prefetched (3 ahead)
        #expect(await reader.isPageCached(at: 1) == true)
        #expect(await reader.isPageCached(at: 2) == true)
        #expect(await reader.isPageCached(at: 3) == true)

        // Page 4 should NOT be prefetched (beyond prefetchAhead limit of 3)
        #expect(await reader.isPageCached(at: 4) == false)
    }

    @Test func prefetch_accessingMiddlePage_prefetchesBothDirections() async throws {
        let archiveURL = try createMangaArchive(
            imageNames: ["p1.jpg", "p2.jpg", "p3.jpg", "p4.jpg", "p5.jpg", "p6.jpg"]
        )
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        // Access page 2 (middle) - should prefetch pages 3, 4, 5 (ahead) and page 1 (behind)
        _ = try await reader.pageData(at: 2)

        // Wait for prefetch to complete
        await reader.waitForPrefetch()

        // Page 2 should be cached (we accessed it)
        #expect(await reader.isPageCached(at: 2) == true)

        // Pages ahead: 3, 4, 5 should be prefetched
        #expect(await reader.isPageCached(at: 3) == true)
        #expect(await reader.isPageCached(at: 4) == true)
        #expect(await reader.isPageCached(at: 5) == true)

        // Page behind: 1 should be prefetched (1 behind)
        #expect(await reader.isPageCached(at: 1) == true)

        // Page 0 should NOT be prefetched (beyond prefetchBehind limit of 1)
        #expect(await reader.isPageCached(at: 0) == false)
    }

    @Test func prefetch_atEndOfArchive_onlyPrefetchesBehind() async throws {
        let archiveURL = try createMangaArchive(
            imageNames: ["p1.jpg", "p2.jpg", "p3.jpg"]
        )
        defer { try? FileManager.default.removeItem(at: archiveURL.deletingLastPathComponent()) }

        let reader = try await MangaArchiveReader(url: archiveURL)

        // Access last page (index 2) - no pages ahead, only page 1 behind
        _ = try await reader.pageData(at: 2)

        // Wait for prefetch to complete
        await reader.waitForPrefetch()

        // Page 2 should be cached (we accessed it)
        #expect(await reader.isPageCached(at: 2) == true)

        // Page 1 should be prefetched (1 behind)
        #expect(await reader.isPageCached(at: 1) == true)

        // Page 0 should NOT be prefetched (beyond prefetchBehind limit)
        #expect(await reader.isPageCached(at: 0) == false)
    }

    // MARK: - Error Description Tests

    @Test func errorDescription_archiveNotReadable_hasDescription() {
        let url = URL(fileURLWithPath: "/test/path.cbz")
        let error = MangaArchiveReaderError.archiveNotReadable(url)

        #expect(error.errorDescription?.contains("path.cbz") == true)
    }

    @Test func errorDescription_pageIndexOutOfBounds_hasDescription() {
        let error = MangaArchiveReaderError.pageIndexOutOfBounds(index: 10, count: 5)

        #expect(error.errorDescription?.contains("10") == true)
        #expect(error.errorDescription?.contains("5") == true)
    }

    @Test func errorDescription_noImagesFound_hasDescription() throws {
        let error = MangaArchiveReaderError.noImagesFound

        #expect(error.errorDescription != nil)
        #expect(try !#require(error.errorDescription?.isEmpty))
    }
}
