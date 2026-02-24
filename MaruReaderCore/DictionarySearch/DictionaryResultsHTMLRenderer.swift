// DictionaryResultsHTMLRenderer.swift
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

public struct DictionaryStyleInfo: Sendable {
    public let id: UUID
    public let title: String

    public init(id: UUID, title: String) {
        self.id = id
        self.title = title
    }
}

public struct DictionaryResultsHTMLRenderer: Sendable {
    public enum Mode: Sendable {
        case results
        case popup
    }

    public let styles: DisplayStyles

    public init(styles: DisplayStyles) {
        self.styles = styles
    }

    public func render(groups: [GroupedSearchResults], mode: Mode) async -> String {
        switch mode {
        case .results:
            await renderResults(groups: groups)
        case .popup:
            renderPopup(groups: groups)
        }
    }

    public func termGroupHTML(_ termGroup: GroupedSearchResults) -> String {
        // Generate term header with optional pitch notation, audio, Anki button, and audio sources area
        let headerHTML = termHeaderHTML(
            for: termGroup,
            cssClass: "term-header",
            includeAudio: true,
            includeAnki: true,
            includeAudioSourcesArea: true
        )

        // Generate tags HTML
        let tagsHTML = termGroup.termTags.isEmpty ? "" : """
        <div class=\"term-tags\">
        \(termGroup.termTags.map { "<span class=\"tag tag-category-\($0.category.escapeHTML())\">\($0.name.escapeHTML())</span>" }.joined(separator: ""))
        </div>
        """

        // Generate deinflection info HTML
        let deinflectionHTML = termGroup.deinflectionInfo.map { info in
            """
            <div class=\"deinflection-info\">\(info.escapeHTML())</div>
            """
        } ?? ""

        let frequencyHTML = termFrequencyHTML(for: termGroup)

        // Generate pitch results area with audio buttons
        let pitchHTML = pitchResultsAreaHTML(for: termGroup, includeAudio: true)

        return """
        <section class=\"term-group\" data-term-key=\"\(termGroup.termKey.escapeHTML())\">
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
                let dictionaryTitleEsc = dictionaryResult.dictionaryTitle.escapeHTML()

                return """
                <section class=\"dictionary-section\" data-dictionary=\"\(dictionaryTitleEsc)\">
                    <h3 class=\"dictionary-header\">\(defTagsHTML)\(dictionaryTitleEsc)</h3>
                    <div class=\"dictionary-content\">
                        \(dictionaryResult.combinedHTML)
                    </div>
                </section>
                """
            }.joined())
        </section>
        """
    }

    public func popupTermGroupHTML(_ termGroup: GroupedSearchResults) -> String {
        // Generate term header with optional pitch notation
        let headerHTML = termHeaderHTML(for: termGroup, cssClass: "popup-term-header")

        // Generate audio button placeholder for popup header
        let primaryPitch = primaryPitchPositionString(for: termGroup)
        let audioButtonHTML = audioButtonHTML(
            term: termGroup.expression,
            reading: termGroup.reading,
            pitchPosition: primaryPitch,
            role: "primary"
        )

        // Generate Anki button for popup header
        let ankiButtonHTML = self.ankiButtonHTML(for: termGroup)

        // Wrap header with audio and Anki buttons if available
        let hasButtons = !audioButtonHTML.isEmpty || !ankiButtonHTML.isEmpty
        let headerSectionHTML: String = if hasButtons {
            """
            <div class=\"popup-term-header-wrapper\">
                \(headerHTML)
                \(audioButtonHTML)\(ankiButtonHTML)
            </div>
            """
        } else {
            headerHTML
        }

        // Generate tags HTML
        let tagsHTML = termGroup.termTags.isEmpty ? "" : """
        <div class=\"popup-term-tags\">
        \(termGroup.termTags.map { "<span class=\"tag tag-category-\($0.category.escapeHTML())\">\($0.name.escapeHTML())</span>" }.joined(separator: ""))
        </div>
        """

        // Generate deinflection info HTML
        let deinflectionHTML = termGroup.deinflectionInfo.map { info in
            """
            <div class=\"popup-deinflection-info\">\(info.escapeHTML())</div>
            """
        } ?? ""

        let frequencyHTML = termFrequencyHTML(for: termGroup, compactOnly: true)

        // Generate pitch results area (compact for popup)
        let pitchHTML = pitchResultsAreaHTML(for: termGroup, compactOnly: true)

        let expressionEscaped = termGroup.expression.escapeHTML()
        return """
        <div class=\"popup-term-group\" data-term-key=\"\(termGroup.termKey.escapeHTML())\" data-expression=\"\(expressionEscaped)\">
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
                let dictionaryTitleEsc = dictionaryResult.dictionaryTitle.escapeHTML()

                return """
                <div class=\"popup-dictionary-section\" data-dictionary=\"\(dictionaryTitleEsc)\">
                    <h3 class=\"popup-dictionary-header\">\(defTagsHTML)\(dictionaryTitleEsc)</h3>
                    <div class=\"popup-dictionary-content\">
                        \(dictionaryResult.combinedHTML)
                    </div>
                </div>
                """
            }.joined())
        </div>
        """
    }

