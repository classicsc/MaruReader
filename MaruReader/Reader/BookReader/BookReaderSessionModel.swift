// BookReaderSessionModel.swift
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
import Observation
import os
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import UIKit

@MainActor
@Observable
final class BookReaderSessionModel {
    var phase: BookReaderPhase = .loading
    var publication: Publication?
    var initialLocation: Locator?
    var currentLocator: Locator?

    private(set) var bookSnapshot: BookReaderBookSnapshot
    private(set) var coverImage: UIImage?
    private(set) var chapterTitleByHref: [String: String] = [:]

    @ObservationIgnored
    weak var navigator: EPUBNavigatorViewController?

    private let bookID: NSManagedObjectID
    private let repository: BookReaderRepository
    @ObservationIgnored private var cachedCoverImage: UIImage?
    @ObservationIgnored private var hasLoadedCoverImage = false
    @ObservationIgnored private var hasStarted = false
    private let logger = Logger.maru(category: "BookReaderSessionModel")

    init(
        bookID: NSManagedObjectID,
        repository: BookReaderRepository,
        loadPublicationOnInit: Bool = true
    ) {
        self.bookID = bookID
        self.repository = repository

        do {
            bookSnapshot = try repository.loadBookSnapshot(bookID: bookID)
        } catch {
            bookSnapshot = .missing(id: bookID)
            phase = .error(error)
        }

        if loadPublicationOnInit, case .loading = phase {
            Task {
                await startIfNeeded()
            }
        }
    }

    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true

        async let coverLoad: UIImage? = loadCoverImageIfNeeded()

        if case .loading = phase {
            await loadPublication()
        }

