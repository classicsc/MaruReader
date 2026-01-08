//
//  MangaReaderOverlayState.swift
//  MaruManga
//

import Foundation

/// State enum for manga reader overlay visibility.
enum MangaReaderOverlayState {
    case none
    case showingToolbars

    var shouldShowToolbars: Bool {
        self == .showingToolbars
    }

    var shouldShowNavigationTitle: Bool {
        shouldShowToolbars
    }

    var shouldShowToolbarToggleButton: Bool {
        !shouldShowToolbars
    }
}

/// Loading state for manga pages.
enum PageLoadingState: Equatable {
    case loading
    case loaded
    case error(String)

    static func == (lhs: PageLoadingState, rhs: PageLoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.loaded, .loaded):
            true
        case let (.error(lhsMsg), .error(rhsMsg)):
            lhsMsg == rhsMsg
        default:
            false
        }
    }
}
