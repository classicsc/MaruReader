// BookReaderTour.swift
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

import MaruDictionaryUICommon
import SwiftUI

/// Tour anchor identifiers for BookReaderView elements.
enum BookReaderTourAnchor {
    static let backButton = "bookReader.backButton"
    static let titleToggle = "bookReader.titleToggle"
    static let tableOfContents = "bookReader.tableOfContents"
    static let dictionaryMode = "bookReader.dictionaryMode"
    static let bookmark = "bookReader.bookmark"
    static let appearanceMenu = "bookReader.appearanceMenu"
}

/// Tour definition for the book reader view.
enum BookReaderTour: TourDefinition {
    static let tourID = "bookReader"

    static let steps: [TourStep] = [
        TourStep(
            id: BookReaderTourAnchor.backButton,
            title: "Return to Library",
            description: "Tap here to close the book and return to your library.",
            popoverEdge: .bottom
        ),
        TourStep(
            id: BookReaderTourAnchor.titleToggle,
            title: "Show or Hide Toolbar",
            description: "Tap the title to show or hide the toolbar.",
            popoverEdge: .bottom
        ),
        TourStep(
            id: BookReaderTourAnchor.tableOfContents,
            title: "Table of Contents",
            description: "View chapters, bookmarks, and jump to any position in the book.",
            popoverEdge: .top
        ),
        TourStep(
            id: BookReaderTourAnchor.dictionaryMode,
            title: "Dictionary Lookup",
            description: "In dictionary mode, tap any word to look it up instantly. Use this button to toggle dictionary mode on or off.",
            popoverEdge: .top
        ),
        TourStep(
            id: BookReaderTourAnchor.bookmark,
            title: "Bookmarks",
            description: "Add a bookmark at your current position or jump to existing bookmarks.",
            popoverEdge: .top
        ),
        TourStep(
            id: BookReaderTourAnchor.appearanceMenu,
            title: "Appearance and Text",
            description: "Adjust text size, switch between Mincho and Gothic fonts, and choose light, dark, sepia, or follow system appearance.",
            popoverEdge: .top
        ),
    ]
}
