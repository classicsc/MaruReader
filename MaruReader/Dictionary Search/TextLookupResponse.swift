//
//  TextLookupResponse.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

import Foundation

struct TextLookupResponse {
    let requestID: UUID
    let results: [GroupedSearchResults] // Dictionary content
    let primaryResult: String // The matched term
    let primaryResultSourceRange: Range<String.Index> // Range in context

    func toPopupHTML() -> String {
        let termGroupsHTML = results.map { termGroup in
            """
            <div class="popup-term-group" onclick="navigateToTerm('\(escapeHTML(termGroup.expression))')">
                <h2 class="popup-term-header">\(escapeHTML(termGroup.displayTerm))</h2>
                \(termGroup.dictionariesResults.map { dictionaryResult in
                    """
                    <div class="popup-dictionary-section">
                        <h3 class="popup-dictionary-header">\(escapeHTML(dictionaryResult.dictionaryTitle))</h3>
                        <div class="popup-dictionary-content">
                            \(dictionaryResult.combinedHTML)
                        </div>
                    </div>
                    """
                }.joined())
            </div>
            """
        }.joined()

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="marureader-resource://structured-content.css">
            <link rel="stylesheet" href="marureader-resource://popup.css">
            <script>
                function navigateToTerm(term) {
                    window.webkit.messageHandlers.dictionaryTermSelected.postMessage(term);
                }
            </script>
        </head>
        <body class="popup-results-body">
            \(termGroupsHTML)
        </body>
        </html>
        """
    }

    func toResultsHTML() -> String {
        let termGroupsHTML = results.map { termGroup in
            """
            <div class="term-group">
                <h1 class="term-header">\(escapeHTML(termGroup.displayTerm))</h1>
                \(termGroup.dictionariesResults.map { dictionaryResult in
                    """
                    <div class="dictionary-section">
                        <h2 class="dictionary-header">\(escapeHTML(dictionaryResult.dictionaryTitle))</h2>
                        <div class="dictionary-content">
                            \(dictionaryResult.combinedHTML)
                        </div>
                    </div>
                    """
                }.joined())
            </div>
            """
        }.joined()

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <link rel="stylesheet" href="marureader-resource://structured-content.css">
            <link rel="stylesheet" href="marureader-resource://popup.css">
            <script src="marureader-resource://domUtilities.js"></script>
            <script src="marureader-resource://popup.js"></script>
            <script src="marureader-resource://textScanning.js"></script>
            <style>
                body { padding: 12px; margin: 0; }
            </style>
        </head>
        <body>
            \(termGroupsHTML)
        </body>
        </html>
        """
    }
}