    public static func dictionaryStylesHTML(
        for results: [GroupedSearchResults],
        stylesheetProvider: (UUID) -> String?
    ) -> String {
        let dictionaries = results.flatMap(\.dictionariesResults)
        let styleInfos = dictionaries.map { DictionaryStyleInfo(id: $0.dictionaryUUID, title: $0.dictionaryTitle) }
        return dictionaryStylesHTML(for: styleInfos, stylesheetProvider: stylesheetProvider)
    }

    public static func dictionaryStylesHTML(
        for dictionaries: [DictionaryStyleInfo],
        stylesheetProvider: (UUID) -> String?
    ) -> String {
        let scopedStyles = dictionaryStylesCSS(for: dictionaries, stylesheetProvider: stylesheetProvider)
        guard !scopedStyles.isEmpty else { return "" }

        return """
        <style id=\"dictionary-styles\">
        \(scopedStyles)
        </style>
        """
    }

    public static func dictionaryStylesCSS(
        for dictionaries: [DictionaryStyleInfo],
        stylesheetProvider: (UUID) -> String?
    ) -> String {
        var seen: Set<UUID> = []
        var scopedStyles: [String] = []

        for dictionary in dictionaries {
            guard seen.insert(dictionary.id).inserted else { continue }
            guard let stylesheet = stylesheetProvider(dictionary.id) else { continue }

            // Sanitize to prevent script injection (GHSA-g3p8-q34q-x686)
            let sanitizedStylesheet = CSSSanitizer.sanitize(stylesheet)

            let trimmedStylesheet = sanitizedStylesheet.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedStylesheet.isEmpty else { continue }

            let escapedTitle = dictionary.title.cssEscape()
            scopedStyles.append("""
            [data-dictionary=\"\(escapedTitle)\"] {
            \(trimmedStylesheet)
            }
            """)
        }

        return scopedStyles.joined(separator: "\n")
    }

    public static func loadDictionaryStylesheet(for dictionaryID: UUID) -> String? {
        guard let appGroupDir = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: DictionaryPersistenceController.appGroupIdentifier
        ) else {
            return nil
        }

        let stylesheetURL = appGroupDir
            .appendingPathComponent("Media", isDirectory: true)
            .appendingPathComponent(dictionaryID.uuidString, isDirectory: true)
            .appendingPathComponent("styles.css", isDirectory: false)

        guard (try? stylesheetURL.checkResourceIsReachable()) == true else {
            return nil
        }

        guard let data = try? Data(contentsOf: stylesheetURL) else {
            return nil
        }

