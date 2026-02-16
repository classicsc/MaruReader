// MangaArchiveReader.swift
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
internal import LRUCache
import MaruVision
internal import ReadiumZIPFoundation

/// A manga page containing image data and OCR text clusters.
public struct MangaPageData: Sendable {
    /// The raw image data for the page.
    public let imageData: Data

    /// The file extension for the page image, if known.
    public let imageFileExtension: String?

    /// Text clusters detected by OCR, sorted by reading order.
    /// Empty if OCR has not been performed on this page.
    public let textClusters: [TextCluster]

    public init(imageData: Data, imageFileExtension: String? = nil, textClusters: [TextCluster] = []) {
        self.imageData = imageData
        self.imageFileExtension = imageFileExtension
        self.textClusters = textClusters
    }
}

/// Errors that can occur when reading manga archives.
public enum MangaArchiveReaderError: LocalizedError {
    case archiveNotReadable(URL)
    case noImagesFound
    case pageIndexOutOfBounds(index: Int, count: Int)
    case extractionFailed(path: String, underlying: Error)

    public var errorDescription: String? {
        switch self {
        case let .archiveNotReadable(url):
            "Unable to read archive at \(url.lastPathComponent)"
        case .noImagesFound:
            "No images found in archive"
        case let .pageIndexOutOfBounds(index, count):
            "Page index \(index) is out of bounds (0..<\(count))"
        case let .extractionFailed(path, error):
            "Failed to extract \(path): \(error.localizedDescription)"
        }
    }
}

