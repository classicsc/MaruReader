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
    let parent: BookReaderView

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
        BookReaderCoordinator(parent: parent, viewContext: viewContext)
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
