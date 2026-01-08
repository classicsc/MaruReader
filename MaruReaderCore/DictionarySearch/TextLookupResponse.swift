// TextLookupResponse.swift
// MaruReader
// Copyright (c) 2025  Sam Smoker
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
    public let request: TextLookupRequest
    public let results: [GroupedSearchResults] // Dictionary content
    public let primaryResult: String // The matched term
    public let primaryResultSourceRange: Range<String.Index> // Range in context
    public let styles: DisplayStyles

    /// Term keys for which Anki notes already exist. Used to change button appearance.
    public var existingNoteTermKeys: Set<String> = []

    /// Whether Anki integration is enabled. When false, Anki buttons are not shown.
    public var ankiEnabled: Bool = false

    /// Mark term keys that already have notes in Anki.
    public mutating func markExistingNotes(_ termKeys: Set<String>) {
        existingNoteTermKeys = termKeys
    }

    /// Enable Anki button display.
    public mutating func setAnkiEnabled(_ enabled: Bool) {
        ankiEnabled = enabled
    }

    /// The original request ID (for backward compatibility).
    public var requestID: UUID { request.id }

    /// Where context starts in full element text (convenience accessor).
    public var contextStartOffset: Int { request.contextStartOffset }

    /// The original context string (convenience accessor).
    public var context: String { request.context }

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
              !firstResult.frequencies.isEmpty
        else {
            return ""
        }

        let sortedFrequencies = firstResult.frequencies.sorted { $0.priority < $1.priority }

        guard let firstFreq = sortedFrequencies.first else { return "" }

        var compactTitle = firstFreq.dictionaryTitle.escapeHTML()
        if let mode = firstFreq.mode {
            compactTitle += ": \(mode.escapeHTML())"
        }
        let compactHTML = "<span class=\"freq-compact\" title=\"\(compactTitle)\">\(firstFreq.displayString.escapeHTML())</span>"

        if compactOnly {
            return """
            <div class="frequency-display">
              \(compactHTML)
            </div>
            """
        }

        // Expanded
        let freqItemsHTML = sortedFrequencies.map { freq in
            let itemTitle = freq.dictionaryTitle.escapeHTML()
            let itemMode = freq.mode ?? "N/A"
            let itemTitleWithMode = itemTitle + ": \(itemMode.escapeHTML())"
            return "<span class=\"freq-item\" title=\"\(itemTitleWithMode)\">\(itemTitle): \(freq.displayString.escapeHTML())</span>"
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

    // MARK: - Pitch Accent HTML Generation

    /// Splits a reading string into individual mora.
    /// Handles small kana that combine with previous characters (きょ → one mora).
    private func splitIntoMora(_ reading: String) -> [String] {
        var mora: [String] = []
        var i = reading.startIndex

        // Small kana that combine with previous character to form one mora
        let smallKana: Set<Character> = [
            "ゃ", "ゅ", "ょ", "ャ", "ュ", "ョ",
            "ぁ", "ぃ", "ぅ", "ぇ", "ぉ",
            "ァ", "ィ", "ゥ", "ェ", "ォ",
        ]

        while i < reading.endIndex {
            let char = reading[i]
            let nextIndex = reading.index(after: i)

            // Check if next character is a small kana
            if nextIndex < reading.endIndex {
                let nextChar = reading[nextIndex]
                if smallKana.contains(nextChar) {
                    mora.append(String(char) + String(nextChar))
                    i = reading.index(after: nextIndex)
                    continue
                }
            }

            mora.append(String(char))
            i = nextIndex
        }

        return mora
    }

    /// Converts mora position to high/low pattern array.
    /// - Position 0 = heiban (flat): LHHH... (low first, then all high, no downstep)
    /// - Position 1 = atamadaka: HLLL... (high first, then all low)
    /// - Position N = nakadaka/odaka: LHHH...LLL (low first, high until N, then low)
    private func moraPositionToPattern(_ position: Int, moraCount: Int) -> [Bool] {
        guard moraCount > 0 else { return [] }

        var pattern = [Bool](repeating: false, count: moraCount)

        if position == 0 {
            // Heiban: first mora low, rest high
            for i in 1 ..< moraCount {
                pattern[i] = true
            }
        } else if position == 1 {
            // Atamadaka: first mora high, rest low
            pattern[0] = true
        } else {
            // Nakadaka or Odaka: first mora low, then high until position, then low
            for i in 1 ..< min(position, moraCount) {
                pattern[i] = true
            }
        }

        return pattern
    }

    /// Converts pattern string (like "HHLL") to boolean array.
    private func patternStringToArray(_ pattern: String) -> [Bool] {
        pattern.map { $0 == "H" || $0 == "h" }
    }

    /// Generates HTML for pitch notation on a reading.
    private func generatePitchNotationHTML(reading: String, pitchAccent: PitchAccent) -> String {
        let moraArray = splitIntoMora(reading)
        guard !moraArray.isEmpty else { return reading.escapeHTML() }

        let pattern: [Bool]
        let downstepPosition: Int?

        switch pitchAccent.position {
        case let .mora(position):
            pattern = moraPositionToPattern(position, moraCount: moraArray.count)
            downstepPosition = position > 0 && position <= moraArray.count ? position : nil
        case let .pattern(patternStr):
            pattern = patternStringToArray(patternStr)
            // Find downstep position in pattern (where H changes to L)
            var foundDownstep: Int?
            for i in 0 ..< pattern.count - 1 where pattern[i] && !pattern[i + 1] {
                foundDownstep = i + 1
                break
            }
            downstepPosition = foundDownstep
        }

        var html = "<span class=\"pitch-reading\">"

        for (index, mora) in moraArray.enumerated() {
            let isHigh = index < pattern.count ? pattern[index] : false
            let isDownstep = downstepPosition != nil && index + 1 == downstepPosition

            var classes = ["pitch-mora"]
            classes.append(isHigh ? "pitch-mora-high" : "pitch-mora-low")
            if isDownstep {
                classes.append("pitch-mora-downstep")
            }

            html += "<span class=\"\(classes.joined(separator: " "))\">\(mora.escapeHTML())</span>"
        }

        html += "</span>"
        return html
    }

    /// Generates the pitch position text display (e.g., circled numbers or pattern string).
    private func generatePitchPositionText(pitchAccent: PitchAccent) -> String {
        switch pitchAccent.position {
        case let .mora(position):
            // Use circled numbers for positions 0-9
            let circledNumbers = ["⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]
            if position >= 0, position < circledNumbers.count {
                return circledNumbers[position]
            }
            return String(position)
        case let .pattern(pattern):
            return pattern
        }
    }

    // MARK: - Audio HTML Generation

    /// Serializes audio sources to JSON for use in HTML data attributes.
    private func audioSourcesJSON(for sources: [AudioSourceResult]) -> String {
        let sourceData = sources.map { source -> [String: String] in
            var dict: [String: String] = ["url": source.url.absoluteString]
            if let pitch = source.pitchNumber {
                dict["pitch"] = pitch
            }
            return dict
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: sourceData),
              let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return "[]"
        }
        return jsonString.escapeHTML()
    }

    /// Generates an audio button HTML element with the given sources.
    private func audioButtonHTML(sources: [AudioSourceResult], pitchPosition: String? = nil) -> String {
        guard !sources.isEmpty else { return "" }

        // Filter by pitch position if specified
        let filteredSources: [AudioSourceResult]
        if let position = pitchPosition {
            let matching = sources.filter { $0.pitchNumber == position }
            filteredSources = matching.isEmpty ? sources : matching
        } else {
            filteredSources = sources
        }

        guard !filteredSources.isEmpty else { return "" }

        let sourcesJSON = audioSourcesJSON(for: filteredSources)
        return """
        <button type="button" class="audio-button" data-audio-sources="\(sourcesJSON)" data-state="ready" aria-label="Play audio"></button>
        """
    }

    /// Generates an Anki button HTML element for the given term group.
    private func ankiButtonHTML(for termGroup: GroupedSearchResults) -> String {
        guard ankiEnabled else { return "" }

        let state = existingNoteTermKeys.contains(termGroup.termKey) ? "exists" : "ready"
        let termKey = termGroup.termKey.escapeHTML()
        let expression = termGroup.expression.escapeHTML()
        let reading = (termGroup.reading ?? "").escapeHTML()

        return """
        <button type="button" class="anki-button" data-term-key="\(termKey)" data-expression="\(expression)" data-reading="\(reading)" data-state="\(state)" aria-label="Add to Anki"></button>
        """
    }

    /// Gets the primary pitch position string from pitch accent results.
    private func primaryPitchPositionString(for termGroup: GroupedSearchResults) -> String? {
        guard let firstPitchResult = termGroup.pitchAccentResults.first,
              let firstPitch = firstPitchResult.pitches.first
        else {
            return nil
        }

        switch firstPitch.position {
        case let .mora(position):
            return String(position)
        case .pattern:
            return nil
        }
    }

    /// Generates HTML for the pitch results area.
    private func pitchResultsAreaHTML(for termGroup: GroupedSearchResults, compactOnly: Bool = false, includeAudio: Bool = false) -> String {
        guard styles.pitchResultsAreaEnabled,
              !termGroup.pitchAccentResults.isEmpty
        else {
            return ""
        }

        let reading = termGroup.reading ?? termGroup.expression

        // Get all pitch results sorted by priority
        let allResults = termGroup.pitchAccentResults
        guard let firstResult = allResults.first,
              !firstResult.pitches.isEmpty
        else {
            return ""
        }

        // Generate HTML for pitch items
        var pitchItemsHTML: [String] = []
        var isFirstItem = true

        for pitchResult in allResults {
            for pitch in pitchResult.pitches {
                var itemClasses = ["pitch-result-item"]
                if !isFirstItem, styles.pitchResultsAreaCollapsedDisplay {
                    itemClasses.append("pitch-result-collapsed")
                }

                var itemHTML = "<div class=\"\(itemClasses.joined(separator: " "))\">"

                // Add visual notation if enabled
                if styles.pitchResultsAreaDownstepNotationEnabled {
                    itemHTML += "<span class=\"pitch-notation\">"
                    itemHTML += generatePitchNotationHTML(reading: reading, pitchAccent: pitch)
                    itemHTML += "</span>"
                }

                // Add position text if enabled
                if styles.pitchResultsAreaDownstepPositionEnabled {
                    let positionText = generatePitchPositionText(pitchAccent: pitch)
                    itemHTML += "<span class=\"pitch-position-text\">\(positionText.escapeHTML())</span>"
                }

                // Add dictionary name
                itemHTML += "<span class=\"pitch-dictionary-name\">\(pitchResult.dictionaryTitle.escapeHTML())</span>"

                // Add audio button for this specific pitch if audio is available
                if includeAudio, let audioResults = termGroup.audioResults {
                    let pitchPositionString: String? = switch pitch.position {
                    case let .mora(pos): String(pos)
                    case .pattern: nil
                    }

                    let pitchSources = audioResults.sources(forPitchPosition: pitchPositionString)
                    if !pitchSources.isEmpty {
                        itemHTML += audioButtonHTML(sources: pitchSources, pitchPosition: pitchPositionString)
                    }
                }

                itemHTML += "</div>"
                pitchItemsHTML.append(itemHTML)
                isFirstItem = false
            }
        }

        // Count total items for toggle button
        let totalItems = allResults.reduce(0) { $0 + $1.pitches.count }
        let showToggle = !compactOnly && styles.pitchResultsAreaCollapsedDisplay && totalItems > 1

        let cssClass = compactOnly ? "popup-pitch-results-area" : "pitch-results-area"

        var html = "<div class=\"\(cssClass)\">"

        if !compactOnly {
            html += "<div class=\"pitch-results-header\">"
            html += "<span class=\"pitch-results-label\">Pitch</span>"
            if showToggle {
                html += """
                <button type="button" class="pitch-toggle" data-expanded="false" aria-label="Show more pitch results">+</button>
                """
            }
            html += "</div>"
        }

        html += "<div class=\"pitch-results-list\">"
        html += pitchItemsHTML.joined()
        html += "</div>"
        html += "</div>"

        return html
    }

    /// Generates the term header with optional pitch notation, audio button, and Anki button.
    private func termHeaderHTML(for termGroup: GroupedSearchResults, cssClass: String, includeAudio: Bool = false, includeAnki: Bool = false) -> String {
        let expression = termGroup.expression.escapeHTML()

        // Generate audio button if requested and audio is available
        let audioHTML: String
        if includeAudio, let audioResults = termGroup.audioResults, audioResults.hasAudio {
            let primaryPitch = primaryPitchPositionString(for: termGroup)
            audioHTML = audioButtonHTML(sources: audioResults.sources, pitchPosition: primaryPitch)
        } else {
            audioHTML = ""
        }

        // Generate Anki button if requested and enabled
        let ankiHTML = includeAnki ? ankiButtonHTML(for: termGroup) : ""

        guard let reading = termGroup.reading, !reading.isEmpty else {
            return "<h2 class=\"\(cssClass)\">\(expression)\(audioHTML)\(ankiHTML)</h2>"
        }

        let readingHTML: String

            // Check if pitch notation in header is enabled and we have pitch data
            = if styles.pitchDownstepNotationInHeaderEnabled,
            let firstPitchResult = termGroup.pitchAccentResults.first,
            let firstPitch = firstPitchResult.pitches.first
        {
            generatePitchNotationHTML(reading: reading, pitchAccent: firstPitch)
        } else {
            reading.escapeHTML()
        }

        return "<h2 class=\"\(cssClass)\">\(expression) [\(readingHTML)]\(audioHTML)\(ankiHTML)</h2>"
    }

    public func toPopupHTML() -> String {
        let termGroupsHTML = results.map { termGroup in
            // Generate term header with optional pitch notation
            let headerHTML = termHeaderHTML(for: termGroup, cssClass: "popup-term-header")

            // Generate audio button for popup header
            let audioButtonHTML: String
            if let audioResults = termGroup.audioResults, audioResults.hasAudio {
                let primaryPitch = primaryPitchPositionString(for: termGroup)
                audioButtonHTML = self.audioButtonHTML(sources: audioResults.sources, pitchPosition: primaryPitch)
            } else {
                audioButtonHTML = ""
            }

            // Generate Anki button for popup header
            let ankiButtonHTML = self.ankiButtonHTML(for: termGroup)

            // Wrap header with audio and Anki buttons if available
            let hasButtons = !audioButtonHTML.isEmpty || !ankiButtonHTML.isEmpty
            let headerSectionHTML: String = if hasButtons {
                """
                <div class="popup-term-header-wrapper">
                    \(headerHTML)
                    \(audioButtonHTML)\(ankiButtonHTML)
                </div>
                """
            } else {
                headerHTML
            }

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

            // Generate pitch results area (compact for popup)
            let pitchHTML = pitchResultsAreaHTML(for: termGroup, compactOnly: true)

            return """
            <div class="popup-term-group" onclick="navigateToTerm('\(termGroup.expression.escapeHTML())')">
                \(headerSectionHTML)
                \(tagsHTML)
                \(deinflectionHTML)
                \(frequencyHTML)
                \(pitchHTML)
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
            <script src="marureader-resource://audioDisplay.js"></script>
            <script src="marureader-resource://ankiDisplay.js"></script>
            <script>
                function navigateToTerm(term) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.navigateToTerm) {
                        window.webkit.messageHandlers.navigateToTerm.postMessage(term);
                    }
                }
                document.addEventListener('DOMContentLoaded', function() {
                    if (window.MaruReader && window.MaruReader.audioDisplay) {
                        window.MaruReader.audioDisplay.initialize();
                    }
                    if (window.MaruReader && window.MaruReader.ankiDisplay) {
                        window.MaruReader.ankiDisplay.initialize();
                    }
                });
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
            // Generate term header with optional pitch notation, audio, and Anki button
            let headerHTML = termHeaderHTML(for: termGroup, cssClass: "term-header", includeAudio: true, includeAnki: true)

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

            // Generate pitch results area with audio buttons
            let pitchHTML = pitchResultsAreaHTML(for: termGroup, includeAudio: true)

            return """
            <section class="term-group">
                \(headerHTML)
                \(tagsHTML)
                \(deinflectionHTML)
                \(frequencyHTML)
                \(pitchHTML)
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
            <script src="marureader-resource://pitchDisplay.js"></script>
            <script src="marureader-resource://audioDisplay.js"></script>
            <script src="marureader-resource://ankiDisplay.js"></script>
            <script>
                document.addEventListener('DOMContentLoaded', function() {
                    if (window.MaruReader && window.MaruReader.textScanning) {
                        window.MaruReader.textScanning.initialize();
                    }
                    if (window.MaruReader && window.MaruReader.frequencyDisplay) {
                        window.MaruReader.frequencyDisplay.initialize();
                    }
                    if (window.MaruReader && window.MaruReader.pitchDisplay) {
                        window.MaruReader.pitchDisplay.initialize();
                    }
                    if (window.MaruReader && window.MaruReader.audioDisplay) {
                        window.MaruReader.audioDisplay.initialize();
                    }
                    if (window.MaruReader && window.MaruReader.ankiDisplay) {
                        window.MaruReader.ankiDisplay.initialize();
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
