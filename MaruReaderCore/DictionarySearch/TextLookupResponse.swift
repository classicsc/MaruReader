//
//  TextLookupResponse.swift
//  MaruReader
//
//  Created by Sam Smoker on 10/2/25.
//

import Foundation

public struct DisplayStyles: Sendable {
    public let fontFamily: String
    public let contentFontSize: Double
    public let popupFontSize: Double
    public let showDeinflection: Bool
    public let pitchDownstepNotationInHeaderEnabled: Bool
    public let pitchResultsAreaCollapsedDisplay: Bool
    public let pitchResultsAreaDownstepNotationEnabled: Bool
    public let pitchResultsAreaDownstepPositionEnabled: Bool
    public let pitchResultsAreaEnabled: Bool

    public init(
        fontFamily: String,
        contentFontSize: Double,
        popupFontSize: Double,
        showDeinflection: Bool,
        pitchDownstepNotationInHeaderEnabled: Bool,
        pitchResultsAreaCollapsedDisplay: Bool,
        pitchResultsAreaDownstepNotationEnabled: Bool,
        pitchResultsAreaDownstepPositionEnabled: Bool,
        pitchResultsAreaEnabled: Bool
    ) {
        self.fontFamily = fontFamily
        self.contentFontSize = contentFontSize
        self.popupFontSize = popupFontSize
        self.showDeinflection = showDeinflection
        self.pitchDownstepNotationInHeaderEnabled = pitchDownstepNotationInHeaderEnabled
        self.pitchResultsAreaCollapsedDisplay = pitchResultsAreaCollapsedDisplay
        self.pitchResultsAreaDownstepNotationEnabled = pitchResultsAreaDownstepNotationEnabled
        self.pitchResultsAreaDownstepPositionEnabled = pitchResultsAreaDownstepPositionEnabled
        self.pitchResultsAreaEnabled = pitchResultsAreaEnabled
    }
}

private extension String {
    func escapeHTML() -> String {
        var result = self.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }

    func cssEscape() -> String {
        var result = self.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        return result
    }
}

public struct TextLookupResponse: Sendable {
    public let requestID: UUID
    public let results: [GroupedSearchResults] // Dictionary content
    public let primaryResult: String // The matched term
    public let primaryResultSourceRange: Range<String.Index> // Range in context
    public let contextStartOffset: Int // Where context starts in full element text
    public let context: String // The original context string
    public let styles: DisplayStyles

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

    private func generateCSS() -> String {
        let fontFamilyEsc = styles.fontFamily.cssEscape()
        return """
        <style>
        :root {
            --font-family: "\(fontFamilyEsc)";
            --content-font-size-multiplier: \(styles.contentFontSize);
            --popup-font-size-multiplier: \(styles.popupFontSize);
            --deinflection-display: \(styles.showDeinflection ? "inline-block" : "none");
        }
        </style>
        """
    }

    private func termFrequencyHTML(for termGroup: GroupedSearchResults, compactOnly: Bool = false) -> String {
        guard let firstDict = termGroup.dictionariesResults.first,
              let firstResult = firstDict.results.first,
              let frequency = firstResult.frequency,
              !firstResult.frequencies.isEmpty
        else {
            return ""
        }

        let sortedFrequencies = firstResult.frequencies.sorted { $0.priority < $1.priority }
        let formattedFreq = String(Int(round(frequency)))

        guard let firstFreq = sortedFrequencies.first else { return "" }

        var compactTitle = firstFreq.dictionaryTitle.escapeHTML()
        if let mode = firstFreq.mode {
            compactTitle += ": \(mode.escapeHTML())"
        }
        let compactHTML = "<span class=\"freq-compact\" title=\"\(compactTitle)\">\(formattedFreq)</span>"

        if compactOnly {
            return """
            <div class="frequency-display">
              \(compactHTML)
            </div>
            """
        }

        // Expanded
        let freqItemsHTML = sortedFrequencies.map { freq in
            let itemFormatted = String(Int(round(freq.value)))
            let itemTitle = freq.dictionaryTitle.escapeHTML()
            let itemMode = freq.mode ?? "N/A"
            let itemTitleWithMode = itemTitle + ": \(itemMode.escapeHTML())"
            return "<span class=\"freq-item\" title=\"\(itemTitleWithMode)\">\(itemTitle): \(itemFormatted)</span>"
        }.joined(separator: "<span class=\"freq-separator\">·</span>")

        return """
        <div class="frequency-display">
          \(compactHTML)
          <button type="button" class="freq-toggle" aria-label="Toggle frequency details">+</button>
          <div class="freq-expanded">
            \(freqItemsHTML)
          </div>
        </div>
        """
    }

