// MangaReaderTour.swift
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
            title: "Return to Library",
            description: "Tap here to close the manga and return to your library."
        ),
        TourStep(
            id: MangaReaderTourAnchor.textRegions,
            title: "Text Recognition",
            description: "Tap on any text to start a dictionary lookup. Use this button if you want to see the exact detected text regions."
        ),
        TourStep(
            id: MangaReaderTourAnchor.readingDirection,
            title: "Reading Direction",
            description: "Choose right-to-left for traditional manga, left-to-right, or vertical scrolling."
        ),
        TourStep(
            id: MangaReaderTourAnchor.pageIndicator,
            title: "Jump to Page",
            description: "Tap to jump directly to any page number."
        ),
    ]
}
