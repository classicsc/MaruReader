//
//  BookReaderCoordinator.swift
//  MaruReader
//
//  Coordinator for managing EPUBNavigatorViewController lifecycle and delegates.
//

import CoreData
import Foundation
import ReadiumNavigator
import ReadiumShared
import SwiftUI
import UIKit
import WebKit

class BookReaderCoordinator: NSObject, NavigatorDelegate, EPUBNavigatorDelegate, WKScriptMessageHandler {
    var book: Book
    var navigator: EPUBNavigatorViewController?
    let viewContext: NSManagedObjectContext
    var httpBaseURL: HTTPURL?
    @Binding var dictionaryLookupQuery: DictionaryLookupRequest?

    init(
        book: Book,
        viewContext: NSManagedObjectContext,
        dictionaryLookupQuery: Binding<DictionaryLookupRequest?>
    ) {
        self.book = book
        self.viewContext = viewContext
        _dictionaryLookupQuery = dictionaryLookupQuery
        super.init()
    }

    // MARK: - NavigatorDelegate

    func navigator(_: Navigator, locationDidChange locator: Locator) {
        // Serialize locator to JSON and save to Book.lastOpenedPage
        Task { @MainActor in
            do {
                let locatorJSON = locator.jsonString
                book.lastOpenedPage = locatorJSON
                try viewContext.save()
            } catch {
                print("Error saving last read location: \(error)")
            }
        }
    }

    func navigator(_: Navigator, presentError error: NavigatorError) {
        print("Navigator error: \(error)")
    }

    func navigator(_: any Navigator, didFailToLoadResourceAt href: RelativeURL, withError error: ReadError) {
        print("Failed to load resource at \(href): \(error)")
    }

    // MARK: - EPUBNavigatorDelegate

    func navigator(_: EPUBNavigatorViewController, setupUserScripts userContentController: WKUserContentController) {
        guard let baseURL = httpBaseURL else {
            print("Warning: No HTTP base URL available for dictionary scripts")
            return
        }

        // Register message handler for term selection in popups
        userContentController.add(self, name: "dictionaryTermSelected")

        // Inject base URL as a global JavaScript variable
        let baseURLScript = WKUserScript(
            source: "window.MARUREADER_BASE_URL = '\(baseURL)';",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(baseURLScript)

        // Inject CSS link for popup styling
        let cssInjectionScript = WKUserScript(
            source: """
            (function() {
                var link = document.createElement('link');
                link.rel = 'stylesheet';
                link.href = '\(baseURL)/dictionary-resources/popup.css';
                document.head.appendChild(link);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(cssInjectionScript)

        // Load and inject JavaScript files
        let scriptNames = ["domUtilities", "popup", "textScanning"]

        for scriptName in scriptNames {
            guard let scriptURL = Bundle.main.url(forResource: scriptName, withExtension: "js"),
                  let scriptSource = try? String(contentsOf: scriptURL, encoding: .utf8)
            else {
                print("Warning: Failed to load \(scriptName).js")
                continue
            }

            let script = WKUserScript(
                source: scriptSource,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            userContentController.addUserScript(script)
            print("Injected \(scriptName).js into EPUB reader")
        }

        print("Dictionary scripts setup complete for EPUB reader")
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "dictionaryTermSelected",
              let term = message.body as? String
        else {
            return
        }

        print("Dictionary term selected from popup: \(term)")

        // Update view to show dictionary sheet with the selected term
        Task { @MainActor in
            dictionaryLookupQuery = DictionaryLookupRequest(query: term)
        }
    }
}