/// An actor that provides efficient, cached access to manga pages within ZIP/CBZ archives.
///
/// `MangaArchiveReader` manages reading from a single manga archive with intelligent caching:
/// - Naturally sorts image files for correct page order
/// - Uses an LRU cache with memory-based eviction
/// - Prefetches pages around the current reading position
///
/// Usage:
/// ```swift
/// let reader = try await MangaArchiveReader(url: archiveURL)
/// let pageData = try await reader.pageData(at: 0)
/// let image = UIImage(data: pageData)
/// ```
public actor MangaArchiveReader {
    // MARK: - Configuration

    /// Default cache size limit in bytes (100 MB)
    public static let defaultCacheLimit: Int = 100_000_000

    /// Number of pages to prefetch ahead of the current page
    public static let prefetchAhead: Int = 3

    /// Number of pages to prefetch behind the current page
    public static let prefetchBehind: Int = 1

    /// Supported image file extensions
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "webp"]

    // MARK: - State

    private let archive: Archive
    private let sortedPages: [Entry]
    private let cache: LRUCache<Int, MangaPageData>
    private var prefetchTask: Task<Void, Never>?
    private let ocr = OCR()

    // MARK: - Initialization

    /// Creates a new manga archive reader for the specified archive URL.
    ///
    /// - Parameters:
    ///   - url: The file URL of the ZIP/CBZ archive to read.
    ///   - cacheSizeLimit: Maximum cache size in bytes. Defaults to 100 MB.
    /// - Throws: `MangaArchiveReaderError.archiveNotReadable` if the archive cannot be opened,
    ///           or `MangaArchiveReaderError.noImagesFound` if the archive contains no images.
    public init(url: URL, cacheSizeLimit: Int = defaultCacheLimit) async throws {
        do {
            self.archive = try await Archive(url: url, accessMode: .read)
        } catch {
            throw MangaArchiveReaderError.archiveNotReadable(url)
        }

        let entries = try await archive.entries()
        self.sortedPages = Self.sortedImageEntries(entries)

        guard !sortedPages.isEmpty else {
            throw MangaArchiveReaderError.noImagesFound
        }

        self.cache = LRUCache<Int, MangaPageData>(totalCostLimit: cacheSizeLimit)
    }

    // MARK: - Public API

    /// The total number of pages in the archive.
    public var pageCount: Int {
        sortedPages.count
    }

    /// Retrieves the page data for the page at the specified index.
    ///
    /// This method checks the cache first and extracts from the archive on a cache miss.
    /// It also triggers prefetching of surrounding pages in the background.
    ///
    /// - Parameter index: The zero-based page index.
    /// - Returns: The manga page data containing image data and text clusters.
    /// - Throws: `MangaArchiveReaderError.pageIndexOutOfBounds` if the index is invalid,
    ///           or `MangaArchiveReaderError.extractionFailed` if extraction fails.
    public func pageData(at index: Int) async throws -> MangaPageData {
        let data = try await loadPage(at: index)

        // Trigger prefetch for surrounding pages
        triggerPrefetch(around: index)

        return data
    }

    /// Internal method to load a page without triggering prefetch.
    /// Used by both public pageData and internal prefetch logic.
    private func loadPage(at index: Int) async throws -> MangaPageData {
        guard index >= 0, index < sortedPages.count else {
            throw MangaArchiveReaderError.pageIndexOutOfBounds(index: index, count: sortedPages.count)
        }

        // Check cache first
        if let cached = cache.value(forKey: index) {
            return cached
        }

        // Extract from archive
        let entry = sortedPages[index]
        let imageData = try await extractPage(entry)
        let clusters = try await ocr.performOCR(imageData: imageData)
        let fileExtension = (entry.path as NSString).pathExtension.lowercased()

        // Create page data with empty text clusters
        let pageData = MangaPageData(
            imageData: imageData,
            imageFileExtension: fileExtension.isEmpty ? nil : fileExtension,
            textClusters: clusters
        )

        // Store in cache with cost = byte count
        cache.setValue(pageData, forKey: index, cost: imageData.count)

        return pageData
    }

    // MARK: - Private Implementation

    /// Filters and naturally sorts image entries from the archive.
    private static func sortedImageEntries(_ entries: [Entry]) -> [Entry] {
        entries
            .filter { $0.type == .file && isImageFile($0.path) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    /// Checks if a file path represents an image file based on its extension.
    private static func isImageFile(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return imageExtensions.contains(ext)
    }

    /// Checks if a page is already in the cache.
    private func isCached(pageIndex: Int) -> Bool {
        cache.hasValue(forKey: pageIndex)
    }

    /// Extracts a page entry to memory via a temporary file.
    ///
    /// Uses a temp file approach for Swift 6 Sendable compliance with the consumer closure.
    private func extractPage(_ entry: Entry) async throws -> Data {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".tmp")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            _ = try await archive.extract(entry, to: tempURL)
            return try Data(contentsOf: tempURL)
        } catch {
            throw MangaArchiveReaderError.extractionFailed(path: entry.path, underlying: error)
        }
    }

    /// Triggers prefetching of pages around the given index.
    ///
    /// This cancels any previous prefetch task and starts a new one.
    /// Prefetch happens in a detached task to avoid blocking the caller.
    private func triggerPrefetch(around index: Int) {
        prefetchTask?.cancel()

        prefetchTask = Task { [weak self] in
            guard let self else { return }

            // Build list of pages to prefetch: ahead first, then behind
            var indices: [Int] = []
            for offset in 1 ... Self.prefetchAhead {
                indices.append(index + offset)
            }
            for offset in 1 ... Self.prefetchBehind {
                indices.append(index - offset)
            }

            for i in indices {
                guard !Task.isCancelled else { break }

                let count = await self.pageCount
                guard i >= 0, i < count else { continue }

                // Skip if already cached
                let isCached = await self.isCached(pageIndex: i)
                if isCached {
                    continue
                }

                // Load the page without triggering another prefetch
                _ = try? await self.loadPage(at: i)
            }
        }
    }

    /// Prefetches specific pages by their indices.
    ///
    /// Used for spread-aware prefetching where the caller knows which pages
    /// to load based on the current spread layout.
    ///
    /// - Parameter indices: The page indices to prefetch.
    public func prefetchPages(_ indices: [Int]) {
        prefetchTask?.cancel()

        prefetchTask = Task { [weak self] in
            guard let self else { return }

            for index in indices {
                guard !Task.isCancelled else { break }

                let count = await self.pageCount
                guard index >= 0, index < count else { continue }

                let isCached = await self.isCached(pageIndex: index)
                if isCached {
                    continue
                }

                _ = try? await self.loadPage(at: index)
            }
        }
    }

    // MARK: - Test Helpers

    /// Returns whether the page at the given index is currently in the cache.
    /// - Parameter index: The page index to check.
    /// - Returns: `true` if the page is cached, `false` otherwise.
    public func isPageCached(at index: Int) -> Bool {
        cache.hasValue(forKey: index)
    }

    /// Returns the number of pages currently in the cache.
    public var cachedPageCount: Int {
        cache.count
    }

    /// Returns the sorted page paths in the archive (for verifying sort order).
    public var sortedPagePaths: [String] {
        sortedPages.map(\.path)
    }

    /// Waits for any in-progress prefetch operation to complete.
    public func waitForPrefetch() async {
        await prefetchTask?.value
    }
}
