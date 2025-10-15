//
//  WebPage+Highlights.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/4/25.
//

import os.log
import WebKit

enum HighlightError: Error {
    case invalidResponse
}

extension WebPage {
    func clearHighlights() async throws {
        let script = "window.MaruReader.textHighlighting.clearAllHighlights();"
        try await self.callJavaScript(script)
    }

    func highlightText(_ text: String, elementSelector: String, styles: String) async throws -> [[String: Double]] {
        let script = "return window.MaruReader.textHighlighting.highlightText('\(text)', '\(elementSelector)', \(styles));"
        let result = try await self.callJavaScript(script)
        guard let dataDict = result as? [String: Any],
              let _ = dataDict["highlightId"] as? String,
              let boundingRects = dataDict["boundingRects"] as? [[String: Double]]
        else {
            throw HighlightError.invalidResponse
        }
        return boundingRects
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
