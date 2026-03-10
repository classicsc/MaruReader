// MangaReaderViewModel.swift
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
import MaruVision
import Observation
import os
import SwiftUI

struct MangaRenderedPage {
    let image: UIImage
    let textClusters: [TextCluster]
}

private struct MangaPageRenderError: LocalizedError {
    var errorDescription: String? {
        MangaLocalization.string("Failed to decode image")
    }
}

@MainActor
@Observable
final class MangaReaderViewModel {
    // MARK: - Configuration

    private static let saveDebounceInterval: UInt64 = 500_000_000 // 0.5 seconds
    private static let singlePageWorkingSetRadius = 1
    private static let spreadWorkingSetRadius = 1
    nonisolated static let screenshotLookupPreferredPrefix = "教授の実験"

    // MARK: - Navigation State

    /// The current page index (0-based)
    var currentPageIndex: Int = 0 {
        didSet {
            if currentPageIndex != oldValue {
                resetZoom()
                debounceSaveProgress()
                scheduleRenderedPageRefresh()
            }
        }
    }

    /// Total page count from the archive reader
    private(set) var pageCount: Int = 0

    // MARK: - Render Cache

    /// Decoded pages currently retained for UI rendering.
    private(set) var renderedPageCache: [Int: MangaRenderedPage] = [:]

    /// Loading state for pages
    private(set) var pageLoadingStates: [Int: PageLoadingState] = [:]

    // MARK: - Reading Settings (Persisted)

    /// Current reading direction
    var readingDirection: MangaReadingDirection = .rightToLeft {
        didSet {
            if readingDirection != oldValue {
                recomputeSpreadLayout()
                saveReadingDirection()
            }
        }
    }

    /// User preference: force single-page mode even in landscape
    var forceSinglePage: Bool = false {
        didSet {
            if forceSinglePage != oldValue {
                recomputeSpreadLayout()
                saveForceSinglePage()
            }
        }
    }

    // MARK: - Spread Layout State

    /// Whether the device is in landscape orientation
    private(set) var isLandscape: Bool = false

    /// Computed spread layout based on current settings
    private(set) var spreadLayout: SpreadLayout = .init(items: [])

    /// Whether spreads are currently active (landscape + not forced single + horizontal mode)
    var isSpreadModeActive: Bool {
        !forceSinglePage && isLandscape && readingDirection != .vertical
    }

    /// Current spread index (for TabView selection in spread mode)
    var currentSpreadIndex: Int {
        get {
            spreadLayout.spreadIndex(forPage: currentPageIndex) ?? 0
        }
        set {
            // When spread changes, update currentPageIndex to first page of spread
            let pages = spreadLayout.pages(atSpreadIndex: newValue)
            if let first = pages.min(), first != currentPageIndex {
                currentPageIndex = first
            }
        }
    }

    // MARK: - Overlay State

    /// Controls toolbar visibility
    var overlayState: MangaReaderOverlayState = .showingToolbars

    /// Whether OCR bounding boxes are visible
    var showBoundingBoxes: Bool = false

    // MARK: - Zoom/Pan State (per page, reset on page change)

    var scale: CGFloat = 1.0
    var lastScale: CGFloat = 1.0
    var offset: CGSize = .zero
    var lastOffset: CGSize = .zero

    /// Whether the view is currently at base zoom level (enables page swipe)
    var isAtBaseZoom: Bool {
        scale <= 1.01 // Small tolerance for floating point
    }

    // MARK: - Dictionary Integration

    /// Currently highlighted cluster (brief highlight before dictionary opens)
    var highlightedCluster: TextCluster?

    /// Whether dictionary sheet is showing
    var showingDictionarySheet: Bool = false

    /// Pending search data for lazy dictionary view model initialization
    private(set) var pendingSearchText: String?
    private(set) var pendingContextValues: LookupContextValues?

    // MARK: - Private State

    let manga: MangaArchive
    private var pageProvider: (any MangaPageProviding)?
    private let persistenceController: MangaDataPersistenceController
    private let archiveReaderFactory: @Sendable (URL) async throws -> any MangaPageProviding

    private var saveTask: Task<Void, Never>?
    private var renderedPageRefreshTask: Task<Void, Never>?
    private var pageLoadTasks: [Int: Task<Void, Never>] = [:]
    /// Tracks the page index that was last successfully saved
    private var lastSavedPageIndex: Int?
    private let logger = Logger.maru(category: "MangaReaderViewModel")

