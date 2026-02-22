// DisplayStyles.swift
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

public struct DisplayStyles: Sendable, Codable {
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

public struct DictionaryWebTheme: Sendable, Codable, Equatable {
    public let colorScheme: String?
    public let textColor: String?
    public let backgroundColor: String?
    public let accentColor: String?
    public let linkColor: String?
    public let glossImageBackgroundColor: String?

    public init(
        colorScheme: String? = nil,
        textColor: String? = nil,
        backgroundColor: String? = nil,
        accentColor: String? = nil,
        linkColor: String? = nil,
        glossImageBackgroundColor: String? = nil
    ) {
        self.colorScheme = colorScheme
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.linkColor = linkColor
        self.glossImageBackgroundColor = glossImageBackgroundColor
    }
}
