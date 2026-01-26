// BookReaderTour.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

import MaruDictionaryUICommon
import SwiftUI

/// Tour anchor identifiers for BookReaderView elements.
enum BookReaderTourAnchor {
    static let backButton = "bookReader.backButton"
    static let titleToggle = "bookReader.titleToggle"
    static let tableOfContents = "bookReader.tableOfContents"
    static let dictionaryMode = "bookReader.dictionaryMode"
    static let bookmark = "bookReader.bookmark"
    static let fontSizeSmaller = "bookReader.fontSizeSmaller"
    static let fontSizeLarger = "bookReader.fontSizeLarger"
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
            id: BookReaderTourAnchor.fontSizeLarger,
            title: "Adjust Text Size",
            description: "Make text larger or smaller to suit your reading preference.",
            popoverEdge: .top
        ),
    ]
}