    // MARK: - Initialization

    init(
        manga: MangaArchive,
        persistenceController: MangaDataPersistenceController = .shared,
        archiveReaderFactory: @escaping @Sendable (URL) async throws -> any MangaPageProviding = { url in
            try await MangaArchiveReader(url: url)
        }
    ) {
        self.manga = manga
        self.persistenceController = persistenceController
        self.archiveReaderFactory = archiveReaderFactory

        // Load persisted state
        loadPersistedState()
    }

    // MARK: - Lifecycle

    /// Loads the archive reader asynchronously. Call this when the view appears.
    func loadArchive() async {
        guard pageProvider == nil else { return }

        guard let localPath = manga.localPath else {
            logger.error("Manga has no local path")
            return
        }

        do {
            let reader = try await archiveReaderFactory(localPath)
            pageProvider = reader
            pageCount = await reader.pageCount
            logger.info("Loaded archive with \(self.pageCount) pages")

            // Compute initial spread layout now that we know page count
            recomputeSpreadLayout()

            await refreshRenderedPageWorkingSet()
        } catch {
            logger.error("Failed to load archive: \(error.localizedDescription)")
        }
    }

    /// Loads a specific page's data
    func loadPage(at index: Int) async {
        guard pageProvider != nil else { return }
        guard index >= 0, index < pageCount else { return }

        if renderedPageCache[index] != nil {
            pageLoadingStates[index] = .loaded
            return
        }

        if let task = pageLoadTasks[index] {
            await task.value
            return
        }

        pageLoadingStates[index] = .loading
        let task = Task { [weak self, pageProvider] in
            guard let pageProvider else {
                await MainActor.run {
                    self?.pageLoadTasks[index] = nil
                }
                return
            }

            do {
                let pageData = try await pageProvider.pageData(at: index)
                guard let image = UIImage(data: pageData.imageData) else {
                    throw MangaPageRenderError()
                }

                await MainActor.run {
                    guard let self else { return }
                    guard self.desiredRenderedPageIndices().contains(index) else {
                        self.pageLoadingStates.removeValue(forKey: index)
                        return
                    }
                    self.renderedPageCache[index] = MangaRenderedPage(
                        image: image,
                        textClusters: pageData.textClusters
                    )
                    self.pageLoadingStates[index] = .loaded
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.logger.error("Failed to load page \(index): \(error.localizedDescription)")
                    self.pageLoadingStates[index] = .error(error.localizedDescription)
                }
            }

            await MainActor.run {
                self?.pageLoadTasks[index] = nil
            }
        }
        pageLoadTasks[index] = task
        await task.value
    }

    // MARK: - Navigation

    func goToNextPage() {
        let nextIndex: Int = switch readingDirection {
        case .rightToLeft:
            currentPageIndex + 1
        case .leftToRight:
            currentPageIndex + 1
        case .vertical:
            currentPageIndex + 1
        }

        if nextIndex < pageCount {
            currentPageIndex = nextIndex
            Task {
                await loadPage(at: nextIndex)
            }
        }
    }

    func goToPreviousPage() {
        let prevIndex: Int = switch readingDirection {
        case .rightToLeft:
            currentPageIndex - 1
        case .leftToRight:
            currentPageIndex - 1
        case .vertical:
            currentPageIndex - 1
        }

        if prevIndex >= 0 {
            currentPageIndex = prevIndex
            Task {
                await loadPage(at: prevIndex)
            }
        }
    }

    func goToPage(_ index: Int) {
        guard index >= 0, index < pageCount else { return }
        currentPageIndex = index
        Task {
            await loadPage(at: index)
        }
    }

    // MARK: - Zoom/Pan

    func resetZoom() {
        withAnimation(.easeOut(duration: 0.25)) {
            scale = 1.0
            lastScale = 1.0
            offset = .zero
            lastOffset = .zero
        }
    }

    // MARK: - Spread Layout

    /// Updates the orientation and recomputes spread layout if needed.
    func updateOrientation(_ landscape: Bool) {
        guard isLandscape != landscape else { return }
        isLandscape = landscape
        recomputeSpreadLayout()
    }

