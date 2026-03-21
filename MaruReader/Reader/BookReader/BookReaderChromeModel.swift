// BookReaderChromeModel.swift
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

import Observation
import ReadiumShared

@MainActor
@Observable
final class BookReaderChromeModel {
    var route: BookReaderChromeRoute = .showingToolbars
    var isDictionaryActive: Bool = true
    var progressDisplayMode: BookReaderProgressDisplayMode = .book

    var isShowingTableOfContents: Bool {
        get { route == .showingTableOfContents }
        set { route = route.settingPresentation(newValue, for: .showingTableOfContents) }
    }

    var isShowingQuickSettings: Bool {
        get { route == .showingQuickSettings }
        set { route = route.settingPresentation(newValue, for: .showingQuickSettings) }
    }

    var isShowingBookmarks: Bool {
        get { route == .showingBookmarks }
        set { route = route.settingPresentation(newValue, for: .showingBookmarks) }
    }

    var showsToolbars: Bool {
        route.shouldShowToolbars
    }

    func toggleOverlay() {
        route = route == .none ? .showingToolbars : .none
    }

    func availableProgressDisplayModes(for locator: Locator?) -> [BookReaderProgressDisplayMode] {
        guard let locator else { return [] }

        var modes: [BookReaderProgressDisplayMode] = []
        if locator.locations.totalProgression != nil {
            modes.append(.book)
        }
        if locator.locations.progression != nil {
            modes.append(.chapter)
        }
        if locator.locations.position != nil {
            modes.append(.position)
        }
        return modes
    }

    func progressDisplayText(for locator: Locator?) -> String? {
        guard let locator else { return nil }
        guard let displayMode = resolvedProgressDisplayMode(for: locator) else { return nil }

        switch displayMode {
        case .book:
            guard let totalProgression = locator.locations.totalProgression else { return nil }
            return String(localized: "Book \(formatProgress(totalProgression))")
        case .chapter:
            guard let progression = locator.locations.progression else { return nil }
            return String(localized: "Chapter \(formatProgress(progression))")
        case .position:
            guard let position = locator.locations.position else { return nil }
            return String(localized: "Position \(position)")
        }
    }

    func cycleProgressDisplayMode(for locator: Locator?) {
        let availableModes = availableProgressDisplayModes(for: locator)
        guard !availableModes.isEmpty else { return }

        guard let currentIndex = availableModes.firstIndex(of: progressDisplayMode) else {
            progressDisplayMode = availableModes[0]
            return
        }

        let nextIndex = (currentIndex + 1) % availableModes.count
        progressDisplayMode = availableModes[nextIndex]
    }

    func syncProgressDisplayMode(for locator: Locator?) {
        let availableModes = availableProgressDisplayModes(for: locator)
        guard let first = availableModes.first else { return }

        if !availableModes.contains(progressDisplayMode) {
            progressDisplayMode = first
        }
    }

    private func resolvedProgressDisplayMode(for locator: Locator) -> BookReaderProgressDisplayMode? {
        let availableModes = availableProgressDisplayModes(for: locator)
        guard let first = availableModes.first else { return nil }
        return availableModes.contains(progressDisplayMode) ? progressDisplayMode : first
    }

    private func formatProgress(_ value: Double) -> String {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue.formatted(.percent.precision(.fractionLength(0)))
    }
}
