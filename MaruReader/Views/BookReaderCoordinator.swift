//
//  BookReaderCoordinator.swift
//  MaruReader
//
//  Coordinator for managing EPUBNavigatorViewController lifecycle and delegates.
//

import CoreData
import Foundation
import os.log
import ReadiumNavigator
import ReadiumShared
import SwiftUI
import UIKit
import WebKit

class BookReaderCoordinator: NSObject, NavigatorDelegate, EPUBNavigatorDelegate, WKScriptMessageHandler {
    var parent: BookReaderView
    var navigator: EPUBNavigatorViewController?
    let viewContext: NSManagedObjectContext

    private let forwardTextScanChars = 15

    private let logger = Logger(subsystem: "net.undefinedstar.MaruReader", category: "BookReaderCoordinator")

    init(parent: BookReaderView, viewContext: NSManagedObjectContext) {
        self.parent = parent
        self.viewContext = viewContext
        super.init()
    }

    // MARK: - NavigatorDelegate

    func navigator(_: Navigator, locationDidChange locator: Locator) {
        // Serialize locator to JSON and save to Book.lastOpenedPage
        Task { @MainActor in
            do {
                let locatorJSON = locator.jsonString
                parent.book.lastOpenedPage = locatorJSON
                try viewContext.save()
            } catch {
                logger.error("Error saving last read location: \(error)")
            }
        }
    }

    func navigator(_: Navigator, presentError error: NavigatorError) {
        logger.error("Navigator error: \(error)")
    }

    func navigator(_: any Navigator, didFailToLoadResourceAt href: RelativeURL, withError error: ReadError) {
        logger.error("Failed to load resource at \(href): \(error)")
    }

    func navigator(_: EPUBNavigatorViewController, setupUserScripts userContentController: WKUserContentController) {
        let scriptNames = ["domUtilities", "textScanning"]
        for name in scriptNames {
            guard let scriptURL = Bundle.main.url(forResource: name, withExtension: "js"),
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
                  let context = messageObject["context"] as? String
            else {
                logger.error("Invalid message body for textScanning")
                return
            }
            // Extract substring from offset to offset + forwardTextScanChars
            let startIndex = context.index(context.startIndex, offsetBy: offset, limitedBy: context.endIndex) ?? context.startIndex
            let endIndex = context.index(startIndex, offsetBy: forwardTextScanChars, limitedBy: context.endIndex) ?? context.endIndex
            let scanText = String(context[startIndex ..< endIndex])

            Task { @MainActor in
                if parent.showingPopup {
                    parent.showingPopup = false
                } else {
                    parent.popupQuery = scanText
                    parent.popupContext = context
                    parent.showingPopup = true
                }
            }
        }
    }
}
