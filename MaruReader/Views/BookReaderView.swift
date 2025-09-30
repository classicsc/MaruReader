//
//  BookReaderView.swift
//  MaruReader
//
//  Ebook reading view with Readium Navigator integration.
//

import CoreData
import Foundation
import ReadiumAdapterGCDWebServer
import ReadiumNavigator
@unsafe @preconcurrency import ReadiumShared
import ReadiumStreamer
import SwiftUI
import UIKit

// MARK: - Supporting Types

struct LoadedPublication {
    let publication: Publication
    let initialLocation: Locator?
}

enum BookReaderError: LocalizedError {
    case bookFileNotFound
    case cannotAccessAppSupport
    case invalidBookPath
    case unknownError

    var errorDescription: String? {
        switch self {
        case .bookFileNotFound:
            "Book file not found"
        case .cannotAccessAppSupport:
            "Cannot access application support directory"
        case .invalidBookPath:
            "Invalid book file path"
        case .unknownError:
            "An unknown error occurred"
        }
    }
}

// MARK: - BookReaderView

struct BookReaderView: View {
    @Environment(\.managedObjectContext) var viewContext
    @Environment(\.dismiss) var dismiss

    @ObservedObject var book: Book

    @State private var showingTableOfContents = false
    @State private var showingSettings = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var loadedPublication: LoadedPublication?
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Navigation content area
            if isLoading {
                ProgressView("Loading book...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let loadedPublication {
                EPUBNavigatorWrapper(
                    book: book,
                    viewContext: viewContext,
                    loadedPublication: loadedPublication
                )
                .ignoresSafeArea()

                // Bottom toolbar
                bottomToolbar
                    .background(.ultraThinMaterial)
            } else if let error {
                errorView(error: error)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(book.title ?? "")
        .task {
            await loadPublication()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Failed to load book")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadPublication() async {
        do {
            guard let fileName = book.fileName else {
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
                    self.error = error
                    showingError = true
                    return
                } else {
                    self.error = BookReaderError.unknownError
                    showingError = true
                    return
                }
            }

            let publicationOpener = PublicationOpener(
                parser: DefaultPublicationParser(httpClient: DefaultHTTPClient(), assetRetriever: assetRetriever, pdfFactory: DefaultPDFDocumentFactory())
            )

            let publicationResult = await publicationOpener.open(asset: asset, allowUserInteraction: false)

            guard case let .success(publication) = publicationResult else {
                if case let .failure(error) = publicationResult {
                    self.error = error
                    showingError = true
                    return
                } else {
                    self.error = BookReaderError.unknownError
                    showingError = true
                    return
                }
            }

            // Get the last read location if available
            var initialLocation: Locator?
            if let lastPageJSON = book.lastOpenedPage {
                initialLocation = try? Locator(jsonString: lastPageJSON)
            }

            await MainActor.run {
                loadedPublication = LoadedPublication(
                    publication: publication,
                    initialLocation: initialLocation
                )
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                isLoading = false
            }
        }
    }

    private var bottomToolbar: some View {
        HStack(spacing: 32) {
            Button {
                showingTableOfContents = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                    Text("Contents")
                        .font(.caption2)
                }
            }

            Button {
                bookmarkCurrentLocation()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "bookmark")
                    Text("Bookmark")
                        .font(.caption2)
                }
            }

            Button {
                showingSettings = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "textformat.size")
                    Text("Settings")
                        .font(.caption2)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private func bookmarkCurrentLocation() {
        // Stub: will be implemented later
        print("Bookmark button tapped")
    }
}

// MARK: - EPUBNavigatorWrapper

struct EPUBNavigatorWrapper: UIViewControllerRepresentable {
    @ObservedObject var book: Book
    let viewContext: NSManagedObjectContext
    let loadedPublication: LoadedPublication

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            // Create the EPUB navigator with pre-loaded publication
            let navigator = try EPUBNavigatorViewController(
                publication: loadedPublication.publication,
                initialLocation: loadedPublication.initialLocation,
                httpServer: GCDHTTPServer(assetRetriever: AssetRetriever(httpClient: DefaultHTTPClient()))
            )

            navigator.delegate = context.coordinator

            // Store navigator reference in coordinator
            context.coordinator.navigator = navigator

            return navigator
        } catch {
            print("Error creating navigator: \(error)")
            return createErrorViewController(message: "Failed to create navigator: \(error.localizedDescription)")
        }
    }

    func updateUIViewController(_: UIViewController, context _: Context) {
        // No updates needed
    }

    func makeCoordinator() -> BookReaderCoordinator {
        BookReaderCoordinator(parent: BookReaderView(book: book), viewContext: viewContext)
    }

    private func createErrorViewController(message: String) -> UIViewController {
        let vc = UIViewController()
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20),
        ])
        return vc
    }
}
