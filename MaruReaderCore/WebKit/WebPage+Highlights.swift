// WebPage+Highlights.swift
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

import WebKit

public enum HighlightError: Error {
    case invalidResponse
}

public extension WebPage {
    func clearHighlights() async throws {
        let script = "window.MaruReader.textHighlighting.clearAllHighlights();"
        try await self.callJavaScript(script)
    }

    func highlightTextByContextRange(cssSelector: String, contextStartOffset: Int, matchStartInContext: Int, matchEndInContext: Int, styles: String) async throws -> [[String: Double]] {
        let script = "return window.MaruReader.textHighlighting.highlightTextByContextRange('\(cssSelector)', \(contextStartOffset), \(matchStartInContext), \(matchEndInContext), \(styles));"
        let result = try await self.callJavaScript(script)
        guard let dataDict = result as? [String: Any],
              let _ = dataDict["highlightId"] as? String,
              let boundingRects = dataDict["boundingRects"] as? [[String: Double]]
        else {
            throw HighlightError.invalidResponse
        }
        return boundingRects
    }
}
