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

class BookReaderCoordinator: NSObject, NavigatorDelegate, EPUBNavigatorDelegate {
    var parent: BookReaderView
    var navigator: EPUBNavigatorViewController?
    let viewContext: NSManagedObjectContext

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
}
