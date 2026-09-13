// MangaReaderViewModelTests.swift
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
@testable import MaruManga
import MaruVision
import Testing
import UIKit

struct MangaReaderViewModelTests {
    @Test func screenshotLookupClusterIndex_PrefersProfessorExperimentPrefix() {
        let transcripts = [
            "ドドドドド",
            "教授の実験を\n見ていたんだ",
            "別の吹き出し",
        ]

        let selectedIndex = MangaReaderViewModel.screenshotLookupClusterIndex(in: transcripts)

        #expect(selectedIndex == 1)
    }

    @Test func screenshotLookupClusterIndex_FallsBackToFirstCluster() {
        let transcripts = [
            "ドドドドド",
            "別の吹き出し",
        ]

        let selectedIndex = MangaReaderViewModel.screenshotLookupClusterIndex(in: transcripts)

        #expect(selectedIndex == 0)
    }

    @Test func loadArchive_LoadsCurrentPageWorkingSet() async throws {
        let (viewModel, provider) = try await makeViewModel(pageCount: 5)

        await viewModel.loadArchive()
        await viewModel.waitForPendingPageLoads()

        let cachedPages = await MainActor.run { Set(viewModel.renderedPageCache.keys) }
        #expect(cachedPages == [0, 1])
        #expect(await provider.requestCount(for: 0) == 1)
        #expect(await provider.requestCount(for: 1) == 1)
        #expect(await provider.requestCount(for: 2) == 0)
    }

    @Test func updateOrientation_UsesSpreadWorkingSet() async throws {
        let (viewModel, _) = try await makeViewModel(pageCount: 6)

        await viewModel.loadArchive()
        await MainActor.run {
            viewModel.updateOrientation(true)
        }
        await viewModel.waitForPendingPageLoads()

        let cachedPages = await MainActor.run { Set(viewModel.renderedPageCache.keys) }
        #expect(cachedPages == [0, 1, 2])
    }

    @Test func updateOrientation_PreservesCurrentPageContextInSpreadMode() async throws {
        let (viewModel, _) = try await makeViewModel(pageCount: 8)

        await viewModel.loadArchive()
        await MainActor.run {
            viewModel.currentPageIndex = 4
            viewModel.updateOrientation(true)
        }
        await viewModel.waitForPendingPageLoads()

        let currentPageIndex = await MainActor.run { viewModel.currentPageIndex }
        let spreadPages = await MainActor.run {
            viewModel.spreadLayout.pages(atSpreadIndex: viewModel.currentSpreadIndex)
        }

        #expect(currentPageIndex == 4)
        #expect(spreadPages == [4, 3])
    }

    @Test func readingDirectionChange_PreservesCurrentPageContextInLandscape() async throws {
        let (viewModel, _) = try await makeViewModel(pageCount: 8)

        await viewModel.loadArchive()
        await MainActor.run {
            viewModel.currentPageIndex = 4
            viewModel.updateOrientation(true)
            viewModel.readingDirection = .leftToRight
        }
        await viewModel.waitForPendingPageLoads()

        let currentPageIndex = await MainActor.run { viewModel.currentPageIndex }
        let spreadPages = await MainActor.run {
            viewModel.spreadLayout.pages(atSpreadIndex: viewModel.currentSpreadIndex)
        }

        #expect(currentPageIndex == 4)
        #expect(spreadPages == [3, 4])
    }

    @Test func currentPageChange_EvictsPagesOutsideWorkingSet() async throws {
        let (viewModel, _) = try await makeViewModel(pageCount: 5)

        await viewModel.loadArchive()
        await MainActor.run {
            viewModel.currentPageIndex = 3
        }
        await viewModel.waitForPendingPageLoads()

        let cachedPages = await MainActor.run { Set(viewModel.renderedPageCache.keys) }
        let loadingStates = await MainActor.run { viewModel.pageLoadingStates }
        #expect(cachedPages == [2, 3, 4])
        #expect(loadingStates[0] == nil)
        #expect(loadingStates[1] == nil)
    }

