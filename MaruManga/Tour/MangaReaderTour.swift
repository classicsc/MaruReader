// MangaReaderTour.swift
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

/// Tour anchor identifiers for MangaReaderView elements.
public enum MangaReaderTourAnchor {
    public static let backButton = "mangaReader.backButton"
    public static let textRegions = "mangaReader.textRegions"
    public static let spreadToggle = "mangaReader.spreadToggle"
    public static let readingDirection = "mangaReader.readingDirection"
    public static let pageIndicator = "mangaReader.pageIndicator"
}

/// Tour definition for the manga reader view.
public enum MangaReaderTour: TourDefinition {
    public static let tourID = "mangaReader"

    public static let steps: [TourStep] = [
        TourStep(
            id: MangaReaderTourAnchor.backButton,
            title: MangaLocalization.string("Return to Library"),
            description: MangaLocalization.string("Tap here to close the manga and return to your library."),
            popoverEdge: .bottom
        ),
        TourStep(
            id: MangaReaderTourAnchor.textRegions,
            title: MangaLocalization.string("Text Recognition"),
            description: MangaLocalization.string("Tap on any text to start a dictionary lookup. Use this button if you want to see the exact detected text regions."),
            popoverEdge: .top
        ),
        TourStep(
            id: MangaReaderTourAnchor.readingDirection,
            title: MangaLocalization.string("Reading Direction"),
            description: MangaLocalization.string("Choose right-to-left for traditional manga, left-to-right, or vertical scrolling."),
            popoverEdge: .top
        ),
        TourStep(
            id: MangaReaderTourAnchor.pageIndicator,
            title: MangaLocalization.string("Jump to Page"),
            description: MangaLocalization.string("Tap to jump directly to any page number."),
            popoverEdge: .top
        ),
    ]
}
