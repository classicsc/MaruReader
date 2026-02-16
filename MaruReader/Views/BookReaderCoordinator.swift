// BookReaderCoordinator.swift
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
import os.log
import ReadiumNavigator
import ReadiumShared
import SwiftUI
import UIKit
import WebKit

@MainActor
class BookReaderCoordinator: NSObject, NavigatorDelegate, EPUBNavigatorDelegate, WKScriptMessageHandler {
    let viewModel: BookReaderViewModel
    let viewContext: NSManagedObjectContext = BookDataPersistenceController.shared.container.viewContext

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookReaderCoordinator")

    init(viewModel: BookReaderViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - NavigatorDelegate

    func navigator(_: Navigator, locationDidChange locator: Locator) {
        // Serialize locator to JSON and save to Book.lastOpenedPage
        Task { @MainActor in
            do {
                viewModel.currentLocator = locator
                let locatorJSON = locator.jsonString
                viewModel.book.lastOpenedPage = locatorJSON
                if let totalProgression = locator.locations.totalProgression {
                    viewModel.book.progressPercent = formatProgress(totalProgression)
                }
                try viewContext.save()
            } catch {
                logger.error("Error saving last read location: \(error)")
            }
        }
    }

    private func formatProgress(_ value: Double) -> String {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue.formatted(.percent.precision(.fractionLength(0)))
    }

    func navigator(_: Navigator, presentError error: NavigatorError) {
        logger.error("Navigator error: \(error)")
    }

    func navigator(_: any Navigator, didFailToLoadResourceAt href: RelativeURL, withError error: ReadError) {
        logger.error("Failed to load resource at \(href): \(error)")
    }

    func navigator(_: EPUBNavigatorViewController, setupUserScripts userContentController: WKUserContentController) {
        let scriptNames = ["domUtilities", "textScanning", "textHighlighting"]
        for name in scriptNames {
            guard let scriptURL = Bundle.framework.url(forResource: name, withExtension: "js"),
                  let scriptContent = try? String(contentsOf: scriptURL, encoding: .utf8)
            else {
                continue
            }
            let userScript = WKUserScript(source: scriptContent, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userContentController.addUserScript(userScript)
            logger.debug("Added user script: \(name).js")
        }
        userContentController.add(self, name: "textScanning")
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "textScanning" {
            logger.debug("Received textScanning message: \(String(describing: message.body))")
            guard let messageObject = message.body as? [String: Any],
                  let offset = messageObject["offset"] as? Int,
                  let context = messageObject["context"] as? String,
                  let contextStartOffset = messageObject["contextStartOffset"] as? Int,
                  let cssSelector = messageObject["cssSelector"] as? String
            else {
                logger.error("Invalid message body for textScanning")
                return
            }

            viewModel.searchInPopup(offset: offset, context: context, contextStartOffset: contextStartOffset, cssSelector: cssSelector)
        }
    }
}