    @Test func evictedPage_IsReloadedWhenNeededAgain() async throws {
        let (viewModel, provider) = try await makeViewModel(pageCount: 5)

        await viewModel.loadArchive()
        await MainActor.run {
            viewModel.currentPageIndex = 3
        }
        await viewModel.waitForPendingPageLoads()

        await MainActor.run {
            viewModel.currentPageIndex = 0
        }
        await viewModel.waitForPendingPageLoads()

        let cachedPages = await MainActor.run { Set(viewModel.renderedPageCache.keys) }
        #expect(cachedPages == [0, 1])
        #expect(await provider.requestCount(for: 0) == 2)
    }

    @Test func concurrentLoadPage_DeduplicatesProviderFetch() async throws {
        let (viewModel, provider) = try await makeViewModel(pageCount: 5, requestDelayNanoseconds: 100_000_000)

        await viewModel.loadArchive()

        let firstLoad = Task {
            await viewModel.loadPage(at: 4)
        }
        let secondLoad = Task {
            await viewModel.loadPage(at: 4)
        }

        await firstLoad.value
        await secondLoad.value

        #expect(await provider.requestCount(for: 4) == 1)
    }

    @Test func rawPageData_CanBeFetchedAfterRenderEviction() async throws {
        let (viewModel, provider) = try await makeViewModel(pageCount: 5)

        await viewModel.loadArchive()
        await MainActor.run {
            viewModel.currentPageIndex = 3
        }
        await viewModel.waitForPendingPageLoads()

        let pageData = await viewModel.rawPageData(at: 0)

        #expect(pageData != nil)
        #expect(await provider.requestCount(for: 0) == 2)
    }

    @Test func loadPage_mokuroMatchFound_usesMokuroClustersInsteadOfVision() async throws {
        let mokuroJSON = """
        {"pages": [{"img_width": 40, "img_height": 60, "blocks": [
            {"box": [0, 0, 40, 20], "vertical": false, "font_size": 20, "lines_coords": [[[0, 0], [40, 0], [40, 20], [0, 20]]], "lines": ["テスト"]}
        ], "img_path": "page-0.jpg"}]}
        """
        let (viewModel, _) = try await makeViewModel(
            pageCount: 1,
            pageFileNames: [0: "page-0.jpg"],
            mokuroJSON: mokuroJSON
        )

        await viewModel.loadArchive()
        await viewModel.waitForPendingPageLoads()

        let clusters = await MainActor.run { viewModel.renderedPageCache[0]?.textClusters }
        let transcripts = clusters?.map(\.transcript) ?? []

        #expect(transcripts.contains("テスト"), "Expected mokuro-sourced text; a blank test image could never produce this via real Vision OCR")
    }

    /// Equal page counts must NOT be taken as permission to pair by position.
    /// Mokuro orders its pages alphabetically by `img_path`, which need not be the
    /// archive's reading order, so a same-length volume can still be misaligned —
    /// a real 166-page pairing was off by one. Positional pairing was removed;
    /// this pins that it stays removed.
    @Test func loadPage_filenamesUnmatchedButPageCountsEqual_stillFallsBackToVision() async throws {
        // The mokuro run came from a differently-named extraction of the same
        // volume, so no filename matches at all.
        let mokuroJSON = """
        {"pages": [{"img_width": 40, "img_height": 60, "blocks": [
            {"box": [0, 0, 40, 20], "vertical": false, "font_size": 20, "lines_coords": [[[0, 0], [40, 0], [40, 20], [0, 20]]], "lines": ["テスト"]}
        ], "img_path": "i-001.jpg"}]}
        """
        let (viewModel, _) = try await makeViewModel(
            pageCount: 1,
            pageFileNames: [0: "001.jpg"],
            mokuroJSON: mokuroJSON
        )

        await viewModel.loadArchive()
        await viewModel.waitForPendingPageLoads()

        let clusters = await MainActor.run { viewModel.renderedPageCache[0]?.textClusters }
        let transcripts = clusters?.map(\.transcript) ?? []

        #expect(
            !transcripts.contains("テスト"),
            "Matching page counts must not be treated as a positional pairing"
        )
    }

    @Test func loadPage_filenamesUnmatchedAndPageCountsDiffer_fallsBackToVision() async throws {
        // One mokuro page against a two-page archive: nothing pairs by name, so
        // every page uses Vision rather than showing confident, wrong text.
        let mokuroJSON = """
        {"pages": [{"img_width": 40, "img_height": 60, "blocks": [
            {"box": [0, 0, 40, 20], "vertical": false, "font_size": 20, "lines_coords": [[[0, 0], [40, 0], [40, 20], [0, 20]]], "lines": ["テスト"]}
        ], "img_path": "i-001.jpg"}]}
        """
        let (viewModel, _) = try await makeViewModel(
            pageCount: 2,
            pageFileNames: [0: "001.jpg", 1: "002.jpg"],
            mokuroJSON: mokuroJSON
        )

        await viewModel.loadArchive()
        await viewModel.waitForPendingPageLoads()

        let clusters = await MainActor.run { viewModel.renderedPageCache[0]?.textClusters }
        let transcripts = clusters?.map(\.transcript) ?? []

        #expect(!transcripts.contains("テスト"), "Nothing pairs by filename, so this page must use Vision")
    }

    @Test func loadPage_noMokuroAttached_behavesAsBefore() async throws {
        let (viewModel, _) = try await makeViewModel(pageCount: 1, pageFileNames: [0: "page-0.jpg"])

        await viewModel.loadArchive()
        await viewModel.waitForPendingPageLoads()

        let renderedPage = await MainActor.run { viewModel.renderedPageCache[0] }
        #expect(renderedPage != nil)
    }
}

