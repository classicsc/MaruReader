// WebViewerTour.swift
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

// MARK: - Toolbar Tour

/// Tour anchor identifiers for WebViewerView toolbar elements.
public enum WebViewerToolbarTourAnchor {
    public static let dismissButton = "webViewer.toolbar.dismiss"
    public static let addressBar = "webViewer.toolbar.addressBar"
    public static let bookmarkButton = "webViewer.toolbar.bookmark"
    public static let readingModeButton = "webViewer.toolbar.readingMode"
}

/// Tour definition for the web viewer toolbar.
public enum WebViewerToolbarTour: TourDefinition {
    public static let tourID = "webViewerToolbar"

    public static let steps: [TourStep] = [
        TourStep(
            id: WebViewerToolbarTourAnchor.dismissButton,
            title: "Exit Web Viewer",
            description: "Open the more actions menu, then tap Exit Web Viewer to close and return to the app.",
            popoverEdge: .top
        ),
        TourStep(
            id: WebViewerToolbarTourAnchor.addressBar,
            title: "Address Bar",
            description: "Tap to edit the URL or see the current site. The reload button refreshes the page.",
            popoverEdge: .top
        ),
        TourStep(
            id: WebViewerToolbarTourAnchor.bookmarkButton,
            title: "Bookmarks",
            description: "Open the more actions menu to add or remove bookmarks and jump to saved pages.",
            popoverEdge: .top
        ),
        TourStep(
            id: WebViewerToolbarTourAnchor.readingModeButton,
            title: "OCR Mode",
            description: "Enable tap-to-look-up mode for dictionary lookups on visible text.",
            popoverEdge: .top
        ),
    ]
}