        _ = await coverLoad
    }

    func attachNavigator(_ navigator: EPUBNavigatorViewController) {
        self.navigator = navigator
        currentLocator = navigator.currentLocation ?? initialLocation
    }

    func handleLocationDidChange(_ locator: Locator) {
        currentLocator = locator

        do {
            try repository.saveReadingProgress(
                bookID: bookID,
                locatorJSON: locator.jsonString,
                progressPercent: formatProgress(locator.locations.totalProgression)
            )
        } catch {
            logger.error("Error saving last read location: \(error.localizedDescription)")
        }
    }

    @discardableResult
    func loadCoverImageIfNeeded() async -> UIImage? {
        if hasLoadedCoverImage {
            return cachedCoverImage
        }

        guard let url = bookCoverURL else { return nil }
        hasLoadedCoverImage = true

        let image = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value

        cachedCoverImage = image
        coverImage = image
        return image
    }

    func loadPublication() async {
        do {
            guard let fileName = bookSnapshot.fileName else {
                throw BookReaderError.bookFileNotFound
            }

            guard let appSupportDir = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            ) else {
                throw BookReaderError.cannotAccessAppSupport
            }

            let bookURL = appSupportDir
                .appendingPathComponent("Books")
                .appendingPathComponent(fileName)

            guard let fileURL = FileURL(url: bookURL) else {
                throw BookReaderError.invalidBookPath
            }

            let assetRetriever = AssetRetriever(httpClient: DefaultHTTPClient())
            let assetResult = await assetRetriever.retrieve(url: fileURL)
            guard case let .success(asset) = assetResult else {
                if case let .failure(error) = assetResult {
                    phase = .error(error)
                } else {
                    phase = .error(BookReaderError.unknownError)
                }
                return
            }

            let publicationOpener = PublicationOpener(
                parser: DefaultPublicationParser(
                    httpClient: DefaultHTTPClient(),
                    assetRetriever: assetRetriever,
                    pdfFactory: DefaultPDFDocumentFactory()
                )
            )
            let publicationResult = await publicationOpener.open(asset: asset, allowUserInteraction: false)
            guard case let .success(publication) = publicationResult else {
                if case let .failure(error) = publicationResult {
                    phase = .error(error)
                } else {
                    phase = .error(BookReaderError.unknownError)
                }
                return
            }

            self.publication = publication
            chapterTitleByHref = Self.makeChapterTitleIndex(for: publication)

            if let lastPageJSON = bookSnapshot.lastOpenedPage {
                initialLocation = try? Locator(jsonString: lastPageJSON)
            }

            logger.info("Successfully loaded publication for book \(self.bookSnapshot.title ?? "Unknown")")
            phase = .reading
        } catch {
            logger.error("Failed to load publication for book \(self.bookSnapshot.title ?? "Unknown"): \(error.localizedDescription)")
            phase = .error(error)
        }
    }

    func navigateToLink(_ link: ReadiumShared.Link, onSuccess: @escaping @MainActor () -> Void = {}) {
        guard let publication, let navigator else {
            logger.warning("Cannot navigate: publication or navigator not ready")
            return
        }

        Task {
            if let locator = await publication.locate(link) {
                _ = await navigator.go(to: locator, options: NavigatorGoOptions(animated: true))
                await MainActor.run {
                    onSuccess()
                }
            } else {
                logger.warning("Could not locate link: \(link.href)")
            }
        }
    }

    func navigateToPosition(_ position: Int, onSuccess: @escaping @MainActor () -> Void = {}) {
        guard position > 0 else {
            logger.warning("Cannot navigate: invalid position \(position)")
            return
        }
        guard let publication, let navigator else {
            logger.warning("Cannot navigate: publication or navigator not ready")
            return
        }

        Task {
            let positions = await publication.positions().getOrNil() ?? []
            guard !positions.isEmpty else {
                self.logger.warning("Cannot navigate: positions list unavailable")
                return
            }

            let locator = positions.first(where: { $0.locations.position == position })
                ?? positions.getOrNil(position - 1)

            guard let locator else {
                self.logger.warning("Cannot navigate: position \(position) out of range")
                return
            }

            _ = await navigator.go(to: locator, options: NavigatorGoOptions(animated: true))
            await MainActor.run {
                onSuccess()
            }
        }
    }

    func navigate(to locator: Locator, onSuccess: @escaping @MainActor () -> Void = {}) {
        guard let navigator else {
            logger.warning("Cannot navigate: navigator not ready")
            return
        }

        Task {
            _ = await navigator.go(to: locator, options: NavigatorGoOptions(animated: true))
            await MainActor.run {
                onSuccess()
            }
        }
    }

    func goLeft() {
        guard let navigator else { return }
        Task {
            await navigator.goLeft(options: .init())
        }
    }

    func goRight() {
        guard let navigator else { return }
        Task {
            await navigator.goRight(options: .init())
        }
    }

    func isVerticalWriting() -> Bool {
        navigator?.settings.verticalText ?? false
    }

    func readingProgression() -> ReadiumNavigator.ReadingProgression {
        navigator?.settings.readingProgression ?? .ltr
    }

    func makeLookupContextValues() async -> LookupContextValues {
        let coverImageURL = await makeCoverContextImageURL()
        return LookupContextValues(
            contextInfo: makeBookContextInfo(),
            documentCoverImageURL: coverImageURL,
            screenshotURL: nil,
            sourceType: .book
        )
    }

    static func makeChapterTitleIndex(for publication: Publication) -> [String: String] {
        let rootLinks = publication.manifest.tableOfContents.isEmpty
            ? publication.readingOrder
            : publication.manifest.tableOfContents
        return makeChapterTitleIndex(from: rootLinks)
    }

    static func makeChapterTitleIndex(from links: [ReadiumShared.Link]) -> [String: String] {
        var index: [String: String] = [:]
        collectChapterTitles(from: links, into: &index)
        return index
    }

    private var bookCoverURL: URL? {
        guard let coverFileName = bookSnapshot.coverFileName else { return nil }

        guard let appSupportDir = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return nil
        }

        return appSupportDir
            .appendingPathComponent("Covers")
            .appendingPathComponent(coverFileName)
    }

    private func makeCoverContextImageURL() async -> URL? {
        guard let coverURL = bookCoverURL else { return nil }
        return await writeJPEGContextImage(from: coverURL, prefix: "book_cover")
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

    private func makeBookContextInfo() -> String {
        let title = bookSnapshot.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = if let title, !title.isEmpty {
            title
        } else {
            String(localized: "Book")
        }

        if let locator = currentLocator {
            if let position = locator.locations.position {
                return AppLocalization.bookContextPosition(title: displayTitle, position: position)
            }
            if let totalProgression = locator.locations.totalProgression {
                let percent = Int(totalProgression * 100)
                return AppLocalization.bookContextPercent(title: displayTitle, percent: percent)
            }
        }

        return displayTitle
    }

    private func formatProgress(_ value: Double?) -> String? {
        guard let value else { return nil }
        let clampedValue = min(max(value, 0), 1)
        return clampedValue.formatted(.percent.precision(.fractionLength(0)))
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

    private static func collectChapterTitles(from links: [ReadiumShared.Link], into index: inout [String: String]) {
        for link in links {
            if let title = link.title, !title.isEmpty {
                index[link.href] = title
            }
            collectChapterTitles(from: link.children, into: &index)
        }
    }
}