    /// Recomputes the spread layout based on current settings.
    private func recomputeSpreadLayout() {
        spreadLayout = SpreadLayout.compute(
            pageCount: pageCount,
            spreadMode: isSpreadModeActive,
            readingDirection: readingDirection
        )
        scheduleRenderedPageRefresh()
    }

    // MARK: - Toolbar

    func toggleToolbars() {
        withAnimation(.easeInOut(duration: 0.2)) {
            overlayState = overlayState == .showingToolbars ? .none : .showingToolbars
        }
    }

    // MARK: - OCR / Dictionary Integration

    /// Handles a tap on a text cluster, showing highlight and opening dictionary
    func handleClusterTap(_ cluster: TextCluster, pageIndex: Int) {
        Task {
            // Set highlighted cluster for visual feedback
            highlightedCluster = cluster

            // Brief delay for highlight animation
            try? await Task.sleep(nanoseconds: 100_000_000)

            // Perform dictionary lookup
            await performDictionaryLookup(text: cluster.transcript, pageIndex: pageIndex)

            // Clear highlight after sheet opens
            highlightedCluster = nil
        }
    }

    private func performDictionaryLookup(text: String, pageIndex: Int) async {
        pendingSearchText = text
        pendingContextValues = await lookupContextValues(for: pageIndex)
        showingDictionarySheet = true
    }

    /// Clears pending search data after the dictionary sheet has initialized
    func clearPendingSearch() {
        pendingSearchText = nil
        pendingContextValues = nil
    }

    /// Triggers a dictionary lookup for the preferred OCR cluster on the current page.
    /// Used in screenshot mode to programmatically stage dictionary results.
    func triggerScreenshotClusterLookup() {
        guard let renderedPage = renderedPageCache[currentPageIndex],
              let clusterIndex = Self.screenshotLookupClusterIndex(
                  in: renderedPage.textClusters.map(\.transcript)
              )
        else { return }
        handleClusterTap(renderedPage.textClusters[clusterIndex], pageIndex: currentPageIndex)
    }

    nonisolated static func screenshotLookupClusterIndex(
        in transcripts: [String],
        preferredPrefix: String = screenshotLookupPreferredPrefix
    ) -> Int? {
        if let preferredIndex = transcripts.firstIndex(where: { $0.hasPrefix(preferredPrefix) }) {
            return preferredIndex
        }
        return transcripts.isEmpty ? nil : 0
    }

    private func lookupContextValues(for pageIndex: Int) async -> LookupContextValues {
        let screenshotURL = await makeScreenshotURL(for: pageIndex)
        let coverImageURL = await makeCoverContextImageURL()
        return LookupContextValues(
            contextInfo: MangaLocalization.readerContextInfo(title: manga.title, pageNumber: pageIndex + 1),
            documentCoverImageURL: coverImageURL,
            screenshotURL: screenshotURL,
            sourceType: .manga
        )
    }

    private func makeScreenshotURL(for pageIndex: Int) async -> URL? {
        guard let pageData = await rawPageData(at: pageIndex) else { return nil }
        return await writeJPEGContextImage(pageData.imageData, prefix: "manga_page")
    }

    func rawPageData(at index: Int) async -> MangaPageData? {
        guard let pageProvider, index >= 0, index < pageCount else { return nil }
        return try? await pageProvider.pageData(at: index)
    }

    private func makeCoverContextImageURL() async -> URL? {
        guard let coverURL = manga.coverImage else { return nil }
        return await writeJPEGContextImage(from: coverURL, prefix: "manga_cover")
    }

    private func writeJPEGContextImage(_ data: Data, prefix: String) async -> URL? {
        await Task.detached {
            guard let jpegData = ContextImageEncoder.jpegData(from: data, quality: 0.9) else {
                return nil
            }
            return Self.writeContextJPEGData(jpegData, prefix: prefix)
        }.value
    }

    private func writeJPEGContextImage(from sourceURL: URL, prefix: String) async -> URL? {
        await Task.detached {
            guard let data = try? Data(contentsOf: sourceURL),
                  let jpegData = ContextImageEncoder.jpegData(from: data, quality: 0.9)
            else {
                return nil
            }
            return Self.writeContextJPEGData(jpegData, prefix: prefix)
        }.value
    }

