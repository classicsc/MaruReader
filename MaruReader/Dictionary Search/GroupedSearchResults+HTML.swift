//
//  GroupedSearchResults+HTML.swift
//  MaruReader
//
//  HTML generation extensions for GroupedSearchResults arrays.
//

import Foundation

extension [GroupedSearchResults] {
    func generateUnifiedHTML() -> String {
        let termGroupsHTML = self.map { termGroup in
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
            <script src="marureader-resource://domUtilities.js"></script>
            <script src="marureader-resource://textScanning.js"></script>
        </head>
        <body>
            \(termGroupsHTML)
        </body>
        </html>
        """
    }
}
