//
//  EPUBNavigatorWrapper.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/30/25.
//

import CoreData
import Foundation
import ReadiumAdapterGCDWebServer
import ReadiumNavigator
@unsafe @preconcurrency import ReadiumShared
import ReadiumStreamer
import SwiftUI
import UIKit

struct EPUBNavigatorWrapper: UIViewControllerRepresentable {
    @ObservedObject var book: Book
    let viewContext: NSManagedObjectContext
    let loadedPublication: LoadedPublication
    @Binding var dictionaryLookupQuery: DictionaryLookupRequest?

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            // Create and configure HTTP server with dictionary handlers
            let httpServer = GCDHTTPServer(assetRetriever: AssetRetriever(httpClient: DefaultHTTPClient()))

            // Register dictionary handlers
            let mediaURL = try httpServer.serve(
                at: "dictionary-media",
                handler: DictionaryHTTPHandlers.createMediaHandler()
            )

            _ = try httpServer.serve(
                at: "dictionary-resources",
                handler: DictionaryHTTPHandlers.createResourceHandler()
            )

            // Extract base URL from the media endpoint
            guard let baseURLString = mediaURL.string.components(separatedBy: "/dictionary-media").first,
                  let serverBaseURL = HTTPURL(string: baseURLString)
            else {
                throw NSError(domain: "EPUBNavigatorWrapper", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to extract base URL from HTTP server",
                ])
            }

            _ = try httpServer.serve(
                at: "dictionary-lookup",
                handler: DictionaryHTTPHandlers.createLookupHandler(
                    searchService: DictionarySearchService(),
                    baseURL: serverBaseURL
                )
            )

            // Store base URL in coordinator for setupUserScripts
            context.coordinator.httpBaseURL = serverBaseURL

            // Create the EPUB navigator with configured HTTP server
            let navigator = try EPUBNavigatorViewController(
                publication: loadedPublication.publication,
                initialLocation: loadedPublication.initialLocation,
                httpServer: httpServer
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
        BookReaderCoordinator(
            book: book,
            viewContext: viewContext,
            dictionaryLookupQuery: $dictionaryLookupQuery
        )
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
