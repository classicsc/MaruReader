// EPUBNavigatorViewController+MaruHighlights.swift
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

import MaruReaderCore
import ReadiumNavigator

extension EPUBNavigatorViewController {
    func clearMaruHighlights() async throws {
        let result = await evaluateJavaScript("window.MaruReader.textHighlighting.clearAllHighlights();")
        switch result {
        case .success:
            return
        case let .failure(error):
            throw error
        }
    }

    func maruHighlightTextByContextRange(
        cssSelector: String,
        contextStartOffset: Int,
        matchStartInContext: Int,
        matchEndInContext: Int,
        styles: String
    ) async throws -> [[String: Double]] {
        let script = "window.MaruReader.textHighlighting.highlightTextByContextRange('\(cssSelector)', \(contextStartOffset), \(matchStartInContext), \(matchEndInContext), \(styles));"
        let result = await evaluateJavaScript(script)
        switch result {
        case let .success(value):
            guard let dataDict = value as? [String: Any],
                  let _ = dataDict["highlightId"] as? String,
                  let boundingRects = dataDict["boundingRects"] as? [[String: Double]]
            else {
                throw HighlightError.invalidResponse
            }
            return boundingRects
        case let .failure(error):
            throw error
        }
    }
}