    public func toPopupHTML() -> String {
        let termGroupsHTML = results.map { termGroup in
            // Generate tags HTML
            let tagsHTML = termGroup.termTags.isEmpty ? "" : """
            <div class="popup-term-tags">
            \(termGroup.termTags.map { "<span class=\"tag tag-category-\($0.category.escapeHTML())\">\($0.name.escapeHTML())</span>" }.joined(separator: ""))
            </div>
            """

            // Generate deinflection info HTML
            let deinflectionHTML = termGroup.deinflectionInfo.map { info in
                """
                <div class="popup-deinflection-info">\(info.escapeHTML())</div>
                """
            } ?? ""

            let frequencyHTML = termFrequencyHTML(for: termGroup, compactOnly: true)

            return """
            <div class="popup-term-group" onclick="navigateToTerm('\(termGroup.expression.escapeHTML())')">
                <h2 class="popup-term-header">\(termGroup.displayTerm.escapeHTML())</h2>
                \(tagsHTML)
                \(deinflectionHTML)
                \(frequencyHTML)
                \(termGroup.dictionariesResults.map { dictionaryResult in
                    // Use first result's definition tags for header
                    let defTagsHTML = dictionaryResult.results.first?.definitionTags.map {
                        "<span class=\"tag tag-category-\($0.category.escapeHTML())\">\($0.name.escapeHTML())</span>"
                    }.joined(separator: "") ?? ""

                    return """
                    <div class="popup-dictionary-section">
                        <h3 class="popup-dictionary-header">\(defTagsHTML)\(dictionaryResult.dictionaryTitle.escapeHTML())</h3>
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
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.navigateToTerm) {
                        window.webkit.messageHandlers.navigateToTerm.postMessage(term);
                    }
                }
            </script>
            \(generateCSS())
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
            <div class="term-tags">
            \(termGroup.termTags.map { "<span class=\"tag tag-category-\($0.category.escapeHTML())\">\($0.name.escapeHTML())</span>" }.joined(separator: ""))
            </div>
            """

            // Generate deinflection info HTML
            let deinflectionHTML = termGroup.deinflectionInfo.map { info in
                """
                <div class="deinflection-info">\(info.escapeHTML())</div>
                """
            } ?? ""

            let frequencyHTML = termFrequencyHTML(for: termGroup)

            return """
            <section class="term-group">
                <h2 class="term-header">\(termGroup.displayTerm.escapeHTML())</h2>
                \(tagsHTML)
                \(deinflectionHTML)
                \(frequencyHTML)
                \(termGroup.dictionariesResults.map { dictionaryResult in
                    // Use first result's definition tags for header
                    let defTagsHTML = dictionaryResult.results.first?.definitionTags.map {
                        "<span class=\"tag tag-category-\($0.category.escapeHTML())\">\($0.name.escapeHTML())</span>"
                    }.joined(separator: "") ?? ""

                    return """
                    <section class="dictionary-section">
                        <h3 class="dictionary-header">\(defTagsHTML)\(dictionaryResult.dictionaryTitle.escapeHTML())</h3>
                        <div class="dictionary-content">
                            \(dictionaryResult.combinedHTML)
                        </div>
                    </section>
                    """
                }.joined())
            </section>
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
            <script src="marureader-resource://frequencyDisplay.js"></script>
            <script>
                document.addEventListener('DOMContentLoaded', function() {
                    if (window.MaruReader && window.MaruReader.frequencyDisplay) {
                        window.MaruReader.frequencyDisplay.initialize();
                    }
                });
            </script>
            \(generateCSS())
        </head>
        <body>
            \(termGroupsHTML)
        </body>
        </html>
        """
    }
}