private extension MangaReaderViewModelTests {
    @MainActor
    func makeViewModel(
        pageCount: Int,
        requestDelayNanoseconds: UInt64 = 0,
        pageFileNames: [Int: String] = [:],
        mokuroJSON: String? = nil
    ) throws -> (MangaReaderViewModel, FakeMangaPageProvider) {
        let persistenceController = makeMangaPersistenceController()
        let context = persistenceController.container.viewContext

        let manga = MangaArchive(context: context)
        manga.id = UUID()
        manga.title = "Test Manga"
        manga.localFileName = "test.cbz"
        manga.importComplete = true
        manga.dateAdded = Date()

        if let mokuroJSON {
            let mangaDir = try #require(MangaArchive.mangaDirectory())
            try FileManager.default.createDirectory(at: mangaDir, withIntermediateDirectories: true)
            let mokuroFileName = "\(manga.id!.uuidString).mokuro"
            try mokuroJSON.write(
                to: mangaDir.appendingPathComponent(mokuroFileName),
                atomically: true,
                encoding: .utf8
            )
            manga.mokuroFileName = mokuroFileName
        }

        try context.save()

        let provider = FakeMangaPageProvider(
            pages: Dictionary(uniqueKeysWithValues: (0 ..< pageCount).map { index in
                (index, MangaPageData(
                    imageData: makeJPEGData(pageNumber: index),
                    imageFileName: pageFileNames[index]
                ))
            }),
            requestDelayNanoseconds: requestDelayNanoseconds
        )

        let viewModel = MangaReaderViewModel(
            manga: manga,
            persistenceController: persistenceController,
            archiveReaderFactory: { _ in provider }
        )

        return (viewModel, provider)
    }

    func makeJPEGData(pageNumber: Int) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 60))
        let image = renderer.image { context in
            UIColor(white: 0.2 + (CGFloat(pageNumber) * 0.1), alpha: 1.0).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else {
            Issue.record("Failed to create JPEG data for test page \(pageNumber)")
            return Data()
        }
        return data
    }
}

private actor FakeMangaPageProvider: MangaPageProviding {
    private let pages: [Int: MangaPageData]
    private let requestDelayNanoseconds: UInt64
    private var requestCounts: [Int: Int] = [:]

    init(pages: [Int: MangaPageData], requestDelayNanoseconds: UInt64) {
        self.pages = pages
        self.requestDelayNanoseconds = requestDelayNanoseconds
    }

    var pageCount: Int {
        pages.count
    }

    var pageFileNames: [String] {
        pages.keys.sorted().compactMap { pages[$0]?.imageFileName }
    }

    func pageData(at index: Int) async throws -> MangaPageData {
        requestCounts[index, default: 0] += 1

        if requestDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: requestDelayNanoseconds)
        }

        guard let page = pages[index] else {
            throw NSError(domain: "FakeMangaPageProvider", code: index)
        }

        return page
    }

    func requestCount(for index: Int) -> Int {
        requestCounts[index, default: 0]
    }
}
