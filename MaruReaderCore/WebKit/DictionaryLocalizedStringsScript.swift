// DictionaryLocalizedStringsScript.swift
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

import Foundation
import WebKit

/// Creates a `WKUserScript` that injects localized UI strings for dictionary web content into
/// `window.MaruReader.localizedStrings` at document start.
@MainActor
public func makeDictionaryLocalizedStringsScript() -> WKUserScript {
    let strings: [String: String] = [
        "loadingResults": String(localized: "dictionary.status.loading", bundle: .framework),
        "noResultsFound": String(localized: "dictionary.status.empty", bundle: .framework),
        "unableToLoadResults": String(localized: "dictionary.status.error", bundle: .framework),
        "showFrequencyDetails": String(localized: "dictionary.frequencyDetails.show", bundle: .framework),
        "hideFrequencyDetails": String(localized: "dictionary.frequencyDetails.hide", bundle: .framework),
        "showMorePitchResults": String(localized: "dictionary.pitchResults.showMore", bundle: .framework),
        "showFewerPitchResults": String(localized: "dictionary.pitchResults.showFewer", bundle: .framework),
        "playAudio": String(localized: "dictionary.audio.play", bundle: .framework),
        "addToAnki": String(localized: "dictionary.anki.add", bundle: .framework),
        "pitchLabel": String(localized: "dictionary.pitch.label", bundle: .framework),
    ]
    // swiftlint:disable:next force_try
    let json = String(data: try! JSONSerialization.data(withJSONObject: strings), encoding: .utf8)!
    let source = "window.MaruReader = window.MaruReader || {}; window.MaruReader.localizedStrings = \(json);"
    return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
}
