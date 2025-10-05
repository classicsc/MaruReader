//
//  EPUBNavigatorWrapper.swift
//  MaruReader
//
//  Created by Sam Smoker on 9/30/25.
//

import CoreData
import Foundation
import os.log
import ReadiumAdapterGCDWebServer
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import SwiftUI
import UIKit

struct EPUBNavigatorWrapper: UIViewControllerRepresentable {
    @State var viewModel: BookReaderViewModel

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "EPUBNavigatorWrapper")

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            guard let publication = viewModel.publication else {
                return createErrorViewController(message: "Publication not ready")
            }

            // Constant value for content insets. We manage our own margins by modifying the size of the view in BookReaderView. Modifying these can cause mismatched coordinates and incorrect popup positioning.
            let insets: [UIUserInterfaceSizeClass: EPUBContentInsets] = [
                .compact: (top: 0, bottom: 0),
                .regular: (top: 0, bottom: 0),
            ]

            let config = EPUBNavigatorViewController.Configuration(preferences: EPUBPreferences(), defaults: EPUBDefaults(), contentInset: insets)

            // Create the EPUB navigator with pre-loaded publication
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: viewModel.initialLocation,
                config: config,
                httpServer: GCDHTTPServer(assetRetriever: AssetRetriever(httpClient: DefaultHTTPClient()))
            )

            navigator.delegate = context.coordinator

            viewModel.navigator = navigator

            return navigator
        } catch {
            logger.error("Error creating navigator: \(error)")
            viewModel.readerState = .error(error)
            return createErrorViewController(message: "Failed to load book: \(error.localizedDescription)")
        }
    }

    func updateUIViewController(_: UIViewController, context _: Context) {
        // No updates needed
    }

    func makeCoordinator() -> BookReaderCoordinator {
        BookReaderCoordinator(viewModel: viewModel)
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
