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
        "loadingResults": FrameworkLocalization.string("dictionary.status.loading"),
        "noResultsFound": FrameworkLocalization.string("dictionary.status.empty"),
        "unableToLoadResults": FrameworkLocalization.string("dictionary.status.error"),
        "showFrequencyDetails": FrameworkLocalization.string("dictionary.frequencyDetails.show"),
        "hideFrequencyDetails": FrameworkLocalization.string("dictionary.frequencyDetails.hide"),
        "showGrammarDetails": FrameworkLocalization.string("dictionary.grammarDetails.show"),
        "hideGrammarDetails": FrameworkLocalization.string("dictionary.grammarDetails.hide"),
        "showMorePitchResults": FrameworkLocalization.string("dictionary.pitchResults.showMore"),
        "showFewerPitchResults": FrameworkLocalization.string("dictionary.pitchResults.showFewer"),
        "playAudio": FrameworkLocalization.string("dictionary.audio.play"),
        "addToAnki": FrameworkLocalization.string("dictionary.anki.add"),
        "pitchLabel": FrameworkLocalization.string("dictionary.pitch.label"),
    ]
    // swiftlint:disable:next force_try
    let json = String(data: try! JSONSerialization.data(withJSONObject: strings), encoding: .utf8)!
    let source = "window.MaruReader = window.MaruReader || {}; window.MaruReader.localizedStrings = \(json);"
    return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: false)
}
