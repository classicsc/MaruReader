// EPUBNavigatorWrapper.swift
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
import os
import ReadiumNavigator
import SwiftUI
import UIKit

struct EPUBNavigatorWrapper: UIViewControllerRepresentable {
    let session: BookReaderSessionModel
    let lookup: BookReaderLookupModel
    let readerPreferences: ReaderPreferences
    let colorScheme: ColorScheme

    private let logger = Logger.maru(category: "EPUBNavigatorWrapper")

    func makeUIViewController(context: Context) -> UIViewController {
        do {
            guard let publication = session.publication else {
                return createErrorViewController(message: "Publication not ready")
            }

            let insets: [UIUserInterfaceSizeClass: EPUBContentInsets] = [
                .compact: (top: 0, bottom: 0),
                .regular: (top: 0, bottom: 0),
            ]

            readerPreferences.systemColorScheme = colorScheme
            let initialPreferences = readerPreferences.buildEPUBPreferences()
            let config = EPUBNavigatorViewController.Configuration(
                preferences: initialPreferences,
                defaults: EPUBDefaults(),
                contentInset: insets,
                readiumCSSRSProperties: CSSRSProperties(overrides: ["-webkit-column-axis": "horizontal"])
            )

            // Create the EPUB navigator with pre-loaded publication
            let navigator = try EPUBNavigatorViewController(
                publication: publication,
                initialLocation: session.initialLocation,
                config: config
            )

            navigator.delegate = context.coordinator

            session.attachNavigator(navigator)

            readerPreferences.navigator = navigator

            return navigator
        } catch {
            logger.error("Error creating navigator: \(error)")
            session.phase = .error(error)
            return createErrorViewController(message: "Failed to load book: \(error.localizedDescription)")
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context _: Context) {
        guard let navigator = uiViewController as? EPUBNavigatorViewController else {
            return
        }

        if session.navigator !== navigator {
            session.attachNavigator(navigator)
        }

        if readerPreferences.navigator !== navigator {
            readerPreferences.navigator = navigator
        }

        readerPreferences.systemColorScheme = colorScheme
    }

    func makeCoordinator() -> BookReaderCoordinator {
        BookReaderCoordinator(session: session, lookup: lookup)
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
