//
//  TextLookupResponse.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

import Foundation

public struct TextLookupResponse: Sendable {
    public let requestID: UUID
    public let results: [GroupedSearchResults] // Dictionary content
    public let primaryResult: String // The matched term
    public let primaryResultSourceRange: Range<String.Index> // Range in context
    public let contextStartOffset: Int // Where context starts in full element text
    public let context: String // The original context string

    /// Start offset of the matched text within the context (UTF-16 code units for JS compatibility)
    public var matchStartInContext: Int {
        guard let utf16Lower = primaryResultSourceRange.lowerBound.samePosition(in: context.utf16) else {
            return 0
        }
        return context.utf16.distance(from: context.utf16.startIndex, to: utf16Lower)
    }

    /// End offset of the matched text within the context (UTF-16 code units for JS compatibility)
    public var matchEndInContext: Int {
        guard let utf16Upper = primaryResultSourceRange.upperBound.samePosition(in: context.utf16) else {
            return 0
        }
        return context.utf16.distance(from: context.utf16.startIndex, to: utf16Upper)
    }

    public func toPopupHTML() -> String {
        let termGroupsHTML = results.map { termGroup in
            // Generate tags HTML
            let tagsHTML = termGroup.termTags.isEmpty ? "" : """
            <div class="popup-term-tags">\(termGroup.termTags.toHTML(type: .term))</div>
            """

            // Generate deinflection info HTML
            let deinflectionHTML = termGroup.deinflectionInfo.map { info in
                """
                <div class="popup-deinflection-info">\(escapeHTML(info))</div>
                """
            } ?? ""

            return """
            <div class="popup-term-group" onclick="navigateToTerm('\(escapeHTML(termGroup.expression))')">
                <h2 class="popup-term-header">\(escapeHTML(termGroup.displayTerm))</h2>
                \(tagsHTML)
                \(deinflectionHTML)
                \(termGroup.dictionariesResults.map { dictionaryResult in
                    // Aggregate definition tags from all results in this dictionary
                    let allDefTags = dictionaryResult.results.map(\.definitionTags)
                    let mergedDefTags = [Tag].merge(allDefTags)
                    let defTagsHTML = mergedDefTags.isEmpty ? "" : mergedDefTags.toHTML(type: .definition) + " "

                    return """
                    <div class="popup-dictionary-section">
                        <h3 class="popup-dictionary-header">\(defTagsHTML)\(escapeHTML(dictionaryResult.dictionaryTitle))</h3>
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
                    var message = new XMLHttpRequest();
                    message.open("POST", "marureader-lookup://lookup/navigate", true);
                    message.setRequestHeader("Content-Type", "application/json;charset=UTF-8");
                    message.send(JSON.stringify({ term: term }));
                }
            </script>
        </head>
        <body class="popup-results-body">
            \(termGroupsHTML)
        </body>
        </html>
        """
    }

    public func toResultsHTML() -> String {
        let termGroupsHTML = results.map { termGroup in
            // Generate tags HTML
            let tagsHTML = termGroup.termTags.isEmpty ? "" : """
            <div class="term-tags">\(termGroup.termTags.toHTML(type: .term))</div>
            """

            // Generate deinflection info HTML
            let deinflectionHTML = termGroup.deinflectionInfo.map { info in
                """
                <div class="deinflection-info">\(escapeHTML(info))</div>
                """
            } ?? ""

            return """
            <div class="term-group">
                <h1 class="term-header">\(escapeHTML(termGroup.displayTerm))</h1>
                \(tagsHTML)
                \(deinflectionHTML)
                \(termGroup.dictionariesResults.map { dictionaryResult in
                    // Aggregate definition tags from all results in this dictionary
                    let allDefTags = dictionaryResult.results.map(\.definitionTags)
                    let mergedDefTags = [Tag].merge(allDefTags)
                    let defTagsHTML = mergedDefTags.isEmpty ? "" : mergedDefTags.toHTML(type: .definition) + " "

                    return """
                    <div class="dictionary-section">
                        <h2 class="dictionary-header">\(defTagsHTML)\(escapeHTML(dictionaryResult.dictionaryTitle))</h2>
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
            <script src="marureader-resource://textHighlighting.js"></script>
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