    private nonisolated static func writeContextJPEGData(_ data: Data, prefix: String) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MaruContextMedia", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let filename = "\(prefix)_\(UUID().uuidString).jpg"
            let fileURL = directory.appendingPathComponent(filename)
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        // Load last read page
        let savedPage = Int(manga.lastReadPage)
        currentPageIndex = savedPage
        lastSavedPageIndex = savedPage // Prevent initial save trigger

        // Load reading direction
        if let directionRaw = manga.readingDirection,
           let directionInt = Int(directionRaw),
           let direction = MangaReadingDirection(rawValue: directionInt)
        {
            readingDirection = direction
        }

        // Load force single page preference
        forceSinglePage = manga.forceSinglePage
    }

    private func debounceSaveProgress() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: Self.saveDebounceInterval)
            guard !Task.isCancelled else { return }
            await saveReadingProgress()
        }
    }

    private func saveReadingProgress() async {
        let pageIndex = currentPageIndex

        // Only save if page actually changed from last save
        guard lastSavedPageIndex != pageIndex else { return }

        logger.debug("Saving reading progress: page \(pageIndex)")
        lastSavedPageIndex = pageIndex

        let mangaID = manga.objectID
        let context = persistenceController.newBackgroundContext()
        await context.perform {
            guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                return
            }
            manga.lastReadPage = Int64(pageIndex)
            manga.lastReadDate = Date()
            try? context.save()
        }
    }

    private func saveReadingDirection() {
        let mangaID = manga.objectID
        let direction = readingDirection.rawValue

        let context = persistenceController.newBackgroundContext()
        context.perform {
            guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                return
            }
            manga.readingDirection = String(direction)
            try? context.save()
        }
    }

    private func saveForceSinglePage() {
        let mangaID = manga.objectID
        let value = forceSinglePage

        let context = persistenceController.newBackgroundContext()
        context.perform {
            guard let manga = try? context.existingObject(with: mangaID) as? MangaArchive else {
                return
            }
            manga.forceSinglePage = value
            try? context.save()
        }
    }

    /// Save progress when view is about to disappear
    func saveOnDisappear() {
        saveTask?.cancel()
        Task {
            await saveReadingProgress()
        }
    }

    func waitForPendingPageLoads() async {
        await renderedPageRefreshTask?.value
        for task in Array(pageLoadTasks.values) {
            _ = await task.result
        }
    }

    private func scheduleRenderedPageRefresh() {
        guard pageProvider != nil, pageCount > 0 else { return }

        renderedPageRefreshTask?.cancel()
        renderedPageRefreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshRenderedPageWorkingSet()
        }
    }

    private func refreshRenderedPageWorkingSet() async {
        let desiredIndices = desiredRenderedPageIndices()
        evictRenderedPages(except: desiredIndices)

        for index in desiredIndices.sorted() {
            guard !Task.isCancelled else { return }
            await loadPage(at: index)
        }

        evictRenderedPages(except: desiredIndices)
    }

    private func desiredRenderedPageIndices() -> Set<Int> {
        guard pageCount > 0 else { return [] }

        if isSpreadModeActive, spreadLayout.count > 0 {
            let currentIndex = max(0, min(currentSpreadIndex, spreadLayout.count - 1))
            let lowerBound = max(0, currentIndex - Self.spreadWorkingSetRadius)
            let upperBound = min(spreadLayout.count - 1, currentIndex + Self.spreadWorkingSetRadius)

            var indices: Set<Int> = []
            for spreadIndex in lowerBound ... upperBound {
                indices.formUnion(spreadLayout.pages(atSpreadIndex: spreadIndex))
            }
            return indices
        }

        let lowerBound = max(0, currentPageIndex - Self.singlePageWorkingSetRadius)
        let upperBound = min(pageCount - 1, currentPageIndex + Self.singlePageWorkingSetRadius)
        return Set(lowerBound ... upperBound)
    }

    private func evictRenderedPages(except desiredIndices: Set<Int>) {
        for index in Array(renderedPageCache.keys) where !desiredIndices.contains(index) {
            renderedPageCache.removeValue(forKey: index)
        }

        for (index, state) in Array(pageLoadingStates) where state == .loaded && !desiredIndices.contains(index) {
            pageLoadingStates.removeValue(forKey: index)
        }
    }
}
