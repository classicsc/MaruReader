// MangaReaderViewModel.swift
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
import MaruDictionaryUICommon
import MaruReaderCore
import MaruVision
import Observation
import os.log
import SwiftUI

@MainActor
@Observable
final class MangaReaderViewModel {
    // MARK: - Configuration

    private static let saveDebounceInterval: UInt64 = 500_000_000 // 0.5 seconds

    // MARK: - Navigation State

    /// The current page index (0-based)
    var currentPageIndex: Int = 0 {
        didSet {
            if currentPageIndex != oldValue {
                resetZoom()
                debounceSaveProgress()
            }
        }
    }

    /// Total page count from the archive reader
    private(set) var pageCount: Int = 0

    // MARK: - Page Data

    /// Cached page data for loaded pages
    private(set) var pageDataCache: [Int: MangaPageData] = [:]

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

    /// View model for the dictionary search sheet
    var dictionarySearchViewModel: DictionarySearchViewModel?

    // MARK: - Private State

    let manga: MangaArchive
    private(set) var archiveReader: MangaArchiveReader?
    private let persistenceController: MangaDataPersistenceController
    private let searchService: DictionarySearchService

    private var saveTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "net.undefinedstar.MaruManga", category: "MangaReaderViewModel")

    // MARK: - Initialization

    init(
        manga: MangaArchive,
        persistenceController: MangaDataPersistenceController = .shared
    ) {
        self.manga = manga
        self.persistenceController = persistenceController
        self.searchService = DictionarySearchService()

        // Load persisted state
        loadPersistedState()
    }

    // MARK: - Lifecycle

    /// Loads the archive reader asynchronously. Call this when the view appears.
    func loadArchive() async {
        guard archiveReader == nil else { return }

        guard let localPath = manga.localPath else {
            logger.error("Manga has no local path")
            return
        }

        do {
            let reader = try await MangaArchiveReader(url: localPath)
            archiveReader = reader
            pageCount = await reader.pageCount
            logger.info("Loaded archive with \(self.pageCount) pages")

            // Compute initial spread layout now that we know page count
            recomputeSpreadLayout()

            // Start loading current page
            await loadPage(at: currentPageIndex)
        } catch {
            logger.error("Failed to load archive: \(error.localizedDescription)")
        }
    }

    /// Loads a specific page's data
    func loadPage(at index: Int) async {
        guard let reader = archiveReader else { return }
        guard index >= 0, index < pageCount else { return }

        // Skip if already loaded or loading
        if pageDataCache[index] != nil { return }
        if pageLoadingStates[index] == .loading { return }

        pageLoadingStates[index] = .loading

        do {
            let pageData = try await reader.pageData(at: index)
            pageDataCache[index] = pageData
            pageLoadingStates[index] = .loaded
        } catch {
            logger.error("Failed to load page \(index): \(error.localizedDescription)")
            pageLoadingStates[index] = .error(error.localizedDescription)
        }
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
    }

    // MARK: - Toolbar

    func toggleToolbars() {
        withAnimation(.easeInOut(duration: 0.2)) {
            overlayState = overlayState == .showingToolbars ? .none : .showingToolbars
        }
    }

    // MARK: - OCR / Dictionary Integration

    /// Handles a tap on a text cluster, showing highlight and opening dictionary
    func handleClusterTap(_ cluster: TextCluster) {
        Task {
            // Set highlighted cluster for visual feedback
            highlightedCluster = cluster

            // Brief delay for highlight animation
            try? await Task.sleep(nanoseconds: 250_000_000)

            // Perform dictionary lookup
            await performDictionaryLookup(text: cluster.transcript)

            // Clear highlight after sheet opens
            highlightedCluster = nil
        }
    }

    private func performDictionaryLookup(text: String) async {
        let request = TextLookupRequest(context: text)

        do {
            if let response = try await searchService.performTextLookup(query: request) {
                dictionarySearchViewModel = DictionarySearchViewModel(response: response)
                showingDictionarySheet = true
            } else {
                // No results - still show the sheet with a search
                dictionarySearchViewModel = DictionarySearchViewModel(resultState: .noResults(text))
                showingDictionarySheet = true
            }
        } catch {
            logger.error("Dictionary lookup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        // Load last read page
        currentPageIndex = Int(manga.lastReadPage)

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
        let mangaID = manga.objectID
        let pageIndex = currentPageIndex

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
}
