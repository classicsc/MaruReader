// BookReaderChromeModelTests.swift
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

@testable import MaruReader
import ReadiumShared
import Testing

@MainActor
struct BookReaderChromeModelTests {
    private func makeLocator(
        position: Int? = nil,
        progression: Double? = nil,
        totalProgression: Double? = nil
    ) -> Locator {
        let anyURL = AnyURL(path: "chapter-1.xhtml")!
        return Locator(
            href: anyURL,
            mediaType: .html,
            locations: .init(
                progression: progression,
                totalProgression: totalProgression,
                position: position
            )
        )
    }

    @Test func progressDisplayText_UsesCurrentDisplayMode() {
        let chrome = BookReaderChromeModel()
        let locator = makeLocator(position: 7, progression: 0.25, totalProgression: 0.42)

        #expect(chrome.progressDisplayText(for: locator) == "Book 42%")

        chrome.progressDisplayMode = .chapter
        #expect(chrome.progressDisplayText(for: locator) == "Chapter 25%")

        chrome.progressDisplayMode = .position
        #expect(chrome.progressDisplayText(for: locator) == "Position 7")
    }

    @Test func cycleProgressDisplayMode_AdvancesThroughAvailableModes() {
        let chrome = BookReaderChromeModel()
        let locator = makeLocator(position: 7, progression: 0.25, totalProgression: 0.42)

        chrome.cycleProgressDisplayMode(for: locator)
        #expect(chrome.progressDisplayMode == .chapter)

        chrome.cycleProgressDisplayMode(for: locator)
        #expect(chrome.progressDisplayMode == .position)

        chrome.cycleProgressDisplayMode(for: locator)
        #expect(chrome.progressDisplayMode == .book)
    }

    @Test func syncProgressDisplayMode_FallsBackWhenModeUnavailable() {
        let chrome = BookReaderChromeModel()
        let locator = makeLocator(position: 7)

        chrome.progressDisplayMode = .chapter
        chrome.syncProgressDisplayMode(for: locator)

        #expect(chrome.progressDisplayMode == .position)
    }
}
