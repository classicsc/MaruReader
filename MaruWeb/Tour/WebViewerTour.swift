// WebViewerTour.swift
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
            description: "Tap here to close the web viewer and return to the app.",
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
            description: "Save your favorite pages and quickly navigate to them.",
            popoverEdge: .top
        ),
        TourStep(
            id: WebViewerToolbarTourAnchor.readingModeButton,
            title: "Reading Mode",
            description: "Enable tap-to-look-up mode for dictionary lookups on any visible text.",
            popoverEdge: .top
        ),
    ]
}

// MARK: - Reading Mode Tour

/// Tour anchor identifiers for WebViewerView reading mode elements.
public enum WebViewerReadingModeTourAnchor {
    public static let pagingToggle = "webViewer.readingMode.pagingToggle"
    public static let exitButton = "webViewer.readingMode.exit"
    public static let collapseButton = "webViewer.readingMode.collapse"
}

/// Tour definition for the web viewer reading mode.
public enum WebViewerReadingModeTour: TourDefinition {
    public static let tourID = "webViewerReadingMode"

    public static let steps: [TourStep] = [
        TourStep(
            id: WebViewerReadingModeTourAnchor.pagingToggle,
            title: "Page Navigation",
            description: "Switch between scroll-based and keypress-based page navigation.",
            popoverEdge: .top
        ),
        TourStep(
            id: WebViewerReadingModeTourAnchor.exitButton,
            title: "Exit Reading Mode",
            description: "Tap to leave reading mode and return to normal browsing.",
            popoverEdge: .top
        ),
        TourStep(
            id: WebViewerReadingModeTourAnchor.collapseButton,
            title: "Collapse Menu",
            description: "Tap to hide these buttons while staying in reading mode. Tap the button again to show them.",
            popoverEdge: .top
        ),
    ]
}
