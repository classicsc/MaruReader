//
//  ConfiguredProfileData.swift
//  MaruAnki
//
//  Stores user configuration choices for a template-based profile.
//

import Foundation

/// Stores the user's configuration choices for a configurable profile template.
/// This is encoded as JSON and stored in `MaruModelSettings.templateConfiguration`.
public struct ConfiguredProfileData: Codable, Sendable {
    public let templateID: String
    public let mainDefinitionDictionaryID: UUID?
    public let cardType: String?

    public init(
        templateID: String,
        mainDefinitionDictionaryID: UUID?,
        cardType: LapisCardType?
    ) {
        self.templateID = templateID
        self.mainDefinitionDictionaryID = mainDefinitionDictionaryID
        self.cardType = cardType?.rawValue
    }

    /// The card type as a LapisCardType enum value.
    public var lapisCardType: LapisCardType? {
        guard let cardType else { return nil }
        return LapisCardType(rawValue: cardType)
    }
}
