//
//  WebPage+Highlights.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/4/25.
//

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
        let script = "window.MaruReader.textHighlighting.highlightText('\(text)', '\(elementSelector)', \(styles));"
        let result = try await self.callJavaScript(script)
        guard let dataDict = result as? [String: Any],
              let _ = dataDict["highlightID"] as? String,
              let boundingRects = dataDict["boundingRects"] as? [[String: Double]]
        else {
            throw HighlightError.invalidResponse
        }
        return boundingRects
    }
}