        return String(decoding: data, as: UTF8.self)
    }

    private func renderResults(groups: [GroupedSearchResults]) async -> String {
        await withTaskGroup(of: (Int, String).self) { group in
            for (index, termGroup) in groups.enumerated() {
                group.addTask {
                    (index, termGroupHTML(termGroup))
                }
            }

            var orderedHTML = Array(repeating: "", count: groups.count)
            for await (index, html) in group {
                orderedHTML[index] = html
            }
            return orderedHTML.joined()
        }
    }

    private func renderPopup(groups: [GroupedSearchResults]) -> String {
        groups.map { popupTermGroupHTML($0) }.joined()
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

        let displayValue = firstFreq.displayString.escapeHTML()
        var buttonTitle = firstFreq.dictionaryTitle.escapeHTML()
        if let mode = firstFreq.mode {
            buttonTitle += ": \(mode.escapeHTML())"
        }

        if compactOnly {
            // Popup: just show the button, no expansion
            return """
            <div class=\"frequency-display\">
                <button type=\"button\" class=\"freq-button\" title=\"\(buttonTitle)\" aria-expanded=\"false\" disabled>\(displayValue)</button>
            </div>
            """
        }

        // Full: expandable with all frequency details
        let freqItemsHTML = sortedFrequencies.map { freq in
            let itemTitle = freq.dictionaryTitle.escapeHTML()
            let itemMode = freq.mode ?? "rank-based (auto)"
            let itemTitleWithMode = itemTitle + ": \(itemMode.escapeHTML())"
            return "<span class=\"freq-item\" title=\"\(itemTitleWithMode)\">\(itemTitle): \(freq.displayString.escapeHTML())</span>"
        }.joined(separator: "<span class=\"freq-separator\">·</span>")

        return """
        <div class=\"frequency-display\">
            <button type=\"button\" class=\"freq-button\" title=\"\(buttonTitle)\" aria-expanded=\"false\" aria-label=\"\(String(localized: "dictionary.frequencyDetails.show", bundle: .framework))\">\(displayValue)</button>
            <div class=\"freq-expanded\">
                \(freqItemsHTML)
            </div>
        </div>
        """
    }

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

    /// Generates an audio button placeholder for async lookup.
    private func audioButtonHTML(
        term: String,
        reading: String?,
        pitchPosition: String? = nil,
        role: String? = nil,
        requireExactMatch: Bool = false,
        extraClasses: [String] = []
    ) -> String {
        let termEscaped = term.escapeHTML()
        let readingEscaped = (reading ?? "").escapeHTML()
        let classes = (["audio-button"] + extraClasses).joined(separator: " ")

        var attributes = [
            "type=\"button\"",
            "class=\"\(classes)\"",
            "data-audio-term=\"\(termEscaped)\"",
            "data-audio-reading=\"\(readingEscaped)\"",
            "data-state=\"disabled\"",
            "aria-disabled=\"true\"",
            "aria-label=\"\(String(localized: "dictionary.audio.play", bundle: .framework))\"",
        ]

        if let pitchPosition {
            attributes.append("data-audio-pitch=\"\(pitchPosition.escapeHTML())\"")
        }

        if let role {
            attributes.append("data-audio-role=\"\(role.escapeHTML())\"")
        }

        if requireExactMatch {
            attributes.append("data-audio-require-exact=\"true\"")
        }

        return "<button \(attributes.joined(separator: " "))></button>"
    }

    /// Generates an Anki button HTML element for the given term group.
    private func ankiButtonHTML(for termGroup: GroupedSearchResults) -> String {
        let termKey = termGroup.termKey.escapeHTML()
        let expression = termGroup.expression.escapeHTML()
        let reading = (termGroup.reading ?? "").escapeHTML()

        return """
        <button type=\"button\" class=\"anki-button\" data-term-key=\"\(termKey)\" data-expression=\"\(expression)\" data-reading=\"\(reading)\" data-state=\"disabled\" aria-disabled=\"true\" aria-label=\"\(String(localized: "dictionary.anki.add", bundle: .framework))\" hidden></button>
        """
    }

    /// Generates the expandable audio sources area HTML for a term group.
    /// This area is hidden by default and revealed by long-pressing the main audio button.
    private func audioSourcesAreaHTML(for termGroup: GroupedSearchResults) -> String {
        let termEscaped = termGroup.expression.escapeHTML()
        let readingEscaped = (termGroup.reading ?? "").escapeHTML()

        return """
        <div class=\"audio-sources-area\" hidden data-audio-term=\"\(termEscaped)\" data-audio-reading=\"\(readingEscaped)\">
            <div class=\"audio-sources-list\"></div>
        </div>
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
    private func pitchResultsAreaHTML(
        for termGroup: GroupedSearchResults,
        compactOnly: Bool = false,
        includeAudio: Bool = false
    ) -> String {
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

                // Add audio button placeholder for this specific pitch
                if includeAudio {
                    let pitchPositionString: String? = switch pitch.position {
                    case let .mora(pos): String(pos)
                    case .pattern: nil
                    }

                    itemHTML += audioButtonHTML(
                        term: termGroup.expression,
                        reading: termGroup.reading,
                        pitchPosition: pitchPositionString,
                        requireExactMatch: true
                    )
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
            html += "<span class=\"pitch-results-label\">\(String(localized: "dictionary.pitch.label", bundle: .framework))</span>"
            if showToggle {
                html += """
                <button type=\"button\" class=\"pitch-toggle\" data-expanded=\"false\" aria-label=\"\(String(localized: "dictionary.pitchResults.showMore", bundle: .framework))\">+</button>
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
    private func termHeaderHTML(
        for termGroup: GroupedSearchResults,
        cssClass: String,
        includeAudio: Bool = false,
        includeAnki: Bool = false,
        includeAudioSourcesArea: Bool = false
    ) -> String {
        let expression = termGroup.expression.escapeHTML()

        // Generate audio button placeholder if requested
        let audioHTML: String
        if includeAudio {
            let primaryPitch = primaryPitchPositionString(for: termGroup)
            audioHTML = audioButtonHTML(
                term: termGroup.expression,
                reading: termGroup.reading,
                pitchPosition: primaryPitch,
                role: "primary"
            )
        } else {
            audioHTML = ""
        }

        // Generate Anki button if requested and enabled
        let ankiHTML = includeAnki ? ankiButtonHTML(for: termGroup) : ""

        // Generate audio sources area if requested
        let audioSourcesHTML = includeAudioSourcesArea ? audioSourcesAreaHTML(for: termGroup) : ""

        // Build header content (expression + optional reading)
        let headerContent: String
        if let reading = termGroup.reading, !reading.isEmpty {
            let readingHTML: String = if styles.pitchDownstepNotationInHeaderEnabled,
                                         let firstPitchResult = termGroup.pitchAccentResults.first,
                                         let firstPitch = firstPitchResult.pitches.first
            {
                generatePitchNotationHTML(reading: reading, pitchAccent: firstPitch)
            } else {
                reading.escapeHTML()
            }
            headerContent = "\(expression) [\(readingHTML)]"
        } else {
            headerContent = expression
        }

        // If we have buttons, use container layout for right alignment
        let hasButtons = !audioHTML.isEmpty || !ankiHTML.isEmpty
        if hasButtons {
            return """
            <div class=\"term-header-container\">
                <div class=\"term-header-content\">
                    <h2 class=\"\(cssClass)\">\(headerContent)</h2>
                </div>
                <div class=\"term-header-buttons\">
                    \(audioHTML)\(ankiHTML)
                </div>
                \(audioSourcesHTML)
            </div>
            """
        }

        return "<h2 class=\"\(cssClass)\">\(headerContent)</h2>"
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
