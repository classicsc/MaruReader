//
//  ConfigurableProfileTemplate.swift
//  MaruAnki
//
//  Defines configurable profile templates that require user input.
//

import Foundation

/// Card types supported by the Lapis notetype.
public enum LapisCardType: String, CaseIterable, Codable, Sendable {
    case vocabularyCard = ""
    case wordAndSentenceCard = "IsWordAndSentenceCard"
    case clickCard = "IsClickCard"
    case sentenceCard = "IsSentenceCard"
    case audioCard = "IsAudioCard"

    public var displayName: String {
        switch self {
        case .vocabularyCard:
            "Vocabulary Card (Default)"
        case .wordAndSentenceCard:
            "Word + Sentence Card"
        case .clickCard:
            "Click Card"
        case .sentenceCard:
            "Sentence Card"
        case .audioCard:
            "Audio Card"
        }
    }

    /// The Anki field name for this card type, or nil for default vocab cards.
    public var fieldName: String? {
        let raw = rawValue
        return raw.isEmpty ? nil : raw
    }
}

/// Configuration requirements that a template may have.
public enum ConfigurationRequirement: Sendable {
    case mainDefinitionDictionary
    case cardType(options: [LapisCardType])
}

/// A configurable profile template that requires user input before use.
public struct ConfigurableProfileTemplate: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let baseFieldMap: AnkiFieldMap
    public let requiredConfiguration: [ConfigurationRequirement]

    public init(
        id: String,
        displayName: String,
        baseFieldMap: AnkiFieldMap,
        requiredConfiguration: [ConfigurationRequirement]
    ) {
        self.id = id
        self.displayName = displayName
        self.baseFieldMap = baseFieldMap
        self.requiredConfiguration = requiredConfiguration
    }

    /// Builds a complete field map by applying user configuration to the base map.
    public func buildFieldMap(
        mainDefinitionDictionaryID: UUID?,
        cardType: LapisCardType
    ) -> AnkiFieldMap {
        var map = baseFieldMap.map

        // Add MainDefinition with selected dictionary
        if let dictionaryID = mainDefinitionDictionaryID {
            map["MainDefinition"] = [.singleDictionaryGlossary(dictionaryID: dictionaryID)]
        }

        // Add card type field if not default
        if let fieldName = cardType.fieldName {
            map[fieldName] = [.customHTMLValue(value: "x")]
        }

        return AnkiFieldMap(map: map)
    }
}

/// Available configurable profile templates.
public enum ConfigurableProfileTemplates {
    /// The Lapis notetype template.
    public static let lapis = ConfigurableProfileTemplate(
        id: "lapis",
        displayName: "Lapis",
        baseFieldMap: lapisBaseFieldMap,
        requiredConfiguration: [
            .mainDefinitionDictionary,
            .cardType(options: LapisCardType.allCases),
        ]
    )

    /// All available configurable templates.
    public static let all: [ConfigurableProfileTemplate] = [lapis]

    /// Finds a template by ID.
    public static func template(for id: String) -> ConfigurableProfileTemplate? {
        all.first { $0.id == id }
    }

    private static var lapisBaseFieldMap: AnkiFieldMap {
        AnkiFieldMap(map: [
            "Expression": [.expression],
            "ExpressionFurigana": [.furigana],
            "ExpressionReading": [.reading],
            "ExpressionAudio": [.pronunciationAudio],
            "SelectionText": [.clozeBody],
            // MainDefinition configured by user
            "Sentence": [
                .clozePrefix,
                .customHTMLValue(value: "<b>"),
                .clozeBody,
                .customHTMLValue(value: "</b>"),
                .clozeSuffix,
            ],
            "SentenceFurigana": [
                .clozeFuriganaPrefix,
                .customHTMLValue(value: "<b>"),
                .clozeFuriganaBody,
                .customHTMLValue(value: "</b>"),
                .clozeFuriganaSuffix,
            ],
            "Picture": [.screenshot],
            "Glossary": [.multiDictionaryGlossary],
            "PitchPosition": [.pitchAccentList],
            "PitchCategories": [.pitchAccentCategories],
            "Frequency": [.frequencyList],
            "FreqSort": [.frequencyRankHarmonicMeanSortField],
            "MiscInfo": [.documentTitle],
            // Is...Card fields configured by user
        ])
    }
}
